class_name HitGeo
extends RefCounted
## Deterministic ray tests shared by the rifle and flying flares (DESIGN_LOG principle 3: never trust the
## physics broadphase alone for things that move every frame).


## Distance along the unit ray `dir` to a sphere, or -1. A ray starting inside the sphere returns 0.
static func ray_vs_sphere(from: Vector3, dir: Vector3, centre: Vector3, radius: float) -> float:
	var oc: Vector3 = from - centre
	var b: float = oc.dot(dir)
	var c: float = oc.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var disc: float = b * b - c
	if disc < 0.0 or b > 0.0:
		return -1.0
	return -b - sqrt(disc)


## Distance along the ray to a vertical cylinder (axis through `centre`, XZ radius `radius`, y slab
## [y0, y1]), clipped to [0, max_t]; -1 on a miss. This is the Rifle's original hit math, unchanged.
static func ray_vs_cylinder(from: Vector3, dir: Vector3, centre: Vector3, radius: float, y0: float, y1: float,
		max_t: float) -> float:
	var to_c: Vector2 = Vector2(centre.x - from.x, centre.z - from.z)
	var flat: Vector2 = Vector2(dir.x, dir.z)
	var lo: float = 0.0
	var hi: float = max_t
	var a: float = flat.length_squared()
	if a < 0.000001:
		if to_c.length_squared() > radius * radius:
			return -1.0
	else:
		var f: Vector2 = Vector2(from.x - centre.x, from.z - centre.z)
		var b: float = f.dot(flat)
		var c: float = f.length_squared() - radius * radius
		var disc: float = b * b - a * c
		if disc < 0.0:
			return -1.0
		var sq: float = sqrt(disc)
		lo = maxf(lo, (-b - sq) / a)
		hi = minf(hi, (-b + sq) / a)
	if absf(dir.y) < 0.000001:
		if from.y < y0 or from.y > y1:
			return -1.0
	else:
		var ta: float = (y0 - from.y) / dir.y
		var tb: float = (y1 - from.y) / dir.y
		lo = maxf(lo, minf(ta, tb))
		hi = minf(hi, maxf(ta, tb))
	if lo > hi:
		return -1.0
	return lo
