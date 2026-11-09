class_name Rifle
extends Node3D
## Bolt-action rifle (SPEC 4.5): ready -> cycling (1.15 s bolt) -> ready/empty, a round-by-round
## reload that firing can interrupt after one round, hitscan with spread, recoil, muzzle flash.
## Gameplay timers run in _physics_process; the visual kick spring runs in _process.

signal ammo_changed
signal shot_fired
## A shot hit an enemy: "lit" (hurt it), "kill" (lit and it died) or "dark" (immune, deflected).
signal hit_marker(kind: String)

@export var mag_size: int = 5
@export var start_reserve: int = 10
@export var max_reserve: int = 25
@export var shot_range: float = 150.0
@export var damage_lit: float = 100.0
@export var damage_dark: float = 0.0
@export var spread_hip_deg: float = 1.5
@export var spread_ads_deg: float = 0.2
@export_group("Bolt cycle")
@export var bolt_up: float = 0.15
@export var bolt_back: float = 0.25
@export var bolt_forward: float = 0.25
@export var bolt_down: float = 0.15
@export var bolt_settle: float = 0.35
@export var bolt_lift_deg: float = 80.0
@export var bolt_travel: float = 0.08
@export_group("Reload")
@export var reload_open: float = 0.45
@export var reload_per_round: float = 0.5
@export var reload_close: float = 0.45
@export_group("Recoil")
@export var recoil_pitch_deg: float = 5.5
@export var recoil_yaw_deg: float = 1.5
@export var shot_trauma: float = 0.12
@export var kick_back: float = 0.12
@export var kick_back_ads_scale: float = 0.2   ## ADS: the camera sits just behind the scope, so the rifle barely slides back
@export var kick_rot_deg: float = 12.0
@export var kick_spring: float = 18.0
@export var kick_damping: float = 0.7
@export_group("Muzzle flash")
@export var flash_time: float = 0.06
@export var flash_light_color: Color = Color(1.0, 0.66, 0.35)
@export var flash_light_energy: float = 14.0
@export var flash_light_range: float = 10.0
@export var flash_fog_energy: float = 3.0
@export var flash_color: Color = Color(1.0, 0.85, 0.60)
@export var flash_energy: float = 9.0
@export var flash_core_energy: float = 40.0
@export var flash_axis_roll: float = -0.45   ## radians: barrel direction on screen from the hip pose

## "ready", "cycling", "reloading", "empty" ("switching" is reported by WeaponHolder)
var state: String = "ready"
var mag: int = 5
var reserve: int = 10
var shots_fired: int = 0
var hits_lit: int = 0
var hits_dark: int = 0
## 0..1: how far the rifle is aimed down sights (set by WeaponHolder).
var ads_amount: float = 0.0
## 0..1: how far the rifle is tipped for the reload animation (read by WeaponHolder if wanted).
var reload_pose: float = 0.0

var _camera: PlayerCamera
var _player: Player
var _field: LightField
var _audio: Soundscape
var _model: Node3D
var _bolt: Node3D
var _right_hand: Node3D
var _muzzle: Marker3D
var _bolt_base: Vector3
var _cycle_t: float = 0.0
var _cycle_len: float = 1.15
var _cycle_clacked: bool = false
var _reload_phase: String = ""     ## "open", "load", "close"
var _reload_t: float = 0.0
var _reload_loaded: int = 0
var _fire_queued: bool = false
var _flash_left: float = 0.0
var _flash: Node3D
var _flash_light: OmniLight3D
var _smoke: GPUParticles3D
var _kick: float = 0.0
var _kick_v: float = 0.0
var _bolt_open: float = 0.0       ## 0..1 visual bolt openness


func setup(camera: PlayerCamera, player: Player, field: LightField, audio: Soundscape) -> void:
	_camera = camera
	_player = player
	_field = field
	_audio = audio


func _ready() -> void:
	mag = mag_size
	reserve = start_reserve
	_cycle_len = bolt_up + bolt_back + bolt_forward + bolt_down + bolt_settle
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var gun: Node3D = ViewmodelBuilder.rifle()
	_model.add_child(gun)
	_model.add_child(ViewmodelBuilder.rifle_left_arm())
	_right_hand = ViewmodelBuilder.rifle_right_hand()
	_model.add_child(_right_hand)
	_bolt = gun.get_node("Bolt") as Node3D
	_bolt_base = _bolt.position
	_muzzle = gun.get_node("Muzzle") as Marker3D
	_build_flash()


# --- commands (from WeaponHolder) -------------------------------------------------------------

func can_fire() -> bool:
	return state == "ready" and mag > 0


## Returns true if a shot was fired. `ads` picks the spread.
func try_fire(ads: bool) -> bool:
	if state == "reloading":
		if _reload_loaded >= 1:
			_fire_queued = true
			if _reload_phase != "close":
				_begin_close()
		return false
	if state == "empty" or (state == "ready" and mag <= 0):
		_audio.play_reload_click()  # dry click
		return false
	if state != "ready":
		return false
	_shoot(ads)
	return true


func try_reload() -> void:
	if state != "ready" and state != "empty":
		return
	if mag >= mag_size or reserve <= 0:
		return
	state = "reloading"
	_reload_phase = "open"
	_reload_t = 0.0
	_reload_loaded = 0
	_fire_queued = false
	_audio.play_reload_click()


## Called when the weapon is put away: a reload stops, rounds loaded so far stay.
func cancel_reload() -> void:
	if state == "reloading":
		_reload_phase = ""
		_fire_queued = false
		reload_pose = 0.0
		_bolt_open = 0.0
		state = "ready" if mag > 0 else "empty"
		ammo_changed.emit()


func add_reserve(amount: int) -> void:
	reserve = mini(reserve + amount, max_reserve)
	ammo_changed.emit()


# --- state machine ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false
			_flash_light.visible = false
	match state:
		"cycling":
			_tick_cycle(delta)
		"reloading":
			_tick_reload(delta)
	_animate_bolt()


func _shoot(ads: bool) -> void:
	mag -= 1
	shots_fired += 1
	state = "cycling"
	_cycle_t = 0.0
	_cycle_clacked = false
	_audio.play_rifle_crack()
	_camera.add_recoil(recoil_pitch_deg, GameRng.randf_range(-recoil_yaw_deg, recoil_yaw_deg))
	_camera.add_trauma(shot_trauma)
	_kick = 1.0
	_kick_v = 0.0
	_fire_flash()
	_hitscan(ads)
	ammo_changed.emit()
	shot_fired.emit()


func _tick_cycle(delta: float) -> void:
	_cycle_t += delta
	if not _cycle_clacked and _cycle_t >= bolt_up:
		_cycle_clacked = true
		_audio.play_bolt()
	if _cycle_t >= _cycle_len:
		state = "ready" if mag > 0 else "empty"
		_bolt_open = 0.0
		ammo_changed.emit()


func _tick_reload(delta: float) -> void:
	_reload_t += delta
	match _reload_phase:
		"open":
			reload_pose = clampf(_reload_t / reload_open, 0.0, 1.0)
			if _reload_t >= reload_open:
				_reload_phase = "load"
				_reload_t = 0.0
				if mag >= mag_size or reserve <= 0:
					_begin_close()
		"load":
			if _reload_t >= reload_per_round:
				_reload_t -= reload_per_round
				mag += 1
				reserve -= 1
				_reload_loaded += 1
				_audio.play_reload_click()
				ammo_changed.emit()
				if mag >= mag_size or reserve <= 0:
					_begin_close()
		"close":
			reload_pose = 1.0 - clampf(_reload_t / reload_close, 0.0, 1.0)
			if _reload_t >= reload_close:
				_reload_phase = ""
				reload_pose = 0.0
				state = "ready" if mag > 0 else "empty"
				_audio.play_bolt()
				ammo_changed.emit()
				if _fire_queued:
					_fire_queued = false
					if state == "ready" and (_player == null or not _player.sprinting):
						_shoot(false)


func _begin_close() -> void:
	_reload_phase = "close"
	_reload_t = 0.0


# --- hitscan ----------------------------------------------------------------------------------

func _hitscan(ads: bool) -> void:
	var cam_xf: Transform3D = _camera.global_transform
	var spread: float = deg_to_rad(spread_ads_deg if ads else spread_hip_deg)
	var ang: float = spread * sqrt(GameRng.randf())
	var rot: float = GameRng.randf() * TAU
	var dir: Vector3 = (-cam_xf.basis.z).rotated(cam_xf.basis.x, ang * sin(rot)).rotated(cam_xf.basis.y, ang * cos(rot)).normalized()
	var from: Vector3 = cam_xf.origin
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * shot_range, 1 | 4, [_player.get_rid()])
	q.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var target: Node = hit["collider"] as Node
	while target != null and not target.has_method("on_rifle_hit"):
		target = target.get_parent()
	if target == null:
		return
	var point: Vector3 = hit["position"]
	var info: Dictionary = _field.query(point) if _field != null else {"shootable": false}
	var shootable: bool = bool(info["shootable"])
	# The target may widen the verdict (a lit Drowned is hurt anywhere on its body).
	if target.has_method("hit_shootable"):
		shootable = bool(target.call("hit_shootable", shootable))
	var was_alive: bool = not target.has_method("is_alive") or bool(target.call("is_alive"))
	if shootable:
		hits_lit += 1
	else:
		hits_dark += 1
	target.call("on_rifle_hit", point, dir, shootable, damage_lit if shootable else damage_dark)
	var killed: bool = was_alive and target.has_method("is_alive") and not bool(target.call("is_alive"))
	if shootable:
		hit_marker.emit("kill" if killed else "lit")
	else:
		_audio.play_deflect()
		hit_marker.emit("dark")


# --- visuals ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Damped spring pulls the shot kick back to rest.
	var accel: float = -kick_spring * kick_spring * _kick - 2.0 * kick_damping * kick_spring * _kick_v
	_kick_v += accel * delta
	_kick += _kick_v * delta
	var tilt: float = reload_pose
	_right_hand.visible = ads_amount < 0.5   # in ADS the grip hand sits behind the camera
	_model.position = Vector3(0.0, 0.0, kick_back * lerpf(1.0, kick_back_ads_scale, ads_amount) * _kick) + Vector3(-0.02, 0.01, 0.0) * tilt
	_model.rotation_degrees = Vector3(kick_rot_deg * _kick + 14.0 * tilt, 0.0, -18.0 * tilt)


func _animate_bolt() -> void:
	var lift: float = 0.0
	var back: float = 0.0
	if state == "cycling":
		var t: float = _cycle_t
		if t < bolt_up:
			lift = t / bolt_up
		elif t < bolt_up + bolt_back:
			lift = 1.0
			back = (t - bolt_up) / bolt_back
		elif t < bolt_up + bolt_back + bolt_forward:
			lift = 1.0
			back = 1.0 - (t - bolt_up - bolt_back) / bolt_forward
		elif t < bolt_up + bolt_back + bolt_forward + bolt_down:
			lift = 1.0 - (t - bolt_up - bolt_back - bolt_forward) / bolt_down
	elif state == "reloading":
		lift = reload_pose
		back = reload_pose
	_bolt_open = lift
	_bolt.rotation_degrees.z = bolt_lift_deg * lift
	_bolt.position = _bolt_base + Vector3(0.0, 0.0, bolt_travel * back)


func _fire_flash() -> void:
	_flash.visible = true
	_flash.rotation.z = GameRng.randf_range(-0.15, 0.15)
	_flash_light.visible = true
	_flash_left = flash_time
	_smoke.restart()
	_smoke.emitting = true


func muzzle_position() -> Vector3:
	return _muzzle.global_position


func _build_flash() -> void:
	var tex: GradientTexture2D = GradientTexture2D.new()
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.35, Color(1, 1, 1, 0.9))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = flash_color
	mat.albedo_texture = tex
	mat.emission_enabled = true
	mat.emission = flash_color
	mat.emission_texture = tex
	mat.emission_energy_multiplier = flash_energy
	mat.no_depth_test = false
	_flash = Node3D.new()
	_flash.name = "MuzzleFlash"
	_flash.visible = false
	_muzzle.add_child(_flash)
	var core_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
	core_mat.emission_energy_multiplier = flash_core_energy
	# One tapered spike along the barrel's on-screen axis (hip view: up and to the left), two
	# side petals and a hot core.
	var shapes: Array[Dictionary] = [
		{"size": Vector2(0.36, 0.07), "z": -0.05, "roll": flash_axis_roll},
		{"size": Vector2(0.13, 0.03), "z": -0.04, "roll": flash_axis_roll + 0.4},
		{"size": Vector2(0.13, 0.03), "z": -0.04, "roll": flash_axis_roll - 0.4},
		{"size": Vector2(0.10, 0.10), "z": -0.02, "roll": 0.0, "core": true},
	]
	for sh: Dictionary in shapes:
		var q: QuadMesh = QuadMesh.new()
		q.size = sh["size"] as Vector2
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = core_mat if sh.has("core") else mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.z = float(sh["z"])
		mi.rotation.z = float(sh["roll"])
		_flash.add_child(mi)
	_flash_light = OmniLight3D.new()
	_flash_light.name = "FlashLight"
	_flash_light.light_color = flash_light_color
	_flash_light.light_energy = flash_light_energy
	_flash_light.omni_range = flash_light_range
	_flash_light.shadow_enabled = false
	_flash_light.light_volumetric_fog_energy = flash_fog_energy
	_flash_light.position.z = -0.12
	_flash_light.visible = false
	_muzzle.add_child(_flash_light)

	_smoke = GPUParticles3D.new()
	_smoke.name = "MuzzleSmoke"
	_smoke.amount = 6
	_smoke.lifetime = 1.4
	_smoke.one_shot = true
	_smoke.explosiveness = 1.0
	_smoke.emitting = false
	_smoke.local_coords = false
	_smoke.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 0.0, -1.0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0.0, 0.25, 0.0)
	pm.damping_min = 0.6
	pm.damping_max = 1.0
	pm.scale_min = 0.4
	pm.scale_max = 0.7
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0.0, 0.3))
	sc.add_point(Vector2(1.0, 1.0))
	var sct: CurveTexture = CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	_smoke.process_material = pm
	var smat: StandardMaterial3D = StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.vertex_color_use_as_albedo = true
	smat.albedo_color = Color(0.5, 0.5, 0.52, 0.45)
	smat.albedo_texture = tex
	smat.roughness = 1.0
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = smat
	_smoke.draw_pass_1 = quad
	_muzzle.add_child(_smoke)
