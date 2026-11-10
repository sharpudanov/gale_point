class_name MapLayout
extends RefCounted
## Where things stand (SPEC §3, §4.2): res://map/layout.tscn is the one content scene and the single source of
## positions for braziers, oil casks, the beam winch, bell buoys and rocks. It holds Marker3D nodes (their
## child meshes and the EditorBackdrop exist only for dragging in the editor) and rock glTF instances. Only X, Z,
## yaw and scale are read; heights come from Island.height_at(). Loaded once, read into typed data, freed.

const PATH: String = "res://map/layout.tscn"

static var _loaded: bool = false
static var _braziers: PackedVector2Array = PackedVector2Array()
static var _casks: Array[Transform3D] = []
static var _winch: Vector2 = Vector2.ZERO
static var _buoys: PackedVector2Array = PackedVector2Array()
static var _rocks: Array[Dictionary] = []


## Brazier XZ points, in marker order (Brazier0..).
static func brazier_points() -> PackedVector2Array:
	_load()
	return _braziers


## Oil cask transforms, in marker order (OilCask0..): origin XZ + yaw (basis) are used.
static func cask_transforms() -> Array[Transform3D]:
	_load()
	return _casks


static func winch_point() -> Vector2:
	_load()
	return _winch


static func buoy_points() -> PackedVector2Array:
	_load()
	return _buoys


## Rocks as {scene: String (glTF path), xform: Transform3D}, in node order.
static func rocks() -> Array[Dictionary]:
	_load()
	return _rocks


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var ps: PackedScene = load(PATH) as PackedScene
	if ps == null:
		push_error("MapLayout: %s is missing; no props, buoys or rocks are placed" % PATH)
		return
	var root: Node3D = ps.instantiate() as Node3D
	for xf: Transform3D in _group(root, "Braziers"):
		_braziers.append(Vector2(xf.origin.x, xf.origin.z))
	_casks = _group(root, "Casks")
	var winch: Node3D = root.get_node_or_null("Winch") as Node3D
	if winch != null:
		_winch = Vector2(winch.position.x, winch.position.z)
	else:
		push_error("MapLayout: no Winch marker in %s" % PATH)
	for xf: Transform3D in _group(root, "Buoys"):
		_buoys.append(Vector2(xf.origin.x, xf.origin.z))
	var rocks_node: Node3D = root.get_node_or_null("Rocks") as Node3D
	if rocks_node != null:
		for c: Node in rocks_node.get_children():
			var r: Node3D = c as Node3D
			if r != null and not r.scene_file_path.is_empty():
				_rocks.append({"scene": r.scene_file_path, "xform": rocks_node.transform * r.transform})
	root.free()


## Transforms (relative to the layout root) of the Node3D children of group `n`, in node order.
static func _group(root: Node3D, n: String) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var g: Node3D = root.get_node_or_null(n) as Node3D
	if g == null:
		push_error("MapLayout: no %s group in %s" % [n, PATH])
		return out
	for c: Node in g.get_children():
		var m: Node3D = c as Node3D
		if m != null:
			out.append(g.transform * m.transform)
	return out
