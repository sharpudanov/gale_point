class_name Sandbox
extends Node
## Live human sandbox (DESIGN_LOG / `/iterate` step 4). Only built in normal play (never during a locked
## `--shot` preset); the headless sim bot can press the same keys.
##   F1  spawn the newest enemies 10 m ahead in the dark: a Lantern Captain, a Drowned already wounded to
##       wounded_hp (smoldering) and a fresh one.
##   F2  a burning flare at the aim point, plus full rifle magazine/reserve and full flares.
##   F3  toggle god mode and restore full HP.
##   F4  start the next wave now (its bell tolls), or a lightning strike when no wave is left.

@export var spawn_distance: float = 10.0
@export var spawn_spacing: float = 2.6
@export var wounded_hp: float = 45.0
@export var flare_max_distance: float = 80.0
@export var flare_fallback_distance: float = 18.0
@export var flare_start_age: float = 0.6     ## already past the ignite ramp

var main: Node3D
var player: Player
var weapons: WeaponHolder
var enemies: Enemies
var waves: WaveDirector
var weather: StormWeather
var island: Island

var spawns: int = 0
var flares: int = 0
var god_toggles: int = 0
var wave_skips: int = 0
var strikes: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if player == null or event.is_echo():
		return
	if event.is_action_pressed("dev_spawn"):
		spawn_trio()
	elif event.is_action_pressed("dev_flare"):
		flare_and_refill()
	elif event.is_action_pressed("dev_god"):
		toggle_god()
	elif event.is_action_pressed("dev_wave"):
		next_wave_or_strike()


func _ahead() -> Dictionary:
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right: Vector3 = Vector3(-fwd.z, 0.0, fwd.x)
	return {"fwd": fwd, "right": right, "base": player.global_position + fwd * spawn_distance}


func spawn_trio() -> void:
	var a: Dictionary = _ahead()
	var base: Vector3 = a["base"]
	var right: Vector3 = a["right"]
	enemies.spawn(Vector2(base.x, base.z), true, "captain")
	var hurt: Drowned = enemies.spawn(Vector2(base.x - right.x * spawn_spacing, base.z - right.z * spawn_spacing), true)
	hurt.hp = wounded_hp
	enemies.spawn(Vector2(base.x + right.x * spawn_spacing, base.z + right.z * spawn_spacing), true)
	spawns += 1


func flare_and_refill() -> void:
	var cam: Camera3D = player.camera
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * flare_max_distance, 1, [player.get_rid()])
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	var p: Vector3
	if hit.is_empty():
		var a: Dictionary = _ahead()
		var fwd: Vector3 = a["fwd"]
		p = player.global_position + fwd * flare_fallback_distance
		p.y = island.height_at(p.x, p.z) + 0.06
	else:
		p = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.06
	weapons.flare_gun.spawn_flare(p, Vector3.ZERO, flare_start_age)
	weapons.refill_all()
	flares += 1


func toggle_god() -> void:
	player.god = not player.god
	if player.is_alive():
		player.hp = player.max_hp
	god_toggles += 1


func next_wave_or_strike() -> void:
	if waves != null and waves.enabled and waves.force_next():
		wave_skips += 1
		return
	weather.strike(0.08)
	strikes += 1


func telemetry() -> Dictionary:
	return {"spawns": spawns, "flares": flares, "god_toggles": god_toggles, "wave_skips": wave_skips,
		"strikes": strikes, "god": player.god if player != null else false}
