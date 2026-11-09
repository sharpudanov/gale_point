class_name StormDirector
extends Node
## Evaluates the SPEC §5.2 escalation curves every physics tick and pushes them into the mood rig,
## sky, ocean, weather, terrain and soundscape. value = lerp(lerp(calm, peak, s), dawn, d).

@export_group("calm / peak / dawn")
@export var vfog: Vector3 = Vector3(0.0085, 0.026, 0.003)
@export var mist: Vector3 = Vector3(0.025, 0.065, 0.0)
@export var mist_patch: Vector3 = Vector3(0.04, 0.09, 0.0)
@export var depth_fog: Vector3 = Vector3(0.004, 0.012, 0.0015)
@export var wave_scale: Vector3 = Vector3(0.75, 1.30, 0.60)
@export var foam_threshold: Vector3 = Vector3(0.24, 0.22, 0.18)
@export var ocean_roughness: Vector3 = Vector3(0.10, 0.16, 0.09)
@export var wind_speed: Vector3 = Vector3(5.0, 13.0, 3.0)
@export var rain_ratio: Vector3 = Vector3(0.45, 1.0, 0.0)
@export var spray_ratio: Vector3 = Vector3(0.3, 1.0, 0.05)
@export var lightning_min: Vector2 = Vector2(16.0, 4.0)   ## calm, peak (s, x k)
@export var lightning_max: Vector2 = Vector2(26.0, 9.0)
@export var sun_energy: Vector3 = Vector3(0.9, 1.0, 1.6)
@export var ambient_energy: Vector3 = Vector3(1.0, 1.3, 1.0)
@export var exposure: Vector3 = Vector3(1.0, 1.05, 0.85)
@export var hdri_energy: Vector3 = Vector3(0.22, 0.3, 0.85)
@export var sky_desaturate: Vector3 = Vector3(0.6, 0.65, 0.5)
@export var sky_reflect_calm: Color = Color(0.24, 0.26, 0.30)
@export var sky_reflect_peak: Color = Color(0.30, 0.33, 0.39)
@export var sky_reflect_dawn: Color = Color(0.55, 0.57, 0.62)
@export var wetness: Vector3 = Vector3(0.85, 0.95, 0.7)
@export var cloud_drift_deg_s: float = 0.2   ## x wind / 13

var clock: NightClock
var mood: MoodRig
var ocean: Ocean
var weather: StormWeather
var island: Island
var soundscape: Soundscape
var no_lightning: bool = false

## Last pushed values (telemetry).
var values: Dictionary = {}
var _s: float = 0.0
var _d: float = 0.0
var _hdri_yaw: float = 0.0


func setup(c: NightClock, m: MoodRig, o: Ocean, w: StormWeather, i: Island, snd: Soundscape) -> void:
	clock = c
	mood = m
	ocean = o
	weather = w
	island = i
	soundscape = snd
	_evaluate(0.0)


func _physics_process(delta: float) -> void:
	_evaluate(delta)


func _curve(v: Vector3) -> float:
	return lerpf(lerpf(v.x, v.y, _s), v.z, _d)


func intensity() -> float:
	return 0.15 + 0.85 * _s * (1.0 - _d)


func progress() -> float:
	return _s


func _evaluate(delta: float) -> void:
	_s = smoothstep(0.0, 1.0, clock.u())
	_d = clock.dawn_progress()

	var ws: float = _curve(wind_speed)
	weather.wind_speed = ws
	var wdir: Vector3 = weather.wind_dir.normalized()
	var mist_d: float = _curve(mist)
	weather.set_mist(mist_d, _curve(mist_patch))
	var rr: float = _curve(rain_ratio)
	var sr: float = _curve(spray_ratio)
	weather.set_ratios(rr, sr)
	weather.schedule_k = clock.k()
	weather.lightning_enabled = not no_lightning and clock.phase == "night"
	weather.lightning_interval = Vector2(
		lerpf(lightning_min.x, lightning_min.y, _s),
		lerpf(lightning_max.x, lightning_max.y, _s)) * clock.k()

	var ws_scale: float = _curve(wave_scale)
	ocean.wave_scale = ws_scale
	var refl: Color = sky_reflect_calm.lerp(sky_reflect_peak, _s).lerp(sky_reflect_dawn, _d)
	ocean.set_look(_curve(foam_threshold), _curve(ocean_roughness), refl, Vector2(wdir.x, wdir.z))

	var vf: float = _curve(vfog)
	var df: float = _curve(depth_fog)
	var expo: float = _curve(exposure)
	mood.apply_storm(vf, df, _curve(sun_energy), _curve(ambient_energy), expo, _d)
	_hdri_yaw += deg_to_rad(cloud_drift_deg_s * ws / 13.0) * delta
	mood.apply_sky(_curve(hdri_energy), _curve(sky_desaturate), _d, _hdri_yaw)
	island.set_wetness(_curve(wetness))
	if soundscape != null:
		soundscape.set_storm(ws, rr, ws_scale)

	values = {
		"wind_speed": ws,
		"wind": [wdir.x * ws, wdir.z * ws],
		"fog_density": vf,
		"mist_density": mist_d,
		"depth_fog_density": df,
		"wave_scale": ws_scale,
		"rain_ratio": rr,
		"spray_ratio": sr,
		"exposure": expo,
	}
