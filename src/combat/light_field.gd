class_name LightField
extends Node3D
## Gameplay light registry (SPEC 4.7). Enemies can only be hurt where this says `shootable`.
## Sources: burning flares, the lighthouse beam, and the lightning reveal window. Muzzle flash and
## the lamp are visual only and never registered.
## Call query() from _physics_process only (it casts physics rays).

@export var lit_threshold: float = 0.2
@export var flare_radius: float = 15.5
@export var flare_ray_height: float = 1.1   ## occlusion rays aim this far above a flare...
@export var flare_ray_lift: float = 1.2     ## ...and start this far above the queried point, so rock bumps never block a visibly lit enemy
@export var flare_dps: float = 12.0
@export var beam_dps: float = 20.0
@export var beam_range: float = 160.0
@export var reveal_time: float = 0.6
@export var occlusion_mask: int = 1  ## physics layer 1 (world)

var flares: Array[Flare] = []
## Other gameplay lights (braziers, oil fires, burning Drowned, burst glare). See GameLight.
var sources: Array[GameLight] = []
var lighthouse: Lighthouse
var player: Player

var _reveal_left: float = 0.0
var _lighthouse_rid: Array[RID] = []


func setup(lh: Lighthouse, p: Player) -> void:
	lighthouse = lh
	player = p
	_lighthouse_rid = [lh.get_rid()]


func register_flare(f: Flare) -> void:
	if not flares.has(f):
		flares.append(f)


func unregister_flare(f: Flare) -> void:
	flares.erase(f)


func register_source(l: GameLight) -> void:
	if not sources.has(l):
		sources.append(l)


func unregister_source(l: GameLight) -> void:
	sources.erase(l)


## Hooked to StormWeather.lightning_struck.
func on_lightning() -> void:
	_reveal_left = reveal_time


func reveal_active() -> bool:
	return _reveal_left > 0.0


func _physics_process(delta: float) -> void:
	_reveal_left = maxf(0.0, _reveal_left - delta)
	if player != null:
		player.in_light = bool(query(player.global_position + Vector3(0.0, 1.0, 0.0))["lit"])


## {lit: bool, dps: float, shootable: bool} at a world position (SPEC 4.7).
func query(pos: Vector3) -> Dictionary:
	var total: float = 0.0
	var dps: float = 0.0
	var shootable: bool = false
	if _reveal_left > 0.0:
		total += 1.0
		shootable = true
	for f: Flare in flares:
		var c: float = f.light_contribution(pos, flare_radius)
		if c <= 0.0:
			continue
		if _occluded(pos + Vector3(0.0, flare_ray_lift, 0.0), f.global_position + Vector3(0.0, flare_ray_height, 0.0)):
			continue
		total += c
		dps = maxf(dps, flare_dps)
		shootable = true
	for l: GameLight in sources:
		var c: float = l.contribution(pos)
		if c <= 0.0:
			continue
		if l.occludable and _occluded(pos + Vector3(0.0, flare_ray_lift, 0.0), l.origin()):
			continue
		total += c
		dps = maxf(dps, l.dps)
		shootable = true
	if lighthouse != null and lighthouse.beam != null and not lighthouse.is_guttering():
		if _in_beam(pos) and not _occluded(pos, lighthouse.beam.global_position):
			total += 1.0
			dps = maxf(dps, beam_dps * lighthouse.beam_dps_mult())
			shootable = true
	var lit: bool = total >= lit_threshold
	return {"lit": lit, "dps": dps if lit else 0.0, "shootable": shootable and lit}


func _in_beam(pos: Vector3) -> bool:
	var b: SpotLight3D = lighthouse.beam
	var origin: Vector3 = b.global_position
	var to_p: Vector3 = pos - origin
	var dist: float = to_p.length()
	if dist < 0.5 or dist > beam_range:
		return false
	var fwd: Vector3 = -b.global_transform.basis.z
	return fwd.dot(to_p / dist) >= cos(deg_to_rad(b.spot_angle))


func _occluded(a: Vector3, b: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b, occlusion_mask, _lighthouse_rid)
	return not space.intersect_ray(q).is_empty()
