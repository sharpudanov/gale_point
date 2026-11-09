class_name GameLight
extends Node3D
## A gameplay light that is not a flare or the beam (SPEC 4.7 "other sources"): brazier fire, oil pools, a
## burning Drowned, the brief glare of a fire burst. Registers itself with LightField while in the tree.
## `strength` (0..1) scales the contribution; 0 = off. Visual light nodes are owned by the subclass/owner
## and must use shadow_enabled = false (only the beam and active flares cast shadows).

@export var radius: float = 8.0
@export var dps: float = 12.0
@export var ray_height: float = 0.8     ## occlusion rays aim this far above the origin
@export var occludable: bool = true

var strength: float = 1.0
var field: LightField


func _enter_tree() -> void:
	if field != null:
		field.register_source(self)


func _exit_tree() -> void:
	if field != null:
		field.unregister_source(self)


## 0..1 at a world position: `strength` inside `radius`, else 0.
func contribution(pos: Vector3) -> float:
	if strength <= 0.0:
		return 0.0
	if pos.distance_to(global_position) > radius:
		return 0.0
	return strength


func origin() -> Vector3:
	return global_position + Vector3(0.0, ray_height, 0.0)
