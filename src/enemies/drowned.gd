class_name Drowned
extends Node3D
## One of the Drowned (SPEC 4.8): rises out of the sea, glides (no walk cycle) toward the lighthouse door
## or a nearby player, is hurt and slowed only while LightField says it stands in light, and is much
## faster in the dark. Reaching the player or the tower costs 1 HP and it dissolves.

@export var max_hp: float = 100.0
@export var base_speed: float = 2.4
@export var dark_mult: float = 1.35
@export var lit_mult: float = 0.35
@export var speed_response: float = 4.0
@export var turn_rate_deg: float = 90.0
@export var separation: float = 1.5
@export_group("Animated body (DrownedRig)")
@export var use_rig: bool = true              ## false, or a missing model file: the code-built cloak
@export var rig_height: float = 2.0           ## rest-pose height in metres (the walk stoops below it)
@export var rig_walk_ref_speed: float = 1.5   ## m/s the walk clip covers at speed_scale 1
@export var rig_walk_scale: Vector2 = Vector2(0.7, 2.0)   ## clamp of the walk clip's speed_scale
@export var rig_lean_scale: float = 0.35      ## share of the glide lean kept on top of the clip's own stoop
@export var rig_attack_range: float = 2.6     ## closer than this to its target it claws
@export var rig_blend: float = 0.25           ## s, cross-fade between clips
@export_group("")
@export var hover_height: float = 0.25
@export var bob_amp: float = 0.08
@export var bob_hz: float = 0.6
@export var lean_deg: float = 8.0
@export var emerge_time: float = 2.5
@export var emerge_depth: float = 1.8
@export var aggro_radius: float = 25.0
@export var contact_radius: float = 1.3
@export var tower_radius: float = 3.6
@export var dissolve_time: float = 1.2
@export var sink_depth: float = 0.6
@export var dawn_sink_depth: float = 1.9   ## dawn: sink under the surface, not a twitch
@export var trail_step: float = 0.9
@export var moan_first: Vector2 = Vector2(0.0, 3.0)
@export var moan_interval: Vector2 = Vector2(6.0, 14.0)
@export var chest_height: float = 1.35
@export_group("Light reaction")
@export var lit_shudder_amp: float = 0.02
@export var lit_shudder_hz: float = 14.0
@export var lit_flutter_mult: float = 1.6
@export var dark_hit_shudder_time: float = 0.25
@export var dark_hit_shudder_amp: float = 0.04
@export var drag_factor: float = 0.12
@export var drip_rate: float = 12.0
@export var frozen_drag_speed: float = 0.7   ## fraction of base_speed the hem trails by while frozen
@export_group("Dark hits")
@export var dark_hit_damage: float = 50.0     ## live play: a rifle hit on an unlit Drowned still hurts (2 body shots kill)...
@export var dark_knockback: float = 1.4       ## ...and shoves it back this far (metres, over knock_time)
@export var knock_time: float = 0.25
@export var head_center_y: float = 1.9        ## hood/face sphere centre above the feet (model space)
@export var head_radius: float = 0.27         ## a rifle ray through this sphere is a headshot: lethal even in the dark
@export_group("Shove / stagger")
@export var shove_knock_time: float = 0.3     ## the rifle-butt shove plays its knockback over this long
@export var stagger_speed_mult: float = 0.0   ## glide speed while staggered
@export var stagger_lean_deg: float = 22.0    ## the body rocks back this far when shoved
@export_group("Smolder (wounded)")
@export var smolder_energy: float = 0.8       ## ember crack glow of a wounded Drowned in the dark (x wound)
@export var smolder_min_wound: float = 0.05   ## wounds below this do not smolder
@export var ember_amount: int = 4
@export var crackle_db: float = -10.0
@export_group("Hitbox")
@export var hitbox_radius: float = 0.58
@export var hitbox_height: float = 2.15
@export var hitbox_center_y: float = 1.05
@export var shoulder_box: Vector3 = Vector3(1.10, 0.75, 0.65)   ## cloak + sleeves
@export var shoulder_y: float = 1.35
@export_group("Searing (lit)")
@export var sear_response: float = 6.0       ## 1/s: how fast the ember glow rises and fades
@export var sear_face_energy: float = 0.12   ## a dim death mask: the ember eyes carry the look, not the face
@export var sear_eye_energy: float = 1.8
@export var sear_color: Color = Color(1.0, 0.55, 0.22)
@export var steam_amount: int = 16
@export var steam_lifetime: float = 1.6
@export_group("Wounded gait")
@export var wound_threshold: float = 0.5     ## at or below this fraction of max_hp it limps...
@export var wound_lean_deg: float = 10.0     ## ...leaning further forward...
@export var wound_speed_mult: float = 0.85   ## ...and gliding slower
@export_group("Burning (torch)")
@export var burn_dps: float = 8.0            ## self-damage while on fire (on top of any light dps)
@export var impale_damage: float = 25.0      ## a flare that strikes the body
@export var burn_speed_mult: float = 1.0     ## a burning Drowned ignores the light slowdown and keeps coming
@export var torch_light_radius: float = 6.0  ## a burning Drowned lights its packmates (gameplay light)...
@export var torch_light_dps: float = 8.0
@export var torch_light_energy: float = 2.2  ## ...and the ground around it (visual, no shadows)
@export var torch_light_range: float = 7.0
@export_group("Lantern captain")
@export var captain_hp: float = 200.0
@export var captain_speed_mult: float = 0.85
@export var captain_scale: float = 1.2
@export var lantern_damage: float = 120.0    ## its own lantern bursting on it
@export var aura_radius: float = 10.0        ## packmates near a living captain glide faster...
@export var aura_speed_mult: float = 1.15
@export var rout_speed_mult: float = 0.7     ## ...and falter when it dies
@export var rout_time: float = 3.0

var id: int = 0
var hp: float = 100.0
## "emerging", "gliding", "dying"
var state: String = "gliding"
var speed: float = 0.0
var lit: bool = false
var revealed: bool = false
var dying_by: String = ""   ## "rifle", "light", "fire", "contact", "dawn" once dying
## "drowned" or "captain" (set before add_child).
var kind: String = "drowned"
var size_scale: float = 1.0
var burning: bool = false
var impaled_by: Flare
var lantern: CaptainLantern

var _hub: Enemies
var _heading: float = 0.0
var _body: Node3D
var _rigged: bool = false
var _anim: AnimationPlayer
var _cloth: Array[MeshInstance3D] = []
var _hitbox: Area3D
var _drips: GPUParticles3D
var _steam: GPUParticles3D
var _glow_mats: Array[StandardMaterial3D] = []
var _glow_is_eye: Array[bool] = []
var _knock: Vector3 = Vector3.ZERO   ## remaining knockback displacement (m)
var _knock_rate: float = 5.6           ## m/s the remaining knockback is played back at
var _stagger_left: float = 0.0
var _embers: GPUParticles3D
var _crackle: AudioStreamPlayer3D
var _smolder: float = 0.0
var _sear: float = 0.0   ## 0..1 smoothed "searing in the light" amount
var _age: float = 0.0
var _state_t: float = 0.0
var _moan_t: float = 0.0
var _time_offset: float = 0.0
var _shudder_left: float = 0.0
var _trail_dist: float = 0.0
var _vel: Vector3 = Vector3.ZERO
var _flutter: float = 1.0
var _spawn_xz: Vector2 = Vector2.ZERO
var _dissolve_len: float = 1.2
var _sink_len: float = 0.6
var _rout_left: float = 0.0
var _torch: GameLight
var _torch_light: OmniLight3D
var _flames: GPUParticles3D
var _burn_vis: float = 0.0


func setup(hub: Enemies, enemy_id: int, xz: Vector2, emerged: bool, enemy_kind: String = "drowned") -> void:
	_hub = hub
	id = enemy_id
	kind = enemy_kind
	if kind == "captain":
		max_hp = captain_hp
		base_speed *= captain_speed_mult
		size_scale = captain_scale
	hp = max_hp
	_spawn_xz = xz
	speed = base_speed
	var ground: float = _surface(xz.x, xz.y)
	position = Vector3(xz.x, ground + hover_height, xz.y)
	state = "gliding" if emerged else "emerging"
	_heading = _desired_heading(_target_point())


func _ready() -> void:
	_time_offset = GameRng.randf() * 20.0
	_moan_t = GameRng.randf_range(moan_first.x, moan_first.y)
	_rigged = use_rig and DrownedRig.available()
	_body = DrownedRig.build(rig_height) if _rigged else DrownedBuilder.build()
	_body.scale = Vector3.ONE * size_scale
	add_child(_body)
	for mi: MeshInstance3D in ModelKit.meshes(_body):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.has_meta("cloth"):
			_cloth.append(mi)
			mi.set_instance_shader_parameter("time_offset", _time_offset)
	if _rigged:
		_body.position.y = -hover_height   # feet on the rock: a walking body does not hover
		_anim = ModelKit.animation_player(_body)
		if _anim != null:
			_anim.play(DrownedRig.CLIP_WALK)
			_anim.seek(fmod(_time_offset, 1.3), true)   # packs do not march in step
	_build_glow_materials()
	# Hitbox on the root (the rifle also runs an exact geometric test against the visual centre).
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.collision_layer = 4   # layer 3: enemy hitboxes
	_hitbox.collision_mask = 0
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = hitbox_radius * size_scale
	shape.height = hitbox_height * size_scale
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Body"
	cs.shape = shape
	cs.position.y = hitbox_center_y * size_scale
	_hitbox.add_child(cs)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = shoulder_box * size_scale
	var shoulders: CollisionShape3D = CollisionShape3D.new()
	shoulders.name = "Shoulders"
	shoulders.shape = box
	shoulders.position.y = shoulder_y * size_scale
	_hitbox.add_child(shoulders)
	add_child(_hitbox)   # on the root, not _body: _body is animated every frame and would lag the physics broadphase
	_build_drips()
	_build_steam()
	_build_embers()
	if kind == "captain":
		lantern = CaptainLantern.new()
		lantern.name = "Lantern"
		lantern.captain = self
		_body.add_child(lantern)
	rotation.y = _heading
	if state == "emerging":
		_body.position.y = -emerge_depth
		_hub.splash_at(Vector3(position.x, position.y - hover_height, position.z))


# --- queries ----------------------------------------------------------------------------------

func chest_position() -> Vector3:
	return global_position + Vector3(0.0, chest_height * size_scale, 0.0)


func is_alive() -> bool:
	return state != "dying"


func fire_system() -> FireSystem:
	return _hub.fire


func telemetry() -> Dictionary:
	var p: Vector3 = global_position
	return {
		"id": id,
		"pos": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
		"hp": snappedf(hp, 0.1),
		"lit": lit,
		"speed": snappedf(speed, 0.001),
		"state": state,
		"kind": kind,
		"burning": burning,
		"impaled": impaled_by != null,
		"staggered": _stagger_left > 0.0,
		"lantern": lantern != null and lantern.intact,
	}


## Offset of the animated visual body from the root (bob, shudder); the rifle's hit cylinder is centred on it.
func body_offset() -> Vector3:
	return _body.position if _body != null else Vector3.ZERO


## Whether a rifle hit hurts. `shootable` is LightField's verdict for the hit point itself; a lit Drowned (its
## chest is in light) is also hurt when the shot lands on the lower cloak or the back, where the ground can
## occlude a flare's light.
func hit_shootable(shootable: bool) -> bool:
	return shootable or lit or bool(_hub.field.query(chest_position())["shootable"])


## Called by Rifle._hitscan. `shootable` = LightField said the hit point is lit. `headshot` = the ray went
## through the hood sphere: lethal whatever the light.
func on_rifle_hit(point: Vector3, dir: Vector3, shootable: bool, damage: float, headshot: bool = false) -> void:
	if state == "dying":
		return
	if headshot:
		hp = 0.0
		_die("rifle")
		_hub.lethal_hit(point, dir)
		return
	if hit_shootable(shootable):
		hp -= maxf(damage, 0.0)
		if hp <= 0.0:
			_die("rifle")
			_hub.lethal_hit(point, dir)
		else:
			_shudder_left = dark_hit_shudder_time
	else:
		_shudder_left = dark_hit_shudder_time
		HitFx.dark_mist(_hub, point, dir)
		# Darkness is not full immunity. Light is still the multiplier (one shot kills in light), but two
		# body shots in the dark kill too, and each one shoves the Drowned back.
		hp -= dark_hit_damage
		_push(Vector3(dir.x, 0.0, dir.z), dark_knockback, knock_time)
		if hp <= 0.0:
			_die("rifle")
			_hub.lethal_hit(point, dir)
		else:
			HitFx.lethal_splash(_hub, point, dir)


## Ray-vs-hood-sphere: distance along the ray, or -1. The sphere follows the animated body.
func ray_vs_head(from: Vector3, dir: Vector3, slack: float) -> float:
	var c: Vector3 = global_position + body_offset() + Vector3(0.0, head_center_y * size_scale, 0.0)
	var r: float = head_radius * size_scale + slack
	var oc: Vector3 = from - c
	var b: float = oc.dot(dir)
	var cc: float = oc.length_squared() - r * r
	var disc: float = b * b - cc
	if disc < 0.0:
		return -1.0
	var t: float = -b - sqrt(disc)
	return t if t >= 0.0 else -1.0


## Rifle-butt shove (and other blunt pushes): knock back `dist` metres, stagger for `stagger` seconds.
func shove(away: Vector3, dist: float, stagger: float, damage: float) -> void:
	if state == "dying":
		return
	_push(Vector3(away.x, 0.0, away.z), dist, shove_knock_time)
	_stagger_left = maxf(_stagger_left, stagger)
	_shudder_left = dark_hit_shudder_time
	if damage > 0.0 and state != "emerging":
		hp -= damage
		if hp <= 0.0:
			_die("rifle")
			_hub.lethal_hit(chest_position(), away)


func is_staggered() -> bool:
	return _stagger_left > 0.0


func is_wounded() -> bool:
	return hp <= max_hp * wound_threshold


## Set alight (impaled flare, oil pool, fire burst, burning neighbour's lantern...). Burns until it dies: it
## lights its packmates within torch_light_radius and keeps coming at full speed. A captain's lantern bursts.
func ignite() -> void:
	if state == "dying" or burning:
		return
	burning = true
	_torch = GameLight.new()
	_torch.name = "Torch"
	_torch.field = _hub.field
	_torch.radius = torch_light_radius
	_torch.dps = torch_light_dps
	_torch.ray_height = 0.0
	_torch.occludable = false
	_torch.position.y = chest_height * size_scale
	add_child(_torch)
	_torch_light = FireFx.fire_light(torch_light_energy, torch_light_range, 2.0)
	_torch_light.position.y = 1.5 * size_scale
	add_child(_torch_light)
	_flames = FireFx.flames(0.3 * size_scale, 60, 1.2, 0.3)
	_flames.position.y = 1.1 * size_scale
	add_child(_flames)
	if lantern != null and lantern.intact:
		lantern.burst_later()


## A flare struck the body and stuck in it: the impact hurts and the Drowned becomes a walking torch.
func impale(f: Flare) -> void:
	if state == "dying":
		return
	impaled_by = f
	hp -= impale_damage
	_shudder_left = dark_hit_shudder_time
	ignite()
	if hp <= 0.0:
		_die("fire")


## Caught in a fire burst: damage, a shove away from the centre, and set alight.
func burst_hit(away: Vector3, damage: float, knock: float) -> void:
	if state == "dying":
		return
	hp -= damage
	_push(away, knock, shove_knock_time)
	_shudder_left = dark_hit_shudder_time
	ignite()
	if hp <= 0.0:
		_die("fire")


## The captain's lantern was shot (or caught fire): it bursts on him.
func on_lantern_burst(point: Vector3) -> void:
	if state == "dying":
		return
	hp -= lantern_damage
	ignite()
	if hp <= 0.0:
		_die("fire")
		_hub.lethal_hit(point, Vector3.UP)


## Captain aura: a nearby captain dying routs this one for rout_time.
func rout() -> void:
	_rout_left = rout_time


func _push(flat: Vector3, dist: float, time: float) -> void:
	if flat.length() < 0.001 or dist <= 0.0:
		return
	_knock = flat.normalized() * dist
	_knock_rate = dist / maxf(time, 0.01)


# --- simulation -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_age += delta
	_state_t += delta
	_shudder_left = maxf(0.0, _shudder_left - delta)
	_stagger_left = maxf(0.0, _stagger_left - delta)
	_rout_left = maxf(0.0, _rout_left - delta)
	_moan_tick(delta)
	match state:
		"emerging":
			_tick_emerge()
		"gliding":
			_tick_glide(delta)
		"dying":
			_tick_dying()


func _moan_tick(delta: float) -> void:
	if state == "dying":
		return
	_moan_t -= delta
	if _moan_t <= 0.0:
		_moan_t = GameRng.randf_range(moan_interval.x, moan_interval.y)
		_hub.audio.play_moan(global_position + Vector3(0.0, 1.7, 0.0), GameRng.randi_range(0, 3))


func _tick_emerge() -> void:
	_update_light(0.0)
	var k: float = clampf(_state_t / emerge_time, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	_body.position.y = lerpf(-emerge_depth, 0.0, k)
	global_position.y = _surface(global_position.x, global_position.z) + hover_height
	if _state_t >= emerge_time:
		state = "gliding"
		_state_t = 0.0
		_body.position.y = 0.0


func _tick_glide(delta: float) -> void:
	_update_light(delta)
	if hp <= 0.0:
		_die("fire" if burning else "light")
		return
	var target: Vector3 = _target_point()
	var to_t: Vector3 = target - global_position
	to_t.y = 0.0
	var dir: Vector3 = to_t.normalized() if to_t.length() > 0.001 else Vector3.ZERO
	dir = (dir + _hub.separation_push(self, separation) * 1.2).normalized() if dir != Vector3.ZERO else dir
	if dir != Vector3.ZERO:
		var want: float = atan2(-dir.x, -dir.z)
		var diff: float = angle_difference(_heading, want)
		var max_turn: float = deg_to_rad(turn_rate_deg) * delta
		_heading += clampf(diff, -max_turn, max_turn)
	var target_speed: float = base_speed * (lit_mult if lit else dark_mult)
	if burning:
		target_speed = base_speed * burn_speed_mult
	if is_wounded():
		target_speed *= wound_speed_mult
	if _rout_left > 0.0:
		target_speed *= rout_speed_mult
	elif kind != "captain" and _hub.near_captain(self, aura_radius):
		target_speed *= aura_speed_mult
	speed = lerpf(target_speed, speed, exp(-speed_response * delta))
	if _stagger_left > 0.0:
		speed *= stagger_speed_mult
	if _hub.freeze:
		speed = 0.0
	var fwd: Vector3 = Vector3(-sin(_heading), 0.0, -cos(_heading))
	_vel = fwd * speed
	var step: Vector3 = _vel * delta
	global_position.x += step.x
	global_position.z += step.z
	if _knock != Vector3.ZERO:
		var left: Vector3 = _knock.move_toward(Vector3.ZERO, _knock_rate * delta)
		global_position += _knock - left
		_knock = left
	global_position.y = _surface(global_position.x, global_position.z) + hover_height
	rotation.y = _heading
	_trail(step.length())
	_check_contacts()


func _update_light(delta: float) -> void:
	var info: Dictionary = _hub.field.query(chest_position())
	lit = bool(info["lit"])
	revealed = lit and _hub.field.reveal_active()
	var dps: float = float(info["dps"])
	if lit and dps > 0.0 and state == "gliding":
		hp -= dps * delta
	if burning and state == "gliding":
		hp -= burn_dps * delta


func _target_point() -> Vector3:
	var pl: Player = _hub.player
	if pl != null and pl.is_alive():
		if Vector2(pl.global_position.x - position.x, pl.global_position.z - position.z).length() < aggro_radius:
			return pl.global_position
	return _hub.door_point


func _desired_heading(p: Vector3) -> float:
	var d: Vector3 = p - Vector3(_spawn_xz.x, 0.0, _spawn_xz.y)
	return atan2(-d.x, -d.z)


func _trail(moved: float) -> void:
	var gx: float = global_position.x
	var gz: float = global_position.z
	var land: float = _hub.island.height_at(gx, gz)
	if land < _hub.ocean.get_height(gx, gz) + 0.2:
		_trail_dist = 0.0
		return
	_trail_dist += moved
	if _trail_dist >= trail_step:
		_trail_dist = 0.0
		_hub.trails.stamp(Vector3(gx, land, gz), _heading)


func _check_contacts() -> void:
	var pl: Player = _hub.player
	var gp: Vector3 = global_position
	if pl != null and pl.is_alive() and _stagger_left <= 0.0:
		var d: float = Vector2(pl.global_position.x - gp.x, pl.global_position.z - gp.z).length()
		if d < contact_radius and absf(pl.global_position.y - gp.y) < 3.0:
			pl.take_hit()
			_die("contact")
			return
	if Vector2(gp.x, gp.z).length() < tower_radius:
		_hub.reached_lighthouse += 1
		_hub.lighthouse.gutter()
		if pl != null:
			pl.take_hit()
		_die("contact")


func _die(by: String) -> void:
	if state == "dying":
		return
	state = "dying"
	dying_by = by
	_state_t = 0.0
	speed = 0.0
	lit = false
	revealed = false
	_dissolve_len = dissolve_time
	_sink_len = sink_depth
	_hitbox.set_deferred("collision_layer", 0)
	_drips.emitting = false
	_embers.emitting = false
	if _crackle != null:
		_crackle.stop()
	_put_out()
	if impaled_by != null and is_instance_valid(impaled_by):
		impaled_by.drop_from_host()
	impaled_by = null
	if kind == "captain":
		_hub.on_captain_died(self)
	_hub.on_death(self, by)
	_hub.trails.puddle(Vector3(global_position.x, _hub.island.height_at(global_position.x, global_position.z), global_position.z))


## Dawn: sink and dissolve over `duration` seconds. Not a kill, not a contact.
func dissolve_away(duration: float) -> void:
	if state == "dying":
		return
	_die("dawn")
	_dissolve_len = duration
	_sink_len = dawn_sink_depth


func _put_out() -> void:
	burning = false
	if _torch != null:
		_torch.queue_free()
		_torch = null
	if _torch_light != null:
		_torch_light.queue_free()
		_torch_light = null
	if _flames != null:
		_flames.emitting = false
		var f: GPUParticles3D = _flames
		get_tree().create_timer(1.0).timeout.connect(f.queue_free)
		_flames = null


func _tick_dying() -> void:
	var k: float = clampf(_state_t / _dissolve_len, 0.0, 1.0)
	for mi: MeshInstance3D in _cloth:
		mi.set_instance_shader_parameter("dissolve", k)
	_body.position.y = -_sink_len * k
	if _state_t >= _dissolve_len:
		_hub.forget(self)
		queue_free()


# --- visuals ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var t: float = _age
	var k: float = clampf(speed / (base_speed * dark_mult), 0.0, 1.0)
	var sh: Vector3 = Vector3.ZERO
	if _rigged:
		_update_rig(k)
	elif state != "dying":
		_body.position.y = _body.position.y if state == "emerging" else bob_amp * sin(TAU * bob_hz * t + _time_offset)
	if lit or _shudder_left > 0.0:
		var amp: float = lit_shudder_amp if lit else 0.0
		if _shudder_left > 0.0:
			amp = maxf(amp, dark_hit_shudder_amp * (_shudder_left / dark_hit_shudder_time))
		var ph: float = TAU * lit_shudder_hz * t
		sh = Vector3(sin(ph), 0.0, cos(ph * 1.13)) * amp
	_body.position.x = sh.x
	_body.position.z = sh.z
	_body.rotation.x = -deg_to_rad(lean_deg) * k - (deg_to_rad(wound_lean_deg) if (is_wounded() and state != "dying") else 0.0)
	if _rigged:
		_body.rotation.x *= rig_lean_scale
	if _stagger_left > 0.0 and state != "dying":
		var sk: float = sin(clampf(_stagger_left / 0.9, 0.0, 1.0) * PI * 0.5)
		_body.rotation.x += deg_to_rad(stagger_lean_deg) * sk
	_flutter = lit_flutter_mult if lit else 1.0
	var vis_vel: Vector3 = _vel
	if _hub.freeze and state != "dying":
		# Frozen captures keep a pretend slow glide so the hem still trails behind.
		vis_vel = Vector3(-sin(_heading), 0.0, -cos(_heading)) * base_speed * frozen_drag_speed
	var local_drag: Vector3 = Basis(Vector3.UP, _heading).inverse() * (-vis_vel * drag_factor)
	for mi: MeshInstance3D in _cloth:
		mi.set_instance_shader_parameter("flutter_scale", _flutter)
		mi.set_instance_shader_parameter("drag_offset", local_drag)
	_update_sear(delta)


## Searing: while lit (so shootable) the cloak shows ember rim light and cracks, the face and eyes catch warm
## light and steam rises. The crack intensity grows as hp falls. Pure shading, no light node, so it is never a
## gameplay light source.
func _update_sear(delta: float) -> void:
	# A burning Drowned lights itself: keep the sear rim low so it reads as charred cloth on fire, not a lamp.
	var want: float = (0.35 if burning else 1.0) if (lit and state != "dying") else 0.0
	_sear = move_toward(_sear, want, sear_response * delta)
	var wear: float = clampf(1.0 - hp / maxf(max_hp, 0.001), 0.0, 1.0)
	# Smolder: a wounded Drowned keeps glowing embers in its cracks even in the dark, so a half-dead one reads
	# at a glance (no health bars). Driven by the wound, not by light.
	var want_smolder: float = wear if (wear >= smolder_min_wound and state != "dying") else 0.0
	_burn_vis = move_toward(_burn_vis, 1.0 if burning else 0.0, 2.0 * delta)
	if burning:
		want_smolder = maxf(want_smolder, 1.0)
	_smolder = move_toward(_smolder, want_smolder, sear_response * delta)
	for mi: MeshInstance3D in _cloth:
		mi.set_instance_shader_parameter("lit_amount", _sear)
		mi.set_instance_shader_parameter("damage_amount", wear)
		mi.set_instance_shader_parameter("smolder_amount", _smolder * smolder_energy)
		mi.set_instance_shader_parameter("burn_amount", _burn_vis)
	_embers.emitting = _smolder > 0.02
	_embers.amount_ratio = clampf(0.35 + _smolder, 0.0, 1.0)
	if _smolder > 0.02 and _crackle == null and _hub.audio != null:
		_crackle = _hub.audio.make_crackle(self)
	if _crackle != null:
		_crackle.volume_db = crackle_db + linear_to_db(maxf(_smolder, 0.001)) + (8.0 if burning else 0.0)
	if _torch_light != null:
		_torch_light.light_energy = torch_light_energy * (0.85 + 0.15 * sin(_age * 17.0 + _time_offset) * sin(_age * 7.3))
	for i: int in _glow_mats.size():
		_glow_mats[i].emission_energy_multiplier = (sear_eye_energy if _glow_is_eye[i] else sear_face_energy) * _sear
	_steam.emitting = _sear > 0.05 and state != "dying"


## Picks the clip for the current state: flinch while staggered or dying, claw next to the target, else walk
## at a pace that follows the real speed. Movement itself stays in code; the clips never move the root.
func _update_rig(pace: float) -> void:
	if _anim == null:
		return
	var clip: StringName = DrownedRig.CLIP_WALK
	var rate: float = clampf(pace * base_speed * dark_mult / rig_walk_ref_speed, rig_walk_scale.x, rig_walk_scale.y)
	if state == "dying" or _stagger_left > 0.0:
		clip = DrownedRig.CLIP_HIT
		rate = 1.0
	elif state == "emerging":
		clip = DrownedRig.CLIP_IDLE
		rate = 1.0
	elif global_position.distance_to(_target_point()) < rig_attack_range:
		clip = DrownedRig.CLIP_ATTACK
		rate = 1.0
	if _anim.current_animation != clip and not (clip == DrownedRig.CLIP_HIT and _anim.assigned_animation == clip):
		_anim.play(clip, rig_blend)
	_anim.speed_scale = rate


func _build_glow_materials() -> void:
	for mi: MeshInstance3D in ModelKit.meshes(_body):
		if not mi.has_meta("glow"):
			continue
		var m: StandardMaterial3D = (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.emission_enabled = true
		m.emission = sear_color
		m.emission_energy_multiplier = 0.0
		mi.material_override = m
		_glow_mats.append(m)
		_glow_is_eye.append(String(mi.get_meta("glow")) == "eye")


func _build_steam() -> void:
	_steam = GPUParticles3D.new()
	_steam.name = "Steam"
	_steam.amount = steam_amount
	_steam.lifetime = steam_lifetime
	_steam.local_coords = false
	_steam.emitting = false
	_steam.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	_steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.38
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.0, 0.35, 0.0)
	pm.damping_min = 0.3
	pm.damping_max = 0.6
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var grow: Curve = Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.4))
	var grow_tex: CurveTexture = CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	# Ember orange at birth, ashy grey as it cools, gone at the top.
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.85, 0.6, 0.42, 0.0), Color(0.85, 0.6, 0.42, 0.25),
		Color(0.62, 0.58, 0.55, 0.28), Color(0.5, 0.5, 0.52, 0.0)])
	var ramp_tex: GradientTexture1D = GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	_steam.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = HitFx._soft()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.26, 0.26)
	quad.material = mat
	_steam.draw_pass_1 = quad
	_steam.position = Vector3(0.0, 1.55, 0.0)
	add_child(_steam)


## Wounded smolder: a slow trickle of tiny unshaded embers lifting off the shoulders (no light node).
func _build_embers() -> void:
	_embers = GPUParticles3D.new()
	_embers.name = "Embers"
	_embers.amount = ember_amount
	_embers.lifetime = 1.5
	_embers.local_coords = false
	_embers.emitting = false
	_embers.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.42
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0.0, 0.6, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var shrink_tex: CurveTexture = CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.6, 0.25, 0.0), Color(1.0, 0.55, 0.2, 1.0),
		Color(0.9, 0.3, 0.08, 0.8), Color(0.3, 0.1, 0.05, 0.0)])
	var ramp_tex: GradientTexture1D = GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	_embers.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = HitFx._soft()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	quad.material = mat
	_embers.draw_pass_1 = quad
	_embers.position = Vector3(0.0, 1.35, 0.0)
	add_child(_embers)


func _build_drips() -> void:
	_drips = GPUParticles3D.new()
	_drips.name = "Drips"
	var life: float = 0.35
	_drips.amount = maxi(1, int(round(drip_rate * life)))
	_drips.lifetime = life
	_drips.local_coords = false
	_drips.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	_drips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.5
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.02
	pm.direction = Vector3.DOWN
	pm.spread = 5.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.0, -9.81, 0.0)
	_drips.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.55, 0.60, 0.66, 0.55)
	mat.roughness = 0.3
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.015, 0.07)
	quad.material = mat
	_drips.draw_pass_1 = quad
	_drips.position = Vector3(0.0, 0.08, 0.0)
	add_child(_drips)


## Highest of the island ground and the sea surface at (x, z).
func _surface(x: float, z: float) -> float:
	return maxf(_hub.island.height_at(x, z), _hub.ocean.get_height(x, z))
