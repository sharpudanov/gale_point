class_name ShootableGear
extends Node3D
## Anything the rifle can hit that is not a Drowned body: a burning flare, an oil cask, a captain's lantern.
## Members join the "rifle_target" group; Rifle._hitscan asks each for a ray distance and calls on_shot()
## on the nearest one if it is closer than the Drowned (and the world) along the shot.

const GROUP: StringName = &"rifle_target"


func _enter_tree() -> void:
	add_to_group(GROUP)


## Distance along the (unit) ray to this target, or -1 when it misses / is not shootable right now.
func ray_hit(_from: Vector3, _dir: Vector3) -> float:
	return -1.0


## The rifle round landed on it.
func on_shot(_point: Vector3, _dir: Vector3) -> void:
	pass
