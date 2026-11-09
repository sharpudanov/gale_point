class_name StormWeather
extends Node3D
## Storm weather (godot-ocean-weather skill template + SPEC §4.10): wind-angled rain that follows
## the player, shore spray ring, sea_mist FogVolume + drifting mist patches, and lightning strikes
## (cold flash light + sky flash + glow guard). Everything is pushed by StormDirector.

signal lightning_struck

const MIST_SHADER_PATH: String = "res://shaders/sea_mist.gdshader"

@export_group("Wind")
@export var wind_dir: Vector3 = Vector3(0.95, 0.0, 0.32)
@export var wind_speed: float = 5.0
@export_group("Rain")
@export var rain_amount: int = 6000
@export var rain_fall_speed: float = 14.0
@export var rain_area: Vector3 = Vector3(24.0, 1.0, 24.0)   ## box extents (half size)
@export var rain_height: float = 16.0
@export var rain_streak: Vector2 = Vector2(0.012, 0.6)  ## quad width, length (m)
@export var rain_color: Color = Color(0.75, 0.80, 0.85, 0.16)
@export var rain_near_fade: Vector2 = Vector2(1.5, 5.0)  ## streaks fade in between these camera distances
@export_group("Spray")
@export var spray_amount: int = 900
@export var spray_ring: Vector2 = Vector2(36.0, 44.0)
@export var spray_lifetime: float = 1.8
@export var spray_color: Color = Color(0.78, 0.80, 0.82, 0.30)
@export_group("Mist")
@export var mist_size: Vector3 = Vector3(260.0, 7.0, 260.0)
@export var mist_center_y: float = 1.5
@export var mist_albedo: Color = Color(0.60, 0.65, 0.70)
@export var patch_count: int = 6
@export var patch_size: Vector3 = Vector3(30.0, 4.0, 30.0)
@export var patch_range: float = 70.0     ## patches respawn upwind beyond this distance
@export_group("Lightning")
@export var flash_peak_energy: float = 4.5
@export var flash_color: Color = Color(0.80, 0.86, 1.0)
@export var flash_fog_energy: float = 0.5
@export var reveal_time: float = 0.6
@export var first_strike_min: float = 12.0  ## seconds, x k
@export var glow_flash_threshold: float = 6.0

var rain: GPUParticles3D
var spray: GPUParticles3D
var mist: FogVolume
var flash_light: DirectionalLight3D
var follow_target: Node3D
var mood: MoodRig

## Lightning schedule (pushed): interval range in seconds, already scaled by k.
var lightning_enabled: bool = true
var lightning_interval: Vector2 = Vector2(16.0, 26.0)
var lightning_count: int = 0
var forced_flash_at: float = -1.0
var schedule_k: float = 1.0
var base_glow_threshold: float = 1.4
var flash_level: float = 0.0              ## 0..1 strike envelope (drives light, sky, glow)

var _rain_pm: ParticleProcessMaterial
var _spray_pm: ParticleProcessMaterial
var _mist_mat: ShaderMaterial
var _patches: Array[FogVolume] = []
var _patch_mats: Array[ShaderMaterial] = []
var _elapsed: float = 0.0
var _next_strike: float = -1.0
var _last_strike: float = -100.0
var _mist_offset: Vector3 = Vector3.ZERO
var _applied_wind: Vector3 = Vector3(-1.0, 0.0, 0.0)
var _strike_tween: Tween


func _ready() -> void:
	_build_rain()
	_build_spray()
	_build_mist()
	_build_flash()
	_apply_wind(wind())


func wind() -> Vector3:
	return wind_dir.normalized() * wind_speed


func flash_active() -> bool:
	return _elapsed - _last_strike <= reveal_time and lightning_count > 0


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var w: Vector3 = wind()
	_mist_offset += w * 0.6 * delta
	_mist_mat.set_shader_parameter("wind_offset", _mist_offset)
	for pm: ShaderMaterial in _patch_mats:
		pm.set_shader_parameter("wind_offset", _mist_offset)
	_move_patches(w, delta)
	if w.distance_to(_applied_wind) > 0.25:
		_apply_wind(w)

	# Lightning schedule (deterministic: physics time + GameRng).
	if forced_flash_at >= 0.0:
		if _elapsed >= forced_flash_at:
			forced_flash_at = -1.0
			strike(0.08)
	elif lightning_enabled:
		if _next_strike < 0.0:
			_next_strike = maxf(first_strike_min * schedule_k, GameRng.randf_range(lightning_interval.x, lightning_interval.y))
		if _elapsed >= _next_strike:
			strike(GameRng.randf_range(0.04, 0.12))
			_next_strike = _elapsed + GameRng.randf_range(lightning_interval.x, lightning_interval.y)


func _process(_delta: float) -> void:
	if follow_target != null and is_instance_valid(follow_target):
		var p: Vector3 = follow_target.global_position
		var w: Vector3 = wind()
		rain.global_position = Vector3(p.x - w.x * 0.5, p.y + rain_height, p.z - w.z * 0.5)
	flash_light.light_energy = flash_level * flash_peak_energy
	if mood != null:
		mood.set_flash(flash_level)
		mood.set_glow_threshold(lerpf(base_glow_threshold, glow_flash_threshold, smoothstep(0.0, 0.15, flash_level)))


## Rain / spray density and mist density (StormDirector).
func set_ratios(rain_ratio: float, spray_ratio: float) -> void:
	rain.amount_ratio = clampf(rain_ratio, 0.0, 1.0)
	rain.emitting = rain_ratio > 0.005
	spray.amount_ratio = clampf(spray_ratio, 0.0, 1.0)
	spray.emitting = spray_ratio > 0.005


func set_mist(big_density: float, patch_density: float) -> void:
	_mist_mat.set_shader_parameter("density", big_density)
	for pm: ShaderMaterial in _patch_mats:
		pm.set_shader_parameter("density", patch_density)


func mist_density() -> float:
	return float(_mist_mat.get_shader_parameter("density"))


## Double-flicker strike: bright, dip, `gap`, brighter, slow exponential decay (skill template).
func strike(gap: float) -> void:
	lightning_count += 1
	_last_strike = _elapsed
	if _strike_tween != null and _strike_tween.is_valid():
		_strike_tween.kill()
	_strike_tween = create_tween()
	_strike_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_strike_tween.tween_property(self, "flash_level", 0.6, 0.03)
	_strike_tween.tween_property(self, "flash_level", 0.05, 0.07)
	_strike_tween.tween_interval(gap)
	_strike_tween.tween_property(self, "flash_level", 1.0, 0.03)
	_strike_tween.tween_property(self, "flash_level", 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	lightning_struck.emit()


func _apply_wind(w: Vector3) -> void:
	_applied_wind = w
	var fall: Vector3 = Vector3(w.x, -rain_fall_speed, w.z)
	_rain_pm.direction = fall.normalized()
	_rain_pm.initial_velocity_min = fall.length() * 0.9
	_rain_pm.initial_velocity_max = fall.length() * 1.1
	_spray_pm.gravity = Vector3(w.x * 0.8, -6.0, w.z * 0.8)


func _build_rain() -> void:
	_rain_pm = ParticleProcessMaterial.new()
	_rain_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_pm.emission_box_extents = rain_area
	_rain_pm.spread = 2.0
	_rain_pm.gravity = Vector3.ZERO

	var streak_mat: StandardMaterial3D = StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_mat.albedo_color = rain_color
	# Fat streaks right at the lens read as artefacts: fade them in with distance.
	streak_mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	streak_mat.distance_fade_min_distance = rain_near_fade.x
	streak_mat.distance_fade_max_distance = rain_near_fade.y
	# No material billboard: BILLBOARD_FIXED_Y forces streaks vertical (skill gotcha).
	var quad: QuadMesh = QuadMesh.new()
	quad.size = rain_streak
	quad.material = streak_mat

	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = rain_amount
	rain.lifetime = 1.3
	rain.preprocess = 1.3
	rain.process_material = _rain_pm
	rain.draw_pass_1 = quad
	rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	rain.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 60, 120))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.top_level = true
	add_child(rain)


func _build_spray() -> void:
	_spray_pm = ParticleProcessMaterial.new()
	_spray_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	_spray_pm.emission_ring_axis = Vector3.UP
	_spray_pm.emission_ring_radius = spray_ring.y
	_spray_pm.emission_ring_inner_radius = spray_ring.x
	_spray_pm.emission_ring_height = 0.5
	_spray_pm.direction = Vector3.UP
	_spray_pm.spread = 25.0
	_spray_pm.initial_velocity_min = 3.0
	_spray_pm.initial_velocity_max = 7.0
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.6))
	curve.max_value = 2.0
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = curve
	_spray_pm.scale_curve = ct
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 1.0))
	fade.add_point(0.6, Color(1, 1, 1, 0.7))
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = fade
	_spray_pm.color_ramp = gt

	var radial: Gradient = Gradient.new()
	radial.set_color(0, Color(1, 1, 1, 1))
	radial.set_color(1, Color(1, 1, 1, 0))
	var rt: GradientTexture2D = GradientTexture2D.new()
	rt.gradient = radial
	rt.fill = GradientTexture2D.FILL_RADIAL
	rt.fill_from = Vector2(0.5, 0.5)
	rt.fill_to = Vector2(0.5, 0.0)
	rt.width = 64
	rt.height = 64

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = spray_color
	mat.albedo_texture = rt
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 1.0
	mat.roughness = 1.0
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.material = mat

	spray = GPUParticles3D.new()
	spray.name = "Spray"
	spray.amount = spray_amount
	spray.lifetime = spray_lifetime
	spray.preprocess = spray_lifetime
	spray.process_material = _spray_pm
	spray.draw_pass_1 = quad
	spray.visibility_aabb = AABB(Vector3(-60, -5, -60), Vector3(120, 20, 120))
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spray)


func _make_mist_material(density: float, noise: NoiseTexture3D) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(MIST_SHADER_PATH) as Shader
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("albedo", mist_albedo)
	m.set_shader_parameter("noise_tex", noise)
	return m


func _build_mist() -> void:
	var fn: FastNoiseLite = FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3
	fn.frequency = 0.06
	fn.seed = GameRng.next_seed()
	var tex: NoiseTexture3D = NoiseTexture3D.new()
	tex.width = 64
	tex.height = 64
	tex.depth = 64
	tex.seamless = true
	tex.normalize = true
	tex.noise = fn

	_mist_mat = _make_mist_material(0.025, tex)
	mist = FogVolume.new()
	mist.name = "SeaMist"
	mist.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	mist.size = mist_size
	mist.material = _mist_mat
	mist.position = Vector3(0.0, mist_center_y, 0.0)
	add_child(mist)

	for i: int in patch_count:
		var pm: ShaderMaterial = _make_mist_material(0.04, tex)
		pm.set_shader_parameter("height_falloff", 0.25)
		var fv: FogVolume = FogVolume.new()
		fv.name = "MistPatch%d" % i
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		fv.size = patch_size
		fv.material = pm
		var a: float = GameRng.randf_range(0.0, TAU)
		var r: float = GameRng.randf_range(0.0, patch_range)
		fv.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		add_child(fv)
		_patches.append(fv)
		_patch_mats.append(pm)


func _move_patches(w: Vector3, delta: float) -> void:
	var dir: Vector3 = w.normalized() if w.length() > 0.01 else wind_dir.normalized()
	for fv: FogVolume in _patches:
		var p: Vector3 = fv.position + w * delta
		var along: float = Vector2(p.x, p.z).dot(Vector2(dir.x, dir.z))
		if along > patch_range:
			# Respawn upwind, at a random lateral offset.
			var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
			p = -dir * patch_range + side * GameRng.randf_range(-patch_range, patch_range)
		var ground: float = 0.0
		fv.position = Vector3(p.x, ground + patch_size.y * 0.35, p.z)


func _build_flash() -> void:
	flash_light = DirectionalLight3D.new()
	flash_light.name = "LightningLight"
	flash_light.light_color = flash_color
	flash_light.light_energy = 0.0
	flash_light.light_volumetric_fog_energy = flash_fog_energy
	flash_light.shadow_enabled = false
	flash_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	flash_light.rotation_degrees = Vector3(-70.0, 140.0, 0.0)
	add_child(flash_light)
