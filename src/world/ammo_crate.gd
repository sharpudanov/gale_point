class_name AmmoCrate
extends StaticBody3D
## Ammo crate just inside the lighthouse door (SPEC 4.9). `use()` gives +15 rifle rounds and +2
## flares once per restock. The lid sits ajar while stocked and closed when empty (diegetic state).

const PLANKS: String = "res://assets/textures/weathered_planks/weathered_planks_%s_1k.jpg"

@export var size: Vector3 = Vector3(0.8, 0.5, 0.6)
@export var plank_albedo: float = 0.55
@export var lid_height: float = 0.07
@export var lid_ajar_deg: float = 14.0
@export var rifle_rounds: int = 15
@export var flares_given: int = 2
@export var stocked: bool = true

var uses: int = 0
var refills: int = 0

var _lid: Node3D
var _lid_target: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var mat: StandardMaterial3D = ViewmodelBuilder.pbr(PLANKS, Color(plank_albedo, plank_albedo, plank_albedo), 0.85, 0.0, 1.6)
	var body_h: float = size.y - lid_height
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(size.x, body_h, size.z)
	body.mesh = bm
	body.material_override = mat
	body.position.y = body_h * 0.5
	add_child(body)
	# Iron straps.
	var strap_mat: StandardMaterial3D = ViewmodelBuilder.metal_material()
	for x: float in [-0.28, 0.28]:
		var sm: BoxMesh = BoxMesh.new()
		sm.size = Vector3(0.05, body_h + 0.01, size.z + 0.01)
		var strap: MeshInstance3D = MeshInstance3D.new()
		strap.mesh = sm
		strap.material_override = strap_mat
		strap.position = Vector3(x * size.x / 0.8, body_h * 0.5, 0.0)
		add_child(strap)
	# Lid hinges at the back edge (-Z, toward the wall) so it opens up and toward the player (+Z).
	_lid = Node3D.new()
	_lid.name = "LidHinge"
	_lid.position = Vector3(0.0, body_h, -size.z * 0.5)
	add_child(_lid)
	var lid: MeshInstance3D = MeshInstance3D.new()
	var lm: BoxMesh = BoxMesh.new()
	lm.size = Vector3(size.x + 0.02, lid_height, size.z + 0.02)
	lid.mesh = lm
	lid.material_override = mat
	lid.position = Vector3(0.0, lid_height * 0.5, size.z * 0.5)
	_lid.add_child(lid)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = size.y * 0.5
	add_child(cs)
	_lid_target = lid_ajar_deg if stocked else 0.0
	_lid.rotation_degrees.x = -_lid_target


func _process(delta: float) -> void:
	_lid_target = lid_ajar_deg if stocked else 0.0
	var cur: float = -_lid.rotation_degrees.x
	_lid.rotation_degrees.x = -move_toward(cur, _lid_target, 60.0 * delta)


func in_reach(player: Player) -> bool:
	return player.global_position.distance_to(global_position) <= player.interact_radius


## Resupply the player. Returns true if anything was handed over.
func use(player: Player) -> bool:
	if not stocked or not in_reach(player) or player.weapons == null:
		return false
	player.weapons.add_ammo(rifle_rounds, flares_given)
	stocked = false
	uses += 1
	return true


## M4 hook: wave_started / wave_cleared refill the crate if it is empty.
func restock() -> void:
	if not stocked:
		stocked = true
		refills += 1


func telemetry() -> Dictionary:
	return {"stocked": stocked, "uses": uses, "refills": refills}
