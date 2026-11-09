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
## No rifle geometry may sit behind this local z (camera near plane at full ADS + kick + bob, see WeaponHolder).
const REAR_LIMIT: float = 0.16


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


## Returns the rifle root. Named children the Rifle script animates: "Bolt" (handle group) and
## "Muzzle" (Marker3D at the barrel tip).
static func rifle() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "RifleModel"
	var wood: StandardMaterial3D = wood_material()
	var metal: StandardMaterial3D = metal_material()
	var leather: StandardMaterial3D = leather_material()

	# Everything behind local z = REAR_LIMIT is forbidden: at full ADS + kick_back + walk bob the camera near
	# plane sits around z 0.2, so the stock is a short block and the wrist ends before the limit.
	# Wood: butt, wrist, fore-end.
	_part(root, "Butt", _box(Vector3(0.045, 0.11, 0.06)), wood, Vector3(0.0, 0.03, 0.115), Vector3(-8.0, 0.0, 0.0))
	var wrist: MeshInstance3D = _part(root, "Wrist", _capsule(0.021, 0.21), wood, Vector3(0.0, 0.055, 0.05), Vector3(90.0, 0.0, 0.0))
	wrist.scale = Vector3(1.0, 1.0, 1.7)   # capsule axis is local Y -> stretch into a 0.04 x 0.07 section
	var fore: MeshInstance3D = _part(root, "Foreend", _capsule(0.021, 0.38), wood, Vector3(0.0, 0.064, -0.17), Vector3(90.0, 0.0, 0.0))
	fore.scale = Vector3(1.0, 1.0, 1.15)
	# Iron: round bolt-action receiver (a single cylinder along Z), barrel, sights.
	_part(root, "Receiver", _cyl(0.022, 0.16, 24), metal, Vector3(0.0, 0.064, 0.08), Vector3(90.0, 0.0, 0.0))
	_part(root, "Barrel", _cyl(0.011, 0.62), metal, Vector3(0.0, BARREL_Y, -0.31), Vector3(90.0, 0.0, 0.0))
	_part(root, "Muzzle_Crown", _cyl(0.0135, 0.02), metal, Vector3(0.0, BARREL_Y, -0.62), Vector3(90.0, 0.0, 0.0))
	_part(root, "FrontSight", _box(Vector3(0.004, 0.012, 0.01)), metal, Vector3(0.0, SIGHT_Y - 0.006, -0.60))
	# Thin protective hood ring round the front blade (torus axis rotated onto Z).
	var hood: TorusMesh = TorusMesh.new()
	hood.inner_radius = 0.011
	hood.outer_radius = 0.0133
	hood.rings = 20
	hood.ring_segments = 6
	_part(root, "FrontHood", hood, metal, Vector3(0.0, SIGHT_Y - 0.006, -0.60), Vector3(90.0, 0.0, 0.0))
	# Rear sight: a base plate with two posts and an open U-notch at x = 0, lined up with the front blade.
	_part(root, "RearBase", _box(Vector3(0.03, 0.006, 0.02)), metal, Vector3(0.0, SIGHT_Y - 0.014, -0.02))
	_part(root, "RearPostL", _box(Vector3(0.008, 0.02, 0.014)), metal, Vector3(-0.0095, SIGHT_Y + 0.001, -0.02))
	_part(root, "RearPostR", _box(Vector3(0.008, 0.02, 0.014)), metal, Vector3(0.0095, SIGHT_Y + 0.001, -0.02))
	# Trigger group.
	var guard: TorusMesh = TorusMesh.new()
	guard.inner_radius = 0.016
	guard.outer_radius = 0.022
	guard.rings = 16
	guard.ring_segments = 8
	_part(root, "TriggerGuard", guard, metal, Vector3(0.0, 0.025, 0.11), Vector3(0.0, 0.0, 90.0))
	_part(root, "Trigger", _box(Vector3(0.006, 0.02, 0.006)), metal, Vector3(0.0, 0.035, 0.11))
	# Floorplate / magazine well: fills the whole gap from the receiver's underside down to the plate.
	_part(root, "Floorplate", _box(Vector3(0.03, 0.036, 0.08)), metal, Vector3(0.0, 0.028, 0.04))
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
	var front_sw: Vector3 = Vector3(0.0, 0.04, -0.32)
	var rear_sw: Vector3 = Vector3(0.0, 0.03, 0.14)
	_part(root, "SwivelFront", swivel, metal, front_sw, Vector3(0.0, 90.0, 0.0))
	_part(root, "SwivelRear", swivel, metal, rear_sw, Vector3(0.0, 90.0, 0.0))
	var segs: int = 8
	var prev: Vector3 = front_sw
	for i: int in range(1, segs + 1):
		var f: float = float(i) / segs
		var p: Vector3 = front_sw.lerp(rear_sw, f)
		p.y -= 0.05 * sin(PI * f)     # slack droop (hugs the stock)
		p.x = 0.0
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
	# Rounded glove wrapped round the front of the fore-end (z -0.34): palm underneath, three finger capsules
	# curling up its left side and over the top, thumb along the right of the top.
	_limb(root, "Palm", 0.02, Vector3(-0.026, 0.034, -0.34), Vector3(0.026, 0.034, -0.34), glove)
	for i: int in range(3):
		var z: float = -0.31 - 0.03 * i
		_limb(root, "Finger%d" % i, 0.0095, Vector3(-0.031, 0.036, z), Vector3(-0.034, 0.066, z), glove)
		_limb(root, "FingerTip%d" % i, 0.0085, Vector3(-0.032, 0.07, z), Vector3(-0.014, 0.086, z), glove)
	_limb(root, "Thumb", 0.009, Vector3(0.022, 0.082, -0.31), Vector3(0.018, 0.084, -0.37), glove)
	# Forearm: leaves the wrist low and to the left, dropping out of the bottom-left of the frame.
	_limb(root, "Sleeve", 0.03, Vector3(-0.035, 0.0, -0.30), Vector3(-0.10, -0.40, -0.30), sleeve)
	return root


## Right hand around the rifle wrist, with its sleeve running down and out of frame.
static func rifle_right_hand() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "RightHand"
	var glove: StandardMaterial3D = glove_material()
	var sleeve: StandardMaterial3D = sleeve_material()
	_limb(root, "Grip", 0.025, Vector3(0.0, 0.01, 0.115), Vector3(0.0, 0.04, 0.115), glove)
	_limb(root, "Knuckles", 0.011, Vector3(-0.018, 0.062, 0.12), Vector3(0.018, 0.062, 0.12), glove)
	_limb(root, "Thumb", 0.008, Vector3(-0.03, 0.056, 0.10), Vector3(-0.026, 0.062, 0.125), glove)
	_limb(root, "Finger", 0.006, Vector3(0.0, 0.042, 0.075), Vector3(0.0, 0.042, 0.095), glove)
	_limb(root, "Sleeve", 0.035, Vector3(0.02, -0.03, 0.115), Vector3(0.10, -0.30, 0.13), sleeve)
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
