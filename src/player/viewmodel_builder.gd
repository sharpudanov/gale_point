class_name ViewmodelBuilder
extends RefCounted
## Static builders for the first-person viewmodels (SPEC 4.5 / 4.6): bolt-action rifle, break-action
## flare gun, oilskin sleeve and wool glove. Everything is primitives plus Poly Haven wear textures.
## Rifle-local axes: -Z is forward (muzzle), +Y up. The barrel axis sits at y = BARREL_Y so that the
## sight tops line up at the ADS height of WeaponHolder (ADS offset y = -SIGHT_Y).

const WOOD_DIR: String = "res://assets/textures/dark_wood/dark_wood_%s_1k.jpg"
const METAL_DIR: String = "res://assets/textures/rusty_metal_02/rusty_metal_02_%s_1k.jpg"
const PAINT_DIR: String = "res://assets/textures/painted_metal_shutter/painted_metal_shutter_%s_1k.jpg"

## Viewmodel meshes sit on render layer 2 so a cold fill light can target only them.
const VIEWMODEL_LAYER: int = 2
const BARREL_Y: float = 0.085
const SIGHT_Y: float = 0.105


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
	m.albedo_color = Color(0.11, 0.075, 0.05)
	m.roughness = 0.75
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


## Returns the rifle root. Named children the Rifle script animates: "Bolt" (handle group) and
## "Muzzle" (Marker3D at the barrel tip).
static func rifle() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "RifleModel"
	var wood: StandardMaterial3D = wood_material()
	var metal: StandardMaterial3D = metal_material()
	var leather: StandardMaterial3D = leather_material()

	# Wood: butt, wrist, fore-end.
	_part(root, "Butt", _box(Vector3(0.045, 0.13, 0.12)), wood, Vector3(0.0, 0.015, 0.52), Vector3(-8.0, 0.0, 0.0))
	# The wrist runs from inside the receiver's rear (z 0.14) to the butt (z 0.50); its top is flush with the
	# receiver top and the fore-end overlaps the receiver's front, so there are no gaps between the parts.
	var wrist: MeshInstance3D = _part(root, "Wrist", _capsule(0.021, 0.36), wood, Vector3(0.0, 0.055, 0.32), Vector3(90.0, 0.0, 0.0))
	wrist.scale = Vector3(1.0, 1.0, 1.7)   # capsule axis is local Y -> stretch into a 0.04 x 0.07 section
	var fore: MeshInstance3D = _part(root, "Foreend", _capsule(0.021, 0.38), wood, Vector3(0.0, 0.064, -0.17), Vector3(90.0, 0.0, 0.0))
	fore.scale = Vector3(1.0, 1.0, 1.15)
	# Iron: receiver, barrel, sights.
	_part(root, "Receiver", _box(Vector3(0.04, 0.05, 0.20)), metal, Vector3(0.0, 0.065, 0.10))
	_part(root, "Barrel", _cyl(0.011, 0.62), metal, Vector3(0.0, BARREL_Y, -0.31), Vector3(90.0, 0.0, 0.0))
	_part(root, "Muzzle_Crown", _cyl(0.0135, 0.02), metal, Vector3(0.0, BARREL_Y, -0.62), Vector3(90.0, 0.0, 0.0))
	_part(root, "FrontSight", _box(Vector3(0.004, 0.012, 0.01)), metal, Vector3(0.0, SIGHT_Y - 0.006, -0.60))
	_part(root, "RearSight", _box(Vector3(0.03, 0.01, 0.02)), metal, Vector3(0.0, SIGHT_Y - 0.005, -0.02))
	# Trigger group.
	var guard: TorusMesh = TorusMesh.new()
	guard.inner_radius = 0.016
	guard.outer_radius = 0.022
	guard.rings = 16
	guard.ring_segments = 8
	_part(root, "TriggerGuard", guard, metal, Vector3(0.0, 0.025, 0.15), Vector3(0.0, 0.0, 90.0))
	_part(root, "Trigger", _box(Vector3(0.006, 0.02, 0.006)), metal, Vector3(0.0, 0.035, 0.15))
	# Floorplate / magazine well: fills the whole gap from the receiver's underside (y 0.0425) down to the plate.
	_part(root, "Floorplate", _box(Vector3(0.03, 0.036, 0.10)), metal, Vector3(0.0, 0.028, 0.05))
	# Bolt handle (animated): pivots about the bolt axis at the receiver's right side.
	var bolt: Node3D = Node3D.new()
	bolt.name = "Bolt"
	bolt.position = Vector3(0.018, 0.075, 0.06)
	root.add_child(bolt)
	_part(bolt, "Stem", _cyl(0.006, 0.07, 10), metal, Vector3(0.035, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
	_part(bolt, "Knob", _sphere(0.012), metal, Vector3(0.075, 0.0, 0.0))
	# Sling swivels and a slack leather sling.
	var swivel: TorusMesh = TorusMesh.new()
	swivel.inner_radius = 0.006
	swivel.outer_radius = 0.01
	swivel.rings = 12
	swivel.ring_segments = 6
	var front_sw: Vector3 = Vector3(0.0, 0.034, -0.32)
	var rear_sw: Vector3 = Vector3(0.0, -0.035, 0.56)
	_part(root, "SwivelFront", swivel, metal, front_sw, Vector3(0.0, 90.0, 0.0))
	_part(root, "SwivelRear", swivel, metal, rear_sw, Vector3(0.0, 90.0, 0.0))
	var segs: int = 8
	var prev: Vector3 = front_sw
	for i: int in range(1, segs + 1):
		var f: float = float(i) / segs
		var p: Vector3 = front_sw.lerp(rear_sw, f)
		p.y -= 0.17 * sin(PI * f)     # slack droop
		p.x = -0.012 * sin(PI * f)
		var d: Vector3 = p - prev
		var seg: MeshInstance3D = _part(root, "Sling%d" % i, _box(Vector3(0.025, 0.004, d.length() + 0.004)), leather, (prev + p) * 0.5)
		seg.basis = Basis.looking_at(d.normalized(), Vector3.UP)
		prev = p
	var muzzle: Marker3D = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, BARREL_Y, -0.64)
	root.add_child(muzzle)
	return root


## Left arm gripping the rifle fore-end (rifle-local).
static func rifle_left_arm() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "LeftArm"
	var glove: StandardMaterial3D = glove_material()
	var sleeve: StandardMaterial3D = sleeve_material()
	# Glove wrapped round the fore-end: palm underneath, fingers curling up its left side, thumb on top.
	_part(root, "Palm", _box(Vector3(0.062, 0.03, 0.09)), glove, Vector3(0.0, 0.045, -0.25))
	_part(root, "FingersSide", _box(Vector3(0.016, 0.06, 0.085)), glove, Vector3(-0.034, 0.058, -0.25))
	_part(root, "FingerTips", _box(Vector3(0.04, 0.02, 0.09)), glove, Vector3(-0.018, 0.092, -0.25))
	_part(root, "Thumb", _box(Vector3(0.014, 0.014, 0.075)), glove, Vector3(0.03, 0.09, -0.235), Vector3(0.0, -8.0, 0.0))
	_part(root, "Cuff", _cyl(0.046, 0.05, 14), glove, Vector3(-0.012, 0.02, -0.2), Vector3(80.0, 20.0, 0.0))
	# Forearm: comes up from the lower left of the screen toward the glove (mostly sideways and down, only
	# slightly back), so it reads as an arm reaching in, not a vertical pillar.
	_limb(root, "Sleeve", 0.032, Vector3(-0.02, 0.02, -0.2), Vector3(-0.30, -0.20, 0.02), sleeve)
	return root


## Right hand around the rifle wrist, with its sleeve running down and out of frame.
static func rifle_right_hand() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "RightHand"
	var glove: StandardMaterial3D = glove_material()
	var sleeve: StandardMaterial3D = sleeve_material()
	_part(root, "Grip", _box(Vector3(0.058, 0.07, 0.07)), glove, Vector3(0.0, 0.025, 0.30))
	_part(root, "Knuckles", _box(Vector3(0.062, 0.02, 0.06)), glove, Vector3(0.0, 0.065, 0.30))
	_part(root, "Thumb", _box(Vector3(0.012, 0.012, 0.06)), glove, Vector3(-0.03, 0.062, 0.27))
	_part(root, "Finger", _box(Vector3(0.008, 0.012, 0.03)), glove, Vector3(0.0, 0.04, 0.16))
	_limb(root, "Sleeve", 0.042, Vector3(0.01, 0.0, 0.33), Vector3(0.12, -0.2, 0.55), sleeve)
	return root


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
	_part(root, "Hand", _box(Vector3(0.05, 0.06, 0.06)), glove, Vector3(0.0, -0.065, 0.10))
	_part(root, "Thumb", _box(Vector3(0.012, 0.012, 0.05)), glove, Vector3(-0.028, -0.02, 0.07))
	_limb(root, "Sleeve", 0.042, Vector3(0.0, -0.075, 0.12), Vector3(0.1, -0.28, 0.34), sleeve)
	return root


static func _dark() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.01, 0.01, 0.01)
	m.roughness = 0.9
	return m
