class_name Reticle
extends Control
## Center reticle + diegetic hit markers (drawn by PostFx, which owns the state).
## Hip: a crisp ivory dot with a dark outline and four short ticks with a gap. ADS: a fine dark-edged
## crosshair with a warm amber pinpoint. Hit markers flash around the center: golden X-ticks for a lit hit or
## kill, a cold slate-blue deflect ring for a hit on a Drowned in the dark (immune).

@export_group("Hip")
@export var dot_size: float = 3.0
@export var dot_color: Color = Color(0.96, 0.93, 0.82)       ## pale ivory
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.85)
@export var tick_gap: float = 9.0
@export var tick_length: float = 7.0
@export var tick_width: float = 2.0
@export var tick_alpha: float = 0.8
@export_group("ADS")
@export var pin_size: float = 3.0
@export var pin_color: Color = Color("#FFC27A")              ## warm amber center pinpoint
@export var ads_gap: float = 7.0
@export var ads_length: float = 34.0
@export var ads_width: float = 1.0
@export var ads_color: Color = Color(0.94, 0.92, 0.86, 0.95)
@export_group("Hit markers")
@export var lit_color: Color = Color("#FFB266")
@export var dark_color: Color = Color(0.42, 0.52, 0.68)      ## cold slate blue
@export var lit_time: float = 0.22
@export var kill_time: float = 0.22
@export var dark_time: float = 0.25

var ads: bool = false

var _lit_left: float = 0.0
var _kill: bool = false
var _dark_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## kind: "lit", "kill" or "dark" (the Rifle.hit_marker signal).
func flash(kind: String) -> void:
	if kind == "dark":
		_dark_left = dark_time
	else:
		_kill = kind == "kill"
		_lit_left = kill_time if _kill else lit_time


func marker_active() -> bool:
	return _lit_left > 0.0 or _dark_left > 0.0


func _process(delta: float) -> void:
	_lit_left = maxf(0.0, _lit_left - delta)
	_dark_left = maxf(0.0, _dark_left - delta)
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = (get_viewport_rect().size * 0.5).round()   # a Control under a CanvasLayer has no size of its own
	if ads:
		_draw_ads(c)
	else:
		_draw_hip(c)
	if _lit_left > 0.0:
		_draw_lit(c)
	if _dark_left > 0.0:
		_draw_dark(c)


func _bar(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	# A dark 1 px outline under the bar, then the bar itself.
	draw_line(a, b, outline_color, w + 2.0, false)
	draw_line(a, b, col, w, false)


func _draw_hip(c: Vector2) -> void:
	var col: Color = Color(dot_color.r, dot_color.g, dot_color.b, tick_alpha)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_bar(c + d * tick_gap, c + d * (tick_gap + tick_length), tick_width, col)
	var o: float = dot_size * 0.5 + 1.0
	draw_rect(Rect2(c - Vector2(o, o), Vector2(o, o) * 2.0), outline_color)
	var h: float = dot_size * 0.5
	draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), dot_color)


func _draw_ads(c: Vector2) -> void:
	# Fine crosshair: four thin arms with a clear centre, a heavier post at the bottom, amber pin in the middle.
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_bar(c + d * ads_gap, c + d * (ads_gap + ads_length), ads_width, ads_color)
	_bar(c + Vector2.DOWN * (ads_gap + ads_length), c + Vector2.DOWN * (ads_gap + ads_length + 26.0), ads_width + 2.0, ads_color)
	var o: float = pin_size * 0.5 + 1.0
	draw_rect(Rect2(c - Vector2(o, o), Vector2(o, o) * 2.0), outline_color)
	var h: float = pin_size * 0.5
	draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), pin_color)


## Four diagonal X-ticks that punch outward; a kill is bigger and thicker.
func _draw_lit(c: Vector2) -> void:
	var total: float = kill_time if _kill else lit_time
	var k: float = 1.0 - _lit_left / total   # 0 -> 1
	var base: float = 14.0 if _kill else 11.0
	var reach: float = 9.0 if _kill else 6.0
	var punch: float = (1.0 + 0.5 * (1.0 - k)) if _kill else 1.0
	var w: float = 3.0 if _kill else 2.0
	var col: Color = Color(lit_color.r, lit_color.g, lit_color.b, 1.0 - k * k)
	var r0: float = base * punch + 8.0 * k
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var d: Vector2 = Vector2(sx, sy).normalized()
			draw_line(c + d * r0, c + d * (r0 + reach), Color(0.0, 0.0, 0.0, col.a * 0.7), w + 2.0, false)
			draw_line(c + d * r0, c + d * (r0 + reach), col, w, false)


## Cold ring with four inward chevron ticks: "it hit, but it is deflected".
func _draw_dark(c: Vector2) -> void:
	var k: float = 1.0 - _dark_left / dark_time
	var a: float = 1.0 - k * k
	var col: Color = Color(dark_color.r, dark_color.g, dark_color.b, a)
	var r: float = 17.0 + 5.0 * k
	draw_arc(c, r, 0.0, TAU, 36, Color(0.0, 0.0, 0.0, a * 0.7), 4.0, false)
	draw_arc(c, r, 0.0, TAU, 36, col, 2.0, false)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var perp: Vector2 = Vector2(-d.y, d.x)
		var tip: Vector2 = c + d * (r - 7.0)
		var from_a: Vector2 = c + d * (r + 1.0) + perp * 5.0
		var from_b: Vector2 = c + d * (r + 1.0) - perp * 5.0
		draw_line(from_a, tip, col, 2.0, false)
		draw_line(from_b, tip, col, 2.0, false)
