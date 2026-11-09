class_name FireFx
extends RefCounted
## Particle builders for player-made fire (braziers, oil pools, burning Drowned, bursts). Flames are additive,
## unshaded and warm (flare family, SPEC 13); smoke is shaded grey. No light nodes here: owners add their own
## OmniLight3D with shadow_enabled = false.

static var _flame_tex: GradientTexture2D


static func _flame_texture() -> GradientTexture2D:
	if _flame_tex != null:
		return _flame_tex
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.4, Color(1, 1, 1, 0.55))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	_flame_tex = GradientTexture2D.new()
	_flame_tex.gradient = g
	_flame_tex.fill = GradientTexture2D.FILL_RADIAL
	_flame_tex.fill_from = Vector2(0.5, 0.5)
	_flame_tex.fill_to = Vector2(1.0, 0.5)
	_flame_tex.width = 64
	_flame_tex.height = 64
	return _flame_tex


static func _ramp(colors: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve(a: float, b: float) -> CurveTexture:
	var c: Curve = Curve.new()
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	var t: CurveTexture = CurveTexture.new()
	t.curve = c
	return t


## Continuous tongues of flame over a disc of `radius`, rising about `height` metres.
static func flames(radius: float, amount: int, height: float, size: float, energy: float = 3.0) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Flames"
	p.amount = amount
	p.lifetime = 0.7
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-radius - 2.0, -1.0, -radius - 2.0), Vector3(radius * 2.0 + 4.0, height + 4.0, radius * 2.0 + 4.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = height * 0.8
	pm.initial_velocity_max = height * 1.6
	pm.gravity = Vector3(0.0, height * 0.6, 0.0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 2.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.scale_curve = _curve(1.0, 0.25)
	pm.color_ramp = _ramp(PackedColorArray([Color(1.0, 0.7, 0.4, 0.0), Color(1.0, 0.55, 0.22, 0.55),
		Color(0.85, 0.28, 0.07, 0.35), Color(0.3, 0.1, 0.04, 0.0)]), PackedFloat32Array([0.0, 0.12, 0.55, 1.0]))
	p.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _flame_texture()
	mat.albedo_color = Color(0.25 * energy / 3.0, 0.25 * energy / 3.0, 0.25 * energy / 3.0, 1.0)   # many quads overlap: keep each faint
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size * 1.4)
	quad.material = mat
	p.draw_pass_1 = quad
	return p


## Dark rising smoke column, drifting with `wind`.
static func smoke(radius: float, amount: int, lifetime: float, wind: Vector3) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 30, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(wind.x * 0.15, 0.1, wind.z * 0.15)
	pm.damping_min = 0.1
	pm.damping_max = 0.3
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	pm.scale_curve = _curve(0.4, 1.4)
	pm.color_ramp = _ramp(PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]),
		PackedFloat32Array([0.0, 0.15, 1.0]))
	p.process_material = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.16, 0.15, 0.15, 0.45)
	mat.albedo_texture = _flame_texture()
	mat.roughness = 1.0
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	quad.material = mat
	p.draw_pass_1 = quad
	return p


## One-shot fireball: flames flung outward in every direction plus hot sparks. Frees itself.
static func burst(parent: Node, pos: Vector3, radius: float) -> void:
	for spec: Dictionary in [
		{"amount": 48, "life": 0.55, "speed": Vector2(radius * 0.8, radius * 1.8), "size": radius * 0.32, "sparks": false},
		{"amount": 70, "life": 0.9, "speed": Vector2(radius * 1.2, radius * 2.6), "size": 0.05, "sparks": true},
	]:
		var p: GPUParticles3D = GPUParticles3D.new()
		p.amount = int(spec["amount"])
		p.lifetime = float(spec["life"])
		p.one_shot = true
		p.explosiveness = 0.95
		p.local_coords = false
		p.emitting = false
		p.visibility_aabb = AABB(Vector3(-radius * 3.0, -4.0, -radius * 3.0), Vector3(radius * 6.0, radius * 4.0 + 6.0, radius * 6.0))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.3
		pm.direction = Vector3.UP
		pm.spread = 180.0 if bool(spec["sparks"]) else 120.0
		var sp: Vector2 = spec["speed"]
		pm.initial_velocity_min = sp.x
		pm.initial_velocity_max = sp.y
		pm.gravity = Vector3(0.0, -9.81, 0.0) if bool(spec["sparks"]) else Vector3(0.0, 2.0, 0.0)
		pm.damping_min = 0.5 if bool(spec["sparks"]) else 6.0
		pm.damping_max = 1.5 if bool(spec["sparks"]) else 9.0
		pm.scale_min = 0.6
		pm.scale_max = 1.3
		if not bool(spec["sparks"]):
			pm.scale_curve = _curve(0.6, 1.6)
		pm.color_ramp = _ramp(PackedColorArray([Color(1.0, 0.8, 0.45, 0.9), Color(1.0, 0.45, 0.1, 0.55),
			Color(0.45, 0.12, 0.03, 0.0)]), PackedFloat32Array([0.0, 0.25, 0.7]))
		p.process_material = pm
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = _flame_texture()
		mat.albedo_color = Color(0.9, 0.9, 0.9, 1.0) if bool(spec["sparks"]) else Color(0.45, 0.45, 0.45, 1.0)
		var quad: QuadMesh = QuadMesh.new()
		var sz: float = float(spec["size"])
		quad.size = Vector2(sz, sz)
		quad.material = mat
		p.draw_pass_1 = quad
		parent.add_child(p)
		p.global_position = pos
		p.restart()
		p.emitting = true
		var tree: SceneTree = parent.get_tree()
		if tree != null:
			tree.create_timer(float(spec["life"]) + 0.5).timeout.connect(p.queue_free)


## Flickering warm OmniLight for a fire. Never casts shadows (performance rule: only beam + flares do).
static func fire_light(energy: float, light_range: float, fog_energy: float) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.name = "FireLight"
	l.light_color = Color(1.0, 0.58, 0.3)
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = fog_energy
	return l
