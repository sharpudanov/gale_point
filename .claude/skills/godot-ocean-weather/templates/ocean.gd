class_name Ocean
extends MeshInstance3D
## Gerstner ocean (template from .claude/skills/godot-ocean-weather). displacement() is a
## line-for-line port of gerstner() in res://shaders/ocean.gdshader; time and wave params are pushed to the shader from here every frame.

const G: float = 9.81
const SHADER_PATH: String = "res://shaders/ocean.gdshader"

@export var size_m: float = 240.0
@export var subdivisions: int = 240
## Each wave: x,y = direction, z = steepness (keep the sum < 1.0), w = wavelength in metres.
@export var waves: PackedVector4Array = PackedVector4Array([
	Vector4(1.0, 0.25, 0.22, 34.0),
	Vector4(0.7, 0.8, 0.16, 19.0),
	Vector4(-0.3, 1.0, 0.12, 11.0),
	Vector4(0.9, -0.5, 0.08, 6.5),
])
@export var time_scale: float = 1.0

var wave_time: float = 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(size_m, size_m)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	mesh = plane
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH) as Shader
	material_override = _mat
	_push_uniforms()


func _process(delta: float) -> void:
	wave_time += delta * time_scale
	_push_uniforms()


func _push_uniforms() -> void:
	_mat.set_shader_parameter("wave_time", wave_time)
	_mat.set_shader_parameter("waves", waves)


## Displacement of the surface point that rests at world (x, z) when flat. Mirrors the shader.
func displacement(p: Vector2, t: float) -> Vector3:
	var out: Vector3 = Vector3.ZERO
	for w: Vector4 in waves:
		var k: float = TAU / w.w
		var c: float = sqrt(G / k)
		var d: Vector2 = Vector2(w.x, w.y).normalized()
		var f: float = k * (d.dot(p) - c * t)
		var a: float = w.z / k
		out += Vector3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f))
	return out


## Water height at world (x, z). Gerstner moves points sideways, so invert the horizontal
## offset by fixed-point iteration. Measured worst xz error with the default waves (steepness
## sum 0.58): 2 it = 11 cm, 4 it = 1.3 cm, 6 it = 1.5 mm. Error shrinks ~3x per iteration.
func get_height(world_x: float, world_z: float, iterations: int = 4) -> float:
	var target: Vector2 = Vector2(world_x, world_z)  # shader samples waves in WORLD xz
	var p: Vector2 = target
	for i: int in iterations:
		var d: Vector3 = displacement(p, wave_time)
		p = target - Vector2(d.x, d.z)
	return global_position.y + displacement(p, wave_time).y


## Horizontal error of get_height's inversion, for tests (metres).
func inversion_error(world_x: float, world_z: float, iterations: int = 4) -> float:
	var target: Vector2 = Vector2(world_x, world_z)
	var p: Vector2 = target
	for i: int in iterations:
		var d: Vector3 = displacement(p, wave_time)
		p = target - Vector2(d.x, d.z)
	var d2: Vector3 = displacement(p, wave_time)
	return (p + Vector2(d2.x, d2.z)).distance_to(target)
