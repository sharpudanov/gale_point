class_name Soundscape
extends Node3D
## Ambient storm mix (SPEC §4.13): wind + rain loops (2D), surf loops at the shore (3D), thunder
## one-shots delayed after each lightning flash. Gains follow the storm curves.
## Mix pass (M4): three buses (Ambience, Weapons, Voices) under a limited Master. A rifle crack
## or thunder ducks the ambience for a moment so the loud events stay clear without being louder.

@export var wind_db: Vector2 = Vector2(-24.0, -10.0)    ## at wind 3 m/s -> 13 m/s
@export var wind_range: Vector2 = Vector2(3.0, 13.0)
@export var rain_db: Vector2 = Vector2(-30.0, -14.0)    ## rain_ratio 0 -> 1
@export var surf_db: Vector2 = Vector2(-18.0, -6.0)     ## wave_scale 0.6 -> 1.3
@export var surf_range: Vector2 = Vector2(0.6, 1.3)
@export var surf_radius: float = 40.0
@export var thunder_db: float = -6.0
@export var thunder_delay: Vector2 = Vector2(0.3, 2.0)
@export var mute_db: float = -80.0
@export var crack_db: float = 0.0
@export var click_db: float = -8.0
@export var launch_db: float = -2.0
@export var hiss_db: float = -4.0
@export var kill_thud_db: float = -4.0
@export var deflect_db: float = -5.0
@export var moan_db: float = -2.0
@export var moan_variants: int = 4
@export var butt_db: float = -3.0
@export var whoosh_db: float = -12.0
@export var bell_db: float = 2.0
@export var bell_unit_size: float = 30.0     ## the bells carry across the water
@export var bell_max_distance: float = 260.0
@export var whoomph_db: float = 0.0
@export var crackle_unit_size: float = 3.0
@export_group("Mix")
@export var ambience_bus_db: float = 0.0
@export var weapons_bus_db: float = -1.0
@export var voices_bus_db: float = -1.0
@export var master_limit_db: float = -1.0       ## limiter ceiling on Master
@export var voice_reverb_wet: float = 0.18
@export var crack_duck_db: float = -7.0
@export var thunder_duck_db: float = -4.0
@export var duck_attack: float = 0.03           ## s to reach the duck depth
@export var duck_release: float = 0.9           ## s to recover
@export var dawn_swell_db: float = 2.0          ## ambience lift as the storm breaks (it is quiet then)

var wind_gain: float = -80.0
var rain_gain: float = -80.0
var surf_gain: float = -80.0
var thunders_played: int = 0
var rifle_cracks: int = 0
var hiss_active: int = 0
var kill_thuds: int = 0
var deflects: int = 0
var moans_played: int = 0
var shove_hits: int = 0
var bells_rung: int = 0
var whoomphs: int = 0
var duck_db: float = 0.0          ## current ambience duck (<= 0), for telemetry

var _duck_target: float = 0.0
var _dawn: float = 0.0
var _wind: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _surf: Array[AudioStreamPlayer3D] = []
var _thunder: AudioStreamPlayer
var _pending_thunder: Array[float] = []
var _crack_pool: Array[AudioStreamPlayer] = []
var _click_pool: Array[AudioStreamPlayer] = []
var _bolt_stream: AudioStreamWAV
var _reload_stream: AudioStreamWAV
var _launch_stream: AudioStreamWAV
var _hiss_stream: AudioStreamWAV
var _thud_stream: AudioStreamWAV
var _deflect_stream: AudioStreamWAV
var _deflect_pool: Array[AudioStreamPlayer] = []
var _moan_streams: Array[AudioStreamWAV] = []
var _crackle_stream: AudioStreamWAV
var _butt_stream: AudioStreamWAV
var _whoosh_stream: AudioStreamWAV
var _bell_streams: Array[AudioStreamWAV] = []
var _whoomph_stream: AudioStreamWAV
var _melee_pool: Array[AudioStreamPlayer] = []
var _whoosh: AudioStreamPlayer


const BUS_AMBIENCE: String = "Ambience"
const BUS_WEAPONS: String = "Weapons"
const BUS_VOICES: String = "Voices"


## Find or create a bus (the buses outlive scene reloads, so never add one twice).
static func _bus(bus_name: String) -> int:
	var i: int = AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


func _build_buses() -> void:
	var amb: int = _bus(BUS_AMBIENCE)
	var wpn: int = _bus(BUS_WEAPONS)
	var voc: int = _bus(BUS_VOICES)
	AudioServer.set_bus_volume_db(amb, ambience_bus_db)
	AudioServer.set_bus_volume_db(wpn, weapons_bus_db)
	AudioServer.set_bus_volume_db(voc, voices_bus_db)
	if AudioServer.get_bus_effect_count(voc) == 0:
		var rv: AudioEffectReverb = AudioEffectReverb.new()
		rv.room_size = 0.7
		rv.damping = 0.6
		rv.wet = voice_reverb_wet
		rv.dry = 1.0
		AudioServer.add_bus_effect(voc, rv)
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
		lim.ceiling_db = master_limit_db
		lim.pre_gain_db = 0.0
		AudioServer.add_bus_effect(0, lim)


func _ready() -> void:
	_build_buses()
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
		p.bus = BUS_AMBIENCE
		p.position = Vector3(cos(a) * surf_radius, 0.5, sin(a) * surf_radius)
		add_child(p)
		_surf.append(p)
	_thunder = AudioStreamPlayer.new()
	_thunder.name = "Thunder"
	_thunder.stream = synth.thunder()
	_thunder.volume_db = thunder_db
	_thunder.bus = BUS_AMBIENCE
	add_child(_thunder)
	var crack: AudioStreamWAV = synth.rifle_crack()
	for i: int in 2:
		_crack_pool.append(_oneshot2d("Crack%d" % i, crack, crack_db))
	_bolt_stream = synth.bolt_clack()
	_reload_stream = synth.reload_click()
	for i: int in 2:
		_click_pool.append(_oneshot2d("Click%d" % i, _bolt_stream, click_db))
	_launch_stream = synth.flare_launch()
	_hiss_stream = synth.flare_hiss()
	_thud_stream = synth.kill_thud()
	for v: int in moan_variants:
		_moan_streams.append(synth.moan(v))
	_deflect_stream = synth.dark_deflect()
	for i: int in 2:
		_deflect_pool.append(_oneshot2d("Deflect%d" % i, _deflect_stream, deflect_db))
	# Iteration 1 sounds (synthesized after the original set, so those keep their exact noise).
	_crackle_stream = synth.ember_crackle()
	_butt_stream = synth.butt_strike()
	_whoosh_stream = synth.swing_whoosh()
	for f0: float in [196.0, 233.0, 262.0]:
		_bell_streams.append(synth.sea_bell(f0))
	_whoomph_stream = synth.fire_whoomph()
	for i: int in 2:
		_melee_pool.append(_oneshot2d("Melee%d" % i, _butt_stream, butt_db))
	_whoosh = _oneshot2d("Whoosh", _whoosh_stream, whoosh_db)
	_wind.play()
	_rain.play()
	for i: int in _surf.size():
		_surf[i].play(float(i) * 2.3)  # stagger the swells


func _player2d(n: String, stream: AudioStream) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = n
	p.stream = stream
	p.volume_db = mute_db
	p.bus = BUS_AMBIENCE
	add_child(p)
	return p


func _oneshot2d(n: String, stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = n
	p.stream = stream
	p.volume_db = db
	p.bus = BUS_WEAPONS
	add_child(p)
	return p


func _play_pooled(pool: Array[AudioStreamPlayer], stream: AudioStream) -> void:
	for p: AudioStreamPlayer in pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	pool[0].stream = stream
	pool[0].play()


## Rifle shot (2D, loud). Counted for tests: headless runs use the dummy audio driver.
func play_rifle_crack() -> void:
	rifle_cracks += 1
	duck(crack_duck_db)
	_play_pooled(_crack_pool, _crack_pool[0].stream)


## Dull, hollow metallic "tonk": the shot hit a Drowned that is in the dark and is immune. 2D so it always reads.
func play_deflect() -> void:
	deflects += 1
	_play_pooled(_deflect_pool, _deflect_stream)


func play_bolt() -> void:
	_play_pooled(_click_pool, _bolt_stream)


func play_reload_click() -> void:
	_play_pooled(_click_pool, _reload_stream)


## Flare launch thump, 3D at the muzzle.
func play_flare_launch(pos: Vector3) -> void:
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = _launch_stream
	p.unit_size = 6.0
	p.volume_db = launch_db
	p.bus = BUS_WEAPONS
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = pos
	p.play()


## A looping flare hiss parented to the flare (3D, unit size 6). The Flare scales its volume.
func make_hiss(parent: Node3D) -> AudioStreamPlayer3D:
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.name = "Hiss"
	p.stream = _hiss_stream
	p.unit_size = 6.0
	p.max_distance = 120.0
	p.volume_db = hiss_db
	p.bus = BUS_WEAPONS
	parent.add_child(p)
	p.play(GameRng.randf() * 3.0)
	return p


func hiss_started() -> void:
	hiss_active += 1


func hiss_stopped() -> void:
	hiss_active = maxi(0, hiss_active - 1)


## Rifle kill: a heavy wet thud, 3D at the hit point (unit size 8).
func play_kill_thud(pos: Vector3) -> void:
	kill_thuds += 1
	_oneshot3d(_thud_stream, pos, 8.0, kill_thud_db, 120.0)


## A Drowned moan, 3D at the enemy (unit size 10, max distance 80 m). `variant` picks one of 4.
func play_moan(pos: Vector3, variant: int) -> void:
	moans_played += 1
	_oneshot3d(_moan_streams[posmod(variant, _moan_streams.size())], pos, 10.0, moan_db, 80.0, BUS_VOICES)


func _oneshot3d(stream: AudioStream, pos: Vector3, unit: float, db: float, max_dist: float,
		bus: String = BUS_WEAPONS) -> void:
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.bus = bus
	p.stream = stream
	p.unit_size = unit
	p.volume_db = db
	p.max_distance = max_dist
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = pos
	p.play()


## Looping ember crackle parented to a smoldering / burning Drowned (3D, short range). The owner sets volume.
func make_crackle(parent: Node3D) -> AudioStreamPlayer3D:
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.name = "Crackle"
	p.stream = _crackle_stream
	p.unit_size = crackle_unit_size
	p.max_distance = 40.0
	p.bus = BUS_VOICES
	parent.add_child(p)
	p.play(fposmod(absf(parent.global_position.x * 1.7 + parent.global_position.z), 2.5))  # no GameRng: keeps wave RNG stable
	return p


## Rifle-butt shove: a wooden knock when it connects, an air whoosh when it does not (2D, it is the player's).
func play_shove(connected: bool) -> void:
	if connected:
		shove_hits += 1
		_play_pooled(_melee_pool, _butt_stream)
	else:
		_whoosh.play()


## A sea-bell buoy tolls (3D, carries far over the water). `variant` picks one of three pitches.
func play_bell(pos: Vector3, variant: int) -> void:
	bells_rung += 1
	_oneshot3d(_bell_streams[posmod(variant, _bell_streams.size())], pos, bell_unit_size, bell_db, bell_max_distance, BUS_AMBIENCE)


## Oil / magnesium fire burst (3D).
func play_whoomph(pos: Vector3) -> void:
	whoomphs += 1
	duck(crack_duck_db * 0.6)
	_oneshot3d(_whoomph_stream, pos, 12.0, whoomph_db, 150.0)


func set_storm(wind_speed: float, rain_ratio: float, wave_scale: float) -> void:
	wind_gain = lerpf(wind_db.x, wind_db.y, clampf(inverse_lerp(wind_range.x, wind_range.y, wind_speed), 0.0, 1.0))
	rain_gain = lerpf(rain_db.x, rain_db.y, clampf(rain_ratio, 0.0, 1.0)) if rain_ratio > 0.01 else mute_db
	surf_gain = lerpf(surf_db.x, surf_db.y, clampf(inverse_lerp(surf_range.x, surf_range.y, wave_scale), 0.0, 1.0))
	_wind.volume_db = wind_gain
	_rain.volume_db = rain_gain
	for p: AudioStreamPlayer3D in _surf:
		p.volume_db = surf_gain


## Push the ambience down for a moment (deeper wins); it recovers over duck_release.
func duck(db: float) -> void:
	_duck_target = minf(_duck_target, db)


## Dawn progress 0..1: the storm is gone, so the remaining ambience is lifted slightly.
func set_dawn(d: float) -> void:
	_dawn = clampf(d, 0.0, 1.0)


## Hooked to StormWeather.lightning_struck.
func on_lightning() -> void:
	_pending_thunder.append(GameRng.randf_range(thunder_delay.x, thunder_delay.y))


func _physics_process(delta: float) -> void:
	# Duck: fast attack toward the target, slow release back to 0 dB.
	var rate: float = absf(_duck_target - duck_db) / maxf(duck_attack, 0.001) if _duck_target < duck_db 			else absf(duck_db) / maxf(duck_release, 0.001) + 3.0
	duck_db = move_toward(duck_db, _duck_target, rate * delta)
	if _duck_target < 0.0 and duck_db <= _duck_target + 0.01:
		_duck_target = 0.0   # reached the depth: start releasing
	AudioServer.set_bus_volume_db(_bus(BUS_AMBIENCE), ambience_bus_db + duck_db + dawn_swell_db * _dawn)
	for i: int in range(_pending_thunder.size() - 1, -1, -1):
		_pending_thunder[i] -= delta
		if _pending_thunder[i] <= 0.0:
			_pending_thunder.remove_at(i)
			_thunder.play()
			duck(thunder_duck_db)
			thunders_played += 1


func telemetry() -> Dictionary:
	return {
		"wind_gain": snappedf(wind_gain, 0.001),
		"rain_gain": snappedf(rain_gain, 0.001),
		"surf_gain": snappedf(surf_gain, 0.001),
		"rifle_cracks": rifle_cracks,
		"kill_thuds": kill_thuds,
		"deflects": deflects,
		"flare_hiss_active": hiss_active > 0,
		"moans_played": moans_played,
		"shove_hits": shove_hits,
		"bells": bells_rung,
		"whoomphs": whoomphs,
		"thunders": thunders_played,
		"duck_db": snappedf(duck_db, 0.01),
		"buses": AudioServer.bus_count,
	}
