class_name BootArgs
extends RefCounted
## Parses user command-line args (everything after `--`), e.g. `-- --shot=storm --frames=600`.


## Returns the value of `--<key>=<value>`, `true` for a bare `--<key>`, or `default` if absent.
static func get_value(key: String, default: Variant = null) -> Variant:
	var prefix: String = "--%s=" % key
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
		if arg == "--" + key:
			return true
	return default


## All values for a repeatable `--<key>=<value>` arg (e.g. several `--expect=`).
static func get_all(key: String) -> PackedStringArray:
	var prefix: String = "--%s=" % key
	var out: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			out.append(arg.substr(prefix.length()))
	return out
