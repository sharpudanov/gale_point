extends Node3D
## Game root. The only node authored in a .tscn — everything else is built in code
## from class_name scripts in res://src/ (see CLAUDE.md, "pure-code scene rule").

## Camera/storm preset requested via `-- --shot=<name>` (tools/capture.sh). Empty = normal play.
var shot: String = ""

var _physics_frames: int = 0


func _ready() -> void:
	shot = str(BootArgs.get_value("shot", ""))
	if shot == "test":
		TestShot.build(self)  # harness self-test (tools/capture.sh test)


func _physics_process(_delta: float) -> void:
	_physics_frames += 1


## Snapshot of game state for tests/sim_bot.gd. Keep it flat-ish, JSON-serializable,
## and extend it as systems are added (player position, wind speed, etc.).
func get_telemetry() -> Dictionary:
	return {
		"physics_frames": _physics_frames,
		"shot": shot,
		"child_count": get_child_count(),
	}
