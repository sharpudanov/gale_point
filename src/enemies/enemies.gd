class_name Enemies
extends Node3D
## Container and shared services for the Drowned (SPEC 3 "Enemies"): spawning, separation, kill
## bookkeeping, hit effects and the telemetry block. M4's WaveDirector spawns through spawn().

signal enemy_killed(enemy: Drowned)

@export var door_point: Vector3 = Vector3(0.0, 5.0, 3.2)
@export var max_alive: int = 14
@export var telemetry_list_max: int = 16
@export var wind_ref_speed: float = 13.0

var island: Island
var ocean: Ocean
var field: LightField
var lighthouse: Lighthouse
var player: Player
var audio: Soundscape
var trails: WetTrails
var weather: StormWeather
var freeze: bool = false

var spawned: int = 0
var killed: int = 0
var killed_by_rifle: int = 0
var killed_by_light: int = 0
var reached_lighthouse: int = 0

var _list: Array[Drowned] = []
var _next_id: int = 0


func setup(isl: Island, oc: Ocean, lf: LightField, lh: Lighthouse, pl: Player, snd: Soundscape,
		wt: WetTrails, wx: StormWeather) -> void:
	island = isl
	ocean = oc
	field = lf
	lighthouse = lh
	player = pl
	audio = snd
	trails = wt
	weather = wx


## Spawn a Drowned at world (x, z). `emerged` = already risen (debug spawns); otherwise it rises from the sea.
func spawn(xz: Vector2, emerged: bool) -> Drowned:
	var d: Drowned = Drowned.new()
	d.name = "Drowned%d" % _next_id
	d.setup(self, _next_id, xz, emerged)
	_next_id += 1
	spawned += 1
	_list.append(d)
	add_child(d)
	return d


func alive_count() -> int:
	var n: int = 0
	for d: Drowned in _list:
		if d.is_alive():
			n += 1
	return n


## Every Drowned node in the scene, including the ones still dissolving (the performance budget).
func node_count() -> int:
	return _list.size()


## Dawn: every living Drowned sinks and dissolves over `duration` seconds.
func sink_all(duration: float) -> void:
	for d: Drowned in _list.duplicate():
		d.dissolve_away(duration)


func first() -> Drowned:
	return _list[0] if not _list.is_empty() else null


## Unit-length sum of "step away" vectors from neighbours closer than `radius` (XZ only).
func separation_push(me: Drowned, radius: float) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	for o: Drowned in _list:
		if o == me or not o.is_alive():
			continue
		var d: Vector3 = me.global_position - o.global_position
		d.y = 0.0
		var l: float = d.length()
		if l < radius:
			push += (d / maxf(l, 0.05)) * (1.0 - l / radius)
	return push


func on_death(d: Drowned, by: String) -> void:
	if by == "rifle" or by == "light":
		killed += 1
		if by == "rifle":
			killed_by_rifle += 1
		else:
			killed_by_light += 1
		enemy_killed.emit(d)


## Rifle kill feedback (SPEC 4.8): splash, brief warm spark and the 3D kill thud at the hit point.
func lethal_hit(point: Vector3, shot_dir: Vector3) -> void:
	HitFx.lethal_splash(self, point, shot_dir)
	HitFx.lethal_spark(self, point, shot_dir)
	audio.play_kill_thud(point)


func splash_at(pos: Vector3) -> void:
	HitFx.emerge_splash(self, pos)


func forget(d: Drowned) -> void:
	_list.erase(d)


func _process(_delta: float) -> void:
	var cloth: ShaderMaterial = DrownedBuilder.cloth_material()
	var w: Vector3 = weather.wind() if weather != null else Vector3.ZERO
	var dir: Vector3 = w.normalized() if w.length() > 0.001 else Vector3(1.0, 0.0, 0.0)
	cloth.set_shader_parameter("wind_dir", Vector2(dir.x, dir.z))
	cloth.set_shader_parameter("wind_strength", clampf(w.length() / wind_ref_speed, 0.0, 1.5))


func telemetry() -> Dictionary:
	var lit_n: int = 0
	var rev_n: int = 0
	var lit_sum: float = 0.0
	var dark_sum: float = 0.0
	var dark_n: int = 0
	var nearest: float = -1.0
	var items: Array = []
	var alive: int = 0
	for d: Drowned in _list:
		if d.state == "dying":
			continue
		alive += 1
		if d.lit:
			lit_n += 1
		if d.revealed:
			rev_n += 1
		if d.state == "gliding":
			if d.lit:
				lit_sum += d.speed
			else:
				dark_sum += d.speed
				dark_n += 1
		if player != null:
			var dist: float = d.global_position.distance_to(player.global_position)
			nearest = dist if nearest < 0.0 else minf(nearest, dist)
	var lit_gliding: int = 0
	for d: Drowned in _list:
		if d.state == "gliding" and d.lit:
			lit_gliding += 1
	for d: Drowned in _list:
		if items.size() >= telemetry_list_max:
			break
		items.append(d.telemetry())
	return {
		"alive": alive,
		"spawned": spawned,
		"killed": killed,
		"killed_by_rifle": killed_by_rifle,
		"killed_by_light": killed_by_light,
		"lit_count": lit_n,
		"revealed_count": rev_n,
		"mean_speed_lit": snappedf(lit_sum / lit_gliding, 0.001) if lit_gliding > 0 else 0.0,
		"mean_speed_dark": snappedf(dark_sum / dark_n, 0.001) if dark_n > 0 else 0.0,
		"nearest_dist": snappedf(nearest, 0.01),
		"reached_lighthouse": reached_lighthouse,
		"list": items,
	}
