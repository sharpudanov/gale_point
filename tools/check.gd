extends SceneTree
## Parse/load checker used by tools/godot_check.sh (the PostToolUse hook).
## Usage: godot --headless --path . --script res://tools/check.gd -- res://a.gd res://b.tscn ...
## Loads the given resources plus every .gd in the project (to catch cascading breakage
## from class_name changes). Engine prints the real errors; we print CHECK_FAIL markers.

const SELF_PATH: String = "res://tools/check.gd"
const SKIP_DIRS: Array[String] = ["res://.godot", "res://addons", "res://.captures", "res://.claude"]


func _initialize() -> void:
	var targets: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("res://") and not targets.has(arg):
			targets.append(arg)
	for path: String in _find_scripts("res://"):
		if not targets.has(path):
			targets.append(path)

	var failed: int = 0
	for path: String in targets:
		if not _check(path):
			failed += 1
	quit(1 if failed > 0 else 0)


func _check(path: String) -> bool:
	if not FileAccess.file_exists(path) or path == SELF_PATH:
		return true  # deleted/renamed, or this checker itself (reloading it would corrupt the VM)
	if path.get_extension() == "gdshader":
		# Loading a Shader compiles it (even on the headless dummy renderer), but engine errors
		# report the location as "(:line)". This marker lets godot_check.sh attribute them.
		printerr("CHECK_SHADER %s" % path)
	var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		printerr("CHECK_FAIL %s: failed to load" % path)
		return false
	# A GDScript with parse/analyzer errors still loads, but never gets a native base type.
	if res is Script and (res as Script).get_instance_base_type() == &"":
		printerr("CHECK_FAIL %s: script does not compile" % path)
		return false
	if res is Shader:
		# Force a compile on the (dummy) RenderingServer; errors are printed by the engine.
		RenderingServer.shader_set_code((res as Shader).get_rid(), (res as Shader).code)
	return true


func _find_scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		var sub_path: String = dir_path.path_join(sub)
		if not SKIP_DIRS.has(sub_path):
			out.append_array(_find_scripts(sub_path))
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			out.append(dir_path.path_join(file))
	return out
