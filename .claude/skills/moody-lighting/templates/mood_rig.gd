class_name MoodRig
extends Node3D
## Moody storm lighting rig: AgX environment, cold low sun, tinted ambient, volumetric fog,
## warm lighthouse beam (the ONE warm accent). Template from .claude/skills/moody-lighting.
## Starting values (render-tested on Godot 4.7.2) — tune via the exports, not in code.

@export_group("Tonemap")
@export var exposure: float = 1.1
@export var agx_white: float = 10.0
@export var agx_contrast: float = 1.3
@export_group("Glow")
@export var glow_threshold: float = 1.2      ## only true HDR (beam core, flash) blooms
@export var glow_intensity: float = 0.5
@export_group("Fog")
@export var vfog_density: float = 0.012
@export var vfog_albedo: Color = Color(0.55, 0.60, 0.65)
@export var vfog_anisotropy: float = 0.6     ## forward scatter -> beams read toward camera
@export var vfog_length: float = 120.0
@export_group("Light")
@export var sun_pitch_deg: float = -14.0     ## low, grazing storm light
@export var sun_yaw_deg: float = -35.0
@export var sun_energy: float = 0.7
@export var sun_color: Color = Color(0.70, 0.78, 0.92)       ## COLD key
@export var ambient_color: Color = Color(0.16, 0.20, 0.26)   ## blue-grey fill
@export var ambient_energy: float = 0.8
@export var beam_color: Color = Color(1.0, 0.76, 0.45)       ## WARM accent (~2700 K)
@export var beam_energy: float = 30.0
@export var beam_fog_energy: float = 150.0
@export var beam_angle_deg: float = 6.0
@export var beam_range: float = 150.0
@export var beam_turn_speed_deg: float = 25.0

var env: Environment
var sun: DirectionalLight3D
var beam: SpotLight3D


func _ready() -> void:
	env = Environment.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.10, 0.12, 0.15)
	sky_mat.sky_horizon_color = Color(0.28, 0.31, 0.35)
	sky_mat.ground_horizon_color = Color(0.28, 0.31, 0.35)
	sky_mat.ground_bottom_color = Color(0.05, 0.06, 0.07)
	sky_mat.sky_energy_multiplier = 0.7
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky

	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = exposure
	env.tonemap_agx_white = agx_white            # tonemap_white is ignored by AgX
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
	env.volumetric_fog_ambient_inject = 0.8       # fog lit by ambient, else it only darkens
	env.volumetric_fog_sky_affect = 0.25

	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.5
	env.ssao_power = 1.8
	env.ssao_light_affect = 0.1

	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_pitch_deg, sun_yaw_deg, 0.0)
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.light_volumetric_fog_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	beam = SpotLight3D.new()
	beam.light_color = beam_color
	beam.light_energy = beam_energy
	beam.light_volumetric_fog_energy = beam_fog_energy
	beam.spot_angle = beam_angle_deg
	beam.spot_range = beam_range
	beam.spot_attenuation = 0.4
	beam.spot_angle_attenuation = 2.0
	beam.shadow_enabled = true                   # shadows make the shaft visible as a cone in fog
	beam.position = Vector3(0.0, 14.0, 0.0)
	beam.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	add_child(beam)


func _process(delta: float) -> void:
	beam.rotate_y(deg_to_rad(beam_turn_speed_deg) * delta)
