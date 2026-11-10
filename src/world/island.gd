class_name Island
extends StaticBody3D
## Lighthouse island (SPEC §4.2): plateau + FBM noise + warped coastline down to a seabed.
## One height function feeds the render mesh, the HeightMapShape3D and height_at().

const ROCK_SHADER_PATH: String = "res://shaders/wet_rock.gdshader"
const TEX_DIR: String = "res://assets/textures/dark_rock_02/"

@export var size_m: float = 128.0
@export var grid: int = 129
@export var plateau_height: float = 5.0
@export var plateau_radius: float = 10.0
@export var shore_radius: float = 40.0
@export var seabed_radius: float = 55.0
@export var seabed_depth: float = -3.0
@export var noise_freq: float = 0.045
@export var noise_octaves: int = 4
@export var noise_amp: float = 1.6
@export var noise_fade: Vector2 = Vector2(6.0, 14.0)
@export var coast_warp_amp: float = 6.0
@export var coast_warp_freq: float = 0.9
@export var coast_warp_fade: Vector2 = Vector2(8.0, 20.0)
@export var shore_block_height: float = 0.6
@export var edge_drop: float = -15.0  ## outermost vertex ring sinks so the mesh edge never shows
@export var rock_count: int = 30
@export var rock_radius: Vector2 = Vector2(30.0, 48.0)
@export var rock_scale: Vector2 = Vector2(0.8, 3.5)
@export var rock_albedo_mult: float = 0.45
@export var rock_roughness: float = 0.3
@export var rock_models: PackedStringArray = PackedStringArray([
	"res://assets/models/boulder_01/boulder_01_1k.gltf",
	"res://assets/models/rock_09/rock_09_1k.gltf",
	"res://assets/models/rock_07/rock_07_1k.gltf",
])

var rock_mat: ShaderMaterial
var rocks: Array[Node3D] = []
var _noise: FastNoiseLite
var _warp: FastNoiseLite


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = noise_octaves
	_noise.frequency = noise_freq
	_noise.seed = GameRng.next_seed()
	_warp = FastNoiseLite.new()
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_warp.frequency = 1.0
	_warp.seed = GameRng.next_seed()
	_build_terrain()
	_scatter_rocks()


## Ground height at world (x, z) — the same function the mesh and collision use.
func height_at(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	var a: float = atan2(z, x)
	var warp: float = coast_warp_amp * _warp.get_noise_2d(cos(a) * coast_warp_freq * 2.0, sin(a) * coast_warp_freq * 2.0)
	warp *= smoothstep(coast_warp_fade.x, coast_warp_fade.y, r)
	var rp: float = r + warp
	var h: float = plateau_height * (1.0 - smoothstep(plateau_radius, shore_radius, rp))
	h += seabed_depth * smoothstep(shore_radius - 2.0, seabed_radius, rp)
	h += noise_amp * _noise.get_noise_2d(x, z) * smoothstep(noise_fade.x, noise_fade.y, r)
	return h


## Walkable radius along XZ angle `a` (radians): walking outward from the centre, the last sample before the
## ground first drops below shore_block_height (the player's shore block). Map view and LayoutCheck.
func walkable_radius(a: float, step: float = 0.25) -> float:
	var r: float = 0.0
	while r < seabed_radius:
		var nr: float = r + step
		if height_at(cos(a) * nr, sin(a) * nr) < shore_block_height:
			return r
		r = nr
	return r


## Downhill unit direction (XZ) at a point, for the player's shore block.
func downhill(x: float, z: float) -> Vector2:
	var e: float = 0.25
	var gx: float = height_at(x + e, z) - height_at(x - e, z)
	var gz: float = height_at(x, z + e) - height_at(x, z - e)
	var g: Vector2 = Vector2(-gx, -gz)
	return g.normalized() if g.length() > 0.00001 else Vector2.ZERO


func _build_terrain() -> void:
	var n: int = grid
	var half: float = size_m * 0.5
	var step: float = size_m / float(n - 1)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(n * n)
	for iz: int in n:
		for ix: int in n:
			heights[iz * n + ix] = height_at(-half + ix * step, -half + iz * step)

	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	verts.resize(n * n)
	normals.resize(n * n)
	for iz: int in n:
		for ix: int in n:
			var h: float = heights[iz * n + ix]
			if ix == 0 or iz == 0 or ix == n - 1 or iz == n - 1:
				h = edge_drop
			verts[iz * n + ix] = Vector3(-half + ix * step, h, -half + iz * step)
			var hl: float = heights[iz * n + maxi(ix - 1, 0)]
			var hr: float = heights[iz * n + mini(ix + 1, n - 1)]
			var hd: float = heights[maxi(iz - 1, 0) * n + ix]
			var hu: float = heights[mini(iz + 1, n - 1) * n + ix]
			normals[iz * n + ix] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
	var indices: PackedInt32Array = PackedInt32Array()
	for iz: int in n - 1:
		for ix: int in n - 1:
			var i0: int = iz * n + ix
			var i1: int = i0 + 1
			var i2: int = i0 + n
			var i3: int = i2 + 1
			indices.append_array([i0, i1, i3, i0, i3, i2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	rock_mat = ShaderMaterial.new()
	rock_mat.shader = load(ROCK_SHADER_PATH) as Shader
	rock_mat.set_shader_parameter("albedo_tex", load(TEX_DIR + "dark_rock_02_diff_2k.jpg") as Texture2D)
	rock_mat.set_shader_parameter("normal_tex", load(TEX_DIR + "dark_rock_02_nor_gl_2k.jpg") as Texture2D)
	rock_mat.set_shader_parameter("roughness_tex", load(TEX_DIR + "dark_rock_02_rough_2k.jpg") as Texture2D)
	rock_mat.set_shader_parameter("ao_tex", load(TEX_DIR + "dark_rock_02_ao_2k.jpg") as Texture2D)
	var pn: FastNoiseLite = FastNoiseLite.new()
	pn.frequency = 0.02
	pn.seed = GameRng.next_seed()
	var ptex: NoiseTexture2D = NoiseTexture2D.new()
	ptex.width = 256
	ptex.height = 256
	ptex.seamless = true
	ptex.noise = pn
	rock_mat.set_shader_parameter("puddle_noise", ptex)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = rock_mat
	add_child(mi)

	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, 1.0, step)
	add_child(cs)


func set_wetness(w: float) -> void:
	rock_mat.set_shader_parameter("wetness", w)


func _scatter_rocks() -> void:
	var scenes: Array[PackedScene] = []
	for path: String in rock_models:
		var ps: PackedScene = load(path) as PackedScene
		if ps != null:
			scenes.append(ps)
	if scenes.is_empty():
		return
	var shapes: Dictionary = {}
	for i: int in rock_count:
		var idx: int = GameRng.randi_range(0, scenes.size() - 1)
		var a: float = GameRng.randf_range(0.0, TAU)
		var r: float = GameRng.randf_range(rock_radius.x, rock_radius.y)
		var s: float = lerpf(rock_scale.x, rock_scale.y, pow(GameRng.randf(), 1.6))
		var x: float = cos(a) * r
		var z: float = sin(a) * r
		var rock: Node3D = scenes[idx].instantiate() as Node3D
		rock.name = "Rock%d" % i
		rock.scale = Vector3.ONE * s
		rock.rotation = Vector3(GameRng.randf_range(-0.2, 0.2), GameRng.randf_range(0.0, TAU), GameRng.randf_range(-0.2, 0.2))
		rock.position = Vector3(x, height_at(x, z) - 0.25 * s, z)
		add_child(rock)
		rocks.append(rock)
		for mi: MeshInstance3D in _mesh_instances(rock):
			_wet_materials(mi)
			if not shapes.has(mi.mesh):
				shapes[mi.mesh] = mi.mesh.create_convex_shape()
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = shapes[mi.mesh] as Shape3D
			add_child(cs)
			cs.global_transform = mi.global_transform


func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c: Node in node.get_children():
		out.append_array(_mesh_instances(c))
	return out


## glTF rock materials get darker and glossier (wet) — SPEC §4.2.
func _wet_materials(mi: MeshInstance3D) -> void:
	for si: int in mi.mesh.get_surface_count():
		var src: Material = mi.get_active_material(si)
		if src is StandardMaterial3D:
			var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.albedo_color = Color(m.albedo_color.r * rock_albedo_mult, m.albedo_color.g * rock_albedo_mult, m.albedo_color.b * rock_albedo_mult * 1.05)
			m.roughness = rock_roughness
			mi.set_surface_override_material(si, m)
