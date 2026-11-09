extends SceneTree
## Headless simulation bot. Loads a scene, replays a timed input plan, steps physics as fast
## as possible, prints telemetry JSON and checks expectations.
##
## Run via tools/sim.sh (adds --headless --fixed-fps 60 so every frame is one physics tick):
##   tools/sim.sh --plan=res://tests/plans/smoke.json --frames=600 --every=60 \
##                --expect="physics_frames>=600" --expect="player.on_floor==true"
##
## User args (after `--`):
##   --scene=res://main.tscn   scene to load (default main.tscn)
##   --frames=N                physics frames to run (default 300)
##   --every=N                 print TELEMETRY every N frames (default 60; 0 = only start/end)
##   --plan=res://...json      input plan file;  --plan-json='[...]' inline plan
##   --expect="path OP value"  final-state check, repeatable. OP: == != >= <= > <
##                             path is dot-separated into get_telemetry() (arrays: pos.1)
##   --tolerate-errors         don't fail on engine/script errors (still reported)
##
## Plan = JSON array of steps. Timing: "f" (physics frame) or "t" (seconds). Optional "to"/"until"
## makes a step repeat every frame in [f, to). Step kinds:
##   {"f":0,  "key":"W", "down":true}            key press / release ("hold":N auto-releases)
##   {"f":10, "key":"Space", "hold":5}
##   {"f":0,  "to":120, "mouse_motion":[4,0]}    relative mouse motion (px) each frame
##   {"f":30, "mouse_button":"left", "hold":3}   left|right|middle|wheel_up|wheel_down
##   {"f":30, "action":"jump", "down":true}      InputEventAction (or "hold":N)
##   {"f":200,"expect":"speed>1.5"}              mid-run expectation at that frame
##
## Output lines (stable prefixes, made for grep / the playtester agent):
##   TELEMETRY {"frame":N, ...}   EXPECT PASS|FAIL ...   SIM_ERROR ...   SIM_RESULT PASS|FAIL ...
## Exit codes: 0 pass, 1 expectation failed, 2 errors logged, 3 setup failure.

const PHYSICS_HZ: float = 60.0


class ErrorCatcher extends Logger:
	var mutex: Mutex = Mutex.new()
	var errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][error_type]
		var msg: String = rationale if not rationale.is_empty() else code
		var where: String = "%s:%d (%s)" % [file, line, function]
		var trace: String = ""
		for bt: ScriptBacktrace in script_backtraces:
			if bt != null and not bt.is_empty():
				trace = bt.format().strip_edges()
				break
		mutex.lock()
		errors.append("%s: %s @ %s%s" % [kind, msg, where, ("\n" + trace) if trace != "" else ""])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _catcher: ErrorCatcher = ErrorCatcher.new()
var _main: Node
var _plan: Array = []
var _frame: int = 0
var _frames: int = 300
var _every: int = 60
var _first_telemetry: Dictionary = {}
var _expect_failures: PackedStringArray = []
var _finished: bool = false


func _initialize() -> void:
	OS.add_logger(_catcher)
	_frames = int(_arg("frames", "300"))
	_every = int(_arg("every", "60"))

	var scene_path: String = _arg("scene", "res://main.tscn")
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		_finish(3, "cannot load scene %s" % scene_path)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	current_scene = _main

	if not _load_plan():
		return
	print("SIM_START scene=%s frames=%d steps=%d" % [scene_path, _frames, _plan.size()])


func _physics_process(_delta: float) -> bool:
	# Called once per physics tick, before the scene's nodes. `_frame` = ticks completed so far,
	# so telemetry printed at frame N reflects exactly N simulated ticks.
	if _finished:
		return true
	if _frame == 0:
		_first_telemetry = _telemetry()
		_print_telemetry(_first_telemetry)
	elif _every > 0 and _frame % _every == 0 and _frame < _frames:
		_print_telemetry(_telemetry())
	if _frame >= _frames:
		_end_run()
		return true
	_apply_plan(_frame)
	_frame += 1
	return false


func _end_run() -> void:
	var last: Dictionary = _telemetry()
	_print_telemetry(last)
	print("DELTA " + JSON.stringify(_numeric_delta(_first_telemetry, last)))
	for e: String in BootArgs.get_all("expect"):
		_check_expect(e, last)
	if not _expect_failures.is_empty():
		_finish(1, "%d expectation(s) failed" % _expect_failures.size())
	else:
		_finish(0, "")


func _finish(code: int, reason: String) -> void:
	if _finished:
		return
	_finished = true
	_catcher.mutex.lock()
	var errors: PackedStringArray = _catcher.errors.duplicate()
	_catcher.mutex.unlock()
	var counts: Dictionary = {}  # dedupe repeated per-frame errors, keep first-seen order
	for e: String in errors:
		counts[e] = int(counts.get(e, 0)) + 1
	for e: String in counts:
		var n: int = counts[e]
		print("SIM_ERROR %s%s" % [("(x%d) " % n) if n > 1 else "", e.replace("
", "
    | ")])
	if code == 0 and not errors.is_empty() and not BootArgs.get_value("tolerate-errors", false):
		code = 2
		reason = "%d error(s) logged during run" % errors.size()
	if code == 0:
		print("SIM_RESULT PASS frames=%d errors=%d" % [_frame, errors.size()])
	else:
		print("SIM_RESULT FAIL code=%d frame=%d reason=%s" % [code, _frame, reason])
	quit(code)


# --- plan -------------------------------------------------------------------------------------

func _load_plan() -> bool:
	var text: String = str(_arg("plan-json", ""))
	var plan_path: String = str(_arg("plan", ""))
	if text.is_empty() and not plan_path.is_empty():
		if not FileAccess.file_exists(plan_path):
			_finish(3, "plan not found: %s" % plan_path)
			return false
		text = FileAccess.get_file_as_string(plan_path)
	if text.is_empty():
		return true
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Array:
		_finish(3, "plan is not a JSON array")
		return false
	for step: Variant in parsed:
		if not step is Dictionary:
			continue
		var s: Dictionary = step
		s["_f"] = _to_frame(s, "f", "t", 0)
		s["_to"] = _to_frame(s, "to", "until", -1)
		_plan.append(s)
		if s.has("hold"):  # synthesize the matching release
			var rel: Dictionary = s.duplicate()
			rel.erase("hold")
			rel["down"] = false
			rel["_f"] = int(s["_f"]) + int(s["hold"])
			rel["_to"] = -1
			s["down"] = true
			_plan.append(rel)
	return true


func _to_frame(s: Dictionary, frame_key: String, time_key: String, default: int) -> int:
	if s.has(frame_key):
		return int(s[frame_key])
	if s.has(time_key):
		return roundi(float(s[time_key]) * PHYSICS_HZ)
	return default


func _apply_plan(frame: int) -> void:
	for s: Dictionary in _plan:
		var start: int = s["_f"]
		var stop: int = s["_to"]
		var active: bool = frame == start if stop < 0 else (frame >= start and frame < stop)
		if active:
			_apply_step(s)


func _apply_step(s: Dictionary) -> void:
	var down: bool = bool(s.get("down", true))
	if s.has("key"):
		var ev: InputEventKey = InputEventKey.new()
		var code: Key = OS.find_keycode_from_string(str(s["key"]))
		if code == KEY_NONE:
			push_error("sim_bot: unknown key '%s'" % s["key"])
			return
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		_send(ev)
	elif s.has("mouse_motion"):
		var rel: Array = s["mouse_motion"]
		var ev: InputEventMouseMotion = InputEventMouseMotion.new()
		ev.relative = Vector2(float(rel[0]), float(rel[1]))
		ev.screen_relative = ev.relative
		ev.velocity = ev.relative * PHYSICS_HZ
		ev.position = root.get_visible_rect().size * 0.5
		ev.global_position = ev.position
		_send(ev)
	elif s.has("mouse_button"):
		var names: Dictionary = {
			"left": MOUSE_BUTTON_LEFT, "right": MOUSE_BUTTON_RIGHT, "middle": MOUSE_BUTTON_MIDDLE,
			"wheel_up": MOUSE_BUTTON_WHEEL_UP, "wheel_down": MOUSE_BUTTON_WHEEL_DOWN,
		}
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = names.get(str(s["mouse_button"]), MOUSE_BUTTON_LEFT)
		ev.pressed = down
		ev.position = root.get_visible_rect().size * 0.5
		ev.global_position = ev.position
		_send(ev)
	elif s.has("action"):
		var ev: InputEventAction = InputEventAction.new()
		ev.action = StringName(str(s["action"]))
		ev.pressed = down
		ev.strength = 1.0 if down else 0.0
		_send(ev)
	elif s.has("expect"):
		_check_expect(str(s["expect"]), _telemetry(), "@f%d " % _frame)


func _send(ev: InputEvent) -> void:
	# Updates Input singleton state (is_key_pressed / is_action_pressed / velocity) and,
	# once flushed, dispatches through the viewport (_input / _unhandled_input).
	Input.parse_input_event(ev)


# --- telemetry & expectations -----------------------------------------------------------------

func _telemetry() -> Dictionary:
	var t: Dictionary = {}
	if is_instance_valid(_main) and _main.has_method("get_telemetry"):
		t = _main.call("get_telemetry")
	t["frame"] = _frame
	return t


func _print_telemetry(t: Dictionary) -> void:
	print("TELEMETRY " + JSON.stringify(t, "", false))


func _numeric_delta(a: Variant, b: Variant) -> Variant:
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		var out: Dictionary = {}
		for k: Variant in db:
			if da.has(k):
				var d: Variant = _numeric_delta(da[k], db[k])
				if d != null:
					out[k] = d
		return out if not out.is_empty() else null
	if (a is int or a is float) and (b is int or b is float):
		if is_equal_approx(float(a), float(b)):
			return null
		return b - a if (a is int and b is int) else snappedf(float(b) - float(a), 0.001)
	if a is Vector2 and b is Vector2:
		var va: Vector2 = a
		var vb: Vector2 = b
		return null if va.is_equal_approx(vb) else str(vb - va)
	if a is Vector3 and b is Vector3:
		var wa: Vector3 = a
		var wb: Vector3 = b
		return null if wa.is_equal_approx(wb) else str(wb - wa)
	if a is Array and b is Array and (a as Array).size() == (b as Array).size():
		var aa: Array = a
		var ab: Array = b
		var arr: Array = []
		var any: bool = false
		for i: int in aa.size():
			var d: Variant = _numeric_delta(aa[i], ab[i])
			any = any or d != null
			arr.append(d if d != null else 0)
		return arr if any else null
	return null if a == b else "%s -> %s" % [a, b]


func _check_expect(expr: String, t: Dictionary, prefix: String = "") -> void:
	var re: RegEx = RegEx.create_from_string("^\\s*([\\w.]+)\\s*(==|!=|>=|<=|>|<)\\s*(.*?)\\s*$")
	var m: RegExMatch = re.search(expr)
	if m == null:
		_expect_failures.append(expr)
		print("EXPECT FAIL %s(bad syntax) %s" % [prefix, expr])
		return
	var actual: Variant = _dig(t, m.get_string(1))
	var want: Variant = _parse_value(m.get_string(3))
	var ok: bool = _compare(actual, m.get_string(2), want)
	if not ok:
		_expect_failures.append(expr)
	print("EXPECT %s %s%s (actual=%s)" % ["PASS" if ok else "FAIL", prefix, expr, actual])


func _dig(t: Variant, path: String) -> Variant:
	var cur: Variant = t
	for part: String in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = (cur as Dictionary)[part]
		elif (cur is Array or cur is Vector2 or cur is Vector3) and part.is_valid_int():
			cur = cur[int(part)]
		else:
			return null
	return cur


func _parse_value(s: String) -> Variant:
	if s == "true" or s == "false":
		return s == "true"
	if s == "null":
		return null
	if s.is_valid_float():
		return float(s)
	return s.trim_prefix("\"").trim_suffix("\"")


func _compare(a: Variant, op: String, b: Variant) -> bool:
	if a == null and b != null:
		return op == "!="
	if (a is int or a is float or a is bool) and b is float:
		var x: float = float(a)
		var y: float = b
		match op:
			"==": return is_equal_approx(x, y)
			"!=": return not is_equal_approx(x, y)
			">=": return x >= y
			"<=": return x <= y
			">": return x > y
			"<": return x < y
	match op:
		"==": return str(a) == str(b)
		"!=": return str(a) != str(b)
	return false


func _arg(key: String, default: String) -> String:
	return str(BootArgs.get_value(key, default))
