class_name OilCask
extends ShootableGear
## A cask of lamp oil on the shore (Poly Haven CC0 "wine_barrel_01"). A rifle round, a fire burst, a burning
## flare resting against it or a burning Drowned brushing past ruptures it: a fire burst plus a burning oil
## pool that lights the ground and sets alight whatever glides through. Re-stocked at the start of each wave.
## Not a red barrel: it only matters because fire is light (DESIGN_LOG, rejected clichés).

const MODEL: String = "res://assets/models/wine_barrel_01/wine_barrel_01_1k.gltf"

@export var radius: float = 0.38
@export var height: float = 0.87
@export var tint: Color = Color(0.55, 0.52, 0.5)
@export var burst_scale: float = 0.8
@export var touch_radius: float = 1.2         ## a burning Drowned or flare this close sets it off
@export var ignite_delay: float = 0.15

var fire: FireSystem
var enemies: Enemies
var field: LightField
var intact: bool = true
var ruptures: int = 0

var _model: Node3D
var _body: StaticBody3D
var _pending: bool = false


func _ready() -> void:
	add_to_group(FireSystem.BURNABLE)
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	if ResourceLoader.exists(MODEL):
		var scene: PackedScene = load(MODEL) as PackedScene
		var inst: Node3D = scene.instantiate() as Node3D
		_model.add_child(inst)
		for mi: MeshInstance3D in CaptainLantern._meshes(inst):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for si: int in mi.get_surface_override_material_count():
				var m: Material = mi.mesh.surface_get_material(si)
				if m is StandardMaterial3D:
					var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					d.albedo_color = d.albedo_color * tint
					mi.set_surface_override_material(si, d)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position.y = height * 0.5
	_body.add_child(cs)
	add_child(_body)


func ray_hit(from: Vector3, dir: Vector3) -> float:
	if not intact:
		return -1.0
	var c: Vector3 = global_position
	return HitGeo.ray_vs_cylinder(from, dir, c, radius, c.y, c.y + height, 200.0)


func on_shot(_point: Vector3, _dir: Vector3) -> void:
	rupture()


## Burnable: fire reached it.
func ignite() -> void:
	if not intact or _pending:
		return
	_pending = true
	get_tree().create_timer(ignite_delay, false, true).timeout.connect(rupture)


func rupture() -> void:
	_pending = false
	if not intact:
		return
	intact = false
	ruptures += 1
	_model.visible = false
	_body.collision_layer = 0
	if fire != null:
		fire.burst(global_position + Vector3(0.0, height * 0.6, 0.0), burst_scale)
		fire.oil_fire(global_position)


## WaveDirector.wave_started: a fresh cask is rolled out.
func restock() -> void:
	if intact:
		return
	intact = true
	_model.visible = true
	_body.collision_layer = 1


func _physics_process(_delta: float) -> void:
	if not intact or _pending:
		return
	var p: Vector3 = global_position
	if enemies != null:
		for d: Drowned in enemies.living():
			if d.burning and Vector2(d.global_position.x - p.x, d.global_position.z - p.z).length() < touch_radius:
				ignite()
				return
	if field != null:
		for f: Flare in field.flares:
			if f.state == "resting" and f.burn > 0.3 and f.global_position.distance_to(p + Vector3(0.0, 0.4, 0.0)) < touch_radius:
				ignite()
				return
