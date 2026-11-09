class_name DebugArgs
extends RefCounted
## Typed view of the SPEC §7 debug boot args. Shot-preset defaults are merged underneath;
## explicit command-line args always win. Unknown args are ignored.

var seed: int = 1
var night_t: float = 0.0
var night_len: float = 300.0
var no_waves: bool = false
var no_lightning: bool = false
var flash_at: float = -1.0            ## < 0 = no forced strike
var spawn_at: Array[Vector2] = []
var freeze_enemies: bool = false
var aim: bool = false
var place_flare: float = -1.0         ## < 0 = none
var god: bool = false
var has_player_at: bool = false
var player_at: Vector2 = Vector2(0.0, 6.0)
var has_look: bool = false
var look: Vector2 = Vector2(180.0, 0.0)  ## yaw, pitch (degrees)
var has_beam_yaw: bool = false
var beam_yaw: float = 0.0
var beam_still: bool = false
var fire_at: float = -1.0


static func parse(preset_defaults: Dictionary) -> DebugArgs:
	var d: DebugArgs = DebugArgs.new()
	var get_v: Callable = func(key: String) -> Variant:
		var v: Variant = BootArgs.get_value(key, null)
		return v if v != null else preset_defaults.get(key, null)

	var v: Variant = get_v.call("seed")
	if v != null:
		d.seed = int(str(v))
	v = get_v.call("night_t")
	if v != null:
		d.night_t = float(str(v))
	v = get_v.call("night_len")
	if v != null:
		d.night_len = maxf(1.0, float(str(v)))
	d.no_waves = get_v.call("no_waves") != null
	d.no_lightning = get_v.call("no_lightning") != null
	v = get_v.call("flash_at")
	if v != null:
		d.flash_at = float(str(v))
		d.no_lightning = true  # a forced strike implies no random ones
	v = get_v.call("spawn_at")
	if v != null:
		for pair: String in str(v).split(";", false):
			d.spawn_at.append(_vec2(pair))
	d.freeze_enemies = get_v.call("freeze_enemies") != null
	d.aim = get_v.call("aim") != null
	v = get_v.call("place_flare")
	if v != null:
		d.place_flare = float(str(v))
	d.god = get_v.call("god") != null
	v = get_v.call("player_at")
	if v != null:
		d.has_player_at = true
		d.player_at = _vec2(str(v))
	v = get_v.call("look")
	if v != null:
		d.has_look = true
		d.look = _vec2(str(v))
	v = get_v.call("beam_yaw")
	if v != null:
		d.has_beam_yaw = true
		d.beam_yaw = float(str(v))
	d.beam_still = get_v.call("beam_still") != null
	v = get_v.call("fire_at")
	if v != null:
		d.fire_at = float(str(v))
	return d


static func _vec2(s: String) -> Vector2:
	var parts: PackedStringArray = s.split(",")
	if parts.size() < 2:
		return Vector2.ZERO
	return Vector2(float(parts[0]), float(parts[1]))
