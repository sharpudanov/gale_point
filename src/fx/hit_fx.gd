class_name HitFx
extends RefCounted
## One-shot particle bursts for enemy hits (SPEC 4.8). None of them contains a light node, so they
## never count as gameplay light; the spark is unshaded and brief ("muzzle-flash family", SPEC 5.1).

static var _soft_tex: GradientTexture2D


static func _soft() -> GradientTexture2D:
	if _soft_tex != null:
		return _soft_tex
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.5, Color(1, 1, 1, 0.6))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	_soft_tex = GradientTexture2D.new()
	_soft_tex.gradient = g
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex.width = 64
	_soft_tex.height = 64
	return _soft_tex


## Dark water / cloth splash thrown away from the shooter: 40 particles, 0.7 s, 2-5 m/s, 60 deg cone.
static func lethal_splash(parent: Node, pos: Vector3, away: Vector3) -> void:
	_burst(parent, pos, away, 40, 0.7, Vector2(2.0, 5.0), 30.0, Vector3(0.0, -9.81, 0.0),
		Color(0.06, 0.07, 0.08), Color(0.30, 0.33, 0.36), 0.14, true, 0.0)


## Brief warm spark at the impact point: 8 particles, 0.12 s, emissive energy 4, no light node.
static func lethal_spark(parent: Node, pos: Vector3, away: Vector3) -> void:
	_burst(parent, pos, away, 8, 0.12, Vector2(1.5, 4.0), 60.0, Vector3.ZERO,
		Color(1.0, 0.66, 0.35), Color(1.0, 0.66, 0.35), 0.06, false, 4.0)


## The kill: a body full of light comes apart. A fountain of embers thrown up and away (70 particles,
## 1.3 s, falling) plus a cold ash puff. Emissive particles only, no light node: never a gameplay light.
static func kill_burst(parent: Node, pos: Vector3, away: Vector3) -> void:
	_burst(parent, pos, (away + Vector3.UP * 1.4).normalized(), 70, 1.3, Vector2(2.5, 7.0), 55.0, Vector3(0.0, -6.0, 0.0),
		Color(1.0, 0.72, 0.4), Color(1.0, 0.45, 0.16), 0.09, false, 5.0)
	_burst(parent, pos, Vector3.UP, 26, 1.1, Vector2(0.6, 2.0), 70.0, Vector3(0.0, 0.5, 0.0),
		Color(0.30, 0.32, 0.35), Color(0.50, 0.53, 0.57), 0.4, true, 0.0)


## Grey mist puff when a dark (harmless) hit lands: 20 particles.
static func dark_mist(parent: Node, pos: Vector3, away: Vector3) -> void:
	_burst(parent, pos, away, 20, 0.9, Vector2(0.4, 1.4), 50.0, Vector3(0.0, 0.3, 0.0),
		Color(0.40, 0.42, 0.45), Color(0.55, 0.58, 0.62), 0.32, true, 0.0)


## Splash of sea water when a Drowned rises out of the waves.
static func emerge_splash(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, Vector3.UP, 36, 1.1, Vector2(2.0, 4.5), 40.0, Vector3(0.0, -9.81, 0.0),
		Color(0.45, 0.50, 0.55), Color(0.75, 0.78, 0.80), 0.22, true, 0.0)


static func _burst(parent: Node, pos: Vector3, dir: Vector3, amount: int, life: float, speed: Vector2,
		spread_deg: float, gravity: Vector3, col_a: Color, col_b: Color, size: float, shaded: bool,
		emission: float) -> void:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = dir.normalized() if dir.length() > 0.001 else Vector3.UP
	pm.spread = spread_deg
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = gravity
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	grad.colors = PackedColorArray([Color(col_a, 1.0), Color(col_b, 0.8), Color(col_b, 0.0)])
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft()
	mat.roughness = 1.0
	if not shaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = col_a
		mat.emission_energy_multiplier = emission
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	p.draw_pass_1 = quad
	parent.add_child(p)
	p.global_position = pos
	p.restart()
	p.emitting = true
	var tree: SceneTree = parent.get_tree()
	if tree != null:
		tree.create_timer(life + 0.5).timeout.connect(p.queue_free)
