class_name SceneExporter
extends RefCounted
## --export_scene[=res://path.tscn] (tools/export_scene.sh): saves the game tree that main.gd built in code as a
## real scene you can open and inspect in the Godot editor. A snapshot for looking, not the game: scripts are
## stripped (otherwise running it would build everything a second time on top of the saved nodes), runtime
## signal connections are not saved, and the procedural audio streams are dropped (megabytes of samples as text).
## Default path: res://snapshot/game.tscn (gitignored). The game itself never loads it.

const DEFAULT_PATH: String = "res://snapshot/game.tscn"


static func save_tree(root: Node, path: String) -> Error:
	var target: String = path if path.ends_with(".tscn") or path.ends_with(".scn") else DEFAULT_PATH
	root.scene_file_path = ""
	var stats: Dictionary = {"nodes": 0, "instances": 0, "audio": 0}
	_prepare(root, root, stats)
	root.set_script(null)
	var ps: PackedScene = PackedScene.new()
	var err: Error = ps.pack(root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
		err = ResourceSaver.save(ps, target)
	print("export_scene: %s -> %s (nodes %d, instanced %d, audio streams dropped %d)" % [
		error_string(err), target, int(stats["nodes"]), int(stats["instances"]), int(stats["audio"])])
	return err


## Owns every code-built node to `root` so pack() saves it; instanced glTF scenes stay instances, with editable
## children so their runtime material overrides (wet rocks) are saved too.
static func _prepare(root: Node, node: Node, stats: Dictionary) -> void:
	for c: Node in node.get_children():
		if c.owner == null:
			c.owner = root
		stats["nodes"] = int(stats["nodes"]) + 1
		if not c.scene_file_path.is_empty():
			root.set_editable_instance(c, true)
			stats["instances"] = int(stats["instances"]) + 1
		_prepare(root, c, stats)
		_strip(c, stats)


static func _strip(n: Node, stats: Dictionary) -> void:
	if n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D:
		if n.get("stream") != null:
			n.set("stream", null)
			stats["audio"] = int(stats["audio"]) + 1
	if n.get_script() != null:
		n.set_script(null)
