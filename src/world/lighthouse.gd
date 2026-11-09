class_name Lighthouse
extends StaticBody3D
## Lighthouse (SPEC §4.3): lathe tower with a +Z door gap, stone plinth, interior floor, gallery,
## lantern room, warm lamp and the sweeping warm beam (the moody-lighting skill's beam).

const PLASTER_DIR: String = "res://assets/textures/plastered_wall/"
const STONE_DIR: String = "res://assets/textures/stone_block_wall/"

@export var base_y: float = 5.0
@export var tower_height: float = 15.0
@export var base_radius: float = 3.0
@export var top_radius: float = 2.2
@export var wall_thickness: float = 0.4
@export var door_size: Vector2 = Vector2(1.2, 2.2)
@export var plinth_height: float = 1.2
@export var plinth_radius: float = 3.3
@export var plaster_albedo: float = 0.62
@export var plaster_roughness: float = 0.8
@export var segments: int = 48
@export var crate_z: float = 1.4  ## ammo crate just inside the door
@export_group("Lamp")
@export var lamp_color: Color = Color(1.0, 0.74, 0.46)
@export var lamp_emission_energy: float = 5.0
@export var lamp_light_color: Color = Color(1.0, 0.72, 0.42)
@export var lamp_light_energy: float = 2.5
@export var lamp_light_range: float = 8.0
@export var lamp_fog_energy: float = 2.0
@export var lamp_height: float = 20.5
@export_group("Beam")
@export var beam_color: Color = Color(1.0, 0.76, 0.45)
@export var beam_energy: float = 30.0
@export var beam_fog_energy: float = 150.0
@export var beam_angle_deg: float = 6.0
@export var beam_range: float = 160.0
@export var beam_attenuation: float = 0.4
@export var beam_angle_attenuation: float = 2.0
@export var beam_pitch_deg: float = -12.0
@export var beam_turn_speed_deg: float = 25.0
@export var gutter_time: float = 3.0
@export var gutter_level: float = 0.15
@export_group("Beam overdrive (winch)")
@export var overdrive_time: float = 10.0
@export var overdrive_pitch_deg: float = -24.0   ## lands the beam about 46 m out instead of ~96 m
@export var overdrive_angle_deg: float = 10.0
@export var overdrive_dps_mult: float = 2.0      ## beam_dps 20 -> 40
@export var overdrive_energy_mult: float = 1.6
@export var overdrive_fog_mult: float = 0.4     ## the lowered beam is seen end-on from the tower: less fog glare
@export var overdrive_follow_deg: float = 140.0  ## deg/s the beam swings after the operator's view
@export var overdrive_ease_time: float = 0.6     ## s to lower / raise the beam

var beam: SpotLight3D
var crate: AmmoCrate
var lamp_light: OmniLight3D
var beam_still: bool = false
var lamp_on: bool = true
var _beam_pivot: Node3D
var _beam_yaw_deg: float = 0.0
var _gutter_left: float = 0.0
var _lamp_mat: StandardMaterial3D
var _overdrive_left: float = 0.0
var _overdrive_amt: float = 0.0        ## 0..1 eased
var _operator: Player
var overdrives: int = 0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var plaster: StandardMaterial3D = _tex_material(PLASTER_DIR, "plastered_wall", "2k", Color(plaster_albedo, plaster_albedo, plaster_albedo * 1.02), plaster_roughness)
	plaster.normal_scale = 0.6  # full-strength 2k plaster normals alias into grain at range
	var stone: StandardMaterial3D = _tex_material(STONE_DIR, "stone_block_wall", "1k", Color(0.5, 0.5, 0.52), 0.85)
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = Color(0.055, 0.052, 0.05)
	iron.metallic = 0.7
	iron.roughness = 0.55

	var top_y: float = base_y + tower_height
	var shadow_cut: float = top_y - 1.0  # top metre never shadows the beam (it rotates inside it)
	var tower: ArrayMesh = _lathe_wall(base_y, shadow_cut, base_radius, _radius_at(shadow_cut), true)
	_add_mesh("Tower", tower, plaster, true)
	_add_mesh("TowerTop", _lathe_wall(shadow_cut, top_y, _radius_at(shadow_cut), top_radius, false), plaster, false)
	_add_mesh("Plinth", _lathe_wall(base_y - 1.0, base_y + plinth_height, plinth_radius, plinth_radius, true, plinth_radius - base_radius + wall_thickness), stone, true)

	# Collision: the walls (trimesh keeps the door open) + floor.
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = tower.create_trimesh_shape()
	add_child(cs)
	var plinth_cs: CollisionShape3D = CollisionShape3D.new()
	plinth_cs.shape = (get_node("Plinth") as MeshInstance3D).mesh.create_trimesh_shape()
	add_child(plinth_cs)

	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = base_radius - wall_thickness + 0.05
	floor_mesh.bottom_radius = floor_mesh.top_radius
	floor_mesh.height = 1.0
	var floor_mi: MeshInstance3D = _add_mesh("Floor", floor_mesh, stone, true)
	floor_mi.position.y = base_y - 0.5
	var floor_cs: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: CylinderShape3D = CylinderShape3D.new()
	floor_shape.radius = floor_mesh.top_radius
	floor_shape.height = 1.0
	floor_cs.shape = floor_shape
	floor_cs.position.y = base_y - 0.5
	add_child(floor_cs)

	_build_top(top_y, iron)
	_build_lamp()
	crate = AmmoCrate.new()
	crate.name = "AmmoCrate"
	crate.position = Vector3(0.0, base_y, crate_z)
	add_child(crate)


func _physics_process(delta: float) -> void:
	_overdrive_left = maxf(0.0, _overdrive_left - delta)


func _process(delta: float) -> void:
	_overdrive_amt = move_toward(_overdrive_amt, 1.0 if _overdrive_left > 0.0 else 0.0, delta / maxf(overdrive_ease_time, 0.01))
	if _overdrive_left > 0.0 and _operator != null:
		# Overdrive: the keeper cranks the lens round to wherever they look.
		var want: float = _operator.yaw_deg()
		var diff: float = wrapf(want - _beam_yaw_deg, -180.0, 180.0)
		_beam_yaw_deg = fposmod(_beam_yaw_deg + clampf(diff, -overdrive_follow_deg * delta, overdrive_follow_deg * delta), 360.0)
		_beam_pivot.rotation_degrees.y = _beam_yaw_deg
	elif not beam_still:
		_beam_yaw_deg = fposmod(_beam_yaw_deg + beam_turn_speed_deg * delta, 360.0)
		_beam_pivot.rotation_degrees.y = _beam_yaw_deg
	beam.rotation_degrees.x = lerpf(beam_pitch_deg, overdrive_pitch_deg, _overdrive_amt)
	beam.spot_angle = lerpf(beam_angle_deg, overdrive_angle_deg, _overdrive_amt)
	var level: float = lerpf(1.0, overdrive_energy_mult, _overdrive_amt)
	if _gutter_left > 0.0:
		_gutter_left -= delta
		level *= gutter_level * (0.6 + 0.4 * sin(_gutter_left * 37.0))
	beam.light_energy = beam_energy * level
	beam.light_volumetric_fog_energy = beam_fog_energy * level * lerpf(1.0, overdrive_fog_mult / overdrive_energy_mult, _overdrive_amt)
	lamp_light.light_energy = lamp_light_energy * level
	_lamp_mat.emission_energy_multiplier = lamp_emission_energy * level


func set_beam_yaw(deg: float) -> void:
	_beam_yaw_deg = fposmod(deg, 360.0)
	if _beam_pivot != null:
		_beam_pivot.rotation_degrees.y = _beam_yaw_deg


func beam_yaw() -> float:
	return _beam_yaw_deg


## Winch: for overdrive_time seconds the beam drops, widens, burns twice as hot and follows `operator`'s view.
func start_overdrive(operator: Player) -> void:
	_operator = operator
	_overdrive_left = overdrive_time
	overdrives += 1


func overdrive_left() -> float:
	return _overdrive_left


func beam_dps_mult() -> float:
	return overdrive_dps_mult if _overdrive_left > 0.0 else 1.0


func is_guttering() -> bool:
	return _gutter_left > 0.0


## A Drowned reached the tower: the lamp and beam flicker low for gutter_time (M3 hook).
func gutter() -> void:
	_gutter_left = gutter_time


func _radius_at(y: float) -> float:
	return lerpf(base_radius, top_radius, (y - base_y) / tower_height)


## Lathe wall ring from y0 to y1 with outer radii r0 -> r1. With `door`, a door_size gap faces +Z.
func _lathe_wall(y0: float, y1: float, r0: float, r1: float, door: bool, thickness: float = -1.0) -> ArrayMesh:
	var th: float = wall_thickness if thickness < 0.0 else thickness
	var door_top: float = base_y + door_size.y
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rows: split at the door top so the gap has a clean lintel.
	var ys: PackedFloat32Array = PackedFloat32Array([y0])
	if door and door_top > y0 and door_top < y1:
		ys.append(door_top)
	var rows: int = maxi(1, int((y1 - y0) / 1.5))
	for i: int in range(1, rows + 1):
		var yy: float = lerpf(y0, y1, float(i) / rows)
		if absf(yy - door_top) > 0.05:
			ys.append(yy)
	ys.sort()
	for ri: int in ys.size() - 1:
		var ya: float = ys[ri]
		var yb: float = ys[ri + 1]
		var ra: float = lerpf(r0, r1, (ya - y0) / (y1 - y0))
		var rb: float = lerpf(r0, r1, (yb - y0) / (y1 - y0))
		var gap: bool = door and ya < door_top - 0.01 and yb > base_y - 0.01
		var half_a: float = asin(clampf(door_size.x * 0.5 / ra, 0.0, 1.0)) if gap else 0.0
		var a_start: float = half_a
		var a_end: float = TAU - half_a
		for si: int in segments:
			var a0: float = lerpf(a_start, a_end, float(si) / segments)
			var a1: float = lerpf(a_start, a_end, float(si + 1) / segments)
			_quad_ring(st, a0, a1, ya, yb, ra, rb, 1.0)              # outer
			_quad_ring(st, a0, a1, ya, yb, ra - th, rb - th, -1.0)   # inner
		if gap:
			for a: float in [a_start, a_end]:
				_jamb(st, a, ya, yb, ra, rb, th, a == a_start)
	# Top cap ring.
	var rt: float = r1
	# A wall that ends inside the door's height (the plinth) must leave the doorway open on top too.
	var open_door_top: bool = door and door_top >= y1 - 0.01
	var cap_start: float = asin(clampf(door_size.x * 0.5 / rt, 0.0, 1.0)) if open_door_top else 0.0
	var cap_end: float = TAU - cap_start
	for si: int in segments:
		var a0: float = lerpf(cap_start, cap_end, float(si) / segments)
		var a1: float = lerpf(cap_start, cap_end, float(si + 1) / segments)
		var o0: Vector3 = _ring_point(a0, rt, y1)
		var o1: Vector3 = _ring_point(a1, rt, y1)
		var i0: Vector3 = _ring_point(a0, rt - th, y1)
		var i1: Vector3 = _ring_point(a1, rt - th, y1)
		st.set_normal(Vector3.UP)
		for v: Vector3 in [o0, i1, o1, o0, i0, i1]:
			st.set_uv(Vector2(v.x, v.z) * 0.5)
			st.add_vertex(v)
	return st.commit()


## Angle 0 = +Z (door side), increasing toward +X.
func _ring_point(a: float, r: float, y: float) -> Vector3:
	return Vector3(sin(a) * r, y, cos(a) * r)


func _quad_ring(st: SurfaceTool, a0: float, a1: float, ya: float, yb: float, ra: float, rb: float, side: float) -> void:
	var p00: Vector3 = _ring_point(a0, ra, ya)
	var p10: Vector3 = _ring_point(a1, ra, ya)
	var p01: Vector3 = _ring_point(a0, rb, yb)
	var p11: Vector3 = _ring_point(a1, rb, yb)
	var n0: Vector3 = Vector3(sin(a0), 0.0, cos(a0)) * side
	var n1: Vector3 = Vector3(sin(a1), 0.0, cos(a1)) * side
	var u0: float = a0 * base_radius * 0.5
	var u1: float = a1 * base_radius * 0.5
	var tri: Array = [[p00, n0, Vector2(u0, -ya * 0.5)], [p10, n1, Vector2(u1, -ya * 0.5)], [p11, n1, Vector2(u1, -yb * 0.5)],
		[p00, n0, Vector2(u0, -ya * 0.5)], [p11, n1, Vector2(u1, -yb * 0.5)], [p01, n0, Vector2(u0, -yb * 0.5)]]
	if side > 0.0:
		# Outer faces must wind clockwise as seen from outside.
		tri = [tri[0], tri[2], tri[1], tri[3], tri[5], tri[4]]
	for t: Array in tri:
		st.set_normal(t[1] as Vector3)
		st.set_uv(t[2] as Vector2)
		st.add_vertex(t[0] as Vector3)


func _jamb(st: SurfaceTool, a: float, ya: float, yb: float, ra: float, rb: float, th: float, start: bool) -> void:
	var o0: Vector3 = _ring_point(a, ra, ya)
	var o1: Vector3 = _ring_point(a, rb, yb)
	var i0: Vector3 = _ring_point(a, ra - th, ya)
	var i1: Vector3 = _ring_point(a, rb - th, yb)
	var tangent: Vector3 = Vector3(cos(a), 0.0, -sin(a))
	var n: Vector3 = -tangent if start else tangent
	# Both windings: only the side facing the doorway is ever visible, so it is always front-facing.
	var verts: Array[Vector3] = [o0, i1, i0, o0, o1, i1, o0, i0, i1, o0, i1, o1]
	st.set_normal(n)
	for v: Vector3 in verts:
		st.set_uv(Vector2(v.x + v.z, -v.y) * 0.5)
		st.add_vertex(v)


func _build_top(top_y: float, iron: StandardMaterial3D) -> void:
	var gallery: CylinderMesh = CylinderMesh.new()
	gallery.top_radius = 3.0
	gallery.bottom_radius = 2.8
	gallery.height = 0.22
	var g: MeshInstance3D = _add_mesh("Gallery", gallery, iron, false)
	g.position.y = top_y + 0.0

	var post: CylinderMesh = CylinderMesh.new()
	post.top_radius = 0.025
	post.bottom_radius = 0.025
	post.height = 1.05
	var posts: int = 28
	for i: int in posts:
		var a: float = TAU * float(i) / posts
		var p: MeshInstance3D = _add_mesh("Post%d" % i, post, iron, false)
		p.position = Vector3(sin(a) * 2.92, top_y + 0.6, cos(a) * 2.92)
	for h: float in [0.55, 1.1]:
		var rail: TorusMesh = TorusMesh.new()
		rail.inner_radius = 2.9
		rail.outer_radius = 2.94
		rail.rings = 64
		var r: MeshInstance3D = _add_mesh("Rail", rail, iron, false)
		r.position.y = top_y + 0.05 + h

	var glass_mat: StandardMaterial3D = StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.05, 0.06, 0.07, 0.35)
	glass_mat.roughness = 0.05
	glass_mat.metallic_specular = 0.8
	var glass: CylinderMesh = CylinderMesh.new()
	glass.top_radius = 1.6
	glass.bottom_radius = 1.6
	glass.height = 2.5
	glass.cap_top = false
	glass.cap_bottom = false
	var gm: MeshInstance3D = _add_mesh("LanternGlass", glass, glass_mat, false)
	gm.position.y = top_y + 0.11 + 1.25

	# Iron frame: base ring, mullions, and the black cone roof.
	var base_ring: CylinderMesh = CylinderMesh.new()
	base_ring.top_radius = 1.68
	base_ring.bottom_radius = 1.68
	base_ring.height = 0.35
	_add_mesh("LanternBase", base_ring, iron, false).position.y = top_y + 0.11 + 0.175 - 0.4
	var mullion: BoxMesh = BoxMesh.new()
	mullion.size = Vector3(0.06, 2.5, 0.06)
	for i: int in 8:
		var a: float = TAU * (float(i) + 0.5) / 8.0
		var m: MeshInstance3D = _add_mesh("Mullion%d" % i, mullion, iron, false)
		m.position = Vector3(sin(a) * 1.62, top_y + 0.11 + 1.25, cos(a) * 1.62)
		m.rotation.y = a
	var roof: CylinderMesh = CylinderMesh.new()
	roof.top_radius = 0.06
	roof.bottom_radius = 1.95
	roof.height = 1.3
	_add_mesh("Roof", roof, iron, false).position.y = top_y + 0.11 + 2.5 + 0.65
	var vent: SphereMesh = SphereMesh.new()
	vent.radius = 0.18
	vent.height = 0.36
	_add_mesh("Vent", vent, iron, false).position.y = top_y + 0.11 + 2.5 + 1.35


func _build_lamp() -> void:
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = lamp_color
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = lamp_color
	_lamp_mat.emission_energy_multiplier = lamp_emission_energy
	var lens: CylinderMesh = CylinderMesh.new()
	lens.top_radius = 0.32
	lens.bottom_radius = 0.32
	lens.height = 0.6
	var lm: MeshInstance3D = _add_mesh("LampGlass", lens, _lamp_mat, false)
	lm.position.y = lamp_height

	lamp_light = OmniLight3D.new()
	lamp_light.light_color = lamp_light_color
	lamp_light.light_energy = lamp_light_energy
	lamp_light.omni_range = lamp_light_range
	lamp_light.light_volumetric_fog_energy = lamp_fog_energy
	lamp_light.shadow_enabled = false
	lamp_light.position.y = lamp_height + 0.4
	add_child(lamp_light)

	_beam_pivot = Node3D.new()
	_beam_pivot.name = "BeamPivot"
	_beam_pivot.position.y = lamp_height
	add_child(_beam_pivot)
	beam = SpotLight3D.new()
	beam.light_color = beam_color
	beam.light_energy = beam_energy
	beam.light_volumetric_fog_energy = beam_fog_energy
	beam.spot_angle = beam_angle_deg
	beam.spot_range = beam_range
	beam.spot_attenuation = beam_attenuation
	beam.spot_angle_attenuation = beam_angle_attenuation
	beam.shadow_enabled = true
	beam.rotation_degrees.x = beam_pitch_deg
	_beam_pivot.add_child(beam)
	_beam_pivot.rotation_degrees.y = _beam_yaw_deg


func _add_mesh(n: String, m: Mesh, mat: Material, shadows: bool) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi, true)
	return mi


func _tex_material(dir: String, slug: String, res: String, tint: Color, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = load("%s%s_diff_%s.jpg" % [dir, slug, res]) as Texture2D
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("%s%s_nor_gl_%s.jpg" % [dir, slug, res]) as Texture2D
	m.roughness_texture = load("%s%s_rough_%s.jpg" % [dir, slug, res]) as Texture2D
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = rough
	m.ao_enabled = true
	m.ao_texture = load("%s%s_ao_%s.jpg" % [dir, slug, res]) as Texture2D
	m.uv1_scale = Vector3(0.5, 0.5, 1.0)
	return m
