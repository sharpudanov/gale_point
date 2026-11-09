class_name WeaponHolder
extends Node3D
## Child of PlayerCamera (SPEC 3, 4.5). Owns the Rifle and FlareGun viewmodels: input edges,
## switching (0.45 s), ADS, sprint lowering, sway (breathing + mouse lag) and weapon bob.
## Gameplay (state, ammo, firing) updates in _physics_process; poses update in _process.

signal ammo_changed

@export var switch_time: float = 0.45
@export var hip_pos: Vector3 = Vector3(0.16, -0.17, -0.44)
@export var ads_pos: Vector3 = Vector3(0.0, -ViewmodelBuilder.SIGHT_Y, -ViewmodelBuilder.EYE_Z)   ## open iron sights: eye on the barrel line, level with the front post
@export var flare_hip_pos: Vector3 = Vector3(0.15, -0.17, -0.34)
@export var hip_yaw_deg: float = 7.0
@export var sway_breath_hz: float = 0.25
@export var sway_breath_pitch_deg: float = 0.35
@export var sway_breath_yaw_deg: float = 0.2
@export var sway_ads_scale: float = 0.35
@export var sway_mouse_max_deg: float = 3.0
@export var sway_spring: float = 9.0
@export var sway_mouse_gain: float = 0.6
@export var bob_gain: float = 1.6
@export var bob_ads_scale: float = 0.15   ## walk bob multiplier at full ADS (keeps the sights steady)
@export var sprint_offset: Vector3 = Vector3(0.05, -0.07, 0.03)
@export_group("Fill light")
@export var fill_color: Color = Color(0.55, 0.62, 0.78)   ## cold: the only warm lights are flares, flash, lamp
@export var fill_energy: float = 1.4
@export var fill_range: float = 2.5
@export var sprint_tilt_deg: Vector3 = Vector3(-8.0, 22.0, -10.0)
@export_group("Rifle-butt shove (F / V)")
@export var shove_range: float = 2.7          ## metres from the player (XZ) to a Drowned's centre
@export var shove_cone_deg: float = 65.0      ## half-angle in front of the view
@export var shove_knock: float = 3.4          ## knockback distance (m)
@export var shove_stagger: float = 0.9        ## s the Drowned stands still and can't touch you
@export var shove_damage: float = 20.0        ## enough to make it smolder (a wound), never a kill on its own at full hp
@export var shove_cooldown: float = 0.7
@export var shove_max_targets: int = 3
@export var shove_out_time: float = 0.09      ## pose: snap out...
@export var shove_back_time: float = 0.34     ## ...and recover
@export var shove_trauma: float = 0.2
@export var shove_pos: Vector3 = Vector3(-0.07, 0.06, -0.34)   ## viewmodel offset at full extension
@export var shove_rot_deg: Vector3 = Vector3(-14.0, -46.0, 24.0) ## turns the stock forward into view

## "rifle" or "flare"
var current: String = "rifle"
var ads: bool = false
## --ads debug arg: behave as if the aim button were held.
var force_ads: bool = false
var rifle: Rifle
var flare_gun: FlareGun
## Seconds into the scripted shot (--fire_at); < 0 disables.
var fire_at: float = -1.0

var _player: Player
var _camera: PlayerCamera
var _audio: Soundscape
var _shown: String = "rifle"
var _switch_left: float = 0.0
var _ads_amt: float = 0.0
var _sprint_amt: float = 0.0
var _t: float = 0.0
var _vis_t: float = 0.0
var _lag: Vector2 = Vector2.ZERO  ## deg: x pitch, y yaw
var _prev_yaw: float = 0.0
var _prev_pitch: float = 0.0
var _have_prev: bool = false
var _fire_latch: bool = false
var _reload_latch: bool = false
var _switch_latch: String = ""
var _scripted_done: bool = false
var _melee_latch: bool = false
var _shove_cd: float = 0.0
var _shove_t: float = -1.0          ## seconds since the last shove (pose); < 0 = idle
var _enemies: Enemies
## --shove_at debug arg (seconds); < 0 disables.
var shove_at: float = -1.0
var _scripted_shove_done: bool = false
var shoves: int = 0
var shove_hits: int = 0


func setup(player: Player, camera: PlayerCamera, projectiles: Node3D, ocean: Ocean, field: LightField, audio: Soundscape, weather: StormWeather, enemies: Enemies) -> void:
	_player = player
	_camera = camera
	_audio = audio
	_enemies = enemies
	rifle = Rifle.new()
	rifle.name = "Rifle"
	rifle.setup(camera, player, field, audio, enemies)
	add_child(rifle)
	flare_gun = FlareGun.new()
	flare_gun.name = "FlareGun"
	flare_gun.setup(camera, player, projectiles, ocean, field, audio, weather)
	add_child(flare_gun)
	rifle.ammo_changed.connect(func() -> void: ammo_changed.emit())
	flare_gun.ammo_changed.connect(func() -> void: ammo_changed.emit())
	_show(current)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.name = "ViewmodelFill"
	fill.light_color = fill_color
	fill.light_energy = fill_energy
	fill.omni_range = fill_range
	fill.shadow_enabled = false
	fill.light_cull_mask = ViewmodelBuilder.VIEWMODEL_LAYER   # lights nothing but the viewmodel
	fill.light_volumetric_fog_energy = 0.0
	fill.position = Vector3(-0.1, 0.25, 0.1)
	add_child(fill)
	# Narrow cool rim from upper-left behind the gun gives the stock a top-edge highlight.
	var rim: SpotLight3D = SpotLight3D.new()
	rim.name = "ViewmodelRim"
	rim.light_color = Color(0.6, 0.68, 0.8)
	rim.light_energy = 1.2
	rim.spot_range = 2.0
	rim.spot_angle = 40.0
	rim.shadow_enabled = false
	rim.light_cull_mask = ViewmodelBuilder.VIEWMODEL_LAYER
	rim.light_volumetric_fog_energy = 0.0
	rim.position = Vector3(-0.4, 0.5, 0.3)
	add_child(rim)
	rim.look_at_from_position(rim.position, Vector3(0.12, -0.15, -0.35), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _player.input_locked or not _player.is_alive():
		return
	if event.is_action_pressed("fire"):
		_fire_latch = true
	elif event.is_action_pressed("reload"):
		_reload_latch = true
	elif event.is_action_pressed("weapon_rifle"):
		_switch_latch = "rifle"
	elif event.is_action_pressed("weapon_flare"):
		_switch_latch = "flare"
	elif event.is_action_pressed("weapon_toggle"):
		_switch_latch = "flare" if current == "rifle" else "rifle"
	elif event.is_action_pressed("melee"):
		_melee_latch = true


func _physics_process(delta: float) -> void:
	_t += delta
	var alive: bool = _player.is_alive()
	var sprinting: bool = _player.sprinting
	var fire: bool = _fire_latch
	_fire_latch = false
	var want_reload: bool = _reload_latch
	_reload_latch = false
	var want_switch: String = _switch_latch
	_switch_latch = ""
	var want_shove: bool = _melee_latch
	_melee_latch = false
	_shove_cd = maxf(0.0, _shove_cd - delta)
	if _shove_t >= 0.0:
		_shove_t += delta
		if _shove_t > shove_out_time + shove_back_time:
			_shove_t = -1.0
	if shove_at >= 0.0 and not _scripted_shove_done and _t >= shove_at:
		_scripted_shove_done = true
		want_shove = true
	if not alive:
		ads = false
		_camera.ads = false
		return
	if fire_at >= 0.0 and not _scripted_done and _t >= fire_at:
		_scripted_done = true
		fire = true

	if _switch_left > 0.0:
		_switch_left = maxf(0.0, _switch_left - delta)
	if want_switch != "" and want_switch != current and _switch_left <= 0.0:
		_start_switch(want_switch)

	var ready_to_act: bool = _switch_left <= 0.0
	# The shove works mid bolt-cycle and mid reload (that is the point); it does not interrupt either.
	if want_shove and ready_to_act and _shove_cd <= 0.0:
		_do_shove()
	var shoving: bool = _shove_t >= 0.0
	ads = ready_to_act and not shoving and current == "rifle" and not sprinting and (force_ads or (Input.is_action_pressed("aim") and not _player.input_locked))
	_camera.ads = ads
	if ready_to_act and not sprinting:
		if current == "rifle":
			if fire:
				rifle.try_fire(ads)
			elif want_reload:
				rifle.try_reload()
		elif fire:
			flare_gun.try_fire()
	elif ready_to_act and sprinting and current == "rifle" and want_reload:
		pass  # no reload starts while sprinting


## Rifle-butt shove: every living Drowned within shove_range in the front cone (nearest first, up to
## shove_max_targets) is knocked back, staggered (can't touch you) and wounded a little.
func _do_shove() -> void:
	shoves += 1
	_shove_cd = shove_cooldown
	_shove_t = 0.0
	_camera.add_trauma(shove_trauma)
	_camera.add_recoil(-1.2, 0.0)
	var connected: int = 0
	if _enemies != null:
		var fwd: Vector3 = -_camera.global_transform.basis.z
		var flat_fwd: Vector2 = Vector2(fwd.x, fwd.z).normalized()
		var me: Vector3 = _player.global_position
		var cands: Array[Drowned] = []
		for d: Drowned in _enemies.living():
			var to: Vector2 = Vector2(d.global_position.x - me.x, d.global_position.z - me.z)
			if to.length() > shove_range:
				continue
			if to.length() > 0.2 and absf(rad_to_deg(flat_fwd.angle_to(to.normalized()))) > shove_cone_deg:
				continue
			cands.append(d)
		cands.sort_custom(func(a: Drowned, b: Drowned) -> bool:
			return a.global_position.distance_squared_to(me) < b.global_position.distance_squared_to(me))
		for d: Drowned in cands:
			if connected >= shove_max_targets:
				break
			var away: Vector3 = d.global_position - me
			away.y = 0.0
			if away.length() < 0.05:
				away = Vector3(flat_fwd.x, 0.0, flat_fwd.y)
			d.shove(away.normalized(), shove_knock, shove_stagger, shove_damage)
			HitFx.dark_mist(_enemies, d.chest_position(), away.normalized())
			connected += 1
	shove_hits += connected
	if _audio != null:
		_audio.play_shove(connected > 0)


func shove_pose() -> float:
	if _shove_t < 0.0:
		return 0.0
	if _shove_t < shove_out_time:
		var k: float = _shove_t / maxf(shove_out_time, 0.001)
		return 1.0 - (1.0 - k) * (1.0 - k)
	var b: float = clampf((_shove_t - shove_out_time) / maxf(shove_back_time, 0.001), 0.0, 1.0)
	return 1.0 - b * b * (3.0 - 2.0 * b)


func _start_switch(target: String) -> void:
	if current == "rifle":
		rifle.cancel_reload()
	else:
		flare_gun.cancel_reload()
	current = target
	_switch_left = switch_time
	ads = false
	ammo_changed.emit()


func _show(which: String) -> void:
	_shown = which
	rifle.visible = which == "rifle"
	flare_gun.visible = which == "flare"


## Crate resupply (SPEC 4.9).
func add_ammo(rounds: int, flares: int) -> void:
	rifle.add_reserve(rounds)
	flare_gun.add_flares(flares)


## F2 sandbox: full magazine, full reserve, full flares.
func refill_all() -> void:
	rifle.mag = rifle.mag_size
	if rifle.state == "empty":
		rifle.state = "ready"
	rifle.add_reserve(rifle.max_reserve)
	flare_gun.add_flares(flare_gun.flares_max)


func rifle_state() -> String:
	if _switch_left > 0.0 and current == "rifle":
		return "switching"
	return rifle.state


# --- poses ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _player == null:
		return
	_ads_amt = move_toward(_ads_amt, 1.0 if ads else 0.0, delta / maxf(_camera.ads_time, 0.01))
	_sprint_amt = move_toward(_sprint_amt, 1.0 if _player.sprinting else 0.0, delta / 0.18)

	# Mouse lag: the weapon trails look motion, then a spring pulls it back to centre.
	var yaw: float = _player.yaw_deg()
	var pitch: float = _player.pitch_deg()
	if _have_prev:
		var dy: float = wrapf(yaw - _prev_yaw, -180.0, 180.0)
		var dp: float = pitch - _prev_pitch
		_lag.y -= dy * sway_mouse_gain
		_lag.x -= dp * sway_mouse_gain
	_prev_yaw = yaw
	_prev_pitch = pitch
	_have_prev = true
	_lag *= exp(-sway_spring * delta)
	_lag = Vector2(clampf(_lag.x, -sway_mouse_max_deg, sway_mouse_max_deg), clampf(_lag.y, -sway_mouse_max_deg, sway_mouse_max_deg))

	_vis_t += delta
	var time: float = _vis_t
	var k: float = lerpf(1.0, sway_ads_scale, _ads_amt)
	var breath: Vector2 = Vector2(
		sway_breath_pitch_deg * sin(TAU * sway_breath_hz * time),
		sway_breath_yaw_deg * sin(TAU * sway_breath_hz * time * 0.73 + 1.3)) * k
	var sway: Vector2 = breath + _lag * k

	# Switching: dip out of frame, swap at the midpoint, rise again.
	var sp: float = 0.0
	if _switch_left > 0.0:
		var prog: float = 1.0 - _switch_left / switch_time
		if prog >= 0.5 and _shown != current:
			_show(current)
		sp = sin(prog * PI)
	elif _shown != current:
		_show(current)

	var base: Vector3
	if current == "rifle":
		base = hip_pos.lerp(ads_pos, _ads_amt)
	else:
		base = flare_hip_pos
	var bob: Vector3 = _camera.bob_offset * bob_gain * lerpf(1.0, bob_ads_scale, _ads_amt)
	var shove_k: float = shove_pose()
	var pos: Vector3 = base + bob + sprint_offset * _sprint_amt + Vector3(0.0, -0.32 * sp, 0.06 * sp) + shove_pos * shove_k
	var rot: Vector3 = Vector3(sway.x, sway.y + hip_yaw_deg * (1.0 - _ads_amt), 0.0) + sprint_tilt_deg * _sprint_amt + Vector3(-30.0 * sp, 0.0, 0.0) + shove_rot_deg * shove_k

	rifle.ads_amount = _ads_amt
	var active: Node3D = rifle if _shown == "rifle" else flare_gun
	active.position = pos
	active.rotation_degrees = rot


func telemetry() -> Dictionary:
	return {
		"current": current,
		"ads": ads,
		"rifle_mag": rifle.mag,
		"rifle_reserve": rifle.reserve,
		"rifle_state": rifle_state(),
		"shots_fired": rifle.shots_fired,
		"hits_lit": rifle.hits_lit,
		"hits_dark": rifle.hits_dark,
		"hits_head": rifle.hits_head,
		"hits_gear": rifle.hits_gear,
		"shoves": shoves,
		"shove_hits": shove_hits,
	}


func flares_telemetry(active_count: int) -> Dictionary:
	return {
		"left": flare_gun.left,
		"max": flare_gun.flares_max,
		"fired": flare_gun.fired,
		"active": active_count,
		"drowned": flare_gun.drowned,
		"impaled": flare_gun.impaled,
	}
