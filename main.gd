extends Node3D
## Game root. The only node authored in a .tscn — everything else is built in code
## from class_name scripts in res://src/ (see CLAUDE.md, "pure-code scene rule").
## Build order (SPEC §3): BootArgs -> DebugArgs -> GameRng.seed -> ShotPresets -> systems.

## Camera/storm preset requested via `-- --shot=<name>` (tools/capture.sh). Empty = normal play.
var shot: String = ""
var args: DebugArgs

var mood: MoodRig
var clock: NightClock
var director: StormDirector
var ocean: Ocean
var island: Island
var lighthouse: Lighthouse
var weather: StormWeather
var player: Player
var weapons: WeaponHolder
var light_field: LightField
var projectiles: Node3D
var soundscape: Soundscape
var post_fx: PostFx

var _physics_frames: int = 0


func _ready() -> void:
	shot = str(BootArgs.get_value("shot", ""))
	if shot == "test":
		TestShot.build(self)  # harness self-test (tools/capture.sh test)
		return
	InputSetup.ensure()
	args = DebugArgs.parse(ShotPresets.defaults(shot))
	GameRng.seed_with(args.seed)
	_build()
	if shot.is_empty() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	mood = _add(MoodRig.new(), "MoodRig") as MoodRig

	clock = _add(NightClock.new(), "NightClock") as NightClock
	clock.setup(args.night_t, args.night_len)

	director = StormDirector.new()
	director.name = "StormDirector"
	director.no_lightning = args.no_lightning

	ocean = _add(Ocean.new(), "Ocean") as Ocean
	island = _add(Island.new(), "Island") as Island
	lighthouse = _add(Lighthouse.new(), "Lighthouse") as Lighthouse
	lighthouse.beam_still = args.beam_still
	if args.has_beam_yaw:
		lighthouse.set_beam_yaw(args.beam_yaw)

	weather = _add(StormWeather.new(), "StormWeather") as StormWeather
	weather.mood = mood
	weather.forced_flash_at = args.flash_at

	soundscape = _add(Soundscape.new(), "Soundscape") as Soundscape
	weather.lightning_struck.connect(soundscape.on_lightning)
	light_field = _add(LightField.new(), "LightField") as LightField
	weather.lightning_struck.connect(light_field.on_lightning)
	projectiles = _add(Node3D.new(), "Projectiles") as Node3D

	player = _add(Player.new(), "Player") as Player
	var start: Vector2 = args.player_at if args.has_player_at else Vector2(0.0, 6.0)
	var look: Vector2 = args.look if args.has_look else Vector2(180.0, 0.0)
	player.setup(island, start, look, args.god)
	player.input_locked = ShotPresets.has_preset(shot)
	weather.follow_target = player
	light_field.setup(lighthouse, player)
	player.crate = lighthouse.crate

	weapons = WeaponHolder.new()
	weapons.name = "WeaponHolder"
	player.camera.add_child(weapons)
	weapons.setup(player, player.camera, projectiles, ocean, light_field, soundscape, weather)
	weapons.fire_at = args.fire_at
	player.weapons = weapons
	if args.place_flare >= 0.0:
		_place_flare(args.place_flare)

	# The director runs after the clock (tree order) and pushes into everything built above.
	add_child(director)
	move_child(director, clock.get_index() + 1)
	director.setup(clock, mood, ocean, weather, island, soundscape)

	post_fx = _add(PostFx.new(), "PostFx") as PostFx
	post_fx.player = player
	post_fx.set_weapons(weapons)
	player.died.connect(_on_player_died)


## --place_flare=d: a burning flare (age 3 s) resting d m in front of the player; uses no ammo.
func _place_flare(d: float) -> void:
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var p: Vector3 = player.global_position + fwd * d
	p.y = island.height_at(p.x, p.z) + 0.06
	weapons.flare_gun.spawn_flare(p, Vector3.ZERO, 3.0)


func _add(node: Node, n: String) -> Node:
	node.name = n
	add_child(node)
	return node


func _on_player_died() -> void:
	clock.set_dead()


func _physics_process(_delta: float) -> void:
	_physics_frames += 1
	if player != null and player.camera != null:
		player.camera.wind_speed = weather.wind_speed


static func _r(v: float) -> float:
	return snappedf(v, 0.001)


## Snapshot of game state for tests/sim_bot.gd (SPEC §8). JSON-safe nested dictionaries.
func get_telemetry() -> Dictionary:
	var t: Dictionary = {
		"physics_frames": _physics_frames,
		"shot": shot,
		"seed": GameRng.get_seed(),
	}
	if clock == null:
		return t
	t["time"] = {
		"night_t": _r(clock.night_t),
		"night_len": _r(clock.night_len),
		"u": _r(clock.u()),
		"dawn_progress": _r(clock.dawn_progress()),
		"phase": clock.phase,
	}
	var storm: Dictionary = {}
	for k: String in director.values:
		var v: Variant = director.values[k]
		if v is float:
			storm[k] = _r(v)
		elif v is Array:
			storm[k] = [snappedf(float(v[0]), 0.01), snappedf(float(v[1]), 0.01)]
		else:
			storm[k] = v
	storm["intensity"] = _r(director.intensity())
	storm["progress"] = _r(director.progress())
	storm["lightning_count"] = weather.lightning_count
	storm["flash_active"] = weather.flash_active()
	storm["glow_threshold"] = _r(mood.env.glow_hdr_threshold)
	t["storm"] = storm
	t["ocean"] = {
		"wave_time": _r(ocean.wave_time),
		"steepness_sum": _r(ocean.steepness_sum()),
		"height_at_origin": _r(ocean.get_height(0.0, 0.0)),
	}
	t["player"] = player.telemetry()
	t["camera"] = {
		"fov": _r(player.camera.fov),
		"bob_offset": _r(player.camera.bob_offset.y),
		"recoil_pitch": _r(player.camera.recoil_pitch),
	}
	t["weapon"] = weapons.telemetry()
	t["flares"] = weapons.flares_telemetry(light_field.flares.size())
	t["crate"] = lighthouse.crate.telemetry()
	t["lighthouse"] = {
		"lamp_on": lighthouse.lamp_on,
		"guttering": lighthouse.is_guttering(),
		"beam_yaw": _r(lighthouse.beam_yaw()),
	}
	t["fx"] = post_fx.telemetry()
	t["audio"] = soundscape.telemetry()
	return t
