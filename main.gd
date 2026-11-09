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
var trails: WetTrails
var enemies: Enemies
var waves: WaveDirector
var projectiles: Node3D
var soundscape: Soundscape
var post_fx: PostFx
var fire: FireSystem
var props: IslandProps
var buoys: BellBuoys
var sandbox: Sandbox
var _placed_flare: Flare

## Screenshot hotkey output folder (gitignored via .captures/).
@export var screenshot_dir: String = "res://.captures/screenshots"

var _physics_frames: int = 0
var _screenshot_busy: bool = false


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
	trails = _add(WetTrails.new(), "WetTrails") as WetTrails
	enemies = _add(Enemies.new(), "Enemies") as Enemies
	fire = _add(FireSystem.new(), "Fire") as FireSystem

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
	weapons.setup(player, player.camera, projectiles, ocean, light_field, soundscape, weather, enemies)
	weapons.fire_at = args.fire_at
	weapons.force_ads = args.ads
	weapons.shove_at = args.shove_at
	weapons.flare_gun.enemies = enemies
	weapons.flare_gun.fire = fire
	player.weapons = weapons
	if args.place_flare >= 0.0:
		_place_flare(args.place_flare)
	enemies.setup(island, ocean, light_field, lighthouse, player, soundscape, trails, weather)
	enemies.fire = fire
	fire.setup(enemies, light_field, soundscape, island, weather)
	enemies.freeze = args.freeze_enemies
	for i: int in args.spawn_at.size():
		var xz: Vector2 = args.spawn_at[i]
		var d: Drowned = enemies.spawn(xz, true, args.spawn_kind if i == 0 else "drowned")
		if i == 0 and args.spawn_hp >= 0.0:
			d.hp = args.spawn_hp
		if args.pre_trails:
			_pre_trail(xz)
	var first: Drowned = enemies.first()
	if args.impale_first and first != null:
		var f: Flare = weapons.flare_gun.spawn_flare(first.chest_position(), Vector3.ZERO, 3.0)
		f.attach_to(first, first.chest_position() + Vector3(0.0, 0.0, -0.3))
	if args.aim_flare and _placed_flare != null:
		player.aim_at(_placed_flare.global_position)
	elif args.aim and first != null:
		match args.aim_part:
			"head":
				player.aim_at(first.global_position + Vector3(0.0, first.head_center_y * first.size_scale, 0.0))
			"lantern":
				if first.lantern != null:
					player.aim_at(first.lantern.centre())
			_:
				player.aim_at(first.chest_position())

	waves = _add(WaveDirector.new(), "WaveDirector") as WaveDirector
	waves.enabled = not args.no_waves
	waves.setup(clock, enemies, lighthouse.crate)

	buoys = BellBuoys.new()
	buoys.setup(ocean, soundscape)
	_add(buoys, "BellBuoys")
	waves.wave_warning.connect(buoys.on_wave_warning)
	props = _add(IslandProps.new(), "IslandProps") as IslandProps
	props.build(island, fire, enemies, light_field, soundscape, weather, lighthouse, player)
	waves.wave_started.connect(props.on_wave_started)
	if args.light_braziers:
		props.light_all_braziers()
	if args.aim_cask >= 0 and args.aim_cask < props.casks.size():
		var c: OilCask = props.casks[args.aim_cask]
		player.aim_at(c.global_position + Vector3(0.0, c.height * 0.5, 0.0))
	if args.overdrive:
		lighthouse.start_overdrive(player)
	if args.toll > 0:
		var fwd: Vector3 = -player.global_transform.basis.z
		buoys.toll(buoys.nearest(atan2(fwd.z, fwd.x)), args.toll)
	if not ShotPresets.has_preset(shot):
		sandbox = Sandbox.new()
		sandbox.main = self
		sandbox.player = player
		sandbox.weapons = weapons
		sandbox.enemies = enemies
		sandbox.waves = waves
		sandbox.weather = weather
		sandbox.island = island
		_add(sandbox, "Sandbox")

	# The director runs after the clock (tree order) and pushes into everything built above.
	add_child(director)
	move_child(director, clock.get_index() + 1)
	director.setup(clock, mood, ocean, weather, island, soundscape)

	post_fx = _add(PostFx.new(), "PostFx") as PostFx
	post_fx.player = player
	post_fx.set_weapons(weapons)
	player.hit.connect(post_fx.on_hit)
	player.died.connect(post_fx.on_died)
	player.died.connect(_on_player_died)
	clock.won.connect(post_fx.on_won)


## --pre_trails: wet smears from the shore up to a spawn point, as if it had already glided in.
func _pre_trail(xz: Vector2) -> void:
	var out: Vector2 = xz.normalized() if xz.length() > 0.01 else Vector2(0.0, 1.0)
	var step: float = 0.9
	var d: float = step
	while d < 22.0:
		var p: Vector2 = xz + out * d
		var h: float = island.height_at(p.x, p.y)
		if h < ocean.get_height(p.x, p.y) + 0.2:
			break
		trails.stamp(Vector3(p.x, h, p.y), atan2(out.x, out.y) + PI)
		d += step


## --place_flare=d: a burning flare (age 3 s) resting d m in front of the player; uses no ammo.
func _place_flare(d: float) -> void:
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var p: Vector3 = player.global_position + fwd * d
	p.y = island.height_at(p.x, p.z) + 0.06
	_placed_flare = weapons.flare_gun.spawn_flare(p, Vector3.ZERO, 3.0)


func _add(node: Node, n: String) -> Node:
	node.name = n
	add_child(node)
	return node


func _on_player_died() -> void:
	clock.set_dead()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot", false, true):
		_take_screenshot()


## F12 / P: save the finished frame as PNG and put it on the Windows clipboard.
func _take_screenshot() -> void:
	if _screenshot_busy or DisplayServer.get_name() == "headless":
		return
	_screenshot_busy = true
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_screenshot_busy = false
	if img == null or img.is_empty():
		push_warning("screenshot: viewport image was empty")
		return
	var dir_abs: String = ProjectSettings.globalize_path(screenshot_dir)
	DirAccess.make_dir_recursive_absolute(dir_abs)
	var abs_path: String = dir_abs.path_join("shot_%d.png" % int(Time.get_unix_time_from_system()))
	if img.save_png(abs_path) != OK:
		push_warning("screenshot: could not write " + abs_path)
		return
	print("screenshot saved: ", abs_path)
	if OS.get_name() == "Windows":
		# Detached process: the clipboard copy never stalls the frame.
		var ps_path: String = abs_path.replace("/", "\\").replace("'", "''")
		OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-Command",
			"Add-Type -AssemblyName System.Windows.Forms,System.Drawing; "
			+ "[System.Windows.Forms.Clipboard]::SetImage([System.Drawing.Image]::FromFile('" + ps_path + "'))"])


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
	t["enemies"] = enemies.telemetry()
	t["waves"] = waves.telemetry()
	t["crate"] = lighthouse.crate.telemetry()
	t["lighthouse"] = {
		"lamp_on": lighthouse.lamp_on,
		"guttering": lighthouse.is_guttering(),
		"beam_yaw": _r(lighthouse.beam_yaw()),
		"overdrive_left": _r(lighthouse.overdrive_left()),
		"overdrives": lighthouse.overdrives,
	}
	t["fire"] = fire.telemetry()
	t["island"] = props.telemetry()
	t["buoys"] = buoys.telemetry()
	if sandbox != null:
		t["sandbox"] = sandbox.telemetry()
	t["fx"] = post_fx.telemetry()
	t["audio"] = soundscape.telemetry()
	return t
