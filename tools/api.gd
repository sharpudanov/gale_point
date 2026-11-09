extends SceneTree
## Engine API lookup for tools/api.sh: answers from this exact Godot binary's ClassDB, no editor needed.
## Usage: godot --headless --path . --script res://tools/api.gd -- <Class> [filter] [--inherited]
##   filter      only members whose name contains it (case-insensitive); searches inherited members too
##   --inherited list inherited members even without a filter
## Property setters/getters are hidden (use the property). Output is plain text, one member per line.


func _initialize() -> void:
	var cls: String = ""
	var filter: String = ""
	var inherited: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a == "--inherited":
			inherited = true
		elif cls.is_empty():
			cls = a
		else:
			filter = a.to_lower()
	if cls.is_empty():
		print("usage: tools/api.sh <Class> [filter] [--inherited]")
		quit(2)
		return
	if not ClassDB.class_exists(cls):
		var near: PackedStringArray = []
		for c: String in ClassDB.get_class_list():
			if c.to_lower().contains(cls.to_lower()) and near.size() < 15:
				near.append(c)
		print("API_NOT_FOUND %s%s" % [cls, ("  (did you mean: %s)" % ", ".join(near)) if not near.is_empty() else ""])
		quit(1)
		return
	var chain: PackedStringArray = [cls]
	var p: String = ClassDB.get_parent_class(cls)
	while not p.is_empty():
		chain.append(p)
		p = ClassDB.get_parent_class(p)
	print("CLASS %s" % " < ".join(chain))
	var scope: PackedStringArray = chain if (inherited or not filter.is_empty()) else PackedStringArray([cls])
	var shown: int = 0
	for c: String in scope:
		shown += _dump(c, filter, c != cls)
	if shown == 0:
		print("(no members match '%s')" % filter)
	elif scope.size() == 1 and chain.size() > 1:
		print("(own members only; add a filter or --inherited for %s)" % ", ".join(chain.slice(1)))
	quit(0)


func _dump(cls: String, filter: String, tag: bool) -> int:
	var n: int = 0
	var prefix: String = ("[%s] " % cls) if tag else ""
	var accessors: Dictionary = {}
	for prop: Dictionary in ClassDB.class_get_property_list(cls, true):
		var usage: int = prop["usage"]
		if usage & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
			continue
		var pname: String = prop["name"]
		accessors[ClassDB.class_get_property_setter(cls, pname)] = true
		accessors[ClassDB.class_get_property_getter(cls, pname)] = true
		if pname.contains("/") or not _match(pname, filter):
			continue
		var line: String = "  %sprop   %s: %s" % [prefix, pname, _type(prop)]
		var def: Variant = ClassDB.class_get_property_default_value(cls, pname)
		if def != null:
			line += " = %s" % str(def)
		if int(prop["hint"]) == PROPERTY_HINT_ENUM:
			line += "   # enum: %s" % str(prop["hint_string"])
		elif int(prop["hint"]) == PROPERTY_HINT_RANGE:
			line += "   # range: %s" % str(prop["hint_string"])
		print(line)
		n += 1
	for m: Dictionary in ClassDB.class_get_method_list(cls, true):
		var mname: String = m["name"]
		if accessors.has(mname) or not _match(mname, filter):
			continue
		var kind: String = "virt  " if int(m["flags"]) & METHOD_FLAG_VIRTUAL else ("static" if int(m["flags"]) & METHOD_FLAG_STATIC else "func  ")
		print("  %s%s %s(%s) -> %s" % [prefix, kind, mname, _args(m), _type(m["return"], true)])
		n += 1
	for s: Dictionary in ClassDB.class_get_signal_list(cls, true):
		if not _match(str(s["name"]), filter):
			continue
		print("  %ssignal %s(%s)" % [prefix, s["name"], _args(s)])
		n += 1
	for e: String in ClassDB.class_get_enum_list(cls, true):
		var names: PackedStringArray = ClassDB.class_get_enum_constants(cls, e, true)
		var hit: bool = _match(e, filter)
		var parts: PackedStringArray = []
		for c: String in names:
			hit = hit or _match(c, filter)
			parts.append("%s=%d" % [c, ClassDB.class_get_integer_constant(cls, c)])
		if hit:
			print("  %senum   %s { %s }" % [prefix, e, ", ".join(parts)])
			n += 1
	for c: String in ClassDB.class_get_integer_constant_list(cls, true):
		if ClassDB.class_get_integer_constant_enum(cls, c, true).is_empty() and _match(c, filter):
			print("  %sconst  %s = %d" % [prefix, c, ClassDB.class_get_integer_constant(cls, c)])
			n += 1
	return n


func _match(member: String, filter: String) -> bool:
	return filter.is_empty() or member.to_lower().contains(filter)


func _args(m: Dictionary) -> String:
	var args: Array = m["args"]
	var defaults: Array = m.get("default_args", [])
	var first_default: int = args.size() - defaults.size()
	var out: PackedStringArray = []
	for i: int in args.size():
		var a: Dictionary = args[i]
		var s: String = "%s: %s" % [a["name"], _type(a)]
		if i >= first_default:
			s += " = %s" % str(defaults[i - first_default])
		out.append(s)
	return ", ".join(out)


func _type(info: Dictionary, is_return: bool = false) -> String:
	var t: int = info["type"]
	var cn: String = str(info.get("class_name", ""))
	if t == TYPE_OBJECT:
		return cn if not cn.is_empty() else "Object"
	if t == TYPE_NIL:
		if is_return and not (int(info.get("usage", 0)) & PROPERTY_USAGE_NIL_IS_VARIANT):
			return "void"
		return "Variant"
	if t == TYPE_ARRAY and int(info.get("hint", 0)) == PROPERTY_HINT_ARRAY_TYPE:
		return "Array[%s]" % str(info["hint_string"])
	if t == TYPE_INT and not cn.is_empty():
		return "int (%s)" % cn
	return type_string(t)
