class_name WetTrails
extends Node3D
## Pool of Decals (SPEC 4.2/4.8): glossy wet smears left by the Drowned on land, plus a puddle where one
## dissolves. Oldest decal is recycled first. Each decal fades out over its life.

@export var pool_size: int = 160
@export var trail_size: Vector2 = Vector2(1.3, 3.0)     ## width x length of a smear (m)
@export var puddle_size: float = 1.4
@export var life_time: float = 28.0
@export var fade_time: float = 6.0
@export var project_depth: float = 2.5
@export var wet_color: Color = Color(0.06, 0.07, 0.09)
@export var wet_alpha: float = 1.0
@export var wet_roughness: float = 0.0

var stamped: int = 0

var _decals: Array[Decal] = []
var _born: Array[float] = []
var _life: Array[float] = []
var _next: int = 0
var _t: float = 0.0
var _smear_tex: ImageTexture
var _smear_orm: ImageTexture
var _puddle_tex: ImageTexture
var _puddle_orm: ImageTexture


func _ready() -> void:
	_smear_tex = _blob_texture(false, false)
	_smear_orm = _blob_texture(false, true)
	_puddle_tex = _blob_texture(true, false)
	_puddle_orm = _blob_texture(true, true)
	for i: int in pool_size:
		var d: Decal = Decal.new()
		d.name = "Trail%d" % i
		d.size = Vector3(1.0, project_depth, 1.0)
		d.cull_mask = 1
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.normal_fade = 0.05
		d.visible = false
		add_child(d)
		_decals.append(d)
		_born.append(-1000.0)
		_life.append(life_time)


## An elongated wet smear at a ground position, long axis along `yaw` (radians about Y, -Z forward).
func stamp(pos: Vector3, yaw: float) -> void:
	_place(pos, yaw, Vector3(trail_size.x, project_depth, trail_size.y), false, life_time)


## A round puddle where a Drowned dissolved.
func puddle(pos: Vector3) -> void:
	_place(pos, GameRng.randf() * TAU, Vector3(puddle_size, project_depth, puddle_size), true, life_time * 1.4)


func _place(pos: Vector3, yaw: float, size: Vector3, is_puddle: bool, life: float) -> void:
	var d: Decal = _decals[_next]
	_born[_next] = _t
	_life[_next] = life
	_next = (_next + 1) % _decals.size()
	d.texture_albedo = _puddle_tex if is_puddle else _smear_tex
	d.texture_orm = _puddle_orm if is_puddle else _smear_orm
	d.size = size
	d.modulate = Color(1.0, 1.0, 1.0, 1.0)
	d.global_position = pos + Vector3(0.0, 0.5, 0.0)
	d.rotation = Vector3(0.0, yaw, 0.0)
	d.visible = true
	stamped += 1


func _process(delta: float) -> void:
	_t += delta
	for i: int in _decals.size():
		var d: Decal = _decals[i]
		if not d.visible:
			continue
		var age: float = _t - _born[i]
		var left: float = _life[i] - age
		if left <= 0.0:
			d.visible = false
		elif left < fade_time:
			d.modulate.a = left / fade_time


func active_count() -> int:
	var n: int = 0
	for d: Decal in _decals:
		if d.visible:
			n += 1
	return n


## Soft-edged blob: albedo (dark, alpha = coverage) or ORM (R ao, G roughness, B metallic), with a
## streaky noise edge so smears do not read as clean ovals.
func _blob_texture(round_shape: bool, orm: bool) -> ImageTexture:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.09
	noise.seed = 21 if round_shape else 17
	for y: int in n:
		for x: int in n:
			var u: float = (float(x) + 0.5) / n * 2.0 - 1.0
			var v: float = (float(y) + 0.5) / n * 2.0 - 1.0
			var r: float
			if round_shape:
				r = sqrt(u * u + v * v)
			else:
				# Teardrop: wide at the front (v < 0 is forward), tapering into a streak behind.
				var taper: float = lerpf(1.0, 0.35, clampf((v + 1.0) * 0.5, 0.0, 1.0))
				r = sqrt((u / taper) * (u / taper) + v * v * 0.8)
			r += 0.18 * noise.get_noise_2d(float(x), float(y))
			var a: float = clampf(1.0 - smoothstep(0.55, 1.0, r), 0.0, 1.0)
			if orm:
				img.set_pixel(x, y, Color(1.0, lerpf(0.9, wet_roughness, a), 0.0, 1.0))
			else:
				img.set_pixel(x, y, Color(wet_color.r, wet_color.g, wet_color.b, a * wet_alpha))
	return ImageTexture.create_from_image(img)
