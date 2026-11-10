class_name DrownedWater
extends Node3D
## The sea reacting to a Drowned: a foam collar and a trailing wake where the body cuts the surface while it
## wades in, then sea water streaming off its shoulders for a few seconds after it climbs onto the rock.
## Purely visual; it reads the ocean and island heights and never changes a rule.

@export var wake_min_depth: float = 0.25    ## m of water above the feet before the wake shows
@export var wake_max_depth: float = 2.2     ## deeper than this only the head is out: a small ring, no wake
@export var wake_amount: int = 64
@export var wake_lifetime: float = 1.1
@export var wake_radius: float = 0.42
@export var wake_color: Color = Color(0.78, 0.82, 0.86, 0.75)
@export var stream_time: float = 4.0        ## s of streaming water after leaving the sea
@export var stream_amount: int = 40
@export var stream_height: float = 1.35     ## shoulders, metres above the feet (x size)
@export var wet_depth: float = 0.6          ## had to be at least this deep to come out soaking

var drowned: Drowned
var ocean: Ocean
var island: Island
var depth: float = 0.0       ## water above the feet right now
var wading: bool = false

var _wake: GPUParticles3D
var _stream: GPUParticles3D
var _wet_t: float = 0.0
var _was_deep: bool = false


func _ready() -> void:
	top_level = true   # the emitters sit on the water surface, not on the bobbing body
	_wake = _emitter("Wake", wake_amount, wake_lifetime, wake_radius, Vector3.UP, Vector2(0.4, 1.2),
		Vector3(0.0, -4.0, 0.0), wake_color, Vector2(0.14, 0.32))
	_stream = _emitter("Stream", stream_amount, 0.55, 0.28, Vector3.DOWN, Vector2(0.2, 0.8),
		Vector3(0.0, -9.81, 0.0), Color(0.55, 0.60, 0.66, 0.6), Vector2(0.015, 0.09))


func _process(delta: float) -> void:
	if drowned == null or not is_instance_valid(drowned) or ocean == null or island == null:
		return
	var p: Vector3 = drowned.global_position
	var sea: float = ocean.get_height(p.x, p.z)
	var feet: float = p.y - drowned.hover_height
	depth = sea - feet
	var alive: bool = drowned.state != "dying"
	wading = alive and depth > wake_min_depth
	_wake.global_position = Vector3(p.x, sea + 0.04, p.z)
	_wake.emitting = wading
	_wake.amount_ratio = 0.35 if depth > wake_max_depth else 1.0
	if depth > wet_depth:
		_was_deep = true
	elif _was_deep and depth < 0.1:
		_was_deep = false
		_wet_t = stream_time
	_wet_t = maxf(_wet_t - delta, 0.0)
	_stream.global_position = Vector3(p.x, feet + stream_height * drowned.size_scale, p.z)
	_stream.emitting = alive and _wet_t > 0.0
	_stream.amount_ratio = clampf(_wet_t / stream_time, 0.2, 1.0)


static var _dot: GradientTexture2D


## Soft round particle: white centre fading to clear, so foam reads as spray, not squares.
static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(0.5, 0.0)
		_dot.width = 32
		_dot.height = 32
	return _dot


func _emitter(label: String, amount: int, life: float, radius: float, dir: Vector3, speed: Vector2,
		gravity: Vector3, colour: Color, size: Vector2) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = label
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 6, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = radius * 0.6
	pm.emission_ring_height = 0.02
	pm.direction = dir
	pm.spread = 35.0
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = gravity
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	fade.colors = PackedColorArray([Color(colour, 0.0), colour, Color(colour, 0.0)])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	mat.roughness = 0.35
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	return p
