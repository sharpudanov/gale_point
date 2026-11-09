class_name Ocean
extends MeshInstance3D
## Gerstner ocean (godot-ocean-weather skill template). displacement() is a line-for-line port of
## gerstner() in res://shaders/ocean.gdshader. Time and waves are pushed every physics tick.
## `wave_scale` multiplies every steepness (SPEC §5.2). A flat far "skirt" ring carries the sea
## out to the horizon past the 400 m wave plane.

const G: float = 9.81
const SHADER_PATH: String = "res://shaders/ocean.gdshader"

@export var size_m: float = 400.0
@export var subdivisions: int = 320
@export var skirt_size_m: float = 2400.0
## Each wave: x,y = direction, z = base steepness (sum 0.58), w = wavelength in metres.
@export var waves: PackedVector4Array = PackedVector4Array([
	Vector4(1.0, 0.25, 0.22, 34.0),
	Vector4(0.7, 0.8, 0.16, 19.0),
	Vector4(-0.3, 1.0, 0.12, 11.0),
	Vector4(0.9, -0.5, 0.08, 6.5),
])
@export var wave_scale: float = 0.75
@export var time_scale: float = 1.0
@export var foam_noise_freq: float = 0.015
## Waves flatten between these |x|/|z| distances so the plane edge meets the flat skirt seamlessly.
@export var edge_fade: Vector2 = Vector2(150.0, 196.0)

var wave_time: float = 0.0
var _mat: ShaderMaterial
var _skirt_mat: ShaderMaterial
var _scaled: PackedVector4Array = PackedVector4Array()


func _ready() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(size_m, size_m)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = foam_noise_freq
	noise.seed = GameRng.next_seed()
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise

	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH) as Shader
	_mat.set_shader_parameter("foam_noise", tex)
	_mat.set_shader_parameter("edge_fade", edge_fade)
	material_override = _mat

	_skirt_mat = _mat.duplicate() as ShaderMaterial
	var flat: PackedVector4Array = PackedVector4Array()
	for i: int in 4:
		flat.append(Vector4(1.0, 0.0, 0.0, 10.0))
	_skirt_mat.set_shader_parameter("waves", flat)
	var skirt: MeshInstance3D = MeshInstance3D.new()
	skirt.name = "Skirt"
	skirt.mesh = _build_skirt(size_m * 0.5 - 1.0, skirt_size_m * 0.5)
	skirt.material_override = _skirt_mat
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skirt)
	_push_uniforms()


func _physics_process(delta: float) -> void:
	wave_time += delta * time_scale
	_push_uniforms()


func steepness_sum() -> float:
	var s: float = 0.0
	for w: Vector4 in waves:
		s += w.z * wave_scale
	return s


## Visual parameters pushed by StormDirector.
func set_look(foam_threshold: float, roughness: float, sky_reflect: Color, wind_dir: Vector2) -> void:
	for m: ShaderMaterial in [_mat, _skirt_mat]:
		m.set_shader_parameter("foam_threshold", foam_threshold)
		m.set_shader_parameter("roughness", roughness)
		m.set_shader_parameter("sky_reflect_color", sky_reflect)
		m.set_shader_parameter("foam_scroll", wind_dir * 0.02)


func _push_uniforms() -> void:
	_scaled.resize(waves.size())
	for i: int in waves.size():
		var w: Vector4 = waves[i]
		_scaled[i] = Vector4(w.x, w.y, w.z * wave_scale, w.w)
	_mat.set_shader_parameter("wave_time", wave_time)
	_mat.set_shader_parameter("waves", _scaled)
	_skirt_mat.set_shader_parameter("wave_time", wave_time)


## Displacement of the surface point that rests at world (x, z) when flat. Mirrors the shader.
func displacement(p: Vector2, t: float) -> Vector3:
	var out: Vector3 = Vector3.ZERO
	var edge_k: float = 1.0 - smoothstep(edge_fade.x, edge_fade.y, maxf(absf(p.x), absf(p.y)))
	for w: Vector4 in waves:
		var k: float = TAU / w.w
		var c: float = sqrt(G / k)
		var d: Vector2 = Vector2(w.x, w.y).normalized()
		var f: float = k * (d.dot(p) - c * t)
		var a: float = w.z * wave_scale * edge_k / k
		out += Vector3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f))
	return out


## Water height at world (x, z), inverting the sideways Gerstner shift by fixed-point iteration.
func get_height(world_x: float, world_z: float, iterations: int = 4) -> float:
	var target: Vector2 = Vector2(world_x, world_z)
	var p: Vector2 = target
	for i: int in iterations:
		var d: Vector3 = displacement(p, wave_time)
		p = target - Vector2(d.x, d.z)
	return global_position.y + displacement(p, wave_time).y


## Flat square ring from half-size `inner` to `outer` (a hole where the wave plane sits).
func _build_skirt(inner: float, outer: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var rects: Array[Rect2] = [
		Rect2(-outer, -outer, outer * 2.0, outer - inner),          # north band
		Rect2(-outer, inner, outer * 2.0, outer - inner),           # south band
		Rect2(-outer, -inner, outer - inner, inner * 2.0),          # west
		Rect2(inner, -inner, outer - inner, inner * 2.0),           # east
	]
	for r: Rect2 in rects:
		# Subdivide so per-vertex fog/lighting stays smooth far out.
		var nx: int = maxi(1, int(r.size.x / 100.0))
		var nz: int = maxi(1, int(r.size.y / 100.0))
		for ix: int in nx:
			for iz: int in nz:
				var x0: float = r.position.x + r.size.x * float(ix) / nx
				var x1: float = r.position.x + r.size.x * float(ix + 1) / nx
				var z0: float = r.position.y + r.size.y * float(iz) / nz
				var z1: float = r.position.y + r.size.y * float(iz + 1) / nz
				st.add_vertex(Vector3(x0, 0.0, z0))
				st.add_vertex(Vector3(x1, 0.0, z0))
				st.add_vertex(Vector3(x1, 0.0, z1))
				st.add_vertex(Vector3(x0, 0.0, z0))
				st.add_vertex(Vector3(x1, 0.0, z1))
				st.add_vertex(Vector3(x0, 0.0, z1))
	return st.commit()
