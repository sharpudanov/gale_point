extends SceneTree
## Prints what a glTF / GLB holds, so nobody has to open the file: size in metres, node tree, triangles,
## materials, bones and animation clips. Run from the project root:
##   source tools/env.sh && "$GODOT" --headless --path . \
##     --script .claude/skills/godot-models/templates/model_info.gd -- res://assets/models/<name>/<file>.glb

const MAX_LINES: int = 60

var _tris: int = 0
var _surfaces: int = 0
var _lines: int = 0
var _boxes: Array[AABB] = []


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: ... --script <this file> -- res://assets/models/<name>/<file>.glb")
		quit(1)
		return
	var packed: PackedScene = null
	if ResourceLoader.exists(args[0]):
		packed = load(args[0]) as PackedScene
	if packed == null:
		print("MODEL_NOT_LOADED ", args[0], "  (new file? run: source tools/env.sh && ensure_imported force)")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	print("MODEL ", args[0])
	_walk(inst, 0, Transform3D.IDENTITY)
	if _lines > MAX_LINES:
		print("  ... ", _lines - MAX_LINES, " more nodes")
	var box: AABB = AABB()
	for i: int in _boxes.size():
		box = _boxes[i] if i == 0 else box.merge(_boxes[i])
	print("SIZE m  x=%.3f y=%.3f z=%.3f   lowest y=%.3f   centre=(%.3f, %.3f, %.3f)" % [
		box.size.x, box.size.y, box.size.z, box.position.y,
		box.get_center().x, box.get_center().y, box.get_center().z])
	print("TOTAL ", _tris, " triangles, ", _surfaces, " surfaces")
	inst.free()
	quit(0)


func _walk(n: Node, depth: int, parent_xf: Transform3D) -> void:
	var xf: Transform3D = parent_xf
	var n3: Node3D = n as Node3D
	if n3 != null:
		xf = parent_xf * n3.transform
	var note: String = ""
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi != null and mi.mesh != null:
		_boxes.append(xf * mi.get_aabb())
		note = _mesh_note(mi.mesh)
	var sk: Skeleton3D = n as Skeleton3D
	if sk != null:
		note = "%d bones" % sk.get_bone_count()
	_lines += 1
	if _lines <= MAX_LINES:
		print("  ".repeat(depth + 1), n.name, " [", n.get_class(), "] ", note)
	var ap: AnimationPlayer = n as AnimationPlayer
	if ap != null:
		for clip: String in ap.get_animation_list():
			var a: Animation = ap.get_animation(clip)
			print("  ".repeat(depth + 2), "clip \"", clip, "\" %.2f s%s" % [a.length, "" if a.loop_mode == Animation.LOOP_NONE else " loop"])
	for c: Node in n.get_children():
		_walk(c, depth + 1, xf)


func _mesh_note(mesh: Mesh) -> String:
	var tris: int = 0
	var mats: PackedStringArray = PackedStringArray()
	var am: ArrayMesh = mesh as ArrayMesh
	for s: int in mesh.get_surface_count():
		_surfaces += 1
		if am != null:
			var idx: int = am.surface_get_array_index_len(s)
			var count: int = idx if idx > 0 else am.surface_get_array_len(s)
			@warning_ignore("integer_division")
			tris += count / 3
		var m: Material = mesh.surface_get_material(s)
		if m != null:
			mats.append(m.resource_name if m.resource_name != "" else m.get_class())
	_tris += tris
	return "%d tris, materials: %s" % [tris, ", ".join(mats)]
