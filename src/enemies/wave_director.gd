class_name WaveDirector
extends Node
## Wave table, spawning and crate restock (SPEC 4.8 / 4.9). Waves start on the night clock
## (u = night_t / night_len), each one spawns from a seeded 70 degree sector of the sea ring, and
## spawns wait while the Drowned cap is reached. A wave is cleared when everything it spawned is
## dead and nothing is pending. At dawn pending spawns are cancelled and the living Drowned sink.

signal wave_started(index: int)
signal wave_cleared(index: int)
## bell_lead seconds (x k) before a wave starts: the buoy nearest `center` (radians, XZ angle) tolls.
signal wave_warning(index: int, center: float)

@export var start_u: PackedFloat32Array = PackedFloat32Array([0.03, 0.18, 0.34, 0.50, 0.66, 0.82])
@export var counts: PackedInt32Array = PackedInt32Array([3, 5, 7, 9, 11, 14])
@export var intervals: PackedFloat32Array = PackedFloat32Array([3.0, 2.5, 2.0, 1.6, 1.3, 1.0])  ## s, x k
@export var ring_radius: Vector2 = Vector2(60.0, 90.0)
@export var sector_deg: float = 70.0
@export var dawn_sink_time: float = 3.0
@export var enabled: bool = true   ## false = --no_waves
@export var bell_lead: float = 6.0   ## s (x k) of warning before each wave
@export var captain_waves: PackedInt32Array = PackedInt32Array([2, 3, 4, 5])   ## 0-based: waves 3-6 open with a captain
@export var sector_seed: int = 4049  ## sectors come from their own RNG (mixed with the run seed), not GameRng

## Wave number currently in play (0 before wave 1). Waves skipped by --night_t count as played.
var index: int = 0
var state: String = "waiting"   ## waiting | spawning | active | cleared | over
var peak_alive: int = 0

var _clock: NightClock
var _enemies: Enemies
var _crate: AmmoCrate
var _next: int = 0
var _runs: Array[Dictionary] = []   ## {wave, left, timer, interval, center, members:Array[Drowned]}
var _over: bool = false
var _centers: PackedFloat32Array = PackedFloat32Array()
var _warned: int = 0
var forced: int = 0


func setup(clock: NightClock, enemies: Enemies, crate: AmmoCrate) -> void:
	_clock = clock
	_enemies = enemies
	_crate = crate
	# Every wave's sector is known up front so the bells can toll before it rises.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sector_seed * 7919 + GameRng.get_seed()
	_centers.resize(start_u.size())
	for i: int in start_u.size():
		_centers[i] = rng.randf() * TAU
	wave_started.connect(_restock)
	wave_cleared.connect(_restock)
	clock.dawn_started.connect(_on_dawn)
	if clock.phase != "night":
		_begin_over()
		return
	# A late --night_t skips the waves whose start time has already passed.
	while _next < start_u.size() and start_u[_next] * clock.night_len < clock.night_t:
		_next += 1
	index = _next
	_warned = _next
	if not enabled:
		_next = start_u.size()


func total() -> int:
	return start_u.size()


## Night-time second at which the next wave starts (-1 when none is left).
func next_wave_t() -> float:
	if _over or not enabled or _next >= start_u.size():
		return -1.0
	return start_u[_next] * _clock.night_len


func _physics_process(delta: float) -> void:
	if _over or not enabled or _clock == null:
		return
	if _clock.phase == "dead":
		return
	if _warned < start_u.size() and _warned <= _next and _clock.phase == "night" 			and _clock.night_t >= start_u[_warned] * _clock.night_len - bell_lead * _clock.k():
		wave_warning.emit(_warned + 1, _centers[_warned])
		_warned += 1
	if _next < start_u.size() and _clock.u() >= start_u[_next] and _clock.phase == "night":
		_start_wave(_next)
		_next += 1
	_tick_spawns(delta)
	_tick_clears()
	peak_alive = maxi(peak_alive, _enemies.alive_count())
	_refresh_state()


func _start_wave(i: int) -> void:
	index = i + 1
	GameRng.randf()   # keep the GameRng sequence of the original sector pick (moans, flares... stay seeded alike)
	_runs.append({
		"wave": index,
		"left": counts[i],
		"timer": 0.0,
		"interval": intervals[i] * _clock.k(),
		"center": _centers[i],
		"captains": 1 if captain_waves.has(i) else 0,
		"members": [] as Array[Drowned],
	})
	wave_started.emit(index)


func _tick_spawns(delta: float) -> void:
	for run: Dictionary in _runs:
		if int(run["left"]) <= 0:
			continue
		run["timer"] = float(run["timer"]) - delta
		while float(run["timer"]) <= 0.0 and int(run["left"]) > 0:
			if _enemies.alive_count() >= _enemies.max_alive:
				run["timer"] = 0.0   # wait for a free slot; no catch-up burst afterwards
				return
			var members: Array[Drowned] = run["members"]
			var kind: String = "drowned"
			if int(run["captains"]) > 0:
				kind = "captain"
				run["captains"] = int(run["captains"]) - 1
			members.append(_enemies.spawn(_spawn_point(float(run["center"])), false, kind))
			run["left"] = int(run["left"]) - 1
			run["timer"] = float(run["timer"]) + float(run["interval"])


func _tick_clears() -> void:
	for i: int in range(_runs.size() - 1, -1, -1):
		var run: Dictionary = _runs[i]
		if int(run["left"]) > 0:
			continue
		var members: Array[Drowned] = run["members"]
		var any_alive: bool = false
		for m: Drowned in members:
			if is_instance_valid(m) and m.is_alive():
				any_alive = true
				break
		if not any_alive:
			_runs.remove_at(i)
			wave_cleared.emit(int(run["wave"]))


## F4 sandbox: start the next wave right now (its bell tolls at once). Returns false when none is left.
func force_next() -> bool:
	if _over or _next >= start_u.size() or _clock == null or _clock.phase != "night":
		return false
	if _warned <= _next:
		wave_warning.emit(_next + 1, _centers[_next])
		_warned = _next + 1
	_start_wave(_next)
	_next += 1
	forced += 1
	return true


func _spawn_point(center: float) -> Vector2:
	var a: float = center + deg_to_rad(GameRng.randf_range(-sector_deg * 0.5, sector_deg * 0.5))
	var r: float = GameRng.randf_range(ring_radius.x, ring_radius.y)
	return Vector2(cos(a), sin(a)) * r


func _refresh_state() -> void:
	if _over:
		state = "over"
		return
	var spawning: bool = false
	for run: Dictionary in _runs:
		if int(run["left"]) > 0:
			spawning = true
	if spawning:
		state = "spawning"
	elif not _runs.is_empty():
		state = "active"
	elif index > 0:
		state = "cleared"
	else:
		state = "waiting"


func _restock(_wave: int) -> void:
	if _crate != null:
		_crate.restock()


func _on_dawn() -> void:
	_begin_over()


func _begin_over() -> void:
	if _over:
		return
	_over = true
	state = "over"
	_runs.clear()
	if _enemies != null:
		_enemies.sink_all(dawn_sink_time)


func telemetry() -> Dictionary:
	var pending: int = 0
	for run: Dictionary in _runs:
		pending += int(run["left"])
	return {
		"index": index,
		"total": total(),
		"state": state,
		"next_wave_t": snappedf(next_wave_t(), 0.001),
		"pending": pending,
		"peak_alive": peak_alive,
		"warned": _warned,
		"forced": forced,
		"next_sector_deg": snappedf(rad_to_deg(_centers[_warned - 1]), 0.1) if _warned > 0 and _warned <= _centers.size() else -1.0,
	}
