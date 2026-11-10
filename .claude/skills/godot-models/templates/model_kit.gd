class_name ModelKit
extends RefCounted
## Helpers for imported glTF / GLB models (pure-code scenes: the model is loaded and dressed in GDScript).
## Install: copy to res://src/core/model_kit.gd the first time a script needs it.


## A fresh instance of the model, or null when the file is missing (callers then build their placeholder).
static func spawn(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


static func meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi != null:
		out.append(mi)
	for c: Node in n.get_children():
		out.append_array(meshes(c))
	return out


## Bounding box of everything under `model`, in the model's own space (its own transform is not applied).
static func bounds(model: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect(model, Transform3D.IDENTITY, true, boxes)
	var box: AABB = AABB()
	for i: int in boxes.size():
		box = boxes[i] if i == 0 else box.merge(boxes[i])
	return box


## Scales a freshly spawned model to `height` metres and puts its lowest point on the parent's y = 0.
## Call before rotating it (rotate a pivot Node3D above it instead). Returns the scale factor.
static func fit_height(model: Node3D, height: float) -> float:
	var box: AABB = bounds(model)
	if box.size.y < 0.0001:
		return 1.0
	var k: float = height / box.size.y
	model.scale = Vector3.ONE * k
	model.position.y = -box.position.y * k
	return k


## Multiplies every StandardMaterial3D albedo by `colour` on per-instance copies (the import stays untouched).
static func tint(model: Node, colour: Color) -> void:
	for mi: MeshInstance3D in meshes(model):
		for s: int in mi.get_surface_override_material_count():
			var std: StandardMaterial3D = mi.mesh.surface_get_material(s) as StandardMaterial3D
			if std != null:
				var copy: StandardMaterial3D = std.duplicate() as StandardMaterial3D
				copy.albedo_color = copy.albedo_color * colour
				mi.set_surface_override_material(s, copy)


## The imported AnimationPlayer, or null for a static model.
static func animation_player(model: Node) -> AnimationPlayer:
	return model.find_child("AnimationPlayer", true, false) as AnimationPlayer


## glTF clips import as play-once; mark the ones that must loop (idle, walk ...). Unknown names are skipped.
static func set_loops(ap: AnimationPlayer, clips: PackedStringArray) -> void:
	for clip: String in clips:
		if ap.has_animation(clip):
			ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


static func _collect(n: Node, parent_xf: Transform3D, is_root: bool, boxes: Array[AABB]) -> void:
	var xf: Transform3D = parent_xf
	var n3: Node3D = n as Node3D
	if n3 != null and not is_root:
		xf = parent_xf * n3.transform
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi != null and mi.mesh != null:
		boxes.append(xf * mi.get_aabb())
	for c: Node in n.get_children():
		_collect(c, xf, false, boxes)
