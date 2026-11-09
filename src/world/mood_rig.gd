class_name MoodRig
extends Node3D
## Moody storm lighting rig (moody-lighting skill template, adapted per SPEC §5.3): AgX environment,
## HDRI storm sky shader, cold low sun, tinted ambient, volumetric + depth fog.
## The beam lives in Lighthouse. StormDirector pushes the §5.2 curves through the apply_* methods.

const SKY_SHADER_PATH: String = "res://shaders/sky_storm.gdshader"

@export_group("Sky")
@export_file("*.hdr") var storm_hdri_path: String = "res://assets/hdris/overcast_soil_puresky/overcast_soil_puresky_2k.hdr"
@export_file("*.hdr") var dawn_hdri_path: String = "res://assets/hdris/kloppenheim_01_puresky/kloppenheim_01_puresky_2k.hdr"
@export_group("Tonemap")
@export var exposure: float = 1.0
@export var agx_white: float = 10.0
@export var agx_contrast: float = 1.3
@export_group("Glow")
@export var glow_threshold: float = 1.4      ## only true HDR (lamp, beam core, flash) blooms
@export var glow_intensity: float = 0.5
@export_group("Volumetric fog")
@export var vfog_density: float = 0.0085
@export var vfog_albedo: Color = Color(0.55, 0.60, 0.65)
@export var vfog_albedo_dawn: Color = Color(0.62, 0.64, 0.68)
@export var vfog_anisotropy: float = 0.25   ## low: the player watches the beam from behind its source
@export var vfog_length: float = 120.0
@export var vfog_ambient_inject: float = 0.8
@export var vfog_ambient_inject_dawn: float = 0.6
@export var vfog_sky_affect: float = 0.25
@export_group("Depth fog")
@export var fog_density: float = 0.004
@export var fog_light_color: Color = Color(0.30, 0.33, 0.38)
@export var fog_aerial_perspective: float = 0.6
@export var fog_sky_affect: float = 0.5
@export_group("Light")
@export var sun_rotation_night: Vector3 = Vector3(-14.0, -35.0, 0.0)
@export var sun_rotation_dawn: Vector3 = Vector3(-5.0, 90.0, 0.0)
@export var sun_energy: float = 0.9
@export var sun_color_night: Color = Color(0.70, 0.78, 0.92)
@export var sun_color_dawn: Color = Color(0.85, 0.87, 0.92)
@export var ambient_color: Color = Color(0.16, 0.19, 0.26)
@export var ambient_color_dawn: Color = Color(0.32, 0.36, 0.42)
@export var ambient_energy: float = 0.85

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial


func _ready() -> void:
	env = Environment.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER_PATH) as Shader
	sky_mat.set_shader_parameter("storm_hdri", load(storm_hdri_path) as Texture2D)
	sky_mat.set_shader_parameter("dawn_hdri", load(dawn_hdri_path) as Texture2D)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = exposure
	env.tonemap_agx_white = agx_white
	env.tonemap_agx_contrast = agx_contrast

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy

	env.glow_enabled = true
	env.glow_hdr_threshold = glow_threshold
	env.glow_intensity = glow_intensity
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = vfog_density
	env.volumetric_fog_albedo = vfog_albedo
	env.volumetric_fog_anisotropy = vfog_anisotropy
	env.volumetric_fog_length = vfog_length
	env.volumetric_fog_ambient_inject = vfog_ambient_inject
	env.volumetric_fog_sky_affect = vfog_sky_affect

	env.fog_enabled = true
	env.fog_density = fog_density
	env.fog_light_color = fog_light_color
	env.fog_aerial_perspective = fog_aerial_perspective
	env.fog_sky_affect = fog_sky_affect

	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.5
	env.ssao_power = 1.8
	env.ssao_light_affect = 0.1

	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = sun_rotation_night
	sun.light_color = sun_color_night
	sun.light_energy = sun_energy
	sun.light_volumetric_fog_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


## Per-tick values from StormDirector (SPEC §5.2). `d` = dawn progress.
func apply_storm(vfog: float, depth_fog: float, sun_e: float, ambient_e: float, expo: float, d: float) -> void:
	env.volumetric_fog_density = vfog
	env.fog_density = depth_fog
	env.tonemap_exposure = expo
	env.ambient_light_energy = ambient_e
	env.ambient_light_color = ambient_color.lerp(ambient_color_dawn, d)
	env.volumetric_fog_albedo = vfog_albedo.lerp(vfog_albedo_dawn, d)
	env.volumetric_fog_ambient_inject = lerpf(vfog_ambient_inject, vfog_ambient_inject_dawn, d)
	sun.light_energy = sun_e
	sun.rotation_degrees = sun_rotation_night.lerp(sun_rotation_dawn, d)
	sun.light_color = sun_color_night.lerp(sun_color_dawn, d)


func apply_sky(energy: float, desat: float, dawn_mix: float, yaw_rad: float) -> void:
	sky_mat.set_shader_parameter("hdri_energy", energy)
	sky_mat.set_shader_parameter("desaturate", desat)
	sky_mat.set_shader_parameter("dawn_mix", dawn_mix)
	sky_mat.set_shader_parameter("hdri_yaw", yaw_rad)


func set_flash(level: float) -> void:
	sky_mat.set_shader_parameter("flash", level)


func set_glow_threshold(value: float) -> void:
	env.glow_hdr_threshold = value
