class_name StormWeather
extends Node3D
## Storm weather: wind-angled rain, low FogVolume sea mist, lightning flashes.
## Requires Environment.volumetric_fog_enabled = true (Forward+ only) for the mist.

@export var wind: Vector3 = Vector3(6.0, 0.0, 2.0)          ## m/s, horizontal
@export var rain_amount: int = 6000
@export var rain_fall_speed: float = 20.0
@export var rain_area: Vector3 = Vector3(30.0, 1.0, 30.0)   ## box extents (half size)
@export var mist_size: Vector3 = Vector3(240.0, 8.0, 240.0)
@export var mist_density: float = 0.03
@export var flash_peak_energy: float = 6.0
@export var flash_interval: Vector2 = Vector2(4.0, 11.0)    ## random seconds between strikes

var rain: GPUParticles3D
var mist: FogVolume
var flash_light: DirectionalLight3D
var _next_flash: float = 2.0


func _ready() -> void:
	_build_rain()
	_build_mist()
	_build_flash()


func _process(delta: float) -> void:
	_next_flash -= delta
	if _next_flash <= 0.0:
		flash()
		_next_flash = randf_range(flash_interval.x, flash_interval.y)


func _build_rain() -> void:
	var fall: Vector3 = Vector3(wind.x, -rain_fall_speed, wind.z)
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = rain_area
	pm.direction = fall.normalized()
	pm.spread = 2.0
	pm.initial_velocity_min = fall.length() * 0.9
	pm.initial_velocity_max = fall.length() * 1.1
	pm.gravity = Vector3.ZERO                       # constant velocity = straight, readable streaks

	var streak_mat: StandardMaterial3D = StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_mat.albedo_color = Color(0.75, 0.80, 0.85, 0.28)
	# NO material billboard: BILLBOARD_FIXED_Y would force streaks vertical (tested).
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.015, 0.6)
	quad.material = streak_mat

	rain = GPUParticles3D.new()
	rain.amount = rain_amount
	rain.lifetime = 1.4
	rain.preprocess = 1.4                           # already raining on frame 1
	rain.process_material = pm
	rain.draw_pass_1 = quad
	# Faces camera AND stretches along velocity -> slanted streaks that follow the wind.
	rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	rain.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 60, 120))
	# Spawn upwind and above so streaks cross the view; parent this to the camera rig.
	rain.position = Vector3(-wind.x * 0.7, 18.0, -wind.z * 0.7)
	add_child(rain)


func _build_mist() -> void:
	var fm: FogMaterial = FogMaterial.new()
	fm.density = mist_density
	fm.albedo = Color(0.62, 0.68, 0.72)
	fm.height_falloff = 0.35                        # thick at the water, thin above
	fm.edge_fade = 0.3
	mist = FogVolume.new()
	mist.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	mist.size = mist_size
	mist.material = fm
	mist.position = Vector3(0.0, mist_size.y * 0.25, 0.0)
	add_child(mist)


func _build_flash() -> void:
	flash_light = DirectionalLight3D.new()
	flash_light.light_color = Color(0.80, 0.86, 1.0)  # cold
	flash_light.light_energy = 0.0
	flash_light.light_volumetric_fog_energy = 2.0     # lights up the mist from inside
	flash_light.shadow_enabled = false                # a flash shouldn't pop shadow cascades
	flash_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	flash_light.rotation_degrees = Vector3(-70.0, 140.0, 0.0)
	add_child(flash_light)


## Double-flicker strike: bright, dip, brighter, slow exponential decay.
func flash() -> void:
	var t: Tween = create_tween()
	t.tween_property(flash_light, "light_energy", flash_peak_energy * 0.6, 0.03)
	t.tween_property(flash_light, "light_energy", 0.3, 0.07)
	t.tween_interval(randf_range(0.04, 0.12))
	t.tween_property(flash_light, "light_energy", flash_peak_energy, 0.03)
	t.tween_property(flash_light, "light_energy", 0.0, 0.6) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
