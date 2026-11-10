class_name IslandProps
extends Node3D
## Places the interactive island props (DESIGN_LOG iteration 1, "reasons to leave the doorway"): signal
## braziers on the shoulders of the island, oil casks beside them and in the front field, and the beam winch
## behind the tower. Where they stand comes from map/layout.tscn (MapLayout: X, Z and cask yaw); the height is
## Island.height_at(). LayoutCheck reports props on low ground, off the walkable area or too close together.

@export var min_ground: float = 1.2            ## props never stand lower than this (the surf line; LayoutCheck)

var braziers: Array[Brazier] = []
var casks: Array[OilCask] = []
var winch: BeamWinch

var _island: Island


func build(island: Island, fire: FireSystem, enemies: Enemies, field: LightField, audio: Soundscape,
		weather: StormWeather, lighthouse: Lighthouse, player: Player) -> void:
	_island = island
	var brazier_pts: PackedVector2Array = MapLayout.brazier_points()
	var cask_xfs: Array[Transform3D] = MapLayout.cask_transforms()
	# Child order (process order) stays Brazier0, OilCask0, Brazier1, OilCask1, ..., then the other casks.
	for i: int in maxi(brazier_pts.size(), cask_xfs.size()):
		if i < brazier_pts.size():
			var p: Vector2 = brazier_pts[i]
			var b: Brazier = Brazier.new()
			b.name = "Brazier%d" % i
			b.enemies = enemies
			b.field = field
			b.audio = audio
			b.weather = weather
			add_child(b)
			b.global_position = Vector3(p.x, island.height_at(p.x, p.y), p.y)
			braziers.append(b)
		if i < cask_xfs.size():
			_add_cask(cask_xfs[i], fire, enemies, field)
	var w: Vector2 = MapLayout.winch_point()
	winch = BeamWinch.new()
	winch.name = "BeamWinch"
	winch.lighthouse = lighthouse
	winch.player = player
	winch.audio = audio
	add_child(winch)
	winch.global_position = Vector3(w.x, island.height_at(w.x, w.y), w.y)


func _add_cask(xf: Transform3D, fire: FireSystem, enemies: Enemies, field: LightField) -> void:
	var c: OilCask = OilCask.new()
	c.name = "OilCask%d" % casks.size()
	c.fire = fire
	c.enemies = enemies
	c.field = field
	add_child(c)
	var p: Vector3 = xf.origin
	c.global_position = Vector3(p.x, _island.height_at(p.x, p.z) - 0.03, p.z)
	c.rotation.y = xf.basis.get_euler().y
	casks.append(c)


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
