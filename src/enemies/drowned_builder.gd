class_name DrownedBuilder
extends RefCounted
## Builds the Drowned's body from primitives (SPEC 4.8 "Build"): a lathe cloak with a tattered hem and a
## hood opening, two cloth sleeve strips, a pale recessed face, eye sockets and hands.
## Model space: feet/hem at y = 0, height 2.1 m, forward = -Z. No emission anywhere.

const CLOTH_SHADER: String = "res://shaders/drowned_cloth.gdshader"
const FABRIC_NORMAL: String = "res://assets/textures/hessian_230/hessian_230_nor_gl_1k.jpg"
const FABRIC_ROUGH: String = "res://assets/textures/hessian_230/hessian_230_rough_1k.jpg"

const HEIGHT: float = 2.1
const RINGS: int = 12
const SEGMENTS: int = 24
## Ring profile (y, radius), hood apex -> hem. Radius: hood 0.18 -> shoulders 0.42 -> hem 0.55.
const PROFILE: Array[Vector2] = [
	Vector2(2.08, 0.07), Vector2(2.00, 0.16), Vector2(1.90, 0.19), Vector2(1.80, 0.30),
	Vector2(1.70, 0.36), Vector2(1.50, 0.39), Vector2(1.30, 0.43), Vector2(1.10, 0.47),
	Vector2(0.85, 0.52), Vector2(0.60, 0.56), Vector2(0.30, 0.60), Vector2(0.00, 0.64),
]
const HEM_NOISE: float = 0.2
const SLEEVE_SIZE: Vector2 = Vector2(0.09, 0.9)

static var _cloak_mesh: ArrayMesh
static var _sleeve_meshes: Dictionary = {}
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


## Face and eye-socket meshes (tagged "glow"); each Drowned gives them private materials so the warm
## "searing" glow can be driven per enemy.
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
		var sl: MeshInstance3D = MeshInstance3D.new()
		sl.name = "SleeveL" if side < 0 else "SleeveR"
		sl.mesh = _sleeve(float(side))
		sl.material_override = cloth
		sl.set_meta("cloth", true)
		root.add_child(sl)
		var hand: MeshInstance3D = MeshInstance3D.new()
		hand.name = "HandL" if side < 0 else "HandR"
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.03
		cap.height = 0.18
		cap.radial_segments = 10
		cap.rings = 3
		hand.mesh = cap
		hand.material_override = _hand()
		var s: Array[Vector3] = _sleeve_path(float(side))
		var dir: Vector3 = (s[1] - s[0]).normalized()
		hand.position = s[1] + dir * 0.07
		hand.basis = Basis(Quaternion(Vector3.UP, dir))
		root.add_child(hand)

	# Face: pale albedo only, so it shows when (and only when) a light finds it. Recessed in the hood.
	var face: MeshInstance3D = MeshInstance3D.new()
	face.name = "Face"
	var fs: SphereMesh = SphereMesh.new()
	fs.radius = 0.11
	fs.height = 0.22
	fs.radial_segments = 16
	fs.rings = 8
	face.mesh = fs
	face.scale = Vector3(0.85, 1.35, 0.6)
	face.material_override = _face()
	face.position = Vector3(0.0, 1.91, 0.0)
	face.set_meta("glow", "face")
	root.add_child(face)
	for sx: float in [-0.04, 0.04]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		eye.name = "EyeSocket"
		var es: SphereMesh = SphereMesh.new()
		es.radius = 0.02
		es.height = 0.04
		es.radial_segments = 8
		es.rings = 4
		eye.mesh = es
		eye.material_override = _socket()
		eye.position = Vector3(sx, 1.95, -0.075)
		eye.set_meta("glow", "eye")
		root.add_child(eye)
	return root


static func _face() -> StandardMaterial3D:
	if _face_mat == null:
		_face_mat = _std(Color(0.26, 0.27, 0.27), 0.5)
	return _face_mat


static func _socket() -> StandardMaterial3D:
	if _socket_mat == null:
		_socket_mat = _std(Color(0.02, 0.02, 0.02), 0.9)
	return _socket_mat


static func _hand() -> StandardMaterial3D:
	if _hand_mat == null:
		_hand_mat = _std(Color(0.28, 0.29, 0.28), 0.6)
	return _hand_mat


# --- cloak lathe -----------------------------------------------------------------------------

static func _cloak() -> ArrayMesh:
	if _cloak_mesh != null:
		return _cloak_mesh
	var hem_noise: FastNoiseLite = FastNoiseLite.new()
	hem_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hem_noise.frequency = 1.6
	hem_noise.seed = 5
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for ri: int in RINGS:
		var p: Vector2 = PROFILE[ri]
		var p_prev: Vector2 = PROFILE[maxi(ri - 1, 0)]
		var p_next: Vector2 = PROFILE[mini(ri + 1, RINGS - 1)]
		# (r, y) tangent going down the ring list; the outward normal is that tangent rotated by +90 deg.
		var tangent: Vector2 = Vector2(p_next.y - p_prev.y, p_next.x - p_prev.x).normalized()
		var n_r: float = -tangent.y
		var n_y: float = tangent.x
		for si: int in SEGMENTS + 1:
			var a: float = TAU * float(si) / SEGMENTS
			var y: float = p.x
			if ri >= RINGS - 3:
				var w: float = float(ri - (RINGS - 3) + 1) / 3.0
				y += HEM_NOISE * w * hem_noise.get_noise_2d(cos(a) * 1.2, sin(a) * 1.2) * 1.8
			var r: float = p.y
			verts.append(Vector3(r * sin(a), y, -r * cos(a)))
			norms.append(Vector3(n_r * sin(a), n_y, -n_r * cos(a)).normalized())
			uvs.append(Vector2(float(si) / SEGMENTS, 1.0 - float(ri) / (RINGS - 1)))
	var idx: PackedInt32Array = PackedInt32Array()
	for ri: int in RINGS - 1:
		for si: int in SEGMENTS:
			# Hood opening: skip the front 90 deg between rings 1-3 so the face shows.
			if ri >= 1 and ri <= 2 and (si <= 2 or si >= SEGMENTS - 3):
				continue
			var i0: int = ri * (SEGMENTS + 1) + si
			var i1: int = i0 + 1
			var i2: int = i0 + SEGMENTS + 1
			var i3: int = i2 + 1
			idx.append_array(PackedInt32Array([i0, i1, i2, i1, i3, i2]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	_cloak_mesh = ArrayMesh.new()
	_cloak_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# Generous bounds: the vertex shader moves the hem and the instances are far-culled otherwise.
	_cloak_mesh.custom_aabb = AABB(Vector3(-1.0, -0.4, -1.0), Vector3(2.0, 2.8, 2.0))
	return _cloak_mesh


# --- sleeves -----------------------------------------------------------------------------------

## [shoulder, hand] in model space; the arms reach forward and droop.
static func _sleeve_path(side: float) -> Array[Vector3]:
	return [Vector3(0.44 * side, 1.62, -0.05), Vector3(0.47 * side, 1.02, -0.55)]


static func _sleeve(side: float) -> ArrayMesh:
	if _sleeve_meshes.has(side):
		return _sleeve_meshes[side] as ArrayMesh
	var path: Array[Vector3] = _sleeve_path(side)
	var rows: int = 7
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var dir: Vector3 = (path[1] - path[0]).normalized()
	var across: Vector3 = dir.cross(Vector3.UP).normalized()
	var up: Vector3 = across.cross(dir).normalized()
	for i: int in rows:
		var f: float = float(i) / (rows - 1)
		var c: Vector3 = path[0].lerp(path[1], f)
		c.y -= 0.07 * sin(PI * f)
		for j: int in 2:
			var s: float = -0.5 + float(j)
			verts.append(c + across * SLEEVE_SIZE.x * s * (1.0 + 0.5 * f))
			norms.append(up)
			uvs.append(Vector2(float(j), 1.0 - f))
	var idx: PackedInt32Array = PackedInt32Array()
	for i: int in rows - 1:
		var a: int = i * 2
		idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(-1.0, -0.4, -1.2), Vector3(2.0, 2.8, 1.4))
	_sleeve_meshes[side] = m
	return m
