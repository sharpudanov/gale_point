class_name TunableOverrides
extends RefCounted
## Experiment switch for the harness: `-- --set=Class.property=value` (repeatable) overrides an @export
## tunable on every node of that class_name (or a subclass) as it enters the tree, before its _ready().
## It lets tools/sweep.sh and one-off sims try values without editing code:
##   tools/sweep.sh storm_peak MoodRig.fog_density 0.006 0.012 0.024
##   tools/sim.sh --plan=... --set=Drowned.dark_hit_damage=35
## For experiments only: never use --set in tests/suite.txt or ShotPresets (those describe the shipped
## game). Values read in _init() or before the node is added to the tree are not affected.
## Value syntax follows the property's current type: float, int, bool (true/false), String, Color (#rrggbb
## or r,g,b[,a]), Vector2 (x,y), Vector3 (x,y,z).

var requested: int = 0
var applied: int = 0

var _by_class: Dictionary = {}       # class_name -> { property: raw value }
var _reported: Dictionary = {}


## `specs`: every "Class.property=value" string from the command line.
func load_specs(specs: PackedStringArray) -> void:
	for spec: String in specs:
		var eq: int = spec.find("=")
		var dot: int = spec.find(".")
		if eq < 0 or dot < 0 or dot > eq:
			push_error("--set: expected Class.property=value, got '%s'" % spec)
			continue
		var cls: String = spec.substr(0, dot)
		var prop: String = spec.substr(dot + 1, eq - dot - 1)
		if not _by_class.has(cls):
			_by_class[cls] = {}
		var props: Dictionary = _by_class[cls]
		props[prop] = spec.substr(eq + 1)
		requested += 1


func is_empty() -> bool:
	return _by_class.is_empty()


func attach(tree: SceneTree) -> void:
	if not is_empty():
		tree.node_added.connect(_on_node_added)


func telemetry() -> Dictionary:
	return {"requested": requested, "applied": applied}


func _on_node_added(node: Node) -> void:
	var script: Script = node.get_script() as Script
	while script != null:
		var cls: String = str(script.get_global_name())
		if _by_class.has(cls):
			var props: Dictionary = _by_class[cls]
			_apply(node, cls, props)
		script = script.get_base_script()


func _apply(node: Node, cls: String, props: Dictionary) -> void:
	for prop: String in props:
		var raw: String = props[prop]
		var key: String = "%s.%s" % [cls, prop]
		if not prop in node:
			if not _reported.has(key):
				_reported[key] = true
				push_error("--set: %s has no property '%s'" % [cls, prop])
			continue
		node.set(prop, _convert(raw, node.get(prop)))
		if not _reported.has(key):
			_reported[key] = true
			applied += 1
			print("TUNABLE %s=%s (was %s)" % [key, raw, str(_default_of(node, prop))])


func _default_of(node: Node, prop: String) -> Variant:
	var script: Script = node.get_script() as Script
	return script.get_property_default_value(prop) if script != null else null


static func _convert(raw: String, current: Variant) -> Variant:
	match typeof(current):
		TYPE_FLOAT:
			return raw.to_float()
		TYPE_INT:
			return raw.to_int()
		TYPE_BOOL:
			return raw == "true" or raw == "1"
		TYPE_STRING:
			return raw
		TYPE_STRING_NAME:
			return StringName(raw)
		TYPE_COLOR:
			if raw.begins_with("#"):
				return Color.html(raw)
			var c: PackedFloat64Array = raw.split_floats(",")
			return Color(c[0], c[1], c[2], c[3] if c.size() > 3 else 1.0) if c.size() >= 3 else current
		TYPE_VECTOR2:
			var v2: PackedFloat64Array = raw.split_floats(",")
			return Vector2(v2[0], v2[1]) if v2.size() >= 2 else current
		TYPE_VECTOR3:
			var v3: PackedFloat64Array = raw.split_floats(",")
			return Vector3(v3[0], v3[1], v3[2]) if v3.size() >= 3 else current
	return str_to_var(raw)
