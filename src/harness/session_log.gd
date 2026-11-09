class_name SessionLog
extends Node
## Flight recorder for human play sessions (harness, not gameplay). Writes one JSON object per line to
## res://.captures/sessions/session_<unix>.jsonl, so /iterate and the game-director read what actually
## happened in a playtest instead of relying on memory:
##   start   boot args, engine version
##   change  a watched telemetry value changed (hp, phase, wave, sandbox keys, ...), with the time
##   error   a script / engine error that was logged during play (unique messages only)
##   snap    every snapshot_interval seconds: frame rate + a few headline values (breadcrumb after a crash)
##   mark    P / F12 was pressed: the screenshot's file name and the full telemetry at that instant
##   end     reason (dead | won | quit), frame-rate summary and the full final telemetry
## main.gd builds it in normal windowed play only: never under a --shot preset, and in headless sims only
## when --session_log forces it (that run writes sim_session.jsonl, so a test never poses as a human session).
## It only reads telemetry; it never touches game state or GameRng. Digest: tools/evidence.sh.

@export var dir_path: String = "res://.captures/sessions"
@export var poll_interval: float = 1.0        ## s between telemetry polls (change detection)
@export var snapshot_interval: float = 10.0   ## s between "snap" lines
@export var fps_warmup: float = 3.0           ## s ignored at boot (shader compilation hitches)
@export var max_errors: int = 20              ## unique error messages kept per session
## A "change" line is written whenever one of these telemetry paths changes between two polls.
@export var watch_paths: PackedStringArray = [
	"time.phase", "waves.index", "player.hp", "player.alive", "enemies.reached_lighthouse",
	"enemies.captains_killed", "crate.uses", "lighthouse.overdrives", "island.braziers_lit",
	"sandbox.spawns", "sandbox.flares", "sandbox.god_toggles", "sandbox.wave_skips", "sandbox.strikes",
]
## Headline values copied into every "snap" line.
@export var snap_paths: PackedStringArray = [
	"time.night_t", "waves.index", "enemies.alive", "enemies.killed", "player.hp",
	"weapon.shots_fired", "flares.left",
]
## Compact "stats" block written at the front of every "mark" and "end" line (the full telemetry follows it).
@export var summary_paths: PackedStringArray = [
	"time.phase", "time.night_t", "waves.index", "player.hp",
	"weapon.shots_fired", "weapon.hits_lit", "weapon.hits_dark", "weapon.hits_head",
	"flares.fired", "flares.left", "crate.uses",
	"enemies.spawned", "enemies.alive", "enemies.killed", "enemies.killed_by_rifle", "enemies.killed_by_light",
	"enemies.killed_by_fire", "enemies.captains_killed", "enemies.reached_lighthouse",
	"fire.bursts", "fire.oil_fires", "island.braziers_lit", "lighthouse.overdrives",
	"sandbox.spawns", "sandbox.flares", "sandbox.god_toggles", "sandbox.wave_skips", "sandbox.strikes",
]


class ErrorTap extends Logger:
	var mutex: Mutex = Mutex.new()
	var pending: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var msg: String = rationale if not rationale.is_empty() else code
		mutex.lock()
		pending.append("%s @ %s:%d (%s)" % [msg, file, line, function])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


## Returns the telemetry dictionary (main.get_telemetry).
var source: Callable
## Set before the node enters the tree to write this file instead (tools/bench.sh: bench_<preset>.jsonl).
var file_name: String = ""

var lines: int = 0
var changes: int = 0
var marks: int = 0
var errors: int = 0

var _file: FileAccess
var _tap: ErrorTap
var _seen_errors: Dictionary = {}
var _t: float = 0.0
var _poll_left: float = 0.0
var _snap_left: float = 0.0
var _last: Dictionary = {}
var _watched: Dictionary = {}
var _ended: bool = false
# Frame rate: an overall average, the slowest one-second window and the single worst frame.
var _real_t: float = 0.0
var _frames: int = 0
var _frame_time: float = 0.0
var _win_frames: int = 0
var _win_time: float = 0.0
var _fps_low: float = -1.0
var _worst_ms: float = 0.0
var _snap_frames: int = 0
var _snap_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var abs_dir: String = ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var headless: bool = DisplayServer.get_name() == "headless"
	var target: String = file_name
	if target.is_empty():
		target = "sim_session.jsonl" if headless else "session_%d.jsonl" % int(Time.get_unix_time_from_system())
	_file = FileAccess.open(abs_dir.path_join(target), FileAccess.WRITE)
	if _file == null:
		push_warning("SessionLog: cannot write %s (recording disabled)" % abs_dir.path_join(target))
		set_process(false)
		set_physics_process(false)
		return
	_tap = ErrorTap.new()
	OS.add_logger(_tap)
	_snap_left = snapshot_interval
	_write({
		"type": "start",
		"time": Time.get_datetime_string_from_system(),
		"godot": str(Engine.get_version_info().get("string", "")),
		"args": OS.get_cmdline_user_args(),
	})


func _exit_tree() -> void:
	_end("quit")
	if _tap != null:
		OS.remove_logger(_tap)
		_tap = null
	_file = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_end("quit")


func _process(delta: float) -> void:
	_real_t += delta
	if _real_t < fps_warmup:
		return
	_frames += 1
	_frame_time += delta
	_snap_frames += 1
	_snap_time += delta
	_worst_ms = maxf(_worst_ms, delta * 1000.0)
	_win_frames += 1
	_win_time += delta
	if _win_time >= 1.0:
		var fps: float = float(_win_frames) / _win_time
		_fps_low = fps if _fps_low < 0.0 else minf(_fps_low, fps)
		_win_frames = 0
		_win_time = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = poll_interval
		_poll()
	_snap_left -= delta
	if _snap_left <= 0.0:
		_snap_left = snapshot_interval
		_snap()


## P / F12: bookmark this instant (called by main.gd after the PNG is saved).
func mark(png_name: String) -> void:
	if _file == null:
		return
	marks += 1
	var tel: Dictionary = _telemetry()
	_write({"type": "mark", "t": _secs(), "png": png_name, "stats": _pick(tel, summary_paths), "tel": tel})


func telemetry() -> Dictionary:
	return {"active": _file != null, "lines": lines, "changes": changes, "marks": marks, "errors": errors}


func _poll() -> void:
	_drain_errors()
	var tel: Dictionary = _telemetry()
	for path: String in watch_paths:
		var now: Variant = _dig(tel, path)
		if _watched.has(path):
			var was: Variant = _watched[path]
			if typeof(was) != typeof(now) or was != now:
				changes += 1
				_write({"type": "change", "t": _secs(), "path": path, "from": was, "to": now})
		_watched[path] = now
	_last = tel
	var phase: String = str(_dig(tel, "time.phase"))
	if phase == "dead" or phase == "won":
		_end(phase)


func _snap() -> void:
	var fps: float = float(_snap_frames) / _snap_time if _snap_time > 0.0 else 0.0
	_snap_frames = 0
	_snap_time = 0.0
	_write({"type": "snap", "t": _secs(), "fps": snappedf(fps, 0.1), "v": _pick(_last, snap_paths)})


func _end(reason: String) -> void:
	if _ended or _file == null:
		return
	_ended = true
	_drain_errors()
	_write({
		"type": "end",
		"reason": reason,
		"t": _secs(),
		"fps_avg": snappedf(float(_frames) / _frame_time if _frame_time > 0.0 else 0.0, 0.1),
		"fps_low_1s": snappedf(maxf(_fps_low, 0.0), 0.1),
		"worst_frame_ms": snappedf(_worst_ms, 0.1),
		"errors": errors,
		"stats": _pick(_last, summary_paths),
		"tel": _last,
	})


func _drain_errors() -> void:
	if _tap == null:
		return
	_tap.mutex.lock()
	var batch: PackedStringArray = _tap.pending.duplicate()
	_tap.pending.clear()
	_tap.mutex.unlock()
	for msg: String in batch:
		if _seen_errors.has(msg):
			continue
		_seen_errors[msg] = true
		errors += 1
		if errors <= max_errors:
			_write({"type": "error", "t": _secs(), "msg": msg})


func _telemetry() -> Dictionary:
	if not source.is_valid():
		return {}
	var tel: Dictionary = source.call()
	return tel


func _secs() -> float:
	return snappedf(_t, 0.01)


func _write(entry: Dictionary) -> void:
	if _file == null:
		return
	_file.store_line(JSON.stringify(entry, "", false))
	_file.flush()
	lines += 1


static func _pick(tel: Dictionary, paths: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for path: String in paths:
		out[path] = _dig(tel, path)
	return out


static func _dig(root: Variant, path: String) -> Variant:
	var cur: Variant = root
	for part: String in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = (cur as Dictionary)[part]
		elif cur is Array and part.is_valid_int() and int(part) < (cur as Array).size():
			cur = (cur as Array)[int(part)]
		else:
			return null
	return cur
