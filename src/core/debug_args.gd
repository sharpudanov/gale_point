class_name DebugArgs
extends RefCounted
## Typed view of the SPEC §7 debug boot args. Shot-preset defaults are merged underneath;
## explicit command-line args always win. Unknown args are ignored.

var rng_seed: int = 1
var night_t: float = 0.0
var night_len: float = 300.0
var no_waves: bool = false
var no_lightning: bool = false
var flash_at: float = -1.0            ## < 0 = no forced strike
var spawn_at: Array[Vector2] = []
var freeze_enemies: bool = false
var aim: bool = false
var ads: bool = false                 ## hold the rifle in ADS (forces the aim input)
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
var pre_trails: bool = false         ## stamp wet trails behind each spawned Drowned (frozen captures)
var spawn_kind: String = "drowned"   ## the FIRST --spawn_at entry is this kind ("captain")
var spawn_hp: float = -1.0           ## < 0 = full; else the FIRST --spawn_at entry starts at this hp
var impale_first: bool = false       ## a burning flare stuck in the first spawn (walking torch)
var aim_part: String = "chest"       ## --aim target on the first spawn: chest | head | lantern
var aim_flare: bool = false          ## aim at the --place_flare flare instead
var light_braziers: bool = false
var overdrive: bool = false          ## beam overdrive from frame 0 (operator = player)
var shove_at: float = -1.0           ## scripted rifle-butt shove at t seconds
var aim_cask: int = -1               ## >= 0: --aim at this oil cask instead
var toll: int = 0                    ## > 0: the buoy nearest the view tolls this many strokes at boot
var session_log: bool = false        ## force the SessionLog recorder on (headless sims; writes sim_session.jsonl)
var map: bool = false                ## top-down MapView (layout design); --map_plain implies it
var map_plain: bool = false          ## MapView without props, rocks, buoys or labels (editor backdrop)


static func parse(preset_defaults: Dictionary) -> DebugArgs:
	var d: DebugArgs = DebugArgs.new()
	var get_v: Callable = func(key: String) -> Variant:
		var raw: Variant = BootArgs.get_value(key, null)
		return raw if raw != null else preset_defaults.get(key, null)

	var v: Variant = get_v.call("seed")
	if v != null:
		d.rng_seed = int(str(v))
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
	d.ads = get_v.call("ads") != null
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
	d.pre_trails = get_v.call("pre_trails") != null
	v = get_v.call("fire_at")
	if v != null:
		d.fire_at = float(str(v))
	v = get_v.call("spawn_kind")
	if v != null:
		d.spawn_kind = str(v)
	v = get_v.call("spawn_hp")
	if v != null:
		d.spawn_hp = float(str(v))
	d.impale_first = get_v.call("impale_first") != null
	v = get_v.call("aim_part")
	if v != null:
		d.aim_part = str(v)
	d.aim_flare = get_v.call("aim_flare") != null
	d.light_braziers = get_v.call("light_braziers") != null
	d.overdrive = get_v.call("overdrive") != null
	v = get_v.call("shove_at")
	if v != null:
		d.shove_at = float(str(v))
	v = get_v.call("aim_cask")
	if v != null:
		d.aim_cask = int(str(v))
	v = get_v.call("toll")
	if v != null:
		d.toll = int(str(v))
	d.session_log = get_v.call("session_log") != null
	d.map_plain = get_v.call("map_plain") != null
	d.map = d.map_plain or get_v.call("map") != null
	return d


static func _vec2(s: String) -> Vector2:
	var parts: PackedStringArray = s.split(",")
	if parts.size() < 2:
		return Vector2.ZERO
	return Vector2(float(parts[0]), float(parts[1]))
