class_name DrownedBuilder
extends RefCounted
## Builds the Drowned's body in code (SPEC 4.8 "Build"): a gaunt, stooped figure under a hooded cloak.
## The cloak is a swept ring mesh (oval rings with a hood, a neck, shoulders, a forward stoop, pleats and a
## hem that trails behind), the sleeves are bent tapered tubes with hanging cuffs, the hands have fingers and
## the face is a pale death mask with open eye sockets and a slack mouth, set deep inside the hood.
## Model space: feet at y = 0, hood tip at 2.1 m, forward = -Z. No emission anywhere.

const CLOTH_SHADER: String = "res://shaders/drowned_cloth.gdshader"
const FABRIC_NORMAL: String = "res://assets/textures/hessian_230/hessian_230_nor_gl_1k.jpg"
const FABRIC_ROUGH: String = "res://assets/textures/hessian_230/hessian_230_rough_1k.jpg"

const HEIGHT: float = 2.1
const SEGMENTS: int = 40
const RING_SUBDIV: int = 2   ## rings generated per PROFILE interval (cubic interpolation)
## Control rings, hood tip -> hem: (y, half-width along x, half-depth along z, centre z). A negative centre
## leans forward (the stooped head), a positive one trails behind (the hem).
const PROFILE: Array[Vector4] = [
	Vector4(2.12, 0.015, 0.02, 0.17), Vector4(2.07, 0.06, 0.08, 0.11), Vector4(2.00, 0.12, 0.15, 0.04),
	Vector4(1.93, 0.17, 0.21, -0.02), Vector4(1.85, 0.205, 0.245, -0.06), Vector4(1.77, 0.215, 0.24, -0.06),
	Vector4(1.70, 0.22, 0.22, -0.05), Vector4(1.64, 0.25, 0.21, -0.03), Vector4(1.58, 0.30, 0.20, -0.01),
	Vector4(1.50, 0.33, 0.21, 0.0), Vector4(1.38, 0.32, 0.22, 0.01), Vector4(1.22, 0.29, 0.22, 0.02),
	Vector4(1.02, 0.27, 0.23, 0.03), Vector4(0.82, 0.29, 0.26, 0.04), Vector4(0.62, 0.34, 0.31, 0.05),
	Vector4(0.42, 0.41, 0.38, 0.07), Vector4(0.22, 0.47, 0.45, 0.09), Vector4(0.06, 0.53, 0.52, 0.11),
	Vector4(-0.10, 0.58, 0.58, 0.13),
]
const PLEAT_DEPTH: float = 0.07      ## radial fold depth at the hem (fraction of the radius)
const PLEAT_TOP_Y: float = 1.45      ## no folds above this height (the mantle lies flat on the shoulders)
const PLEAT_BOTTOM_Y: float = 0.2    ## full fold depth below this height
const HEM_NOISE: float = 0.2         ## ragged hem: vertical noise amplitude
const HEM_NOISE_TOP_Y: float = 0.5
## Hood opening: an oval cut out of the front of the hood, centred on the face.
const HOOD_OPEN_Y: float = 1.86
const HOOD_OPEN_HALF_HEIGHT: float = 0.15
const HOOD_OPEN_HALF_ANGLE: float = 0.62   ## radians either side of straight ahead

## Arms as quadratic curves [shoulder, elbow (control point), wrist]. The right arm hangs forward (a Lantern
## Captain's hook starts at that hand, see CaptainLantern.hook_from); the left reaches for the player.
const ARM_RIGHT: Array[Vector3] = [Vector3(0.27, 1.52, 0.0), Vector3(0.40, 1.25, -0.18), Vector3(0.42, 1.04, -0.54)]
const ARM_LEFT: Array[Vector3] = [Vector3(-0.27, 1.52, 0.0), Vector3(-0.40, 1.36, -0.26), Vector3(-0.26, 1.30, -0.62)]
const SLEEVE_ROWS: int = 10
const SLEEVE_SIDES: int = 10
const SLEEVE_RADIUS: Vector3 = Vector3(0.075, 0.055, 0.085)   ## at the shoulder, the forearm and the cuff
const SLEEVE_DROOP: float = 0.26     ## how far the underside of the cuff hangs below the wrist (a pointed drape)
const HAND_SCALE: float = 1.15
const FINGER_LENGTHS: Array[float] = [0.085, 0.105, 0.10, 0.08]

## Face: half-width, half-height and depth of the mask; it sits recessed behind the hood brim, bowed forward.
const FACE_SIZE: Vector3 = Vector3(0.078, 0.125, 0.07)
const FACE_POS: Vector3 = Vector3(0.0, 1.875, -0.10)
const FACE_BOW: float = 0.2          ## radians the head is bowed toward the player
const FACE_COLS: int = 18
const FACE_ROWS: int = 26

static var _cloak_mesh: ArrayMesh
static var _sleeve_meshes: Dictionary = {}
static var _hand_meshes: Dictionary = {}
static var _face_mesh_cache: ArrayMesh
static var _cloth: ShaderMaterial
static var _face_mat: StandardMaterial3D
static var _socket_mat: StandardMaterial3D
static var _hand_mat: StandardMaterial3D


## The shared cloth material (wind uniforms are pushed here once for every Drowned).
static func cloth_material() -> ShaderMaterial:
	if _cloth != null:
		return _cloth
	_cloth = ShaderMaterial.new()
	_cloth.shader = load(CLOTH_SHADER) as Shader
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.seed = 11
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	_cloth.set_shader_parameter("tatter_tex", tex)
	if ResourceLoader.exists(FABRIC_NORMAL):
		_cloth.set_shader_parameter("detail_normal", load(FABRIC_NORMAL) as Texture2D)
	if ResourceLoader.exists(FABRIC_ROUGH):
		_cloth.set_shader_parameter("detail_rough", load(FABRIC_ROUGH) as Texture2D)
	return _cloth


static func _std(color: Color, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## All MeshInstance3Ds of a built Drowned that use the cloth shader.
static func cloth_instances(root: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in root.get_children():
		if c is MeshInstance3D and c.has_meta("cloth"):
			out.append(c as MeshInstance3D)
	return out


## Face and eye meshes (tagged "glow"); each Drowned gives them private materials so the warm "searing"
## glow can be driven per enemy.
static func glow_instances(root: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in root.get_children():
		if c is MeshInstance3D and c.has_meta("glow"):
			out.append(c as MeshInstance3D)
	return out


static func build() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "DrownedBody"
	var cloth: ShaderMaterial = cloth_material()

	var cloak: MeshInstance3D = MeshInstance3D.new()
	cloak.name = "Cloak"
	cloak.mesh = _cloak()
	cloak.material_override = cloth
	cloak.set_meta("cloth", true)
	root.add_child(cloak)

	for side: int in [-1, 1]:
		var path: Array[Vector3] = ARM_RIGHT if side > 0 else ARM_LEFT
		var sl: MeshInstance3D = MeshInstance3D.new()
		sl.name = "SleeveL" if side < 0 else "SleeveR"
		sl.mesh = _sleeve(side)
		sl.material_override = cloth
		sl.set_meta("cloth", true)
		root.add_child(sl)
		var hand: MeshInstance3D = MeshInstance3D.new()
		hand.name = "HandL" if side < 0 else "HandR"
		hand.mesh = _hand_mesh(side)
		hand.material_override = _hand()
		var dir: Vector3 = (path[2] - path[1]).normalized()
		hand.basis = Basis.looking_at(dir, Vector3.UP).scaled(Vector3.ONE * HAND_SCALE)
		hand.position = path[2] - dir * 0.03
		root.add_child(hand)

	# Head: everything shares one bowed transform. A black skull behind the mask fills the sockets and the
	# mouth; the mask is pale albedo only, so it shows when (and only when) a light finds it.
	var head: Transform3D = Transform3D(Basis(Vector3.RIGHT, -FACE_BOW), FACE_POS)
	var skull: MeshInstance3D = MeshInstance3D.new()
	skull.name = "Skull"
	var ss: SphereMesh = SphereMesh.new()
	ss.radius = 0.5
	ss.height = 1.0
	ss.radial_segments = 16
	ss.rings = 8
	skull.mesh = ss
	skull.material_override = _socket()
	skull.transform = head * Transform3D(Basis.from_scale(Vector3(0.15, 0.25, 0.14)), Vector3(0.0, 0.0, 0.045))
	root.add_child(skull)
	var face: MeshInstance3D = MeshInstance3D.new()
	face.name = "Face"
	face.mesh = _face_mesh()
	face.material_override = _face()
	face.transform = head
	face.set_meta("glow", "face")
	root.add_child(face)
	for sx: float in [-1.0, 1.0]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		eye.name = "Eye"
		var es: SphereMesh = SphereMesh.new()
		es.radius = 0.014
		es.height = 0.028
		es.radial_segments = 8
		es.rings = 4
		eye.mesh = es
		eye.material_override = _socket()
		eye.transform = head * Transform3D(Basis.IDENTITY, Vector3(sx * 0.031, 0.02, -0.038))
		eye.set_meta("glow", "eye")
		root.add_child(eye)
	return root


static func _face() -> StandardMaterial3D:
	if _face_mat == null:
		_face_mat = _std(Color(0.2, 0.215, 0.21), 0.65)
		_face_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _face_mat


static func _socket() -> StandardMaterial3D:
	if _socket_mat == null:
		_socket_mat = _std(Color(0.012, 0.012, 0.014), 0.95)
	return _socket_mat


static func _hand() -> StandardMaterial3D:
	if _hand_mat == null:
		_hand_mat = _std(Color(0.24, 0.255, 0.25), 0.6)
	return _hand_mat


static func _commit(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array,
		idx: PackedInt32Array) -> ArrayMesh:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# --- cloak -------------------------------------------------------------------------------------

## PROFILE resampled with cubic interpolation: RING_SUBDIV rings per control interval.
static func _rings() -> Array[Vector4]:
	var out: Array[Vector4] = []
	var last: int = PROFILE.size() - 1
	for i: int in last:
		var a: Vector4 = PROFILE[i]
		var b: Vector4 = PROFILE[i + 1]
		var pre: Vector4 = PROFILE[maxi(i - 1, 0)]
		var post: Vector4 = PROFILE[mini(i + 2, last)]
		for s: int in RING_SUBDIV:
			out.append(a.cubic_interpolate(b, pre, post, float(s) / RING_SUBDIV))
	out.append(PROFILE[last])
	return out


static func _cloak() -> ArrayMesh:
	if _cloak_mesh != null:
		return _cloak_mesh
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.6
	noise.seed = 5
	var rings: Array[Vector4] = _rings()
	var rows: int = rings.size()
	var cols: int = SEGMENTS + 1
	var y_min: float = PROFILE[PROFILE.size() - 1].x
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	verts.resize(rows * cols)
	norms.resize(rows * cols)
	uvs.resize(rows * cols)
	# Angle 0 is the back (+Z), so the UV seam is behind the figure and PI is straight ahead.
	for ri: int in rows:
		var ring: Vector4 = rings[ri]
		var fold: float = PLEAT_DEPTH * (1.0 - smoothstep(PLEAT_BOTTOM_Y, PLEAT_TOP_Y, ring.x))
		var ragged: float = HEM_NOISE * (1.0 - smoothstep(0.0, HEM_NOISE_TOP_Y, ring.x))
		for si: int in cols:
			var a: float = TAU * float(si % SEGMENTS) / SEGMENTS
			var ca: float = cos(a)
			var sa: float = sin(a)
			var m: float = 1.0 + fold * (0.6 * cos(7.0 * a + 1.3) + 0.4 * cos(12.0 * a + 4.0)
				+ 0.5 * noise.get_noise_2d(ca * 2.0 + 7.0, sa * 2.0 + ring.x))
			var y: float = ring.x + ragged * noise.get_noise_2d(ca * 1.2, sa * 1.2) * 1.8
			verts[ri * cols + si] = Vector3(maxf(ring.y, 0.01) * m * sa, y, ring.w + maxf(ring.z, 0.01) * m * ca)
			uvs[ri * cols + si] = Vector2(float(si) / SEGMENTS, clampf((ring.x - y_min) / (HEIGHT - y_min), 0.0, 1.0))
	for ri: int in rows:
		for si: int in cols:
			var s: int = si % SEGMENTS
			var du: Vector3 = verts[ri * cols + (s + 1) % SEGMENTS] - verts[ri * cols + (s + SEGMENTS - 1) % SEGMENTS]
			var dv: Vector3 = verts[mini(ri + 1, rows - 1) * cols + s] - verts[maxi(ri - 1, 0) * cols + s]
			var n: Vector3 = dv.cross(du).normalized()
			var a: float = TAU * float(s) / SEGMENTS
			if n.dot(Vector3(sin(a), 0.2, cos(a))) < 0.0:
				n = -n
			norms[ri * cols + si] = n
	var idx: PackedInt32Array = PackedInt32Array()
	for ri: int in rows - 1:
		var yc: float = (rings[ri].x + rings[ri + 1].x) * 0.5
		for si: int in SEGMENTS:
			# Hood opening: leave an oval out of the front so the face shows in the dark of the hood.
			var front: float = absf(TAU * (float(si) + 0.5) / SEGMENTS - PI) / HOOD_OPEN_HALF_ANGLE
			var rise: float = (yc - HOOD_OPEN_Y) / HOOD_OPEN_HALF_HEIGHT
			if front * front + rise * rise < 1.0:
				continue
			var i0: int = ri * cols + si
			var i1: int = i0 + 1
			var i2: int = i0 + cols
			var i3: int = i2 + 1
			idx.append_array(PackedInt32Array([i0, i1, i2, i1, i3, i2]))
	_cloak_mesh = _commit(verts, norms, uvs, idx)
	# Generous bounds: the vertex shader moves the hem and the instances are far-culled otherwise.
	_cloak_mesh.custom_aabb = AABB(Vector3(-1.0, -0.5, -1.0), Vector3(2.0, 2.9, 2.0))
	return _cloak_mesh


# --- sleeves and hands -------------------------------------------------------------------------

## A bent tube that tapers to the forearm and flares into a cuff whose underside hangs down.
## UV.y runs from 1 at the shoulder to about 0.2 at the tip of the cuff, so only the cuff flutters and frays.
static func _sleeve(side: int) -> ArrayMesh:
	if _sleeve_meshes.has(side):
		return _sleeve_meshes[side] as ArrayMesh
	var path: Array[Vector3] = ARM_RIGHT if side > 0 else ARM_LEFT
	var cols: int = SLEEVE_SIDES + 1
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for i: int in SLEEVE_ROWS:
		var f: float = float(i) / (SLEEVE_ROWS - 1)
		var c: Vector3 = path[0] * (1.0 - f) * (1.0 - f) + path[1] * 2.0 * (1.0 - f) * f + path[2] * f * f
		var along: Vector3 = ((path[1] - path[0]) * (1.0 - f) + (path[2] - path[1]) * f).normalized()
		var across: Vector3 = along.cross(Vector3.UP).normalized()
		var up: Vector3 = across.cross(along).normalized()
		var radius: float = lerpf(SLEEVE_RADIUS.x, SLEEVE_RADIUS.y, smoothstep(0.0, 0.6, f)) \
			+ (SLEEVE_RADIUS.z - SLEEVE_RADIUS.y) * smoothstep(0.6, 1.0, f)
		var cuff: float = smoothstep(0.5, 1.0, f)
		for j: int in cols:
			var ang: float = TAU * float(j % SLEEVE_SIDES) / SLEEVE_SIDES
			var out: Vector3 = across * cos(ang) + up * sin(ang) * 0.85
			var under: float = maxf(-sin(ang), 0.0)
			var hang: float = cuff * under * under
			verts.append(c + out * radius + Vector3.DOWN * SLEEVE_DROOP * hang)
			norms.append(out.normalized())
			uvs.append(Vector2(float(j) / SLEEVE_SIDES, lerpf(1.0, 0.5, f) - 0.3 * hang))
	var idx: PackedInt32Array = PackedInt32Array()
	for i: int in SLEEVE_ROWS - 1:
		for j: int in SLEEVE_SIDES:
			var i0: int = i * cols + j
			var i1: int = i0 + 1
			var i2: int = i0 + cols
			var i3: int = i2 + 1
			idx.append_array(PackedInt32Array([i0, i1, i2, i1, i3, i2]))
	var m: ArrayMesh = _commit(verts, norms, uvs, idx)
	m.custom_aabb = AABB(Vector3(-1.0, -0.5, -1.3), Vector3(2.0, 2.9, 1.6))
	_sleeve_meshes[side] = m
	return m


## A gaunt hand: a flat palm, four splayed, drooping fingers and a thumb on the inner side.
## Local space: the wrist at the origin, fingers toward -Z, palm down.
static func _hand_mesh(side: int) -> ArrayMesh:
	if _hand_meshes.has(side):
		return _hand_meshes[side] as ArrayMesh
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var palm: SphereMesh = SphereMesh.new()
	palm.radius = 0.5
	palm.height = 1.0
	palm.radial_segments = 10
	palm.rings = 5
	st.append_from(palm, 0, Transform3D(Basis.from_scale(Vector3(0.07, 0.022, 0.09)), Vector3(0.0, 0.0, -0.045)))
	for i: int in FINGER_LENGTHS.size():
		var k: float = float(i) / (FINGER_LENGTHS.size() - 1)
		var spread: Basis = Basis(Vector3.UP, lerpf(0.28, -0.28, k))
		var knuckle: Vector3 = Vector3(lerpf(-0.026, 0.026, k), 0.0, -0.08)
		_add_finger(st, knuckle, spread, FINGER_LENGTHS[i], 0.3 + 0.12 * absf(k - 0.5))
	# Thumb: toward the body's centre line (the inner side of each hand).
	_add_finger(st, Vector3(-0.03 * side, 0.0, -0.03), Basis(Vector3.UP, 0.9 * side), 0.06, 0.25)
	var m: ArrayMesh = st.commit()
	_hand_meshes[side] = m
	return m


## One finger: a thin capsule from `knuckle`, pointing along -Z turned by `spread` and curled down by `curl`.
static func _add_finger(st: SurfaceTool, knuckle: Vector3, spread: Basis, length: float, curl: float) -> void:
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.008
	cap.height = length
	cap.radial_segments = 6
	cap.rings = 2
	# The capsule's axis is +Y: turning it by -(90 deg + curl) about X points it forward and down.
	var b: Basis = spread * Basis(Vector3.RIGHT, -(PI * 0.5 + curl))
	st.append_from(cap, 0, Transform3D(b, knuckle + b * Vector3(0.0, length * 0.5, 0.0)))


# --- face --------------------------------------------------------------------------------------

static func _bump(x: float, width: float) -> float:
	return exp(-(x * x) / (width * width))


## A point of the mask for u (across) and v (up) in -1..1. Local space: +Y up, the face looks along -Z.
static func _face_point(u: float, v: float) -> Vector3:
	var jaw: float = smoothstep(-1.0, -0.15, v)   # 0 at the chin, 1 from the cheekbones up
	var half_w: float = FACE_SIZE.x * lerpf(0.55, 1.0, jaw) * (1.0 - 0.15 * smoothstep(0.55, 1.0, v))
	var d: float = FACE_SIZE.z * sqrt(maxf(1.0 - u * u * 0.92, 0.0)) * (1.0 - 0.3 * v * v)
	d += 0.010 * _bump(v - 0.42, 0.10) * (1.0 - 0.5 * u * u)                    # brow ridge
	d += 0.014 * _bump(u, 0.13) * _bump(v - 0.05, 0.2)                          # nose
	d += 0.007 * _bump(absf(u) - 0.62, 0.2) * _bump(v + 0.08, 0.14)             # cheekbones
	d -= 0.016 * _bump(absf(u) - 0.42, 0.24) * _bump(v - 0.16, 0.16)            # the sockets sink in
	d -= 0.010 * _bump(absf(u) - 0.5, 0.25) * _bump(v + 0.42, 0.2)              # hollow cheeks
	return Vector3(u * half_w, v * FACE_SIZE.y, -d)


## True inside the eye sockets and the slack mouth: those quads are left out, the black skull shows through.
static func _face_hole(u: float, v: float) -> bool:
	var ex: float = (absf(u) - 0.42) / 0.25
	var ey: float = (v - 0.16) / 0.15
	var mx: float = u / 0.40
	var my: float = (v + 0.60) / 0.10
	return ex * ex + ey * ey < 1.0 or mx * mx + my * my < 1.0


static func _face_mesh() -> ArrayMesh:
	if _face_mesh_cache != null:
		return _face_mesh_cache
	var cols: int = FACE_COLS + 1
	var rows: int = FACE_ROWS + 1
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for vi: int in rows:
		for ui: int in cols:
			var u: float = lerpf(-1.0, 1.0, float(ui) / FACE_COLS)
			var v: float = lerpf(1.0, -1.0, float(vi) / FACE_ROWS)
			verts.append(_face_point(u, v))
			uvs.append(Vector2(float(ui) / FACE_COLS, float(vi) / FACE_ROWS))
	for vi: int in rows:
		for ui: int in cols:
			var du: Vector3 = verts[vi * cols + mini(ui + 1, cols - 1)] - verts[vi * cols + maxi(ui - 1, 0)]
			var dv: Vector3 = verts[mini(vi + 1, rows - 1) * cols + ui] - verts[maxi(vi - 1, 0) * cols + ui]
			var n: Vector3 = du.cross(dv).normalized()
			norms.append(-n if n.z > 0.0 else n)
	var idx: PackedInt32Array = PackedInt32Array()
	for vi: int in FACE_ROWS:
		for ui: int in FACE_COLS:
			var uc: float = lerpf(-1.0, 1.0, (float(ui) + 0.5) / FACE_COLS)
			var vc: float = lerpf(1.0, -1.0, (float(vi) + 0.5) / FACE_ROWS)
			if _face_hole(uc, vc):
				continue
			var i0: int = vi * cols + ui
			var i1: int = i0 + 1
			var i2: int = i0 + cols
			var i3: int = i2 + 1
			idx.append_array(PackedInt32Array([i0, i1, i2, i1, i3, i2]))
	_face_mesh_cache = _commit(verts, norms, uvs, idx)
	return _face_mesh_cache
