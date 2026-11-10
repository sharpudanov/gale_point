class_name MapView
extends Node
## --map (SPEC §7, preset "map"): a top-down orthographic tool view of the island for designing the layout.
## Image: top = -Z, right = +X, 10 m grid with axis numbers. Fog, rain, spray, mist, beam, PostFx and the
## viewmodel are hidden and one shadowless white light points straight down. The overlay labels every prop
## (B0.., C0.., W, Buoy0..; LayoutCheck uses the same labels), draws rocks as dots, the walkable boundary
## (Island.walkable_radius), the lighthouse, its door (+Z) and the player start, and lists layout problems.
## --map_plain: terrain, lighthouse and grid only (props, rocks, buoys and their labels hidden): the
## editor backdrop for the layout scene.

@export var view_size: float = 110.0          ## m, image height (covers the buoy ring)
@export var camera_height: float = 80.0
@export var light_energy: float = 1.6
@export var exposure: float = 1.0
@export var ambient_energy: float = 0.6
@export var grid_step: float = 10.0
@export var boundary_samples: int = 180
@export var font_size: int = 15
@export var rock_dot_px: float = 2.2          ## dot radius per unit of rock scale
@export var prop_dot_px: float = 4.0
@export var grid_color: Color = Color(1.0, 1.0, 1.0, 0.18)
@export var axis_color: Color = Color(1.0, 1.0, 1.0, 0.45)
@export var number_color: Color = Color(0.9, 0.92, 0.95, 0.85)
@export var boundary_color: Color = Color(0.3, 1.0, 0.55, 0.9)
@export var brazier_color: Color = Color(1.0, 0.55, 0.15)
@export var cask_color: Color = Color(1.0, 0.85, 0.2)
@export var winch_color: Color = Color(0.4, 0.8, 1.0)
@export var buoy_color: Color = Color(1.0, 0.35, 0.35)
@export var rock_color: Color = Color(0.75, 0.7, 0.65, 0.9)
@export var landmark_color: Color = Color(1.0, 1.0, 1.0)
@export var problem_color: Color = Color(1.0, 0.3, 0.3)

var camera: Camera3D
var light: DirectionalLight3D
var plain: bool = false

var _island: Island
var _lighthouse: Lighthouse
var _props: IslandProps
var _buoys: BellBuoys
var _mood: MoodRig
var _start: Vector2
var _canvas: Control
var _boundary: PackedVector3Array = PackedVector3Array()


func setup(island: Island, lighthouse: Lighthouse, props: IslandProps, buoys: BellBuoys, mood: MoodRig,
		weather: StormWeather, post_fx: PostFx, weapons: WeaponHolder, player_start: Vector2, plain_view: bool) -> void:
	_island = island
	_lighthouse = lighthouse
	_props = props
	_buoys = buoys
	_mood = mood
	_start = player_start
	plain = plain_view
	weather.rain.visible = false
	weather.spray.visible = false
	weather.mist.visible = false
	weather.flash_light.visible = false
	post_fx.visible = false
	weapons.visible = false
	lighthouse.beam.visible = false
	mood.sun.visible = false
	if plain:
		props.visible = false
		buoys.visible = false
		for r: Node3D in island.rocks:
			r.visible = false


func _ready() -> void:
	process_priority = 1000   # after StormDirector, which pushes fog and exposure every tick
	camera = Camera3D.new()
	camera.name = "MapCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = view_size
	camera.far = camera_height + 50.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, camera_height, 0.0), Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	camera.current = true
	light = DirectionalLight3D.new()
	light.name = "MapLight"
	light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	light.light_color = Color.WHITE
	light.light_energy = light_energy
	light.shadow_enabled = false
	add_child(light)
	for i: int in boundary_samples:
		var a: float = TAU * float(i) / float(boundary_samples)
		var r: float = _island.walkable_radius(a)
		_boundary.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MapOverlay"
	add_child(layer)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_canvas)
	_canvas.draw.connect(_on_draw)


func _process(_delta: float) -> void:
	var env: Environment = _mood.env
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.glow_enabled = false
	env.tonemap_exposure = exposure
	env.ambient_light_energy = ambient_energy
	_canvas.queue_redraw()


func _px(p: Vector3) -> Vector2:
	return camera.unproject_position(Vector3(p.x, 0.0, p.z))


func _text(at: Vector2, s: String, col: Color, size: int = -1) -> void:
	var font: Font = ThemeDB.fallback_font
	var fs: int = font_size if size < 0 else size
	_canvas.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, 4, Color(0.0, 0.0, 0.0, 0.85))
	_canvas.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)


func _on_draw() -> void:
	var vp: Vector2 = _canvas.size
	var half_z: float = view_size * 0.5
	var half_x: float = half_z * vp.x / maxf(vp.y, 1.0)
	_draw_grid(half_x, half_z, vp)
	_draw_compass(vp)
	# Lighthouse footprint and door (+Z).
	var o: Vector2 = _px(Vector3.ZERO)
	var px_per_m: float = vp.y / view_size
	_canvas.draw_arc(o, _lighthouse.plinth_radius * px_per_m, 0.0, TAU, 48, landmark_color, 1.5)
	var door: Vector2 = _px(Vector3(0.0, 0.0, _lighthouse.base_radius))
	_canvas.draw_circle(door, 3.0, landmark_color)
	_text(door + Vector2(-40.0, 5.0), "door", landmark_color)
	if plain:
		return
	var b: PackedVector2Array = PackedVector2Array()
	for p: Vector3 in _boundary:
		b.append(_px(p))
	if b.size() > 1:
		b.append(b[0])
		_canvas.draw_polyline(b, boundary_color, 1.5)
	for r: Node3D in _island.rocks:
		_canvas.draw_circle(_px(r.global_position), maxf(1.5, r.scale.x * rock_dot_px), rock_color)
	var s: Vector2 = _px(Vector3(_start.x, 0.0, _start.y))
	_canvas.draw_line(s - Vector2(5.0, 5.0), s + Vector2(5.0, 5.0), landmark_color, 2.0)
	_canvas.draw_line(s - Vector2(5.0, -5.0), s + Vector2(5.0, -5.0), landmark_color, 2.0)
	_text(s + Vector2(7.0, -6.0), "P", landmark_color)
	for d: Dictionary in LayoutCheck.prop_points(_props):
		var label: String = d["label"]
		var c: Color = winch_color if label == "W" else (brazier_color if label.begins_with("B") else cask_color)
		var pp: Vector2 = _px(d["pos"] as Vector3)
		_canvas.draw_circle(pp, prop_dot_px, c)
		_text(pp + Vector2(6.0, -4.0), label, c)
	var bp: PackedVector3Array = _buoys.points()
	for i: int in bp.size():
		var q: Vector2 = _px(bp[i])
		_canvas.draw_circle(q, prop_dot_px, buoy_color)
		_text(q + Vector2(6.0, -4.0), "Buoy%d" % i, buoy_color)
	var problems: PackedStringArray = LayoutCheck.problems(_island, _props, _buoys, _lighthouse)
	var y: float = vp.y - 12.0 - 18.0 * float(problems.size())
	_text(Vector2(12.0, y), "layout problems: %d" % problems.size(), problem_color if problems.size() > 0 else boundary_color)
	for line: String in problems:
		y += 18.0
		_text(Vector2(12.0, y), line, problem_color)


func _draw_grid(half_x: float, half_z: float, vp: Vector2) -> void:
	var x: float = ceilf(-half_x / grid_step) * grid_step
	while x <= half_x:
		var top: Vector2 = _px(Vector3(x, 0.0, -half_z))
		var bottom: Vector2 = _px(Vector3(x, 0.0, half_z))
		_canvas.draw_line(top, bottom, axis_color if is_zero_approx(x) else grid_color, 1.0)
		_text(Vector2(top.x + 3.0, 16.0), "%d" % int(x), number_color, font_size - 2)
		x += grid_step
	var z: float = ceilf(-half_z / grid_step) * grid_step
	while z <= half_z:
		var left: Vector2 = _px(Vector3(-half_x, 0.0, z))
		var right: Vector2 = _px(Vector3(half_x, 0.0, z))
		_canvas.draw_line(left, right, axis_color if is_zero_approx(z) else grid_color, 1.0)
		if absf(left.y) > 24.0 and left.y < vp.y - 4.0:
			_text(Vector2(4.0, left.y - 3.0), "z%d" % int(z), number_color, font_size - 2)
		z += grid_step


func _draw_compass(vp: Vector2) -> void:
	var c: Vector2 = Vector2(vp.x - 60.0, 70.0)
	_canvas.draw_line(c, c + Vector2(0.0, -34.0), landmark_color, 2.0)
	_canvas.draw_line(c, c + Vector2(34.0, 0.0), landmark_color, 2.0)
	_text(c + Vector2(-12.0, -40.0), "-Z", landmark_color)
	_text(c + Vector2(38.0, 5.0), "+X", landmark_color)
