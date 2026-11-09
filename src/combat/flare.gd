class_name Flare
extends ShootableGear
## A burning flare (SPEC 4.6): ballistic flight with bounces, a 20 s burn curve (ignite -> steady ->
## sputter), a shadow-casting warm light, smoke, sparks, and a hiss. Registers with LightField while
## it burns. Falls into the sea -> "dud": bobs, hisses and dies over dud_time.

signal sank        ## fell into the sea before landing
signal burned_out
signal impaled      ## struck a Drowned in flight and stuck in it

@export var burn_time: float = 20.0
@export var ignite_time: float = 0.5
@export var sputter_time: float = 3.0
@export var gravity: float = 9.81
@export var bounce_damping: float = 0.3
@export var bounce_friction: float = 0.35  ## tangential speed kept per bounce (spec leaves it open)
@export var rest_speed: float = 0.5
@export var dud_time: float = 1.5
@export var sea_margin: float = 0.1
@export_group("Impale / burst")
@export var impale_radius: float = 0.5      ## body cylinder radius a flying flare must pass through (x Drowned scale)
@export var impale_min_speed: float = 6.0   ## a rolling / resting flare does not impale
@export var shot_radius: float = 0.3        ## a rifle round within this of a burning flare detonates it
@export_group("Light")
@export var light_color: Color = Color(1.0, 0.60, 0.36)
@export var light_energy: float = 7.0
@export var light_range: float = 16.0
@export var light_attenuation: float = 1.0
@export var light_fog_energy: float = 8.0
@export var light_height: float = 0.3
@export var flicker_hz: float = 9.0
@export var flicker_amp: float = 0.18
@export var flicker_pos: float = 0.03
@export var gameplay_min_burn: float = 0.25
@export_group("Look")
@export var core_radius: float = 0.06
@export var core_color: Color = Color(1.0, 0.70, 0.45)
@export var core_energy: float = 10.0
@export var smoke_amount: int = 120
@export var smoke_lifetime: float = 6.0
@export var smoke_color: Color = Color(0.45, 0.45, 0.47, 0.35)
@export var spark_amount: int = 40
@export var spark_lifetime: float = 0.6
@export var spark_color: Color = Color(1.0, 0.65, 0.35)
@export var spark_energy: float = 4.0

var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0
## "flying", "resting", "impaled", "dud", "out"
var state: String = "flying"
var enemies: Enemies
var fire: FireSystem
var host: Drowned
var _host_offset: Vector3 = Vector3.ZERO   ## in the host's local frame
var burn: float = 0.0

var _ocean: Ocean
var _field: LightField
var _audio: Soundscape
var _weather: StormWeather
var _noise: FastNoiseLite
var _light: OmniLight3D
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _smoke: GPUParticles3D
var _sparks: GPUParticles3D
var _hiss: AudioStreamPlayer3D
var _hissing: bool = false
var _dud_left: float = 0.0
var _free_left: float = -1.0
var _preprocess_smoke: float = 0.0


func setup(vel: Vector3, ocean: Ocean, field: LightField, audio: Soundscape, weather: StormWeather, start_age: float = 0.0) -> void:
	velocity = vel
	_ocean = ocean
	_field = field
	_audio = audio
	_weather = weather
	age = start_age
	_preprocess_smoke = minf(start_age, smoke_lifetime)


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = GameRng.next_seed()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_build_visuals()
	if _field != null:
		_field.register_flare(self)
	if _audio != null:
		_hiss = _audio.make_hiss(self)
		_audio.hiss_started()
		_hissing = true
	if velocity == Vector3.ZERO and age > 0.0:
		state = "resting"  # --place_flare: already on the ground
	_update_burn()
	_apply_look(0.0)


## 0..1 gameplay contribution at a world position (SPEC 4.7). 0 outside the radius or when too dim.
func light_contribution(pos: Vector3, radius: float) -> float:
	if state == "dud" or state == "out" or burn < gameplay_min_burn:
		return 0.0
	if pos.distance_to(global_position) > radius:
		return 0.0
	return burn


func is_burning() -> bool:
	return state == "flying" or state == "resting" or state == "impaled"


func ray_hit(from: Vector3, dir: Vector3) -> float:
	if not is_burning() or burn < gameplay_min_burn or state == "impaled":
		return -1.0
	return HitGeo.ray_vs_sphere(from, dir, global_position, shot_radius)


## A rifle round through a burning flare: magnesium burst. The flare is spent.
func on_shot(_point: Vector3, _dir: Vector3) -> void:
	if not is_burning():
		return
	if fire != null:
		fire.burst(global_position, 1.0)
	_finish()


## The host died: fall off and keep burning where it lands.
func drop_from_host() -> void:
	if state != "impaled":
		return
	host = null
	state = "flying"
	velocity = Vector3(0.0, 0.5, 0.0)


func _physics_process(delta: float) -> void:
	if _free_left >= 0.0:
		_free_left -= delta
		if _free_left <= 0.0:
			queue_free()
		return
	age += delta
	match state:
		"flying":
			_fly(delta)
		"impaled":
			if host != null and is_instance_valid(host) and host.is_alive():
				global_position = host.global_transform * _host_offset + host.body_offset()
			else:
				drop_from_host()
		"dud":
			_dud_left -= delta
			var h: float = _ocean.get_height(global_position.x, global_position.z) if _ocean != null else global_position.y
			global_position.y = h + 0.05 + 0.03 * sin(age * 7.0)
			if _dud_left <= 0.0:
				_finish()
	if state == "flying" or state == "resting" or state == "impaled":
		if age >= burn_time:
			_finish()
	_update_burn()


func _process(_delta: float) -> void:
	_apply_look(age)


func _fly(delta: float) -> void:
	velocity.y -= gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if _try_impale(from, to, hit):
		return
	if not hit.is_empty():
		var n: Vector3 = hit["normal"]
		global_position = (hit["position"] as Vector3) + n * core_radius
		var vn: float = velocity.dot(n)
		var vt: Vector3 = velocity - n * vn
		velocity = vt * bounce_friction + n * (-vn * bounce_damping)
		if velocity.length() < rest_speed:
			velocity = Vector3.ZERO
			state = "resting"
		return
	global_position = to
	if _ocean != null and to.y < _ocean.get_height(to.x, to.z) + sea_margin:
		_become_dud()


## Same deterministic body test as the rifle, along this frame's flight segment. The nearest Drowned the
## segment passes through (before any world hit) is impaled: the flare sticks in its chest and rides along.
func _try_impale(from: Vector3, to: Vector3, world_hit: Dictionary) -> bool:
	if enemies == null or velocity.length() < impale_min_speed:
		return false
	var seg: Vector3 = to - from
	var seg_len: float = seg.length()
	if seg_len < 0.0001:
		return false
	var dir: Vector3 = seg / seg_len
	var limit: float = seg_len if world_hit.is_empty() else from.distance_to(world_hit["position"] as Vector3)
	var best: float = INF
	var target: Drowned = null
	for d: Drowned in enemies.living():
		if d.state == "emerging":
			continue
		var sc: float = d.size_scale
		var c: Vector3 = d.global_position + d.body_offset() + Vector3(0.0, 1.05 * sc, 0.0)
		var t: float = HitGeo.ray_vs_cylinder(from, dir, c, impale_radius * sc, d.global_position.y + 0.2,
			d.global_position.y + 2.1 * sc, limit)
		if t >= 0.0 and t < best:
			best = t
			target = d
	if target == null:
		return false
	attach_to(target, from + dir * best)
	return true


## Stick into `target` at world point `at` (clamped to the torso); it becomes a walking torch.
func attach_to(target: Drowned, at: Vector3) -> void:
	host = target
	state = "impaled"
	velocity = Vector3.ZERO
	var local: Vector3 = target.global_transform.affine_inverse() * at
	local.y = clampf(local.y, 0.9 * target.size_scale, 1.7 * target.size_scale)
	_host_offset = Vector3(local.x * 0.4, local.y, local.z * 0.4)
	global_position = target.global_transform * _host_offset
	target.impale(self)
	impaled.emit()


func _become_dud() -> void:
	state = "dud"
	velocity = Vector3.ZERO
	_dud_left = dud_time
	if _field != null:
		_field.unregister_flare(self)
	sank.emit()


func _finish() -> void:
	state = "out"
	burn = 0.0
	if _field != null:
		_field.unregister_flare(self)
	if _hissing and _audio != null:
		_audio.hiss_stopped()
		_hissing = false
	if _hiss != null:
		_hiss.stop()
	_smoke.emitting = false
	_sparks.emitting = false
	_light.visible = false
	_core.visible = false
	_free_left = smoke_lifetime
	burned_out.emit()


## Burn factor curve: ignite ramp, steady, ragged sputter over the last sputter_time seconds.
func _update_burn() -> void:
	if state == "out":
		burn = 0.0
		return
	var b: float = clampf(age / ignite_time, 0.0, 1.0)
	if state == "dud":
		b = clampf(_dud_left / dud_time, 0.0, 1.0)
	else:
		var left: float = burn_time - age
		if left < sputter_time:
			var k: float = clampf(left / sputter_time, 0.0, 1.0)
			var drop: float = 0.55 + 0.45 * _noise.get_noise_1d(age * 13.0)
			b *= lerpf(0.0, 1.0, k * k) * clampf(drop + 0.35 * k, 0.0, 1.0)
	burn = clampf(b, 0.0, 1.0)


func _apply_look(t: float) -> void:
	if _light == null or state == "out":
		return
	var f: float = _noise.get_noise_1d(t * flicker_hz)
	var e: float = burn * (1.0 + flicker_amp * f)
	_light.light_energy = light_energy * e
	_light.light_volumetric_fog_energy = light_fog_energy * e
	_light.position = Vector3(
		flicker_pos * _noise.get_noise_2d(t * flicker_hz, 11.0),
		light_height + flicker_pos * _noise.get_noise_2d(t * flicker_hz, 23.0),
		flicker_pos * _noise.get_noise_2d(t * flicker_hz, 37.0))
	_core_mat.emission_energy_multiplier = core_energy * clampf(burn * (1.0 + 0.5 * flicker_amp * f), 0.0, 1.5)
	_sparks.amount_ratio = clampf(burn, 0.05, 1.0)
	if _hiss != null:
		_hiss.volume_db = linear_to_db(maxf(burn, 0.001)) - 2.0


func _build_visuals() -> void:
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = core_color
	_core_mat.emission_enabled = true
	_core_mat.emission = core_color
	_core_mat.emission_energy_multiplier = core_energy
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = core_radius
	sphere.height = core_radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	_core = MeshInstance3D.new()
	_core.name = "Core"
	_core.mesh = sphere
	_core.material_override = _core_mat
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	_light = OmniLight3D.new()
	_light.name = "FlareLight"
	_light.light_color = light_color
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = light_attenuation
	_light.shadow_enabled = true
	_light.light_volumetric_fog_energy = light_fog_energy
	_light.position.y = light_height
	add_child(_light)

	_smoke = _build_smoke()
	add_child(_smoke)
	_sparks = _build_sparks()
	add_child(_sparks)


func _radial_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	return gt


func _build_smoke() -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = smoke_amount
	p.lifetime = smoke_lifetime
	p.local_coords = false
	p.preprocess = _preprocess_smoke
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 30, 40))
	var wind: Vector3 = _weather.wind() if _weather != null else Vector3(2.0, 0.0, 1.0)
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(wind.x * 0.15, 0.0, wind.z * 0.15)  # reaches ~ wind x 0.6 after a few seconds
	pm.damping_min = 0.1
	pm.damping_max = 0.2
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(1.0, 1.0))
	var sct: CurveTexture = CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.12, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = smoke_color
	mat.albedo_texture = _radial_texture()
	mat.roughness = 1.0
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.6
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	quad.material = mat
	p.draw_pass_1 = quad
	return p


func _build_sparks() -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Sparks"
	p.amount = spark_amount
	p.lifetime = spark_lifetime
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.04
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0.0, -7.0, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	p.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = spark_color
	mat.emission_enabled = true
	mat.emission = spark_color
	mat.emission_energy_multiplier = spark_energy
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	quad.material = mat
	p.draw_pass_1 = quad
	return p
