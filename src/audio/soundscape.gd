class_name Soundscape
extends Node3D
## Ambient storm mix (SPEC §4.13): wind + rain loops (2D), surf loops at the shore (3D), thunder
## one-shots delayed after each lightning flash. Gains follow the storm curves.

@export var wind_db: Vector2 = Vector2(-24.0, -10.0)    ## at wind 3 m/s -> 13 m/s
@export var wind_range: Vector2 = Vector2(3.0, 13.0)
@export var rain_db: Vector2 = Vector2(-30.0, -14.0)    ## rain_ratio 0 -> 1
@export var surf_db: Vector2 = Vector2(-18.0, -6.0)     ## wave_scale 0.6 -> 1.3
@export var surf_range: Vector2 = Vector2(0.6, 1.3)
@export var surf_radius: float = 40.0
@export var thunder_db: float = -6.0
@export var thunder_delay: Vector2 = Vector2(0.3, 2.0)
@export var mute_db: float = -80.0

var wind_gain: float = -80.0
var rain_gain: float = -80.0
var surf_gain: float = -80.0
var thunders_played: int = 0

var _wind: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _surf: Array[AudioStreamPlayer3D] = []
var _thunder: AudioStreamPlayer
var _pending_thunder: Array[float] = []


func _ready() -> void:
	var synth: ProcAudio = ProcAudio.new()
	_wind = _player2d("Wind", synth.wind())
	_rain = _player2d("Rain", synth.rain())
	var surf_stream: AudioStreamWAV = synth.surf()
	for i: int in 4:
		var a: float = TAU * (float(i) + 0.5) / 4.0
		var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p.name = "Surf%d" % i
		p.stream = surf_stream
		p.unit_size = 25.0
		p.max_distance = 140.0
		p.position = Vector3(cos(a) * surf_radius, 0.5, sin(a) * surf_radius)
		add_child(p)
		_surf.append(p)
	_thunder = AudioStreamPlayer.new()
	_thunder.name = "Thunder"
	_thunder.stream = synth.thunder()
	_thunder.volume_db = thunder_db
	add_child(_thunder)
	_wind.play()
	_rain.play()
	for i: int in _surf.size():
		_surf[i].play(float(i) * 2.3)  # stagger the swells


func _player2d(n: String, stream: AudioStream) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = n
	p.stream = stream
	p.volume_db = mute_db
	add_child(p)
	return p


func set_storm(wind_speed: float, rain_ratio: float, wave_scale: float) -> void:
	wind_gain = lerpf(wind_db.x, wind_db.y, clampf(inverse_lerp(wind_range.x, wind_range.y, wind_speed), 0.0, 1.0))
	rain_gain = lerpf(rain_db.x, rain_db.y, clampf(rain_ratio, 0.0, 1.0)) if rain_ratio > 0.01 else mute_db
	surf_gain = lerpf(surf_db.x, surf_db.y, clampf(inverse_lerp(surf_range.x, surf_range.y, wave_scale), 0.0, 1.0))
	_wind.volume_db = wind_gain
	_rain.volume_db = rain_gain
	for p: AudioStreamPlayer3D in _surf:
		p.volume_db = surf_gain


## Hooked to StormWeather.lightning_struck.
func on_lightning() -> void:
	_pending_thunder.append(GameRng.randf_range(thunder_delay.x, thunder_delay.y))


func _physics_process(delta: float) -> void:
	for i: int in range(_pending_thunder.size() - 1, -1, -1):
		_pending_thunder[i] -= delta
		if _pending_thunder[i] <= 0.0:
			_pending_thunder.remove_at(i)
			_thunder.play()
			thunders_played += 1


func telemetry() -> Dictionary:
	return {
		"wind_gain": snappedf(wind_gain, 0.001),
		"rain_gain": snappedf(rain_gain, 0.001),
		"surf_gain": snappedf(surf_gain, 0.001),
		"rifle_cracks": 0,
		"kill_thuds": 0,
		"flare_hiss_active": false,
		"moans_played": 0,
		"thunders": thunders_played,
	}
