class_name LayoutCheck
extends RefCounted
## Sanity checks for where the island props stand (SPEC §4.2, telemetry `layout`). A problem is a short
## string naming the prop by its map label (B0.., C0.., W, Buoy0..; the same labels the --map view draws).
## Checked: a brazier, cask or winch below IslandProps.min_ground, outside the walkable boundary
## (Island.walkable_radius) or inside the tower footprint (Lighthouse.plinth_radius); two of them closer
## than MIN_GAP; a buoy over ground at or above sea level.

const MIN_GAP: float = 1.0          ## m between any two props
const BUOY_MAX_GROUND: float = 0.0  ## a buoy needs the seabed below this (sea level)


## Label + position of every placed prop, in map order: braziers, casks, winch.
static func prop_points(props: IslandProps) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in props.braziers.size():
		out.append({"label": "B%d" % i, "pos": props.braziers[i].global_position})
	for i: int in props.casks.size():
		out.append({"label": "C%d" % i, "pos": props.casks[i].global_position})
	if props.winch != null:
		out.append({"label": "W", "pos": props.winch.global_position})
	return out


static func problems(island: Island, props: IslandProps, buoys: BellBuoys, lighthouse: Lighthouse) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var pts: Array[Dictionary] = prop_points(props)
	for i: int in pts.size():
		var label: String = pts[i]["label"]
		var p: Vector3 = pts[i]["pos"]
		var xz: Vector2 = Vector2(p.x, p.z)
		var h: float = island.height_at(p.x, p.z)
		if h < props.min_ground:
			out.append("%s low (ground %.1f < %.1f)" % [label, h, props.min_ground])
		var edge: float = island.walkable_radius(xz.angle())
		if xz.length() > edge:
			out.append("%s off walkable (r %.1f > %.1f)" % [label, xz.length(), edge])
		if xz.length() < lighthouse.plinth_radius:
			out.append("%s inside tower (r %.1f < %.1f)" % [label, xz.length(), lighthouse.plinth_radius])
		for j: int in range(i + 1, pts.size()):
			var q: Vector3 = pts[j]["pos"]
			var d: float = xz.distance_to(Vector2(q.x, q.z))
			if d < MIN_GAP:
				out.append("%s-%s too close (%.2f m)" % [label, str(pts[j]["label"]), d])
	var bp: PackedVector3Array = buoys.points()
	for i: int in bp.size():
		var g: float = island.height_at(bp[i].x, bp[i].z)
		if g >= BUOY_MAX_GROUND:
			out.append("Buoy%d on land (ground %.1f)" % [i, g])
	return out
