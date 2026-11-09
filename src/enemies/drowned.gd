class_name Drowned
extends Node3D
## One of the Drowned (SPEC 4.8): rises out of the sea, glides (no walk cycle) toward the lighthouse door
## or a nearby player, is hurt and slowed only while LightField says it stands in light, and is much
## faster in the dark. Reaching the player or the tower costs 1 HP and it dissolves.

@export var max_hp: float = 100.0
@export var base_speed: float = 2.4
@export var dark_mult: float = 1.35
@export var lit_mult: float = 0.35
@export var speed_response: float = 4.0
@export var turn_rate_deg: float = 90.0
@export var separation: float = 1.5
@export var hover_height: float = 0.25
@export var bob_amp: float = 0.08
@export var bob_hz: float = 0.6
@export var lean_deg: float = 8.0
@export var emerge_time: float = 2.5
@export var emerge_depth: float = 1.8
@export var aggro_radius: float = 25.0
@export var contact_radius: float = 1.3
@export var tower_radius: float = 3.6
@export var dissolve_time: float = 1.2
@export var sink_depth: float = 0.6
@export var dawn_sink_depth: float = 1.9   ## dawn: sink under the surface, not a twitch
@export var trail_step: float = 0.9
@export var moan_first: Vector2 = Vector2(0.0, 3.0)
@export var moan_interval: Vector2 = Vector2(6.0, 14.0)
@export var chest_height: float = 1.35
@export_group("Light reaction")
@export var lit_shudder_amp: float = 0.02
@export var lit_shudder_hz: float = 14.0
@export var lit_flutter_mult: float = 1.6
@export var dark_hit_shudder_time: float = 0.25
@export var dark_hit_shudder_amp: float = 0.04
@export var drag_factor: float = 0.12
@export var drip_rate: float = 12.0
@export var frozen_drag_speed: float = 0.7   ## fraction of base_speed the hem trails by while frozen
@export_group("Dark hits")
@export var dark_hit_damage: float = 35.0     ## live play: a rifle hit on an unlit Drowned still hurts (3 shots)...
@export var dark_knockback: float = 1.4       ## ...and shoves it back this far (metres, over knock_time)
@export var knock_time: float = 0.25
@export_group("Hitbox")
@export var hitbox_radius: float = 0.58
@export var hitbox_height: float = 2.15
@export var hitbox_center_y: float = 1.05
@export var shoulder_box: Vector3 = Vector3(1.10, 0.75, 0.65)   ## cloak + sleeves
@export var shoulder_y: float = 1.35
@export_group("Searing (lit)")
@export var sear_response: float = 6.0       ## 1/s: how fast the ember glow rises and fades
@export var sear_face_energy: float = 0.9
@export var sear_eye_energy: float = 3.0
@export var sear_color: Color = Color(1.0, 0.55, 0.22)
@export var steam_amount: int = 16
@export var steam_lifetime: float = 1.6

var id: int = 0
var hp: float = 100.0
## "emerging", "gliding", "dying"
var state: String = "gliding"
var speed: float = 0.0
var lit: bool = false
var revealed: bool = false
var dying_by: String = ""   ## "rifle", "light", "contact", "dawn" once dying

var _hub: Enemies
var _heading: float = 0.0
var _body: Node3D
var _cloth: Array[MeshInstance3D] = []
var _hitbox: Area3D
var _drips: GPUParticles3D
var _steam: GPUParticles3D
var _glow_mats: Array[StandardMaterial3D] = []
var _glow_is_eye: Array[bool] = []
var _knock: Vector3 = Vector3.ZERO   ## remaining knockback displacement (m)
var _sear: float = 0.0   ## 0..1 smoothed "searing in the light" amount
var _age: float = 0.0
var _state_t: float = 0.0
var _moan_t: float = 0.0
var _time_offset: float = 0.0
var _shudder_left: float = 0.0
var _trail_dist: float = 0.0
var _vel: Vector3 = Vector3.ZERO
var _flutter: float = 1.0
var _spawn_xz: Vector2 = Vector2.ZERO
var _dissolve_len: float = 1.2
var _sink_len: float = 0.6


func setup(hub: Enemies, enemy_id: int, xz: Vector2, emerged: bool) -> void:
	_hub = hub
	id = enemy_id
	hp = max_hp
	_spawn_xz = xz
	speed = base_speed
	var ground: float = _surface(xz.x, xz.y)
	position = Vector3(xz.x, ground + hover_height, xz.y)
	state = "gliding" if emerged else "emerging"
	_heading = _desired_heading(_target_point())


func _ready() -> void:
	_time_offset = GameRng.randf() * 20.0
	_moan_t = GameRng.randf_range(moan_first.x, moan_first.y)
	_body = DrownedBuilder.build()
	add_child(_body)
	_cloth = DrownedBuilder.cloth_instances(_body)
	for mi: MeshInstance3D in _cloth:
		mi.set_instance_shader_parameter("time_offset", _time_offset)
	for mi: Node in _body.get_children():
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_build_glow_materials()
	# Hitbox on the root (the rifle also runs an exact geometric test against the visual centre).
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.collision_layer = 4   # layer 3: enemy hitboxes
	_hitbox.collision_mask = 0
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = hitbox_radius
	shape.height = hitbox_height
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Body"
	cs.shape = shape
	cs.position.y = hitbox_center_y
	_hitbox.add_child(cs)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = shoulder_box
	var shoulders: CollisionShape3D = CollisionShape3D.new()
	shoulders.name = "Shoulders"
	shoulders.shape = box
	shoulders.position.y = shoulder_y
	_hitbox.add_child(shoulders)
	add_child(_hitbox)   # on the root, not _body: _body is animated every frame and would lag the physics broadphase
	_build_drips()
	_build_steam()
	rotation.y = _heading
	if state == "emerging":
		_body.position.y = -emerge_depth
		_hub.splash_at(Vector3(position.x, position.y - hover_height, position.z))


# --- queries ----------------------------------------------------------------------------------

func chest_position() -> Vector3:
	return global_position + Vector3(0.0, chest_height, 0.0)


func is_alive() -> bool:
	return state != "dying"


func telemetry() -> Dictionary:
	var p: Vector3 = global_position
	return {
		"id": id,
		"pos": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
		"hp": snappedf(hp, 0.1),
		"lit": lit,
		"speed": snappedf(speed, 0.001),
		"state": state,
	}


## Offset of the animated visual body from the root (bob, shudder); the rifle's hit cylinder is centred on it.
func body_offset() -> Vector3:
	return _body.position if _body != null else Vector3.ZERO


## Whether a rifle hit hurts. `shootable` is LightField's verdict for the hit point itself; a lit Drowned (its
## chest is in light) is also hurt when the shot lands on the lower cloak or the back, where the ground can
## occlude a flare's light.
func hit_shootable(shootable: bool) -> bool:
	return shootable or lit or bool(_hub.field.query(chest_position())["shootable"])


## Called by Rifle._hitscan. `shootable` = LightField said the hit point is lit.
func on_rifle_hit(point: Vector3, dir: Vector3, shootable: bool, damage: float) -> void:
	if state == "dying":
		return
	if hit_shootable(shootable):
		hp -= maxf(damage, 0.0)
		if hp <= 0.0:
			_die("rifle")
			_hub.lethal_hit(point, dir)
		else:
			_shudder_left = dark_hit_shudder_time
	else:
		_shudder_left = dark_hit_shudder_time
		HitFx.dark_mist(_hub, point, dir)
		if not _hub.freeze:
			# Live play: darkness is not full immunity. Light is still the 3x multiplier (one shot kills in
			# light), but three shots in the dark kill too, and each one shoves the Drowned back.
			hp -= dark_hit_damage
			var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
			if flat.length() > 0.001:
				_knock = flat.normalized() * dark_knockback
			if hp <= 0.0:
				_die("rifle")
				_hub.lethal_hit(point, dir)
			else:
				HitFx.lethal_splash(_hub, point, dir)


# --- simulation -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_age += delta
	_state_t += delta
	_shudder_left = maxf(0.0, _shudder_left - delta)
	_moan_tick(delta)
	match state:
		"emerging":
			_tick_emerge()
		"gliding":
			_tick_glide(delta)
		"dying":
			_tick_dying()


func _moan_tick(delta: float) -> void:
	if state == "dying":
		return
	_moan_t -= delta
	if _moan_t <= 0.0:
		_moan_t = GameRng.randf_range(moan_interval.x, moan_interval.y)
		_hub.audio.play_moan(global_position + Vector3(0.0, 1.7, 0.0), GameRng.randi_range(0, 3))


func _tick_emerge() -> void:
	_update_light(0.0)
	var k: float = clampf(_state_t / emerge_time, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	_body.position.y = lerpf(-emerge_depth, 0.0, k)
	global_position.y = _surface(global_position.x, global_position.z) + hover_height
	if _state_t >= emerge_time:
		state = "gliding"
		_state_t = 0.0
		_body.position.y = 0.0


func _tick_glide(delta: float) -> void:
	_update_light(delta)
	if hp <= 0.0:
		_die("light")
		return
	var target: Vector3 = _target_point()
	var to_t: Vector3 = target - global_position
	to_t.y = 0.0
	var dir: Vector3 = to_t.normalized() if to_t.length() > 0.001 else Vector3.ZERO
	dir = (dir + _hub.separation_push(self, separation) * 1.2).normalized() if dir != Vector3.ZERO else dir
	if dir != Vector3.ZERO:
		var want: float = atan2(-dir.x, -dir.z)
		var diff: float = angle_difference(_heading, want)
		var max_turn: float = deg_to_rad(turn_rate_deg) * delta
		_heading += clampf(diff, -max_turn, max_turn)
	var target_speed: float = base_speed * (lit_mult if lit else dark_mult)
	speed = lerpf(target_speed, speed, exp(-speed_response * delta))
	if _hub.freeze:
		speed = 0.0
	var fwd: Vector3 = Vector3(-sin(_heading), 0.0, -cos(_heading))
	_vel = fwd * speed
	var step: Vector3 = _vel * delta
	global_position.x += step.x
	global_position.z += step.z
	if _knock != Vector3.ZERO:
		var left: Vector3 = _knock.move_toward(Vector3.ZERO, dark_knockback / maxf(knock_time, 0.01) * delta)
		global_position += _knock - left
		_knock = left
	global_position.y = _surface(global_position.x, global_position.z) + hover_height
	rotation.y = _heading
	_trail(step.length())
	_check_contacts()


func _update_light(delta: float) -> void:
	var info: Dictionary = _hub.field.query(chest_position())
	lit = bool(info["lit"])
	revealed = lit and _hub.field.reveal_active()
	var dps: float = float(info["dps"])
	if lit and dps > 0.0 and state == "gliding":
		hp -= dps * delta


func _target_point() -> Vector3:
	var pl: Player = _hub.player
	if pl != null and pl.is_alive():
		if Vector2(pl.global_position.x - position.x, pl.global_position.z - position.z).length() < aggro_radius:
			return pl.global_position
	return _hub.door_point


func _desired_heading(p: Vector3) -> float:
	var d: Vector3 = p - Vector3(_spawn_xz.x, 0.0, _spawn_xz.y)
	return atan2(-d.x, -d.z)


func _trail(moved: float) -> void:
	var gx: float = global_position.x
	var gz: float = global_position.z
	var land: float = _hub.island.height_at(gx, gz)
	if land < _hub.ocean.get_height(gx, gz) + 0.2:
		_trail_dist = 0.0
		return
	_trail_dist += moved
	if _trail_dist >= trail_step:
		_trail_dist = 0.0
		_hub.trails.stamp(Vector3(gx, land, gz), _heading)


func _check_contacts() -> void:
	var pl: Player = _hub.player
	var gp: Vector3 = global_position
	if pl != null and pl.is_alive():
		var d: float = Vector2(pl.global_position.x - gp.x, pl.global_position.z - gp.z).length()
		if d < contact_radius and absf(pl.global_position.y - gp.y) < 3.0:
			pl.take_hit()
			_die("contact")
			return
	if Vector2(gp.x, gp.z).length() < tower_radius:
		_hub.reached_lighthouse += 1
		_hub.lighthouse.gutter()
		if pl != null:
			pl.take_hit()
		_die("contact")


func _die(by: String) -> void:
	if state == "dying":
		return
	state = "dying"
	dying_by = by
	_state_t = 0.0
	speed = 0.0
	lit = false
	revealed = false
	_dissolve_len = dissolve_time
	_sink_len = sink_depth
	_hitbox.set_deferred("collision_layer", 0)
	_drips.emitting = false
	_hub.on_death(self, by)
	_hub.trails.puddle(Vector3(global_position.x, _hub.island.height_at(global_position.x, global_position.z), global_position.z))


## Dawn: sink and dissolve over `duration` seconds. Not a kill, not a contact.
func dissolve_away(duration: float) -> void:
	if state == "dying":
		return
	_die("dawn")
	_dissolve_len = duration
	_sink_len = dawn_sink_depth


func _tick_dying() -> void:
	var k: float = clampf(_state_t / _dissolve_len, 0.0, 1.0)
	for mi: MeshInstance3D in _cloth:
		mi.set_instance_shader_parameter("dissolve", k)
	_body.position.y = -_sink_len * k
	if _state_t >= _dissolve_len:
		_hub.forget(self)
		queue_free()


# --- visuals ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var t: float = _age
	var k: float = clampf(speed / (base_speed * dark_mult), 0.0, 1.0)
	var sh: Vector3 = Vector3.ZERO
	if state != "dying":
		_body.position.y = _body.position.y if state == "emerging" else bob_amp * sin(TAU * bob_hz * t + _time_offset)
	if lit or _shudder_left > 0.0:
		var amp: float = lit_shudder_amp if lit else 0.0
		if _shudder_left > 0.0:
			amp = maxf(amp, dark_hit_shudder_amp * (_shudder_left / dark_hit_shudder_time))
		var ph: float = TAU * lit_shudder_hz * t
		sh = Vector3(sin(ph), 0.0, cos(ph * 1.13)) * amp
	_body.position.x = sh.x
	_body.position.z = sh.z
	_body.rotation.x = -deg_to_rad(lean_deg) * k
	_flutter = lit_flutter_mult if lit else 1.0
	var vis_vel: Vector3 = _vel
	if _hub.freeze and state != "dying":
		# Frozen captures keep a pretend slow glide so the hem still trails behind.
		vis_vel = Vector3(-sin(_heading), 0.0, -cos(_heading)) * base_speed * frozen_drag_speed
	var local_drag: Vector3 = Basis(Vector3.UP, _heading).inverse() * (-vis_vel * drag_factor)
	for mi: MeshInstance3D in _cloth:
		mi.set_instance_shader_parameter("flutter_scale", _flutter)
		mi.set_instance_shader_parameter("drag_offset", local_drag)
	_update_sear(delta)


## Searing: while lit (so shootable) the cloak shows ember rim light and cracks, the face and eyes catch warm
## light and steam rises. The crack intensity grows as hp falls. Pure shading, no light node, so it is never a
## gameplay light source.
func _update_sear(delta: float) -> void:
	var want: float = 1.0 if (lit and state != "dying") else 0.0
	_sear = move_toward(_sear, want, sear_response * delta)
	var wear: float = clampf(1.0 - hp / maxf(max_hp, 0.001), 0.0, 1.0)
	for mi: MeshInstance3D in _cloth:
		mi.set_instance_shader_parameter("lit_amount", _sear)
		mi.set_instance_shader_parameter("damage_amount", wear)
	for i: int in _glow_mats.size():
		_glow_mats[i].emission_energy_multiplier = (sear_eye_energy if _glow_is_eye[i] else sear_face_energy) * _sear
	_steam.emitting = _sear > 0.05 and state != "dying"


func _build_glow_materials() -> void:
	for mi: MeshInstance3D in DrownedBuilder.glow_instances(_body):
		var m: StandardMaterial3D = (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.emission_enabled = true
		m.emission = sear_color
		m.emission_energy_multiplier = 0.0
		mi.material_override = m
		_glow_mats.append(m)
		_glow_is_eye.append(String(mi.get_meta("glow")) == "eye")


func _build_steam() -> void:
	_steam = GPUParticles3D.new()
	_steam.name = "Steam"
	_steam.amount = steam_amount
	_steam.lifetime = steam_lifetime
	_steam.local_coords = false
	_steam.emitting = false
	_steam.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	_steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.38
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.0, 0.35, 0.0)
	pm.damping_min = 0.3
	pm.damping_max = 0.6
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var grow: Curve = Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.4))
	var grow_tex: CurveTexture = CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	# Ember orange at birth, ashy grey as it cools, gone at the top.
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.55, 0.22, 0.0), Color(1.0, 0.55, 0.22, 0.5),
		Color(0.62, 0.58, 0.55, 0.28), Color(0.5, 0.5, 0.52, 0.0)])
	var ramp_tex: GradientTexture1D = GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	_steam.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = HitFx._soft()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.26, 0.26)
	quad.material = mat
	_steam.draw_pass_1 = quad
	_steam.position = Vector3(0.0, 1.55, 0.0)
	add_child(_steam)


func _build_drips() -> void:
	_drips = GPUParticles3D.new()
	_drips.name = "Drips"
	var life: float = 0.35
	_drips.amount = maxi(1, int(round(drip_rate * life)))
	_drips.lifetime = life
	_drips.local_coords = false
	_drips.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	_drips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.5
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.02
	pm.direction = Vector3.DOWN
	pm.spread = 5.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.0, -9.81, 0.0)
	_drips.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.55, 0.60, 0.66, 0.55)
	mat.roughness = 0.3
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.015, 0.07)
	quad.material = mat
	_drips.draw_pass_1 = quad
	_drips.position = Vector3(0.0, 0.08, 0.0)
	add_child(_drips)


## Highest of the island ground and the sea surface at (x, z).
func _surface(x: float, z: float) -> float:
	return maxf(_hub.island.height_at(x, z), _hub.ocean.get_height(x, z))
