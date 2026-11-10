class_name ViewmodelBuilder
extends RefCounted
## Static builders for the first-person viewmodels (SPEC 4.5 / 4.6): bolt-action rifle, break-action
## flare gun, oilskin sleeve and wool glove. Everything is primitives plus Poly Haven wear textures.
## Rifle-local axes: -Z is forward (muzzle), +Y up; the scope axis sets the ADS pose of WeaponHolder.

const WOOD_DIR: String = "res://assets/textures/dark_wood/dark_wood_%s_1k.jpg"
const METAL_DIR: String = "res://assets/textures/rusty_metal_02/rusty_metal_02_%s_1k.jpg"
const PAINT_DIR: String = "res://assets/textures/painted_metal_shutter/painted_metal_shutter_%s_1k.jpg"

## Viewmodel meshes sit on render layer 2 so a cold fill light can target only them.
const VIEWMODEL_LAYER: int = 2
const RIFLE_MODEL: String = "res://assets/models/bolt_action_rifle_7_62/bolt_action_rifle_7_62_2k.gltf"
const RIFLE_TINT: Color = Color(0.42, 0.42, 0.44)   ## the Poly Haven wood is bright orange: dim it for the storm
const ARMS_MODEL: String = "res://assets/models/fps_arms/fps_arms.fbx"
const ARMS_SKIN: String = "res://assets/models/fps_arms/new_diff.png"
const ARMS_TINT: Color = Color(0.3, 0.3, 0.32)   ## cold and dim, like the rifle: bare skin must not glow in the storm
const ARM_CURL_DEG: float = -68.0
## Rifle hold: [wrist, forearm direction, palm direction] in rifle space (-Z forward).
const RIFLE_HAND_R: Array[Vector3] = [Vector3(0.045, -0.13, 0.43), Vector3(-0.2, 0.3, -0.93), Vector3(-1.0, 0.0, 0.0)]
const RIFLE_HAND_L: Array[Vector3] = [Vector3(-0.04, -0.065, -0.07), Vector3(0.6, 0.45, -0.66), Vector3(0.0, 1.0, 0.0)]
const FLARE_HAND_R: Array[Vector3] = [Vector3(0.02, -0.12, 0.17), Vector3(-0.2, 0.45, -0.87), Vector3(-1.0, 0.0, 0.0)]
const BARREL_Y: float = 0.05
const BOLT_Z: float = 0.237      ## bolt pivot behind the origin (model x = -0.237)
const MUZZLE_Z: float = 0.60
const SIGHT_Y: float = 0.074      ## eye height for ADS: level with the front sight tip, just over the receiver
const FRONT_TIP_Z: float = 0.588 ## muzzle-end front sight post (tip at y 0.072)
const BOLT_B_TUCK: float = 0.045    ## model-x shift of the bolt body's rear half (toward the muzzle)
const FRONT_TIP_COLOR: Color = Color(1.0, 0.86, 0.62)
const EYE_Z: float = 0.52        ## ADS eye distance behind the rifle origin (over the wrist, well behind the bolt)


## Textured material; triplanar in object space so boxes, cylinders and spheres all get wear.
static func pbr(pattern: String, tint: Color, roughness: float, metallic: float, tex_scale: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = 0.5
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * tex_scale
	var diff: String = pattern % "diff"
	if ResourceLoader.exists(diff):
		m.albedo_texture = load(diff) as Texture2D
	var nor: String = pattern % "nor_gl"
	if ResourceLoader.exists(nor):
		m.normal_enabled = true
		m.normal_texture = load(nor) as Texture2D
		m.normal_scale = 1.2
	var rough: String = pattern % "rough"
	if ResourceLoader.exists(rough):
		m.roughness_texture = load(rough) as Texture2D
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	return m


static func wood_material() -> StandardMaterial3D:
	return pbr(WOOD_DIR, Color(0.30, 0.28, 0.27), 0.62, 0.0, 1.6)


static func metal_material() -> StandardMaterial3D:
	return pbr(METAL_DIR, Color(0.22, 0.22, 0.23) * 1.5, 0.6, 0.7, 1.5)


static func paint_material() -> StandardMaterial3D:
	return pbr(PAINT_DIR, Color(0.18, 0.19, 0.17) * 1.9, 0.6, 0.35, 3.0)


static func leather_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.055, 0.04)
	m.roughness = 0.9
	return m


static func sleeve_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.06, 0.06, 0.055)
	m.roughness = 0.85
	return m


static func glove_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.075, 0.07)
	m.roughness = 0.9
	return m


static func _part(parent: Node3D, n: String, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = VIEWMODEL_LAYER
	parent.add_child(mi)
	return mi


## A capsule limb whose axis runs from `a` to `b` (both parent-local).
static func _limb(parent: Node3D, n: String, radius: float, a: Vector3, b: Vector3, mat: Material) -> MeshInstance3D:
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = radius
	cap.height = a.distance_to(b) + radius * 2.0
	cap.radial_segments = 14
	cap.rings = 4
	var mi: MeshInstance3D = _part(parent, n, cap, mat, (a + b) * 0.5)
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return mi


static func _capsule(radius: float, length: float) -> CapsuleMesh:
	var c: CapsuleMesh = CapsuleMesh.new()
	c.radius = radius
	c.height = length
	c.radial_segments = 14
	c.rings = 4
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	return b


static func _cyl(radius: float, length: float, radial: int = 16) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = radial
	c.rings = 1
	return c


static func _sphere(radius: float) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


## Returns the rifle root (Poly Haven "Bolt Action Rifle 7.62", CC0, real scale: 1.23 m). The glTF is modelled
## along +X (muzzle) / +Y up / +Z right; it is turned so the muzzle points to -Z. Rifle-local axes: -Z is
## forward, +Y up, +X right; the barrel axis is at y = BARREL_Y, x = 0. The scope and its mount are removed:
## ADS looks over the open iron sights from (0, SIGHT_Y, EYE_Z). Named children the Rifle script animates: "Bolt" (pivot on the bore axis, so
## rotation.z lifts the handle and +z draws it back) and "Muzzle" (Marker3D at the barrel tip).
static func rifle() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "RifleModel"
	var packed: PackedScene = load(RIFLE_MODEL) as PackedScene
	var gun: Node3D = packed.instantiate() as Node3D
	gun.name = "Gun"
	gun.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	root.add_child(gun)
	# The two bolt meshes move together about the bolt axis (model x = -0.237, y = 0.0507).
	var bolt: Node3D = Node3D.new()
	bolt.name = "Bolt"
	bolt.position = Vector3(0.0, BARREL_Y, BOLT_Z)
	root.add_child(bolt)
	var bolt_mesh: Node3D = Node3D.new()
	bolt_mesh.name = "BoltMesh"
	bolt_mesh.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	bolt.add_child(bolt_mesh)
	for part: String in ["bolt_action_rifle_7_62_bolt_a", "bolt_action_rifle_7_62_bolt_b"]:
		var n: Node3D = gun.get_node(part) as Node3D
		gun.remove_child(n)
		bolt_mesh.add_child(n)
		n.position = Vector3.ZERO
	gun.get_node("bolt_action_rifle_7_62_bullet_54mm").queue_free()   # loose cartridge floating under the magazine
	# Open iron sights only: drop the scope and its mount, and tuck the bolt body's rear end forward so it does not
	# fill the bottom of the ADS picture.
	for n: Node in gun.get_children():
		if String(n.name).contains("scope"):
			n.queue_free()
	(bolt_mesh.get_node("bolt_action_rifle_7_62_bolt_b") as Node3D).position = Vector3(BOLT_B_TUCK, 0.0, 0.0)
	_dress(root)
	# A tiny warm ivory dot on top of the front sight post, so the muzzle end is readable in the dark.
	var tip: MeshInstance3D = MeshInstance3D.new()
	tip.name = "FrontTip"
	var tip_mesh: SphereMesh = SphereMesh.new()
	tip_mesh.radius = 0.0016
	tip_mesh.height = 0.0032
	tip_mesh.radial_segments = 8
	tip_mesh.rings = 4
	tip.mesh = tip_mesh
	var tip_mat: StandardMaterial3D = StandardMaterial3D.new()
	tip_mat.albedo_color = FRONT_TIP_COLOR
	tip_mat.emission_enabled = true
	tip_mat.emission = FRONT_TIP_COLOR
	tip_mat.emission_energy_multiplier = 1.2
	tip.material_override = tip_mat
	tip.position = Vector3(0.0, 0.0725, -FRONT_TIP_Z)
	tip.layers = VIEWMODEL_LAYER
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tip)
	var muzzle: Marker3D = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, BARREL_Y, -MUZZLE_Z)
	root.add_child(muzzle)
	for hold: Array[Vector3] in [RIFLE_HAND_R, RIFLE_HAND_L]:
		var limb: Node3D = arm(1 if hold == RIFLE_HAND_R else -1, hold[0], hold[1], hold[2], ARM_CURL_DEG)
		if limb != null:
			root.add_child(limb)
	return root


## Viewmodel layer, no shadows, and storm-dark materials (the albedo is dimmed).
## One imported first-person arm ("FPS arms", CC0, see ASSETS.md) placed rigidly: its wrist sits at `wrist`
## (in the parent's space), the forearm runs along `forearm_dir` into the hand and the palm faces `palm_dir`.
## The fingers are curled by `curl_deg` per joint; the other arm of the model is collapsed out of sight.
## side: +1 right, -1 left. Returns null when the model file is missing.
static func arm(side: int, wrist: Vector3, forearm_dir: Vector3, palm_dir: Vector3, curl_deg: float) -> Node3D:
	var model: Node3D = ModelKit.spawn(ARMS_MODEL)
	if model == null:
		return null
	model.name = "ArmR" if side > 0 else "ArmL"
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var tag: String = ".R" if side > 0 else ".L"
	var other: String = ".L" if side > 0 else ".R"
	var hand: int = sk.find_bone("hand" + tag)
	var forearm: int = sk.find_bone("forearm" + tag)
	if hand < 0 or forearm < 0:
		model.free()
		return null
	var to_model: Transform3D = (sk.get_parent() as Node3D).transform * sk.transform
	var hand_rest: Transform3D = to_model * sk.get_bone_global_rest(hand)
	var from: Basis = _frame((to_model * sk.get_bone_global_rest(forearm)).basis.y, hand_rest.basis.z)
	var turn: Basis = _frame(forearm_dir, palm_dir) * from.inverse()
	model.transform = Transform3D(turn, wrist - turn * hand_rest.origin)
	for i: int in sk.get_bone_count():
		var bone: String = sk.get_bone_name(i)
		if bone.begins_with("f_") and bone.ends_with(tag):
			sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(curl_deg)))
		elif bone == "clavicle" + other or bone == "hand" + other + ".control":
			sk.set_bone_pose_scale(i, Vector3.ONE * 0.0001)
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists(ARMS_SKIN):
		skin.albedo_texture = load(ARMS_SKIN) as Texture2D
	skin.albedo_color = ARMS_TINT
	skin.roughness = 0.65
	for mi: MeshInstance3D in ModelKit.meshes(model):
		mi.material_override = skin
		mi.layers = VIEWMODEL_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return model


## Orthonormal basis whose y runs along `along` and whose z is `facing` made square to it.
static func _frame(along: Vector3, facing: Vector3) -> Basis:
	var y: Vector3 = along.normalized()
	var z: Vector3 = (facing - y * facing.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


static func _dress(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.layers = VIEWMODEL_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i: int in mi.mesh.get_surface_count():
			var src: BaseMaterial3D = mi.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var m: BaseMaterial3D = src.duplicate() as BaseMaterial3D
			m.albedo_color = RIFLE_TINT
			mi.set_surface_override_material(i, m)
	for c: Node in node.get_children():
		_dress(c)


## Break-action flare gun. Named children: "Barrels" (pivot that tips down to break open), "Hammer",
## "Muzzle" (Marker3D). Gun-local: -Z forward, origin at the hinge/frame.
static func flare_gun() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "FlareGunModel"
	var paint: StandardMaterial3D = paint_material()
	var metal: StandardMaterial3D = metal_material()
	var wood: StandardMaterial3D = wood_material()
	var glove: StandardMaterial3D = glove_material()
	var sleeve: StandardMaterial3D = sleeve_material()
	_part(root, "Frame", _box(Vector3(0.036, 0.05, 0.12)), paint, Vector3(0.0, 0.0, 0.04))
	_part(root, "Grip", _box(Vector3(0.034, 0.11, 0.045)), wood, Vector3(0.0, -0.075, 0.085), Vector3(-14.0, 0.0, 0.0))
	var guard: TorusMesh = TorusMesh.new()
	guard.inner_radius = 0.014
	guard.outer_radius = 0.019
	guard.rings = 14
	guard.ring_segments = 8
	_part(root, "TriggerGuard", guard, metal, Vector3(0.0, -0.038, 0.035), Vector3(0.0, 0.0, 90.0))
	_part(root, "Trigger", _box(Vector3(0.006, 0.02, 0.006)), metal, Vector3(0.0, -0.028, 0.04))
	_part(root, "Hammer", _box(Vector3(0.008, 0.028, 0.012)), metal, Vector3(0.0, 0.04, 0.10), Vector3(-25.0, 0.0, 0.0))
	# Barrel group hinges at the front of the frame.
	var barrels: Node3D = Node3D.new()
	barrels.name = "Barrels"
	barrels.position = Vector3(0.0, 0.012, -0.02)
	root.add_child(barrels)
	_part(barrels, "Barrel", _cyl(0.02, 0.18, 18), paint, Vector3(0.0, 0.0, -0.09), Vector3(90.0, 0.0, 0.0))
	_part(barrels, "Bore", _cyl(0.0125, 0.004, 14), _dark(), Vector3(0.0, 0.0, -0.181), Vector3(90.0, 0.0, 0.0))
	_part(barrels, "Rib", _box(Vector3(0.008, 0.008, 0.17)), metal, Vector3(0.0, 0.024, -0.095))
	_part(barrels, "Sight", _box(Vector3(0.004, 0.01, 0.008)), metal, Vector3(0.0, 0.032, -0.17))
	var muzzle: Marker3D = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.012, -0.21)
	root.add_child(muzzle)
	# Right hand on the grip, sleeve trailing down-right.
	var limb: Node3D = arm(1, FLARE_HAND_R[0], FLARE_HAND_R[1], FLARE_HAND_R[2], ARM_CURL_DEG)
	if limb != null:
		root.add_child(limb)
	else:
		_part(root, "Hand", _box(Vector3(0.05, 0.06, 0.06)), glove, Vector3(0.0, -0.065, 0.10))
		_part(root, "Thumb", _box(Vector3(0.012, 0.012, 0.05)), glove, Vector3(-0.028, -0.02, 0.07))
		_limb(root, "Sleeve", 0.042, Vector3(0.0, -0.075, 0.12), Vector3(0.1, -0.28, 0.34), sleeve)
	return root


static func _dark() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.01, 0.01, 0.01)
	m.roughness = 0.9
	return m
