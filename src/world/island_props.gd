class_name IslandProps
extends Node3D
## Places the interactive island props (DESIGN_LOG iteration 1, "reasons to leave the doorway"): signal
## braziers on the shoulders of the island, oil casks beside them and in the front field, and the beam winch
## behind the tower. Angles are XZ angles (x = cos, z = sin; the door faces +Z = 90 deg). Every prop is put
## on the first patch of solid ground found walking inward from `search_from` along its angle.

@export var brazier_angles_deg: PackedFloat32Array = PackedFloat32Array([30.0, 150.0, 215.0, 325.0])
@export var brazier_radius: float = 25.0
@export var cask_front_angles_deg: PackedFloat32Array = PackedFloat32Array([68.0, 112.0])
@export var cask_front_radius: float = 18.0
@export var cask_beside_brazier: float = 2.6   ## m to the side of each brazier
@export var min_ground: float = 1.2            ## props never stand lower than this (the surf line)
@export var winch_pos: Vector3 = Vector3(0.0, 0.0, -3.75)

var braziers: Array[Brazier] = []
var casks: Array[OilCask] = []
var winch: BeamWinch

var _island: Island


func build(island: Island, fire: FireSystem, enemies: Enemies, field: LightField, audio: Soundscape,
		weather: StormWeather, lighthouse: Lighthouse, player: Player) -> void:
	_island = island
	for a: float in brazier_angles_deg:
		var p: Vector3 = _ground_point(deg_to_rad(a), brazier_radius)
		var b: Brazier = Brazier.new()
		b.name = "Brazier%d" % braziers.size()
		b.enemies = enemies
		b.field = field
		b.audio = audio
		b.weather = weather
		add_child(b)
		b.global_position = p
		braziers.append(b)
		var side: Vector3 = Vector3(-sin(deg_to_rad(a)), 0.0, cos(deg_to_rad(a))) * cask_beside_brazier
		_add_cask(Vector3(p.x + side.x, 0.0, p.z + side.z), fire, enemies, field)
	for a: float in cask_front_angles_deg:
		_add_cask(_ground_point(deg_to_rad(a), cask_front_radius), fire, enemies, field)
	winch = BeamWinch.new()
	winch.name = "BeamWinch"
	winch.lighthouse = lighthouse
	winch.player = player
	winch.audio = audio
	add_child(winch)
	winch.global_position = Vector3(winch_pos.x, island.height_at(winch_pos.x, winch_pos.z), winch_pos.z)


func _add_cask(xz: Vector3, fire: FireSystem, enemies: Enemies, field: LightField) -> void:
	var c: OilCask = OilCask.new()
	c.name = "OilCask%d" % casks.size()
	c.fire = fire
	c.enemies = enemies
	c.field = field
	add_child(c)
	c.global_position = Vector3(xz.x, _island.height_at(xz.x, xz.z) - 0.03, xz.z)
	c.rotation.y = float(casks.size()) * 1.37
	casks.append(c)


## First point at or above min_ground walking inward from `r` along angle `a`.
func _ground_point(a: float, r: float) -> Vector3:
	var d: float = r
	while d > 4.0:
		var x: float = cos(a) * d
		var z: float = sin(a) * d
		var h: float = _island.height_at(x, z)
		if h >= min_ground:
			return Vector3(x, h, z)
		d -= 0.5
	return Vector3(cos(a) * d, _island.height_at(cos(a) * d, sin(a) * d), sin(a) * d)


## WaveDirector.wave_started: fresh casks, re-fuelled braziers, a winch charge.
func on_wave_started(_wave: int) -> void:
	for c: OilCask in casks:
		c.restock()
	for b: Brazier in braziers:
		b.refuel()
	if winch != null:
		winch.recharge()


func light_all_braziers() -> void:
	for b: Brazier in braziers:
		b.ignite()


func telemetry() -> Dictionary:
	var lit: int = 0
	var lightings: int = 0
	for b: Brazier in braziers:
		if b.lit:
			lit += 1
		lightings += b.lightings
	var intact: int = 0
	var ruptured: int = 0
	for c: OilCask in casks:
		if c.intact:
			intact += 1
		ruptured += c.ruptures
	return {
		"braziers": braziers.size(),
		"braziers_lit": lit,
		"brazier_lightings": lightings,
		"casks": casks.size(),
		"casks_intact": intact,
		"casks_ruptured": ruptured,
		"winch": winch.telemetry() if winch != null else {},
		"brazier_pos": braziers.map(func(b: Brazier) -> Array: return [snappedf(b.global_position.x, 0.1), snappedf(b.global_position.y, 0.1), snappedf(b.global_position.z, 0.1)]),
		"cask_pos": casks.map(func(c: OilCask) -> Array: return [snappedf(c.global_position.x, 0.1), snappedf(c.global_position.y, 0.1), snappedf(c.global_position.z, 0.1)]),
	}
