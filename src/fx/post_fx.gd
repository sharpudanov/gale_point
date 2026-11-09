class_name PostFx
extends CanvasLayer
## Full-screen film pass (SPEC §4.11 / §6.6): grain, vignette, damage edge, fade.
## The ammo tally and end cards arrive in later milestones.

const SHADER_PATH: String = "res://shaders/post_film.gdshader"

@export var grain_amount: float = 0.035
@export var vignette_strength: float = 0.32
@export var damage_by_hp: PackedFloat32Array = PackedFloat32Array([0.65, 0.35, 0.0])  ## hp 1, 2, 3
@export var hit_spike: float = 0.3
@export var hit_decay_time: float = 0.8
@export var pulse_hz: float = 1.1
@export var pulse_amp: float = 0.15
@export_group("Tally")
@export var tally_color: Color = Color(0.82, 0.84, 0.88)
@export var tally_alpha: float = 0.95
@export var tally_fade_time: float = 2.0
@export var tally_font_size: int = 34
@export var tally_margin: Vector2 = Vector2(48.0, 40.0)
@export var dot_alpha: float = 0.25
@export var dot_size: float = 2.0

var player: Player
var weapons: WeaponHolder
var damage: float = 0.0
var fade: float = 0.0

var _rect: ColorRect
var _mat: ShaderMaterial
var _frame: int = 0
var _spike: float = 0.0
var _t: float = 0.0
var _tally: Label
var _dot: ColorRect
var _tally_left: float = 0.0


func _ready() -> void:
	layer = 10
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH) as Shader
	_mat.set_shader_parameter("grain_amount", grain_amount)
	_mat.set_shader_parameter("vignette_strength", vignette_strength)
	_rect = ColorRect.new()
	_rect.name = "PostFilm"
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	_tally = Label.new()
	_tally.name = "Tally"
	_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tally.add_theme_font_size_override("font_size", tally_font_size)
	_tally.add_theme_color_override("font_color", tally_color)
	_tally.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_tally.add_theme_constant_override("outline_size", 5)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tally.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tally.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tally.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tally.offset_right = -tally_margin.x
	_tally.offset_bottom = -tally_margin.y
	_tally.modulate.a = 0.0
	add_child(_tally)
	_dot = ColorRect.new()
	_dot.name = "HipDot"
	_dot.color = Color(1.0, 1.0, 1.0, dot_alpha)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.offset_left = -dot_size * 0.5
	_dot.offset_right = dot_size * 0.5
	_dot.offset_top = -dot_size * 0.5
	_dot.offset_bottom = dot_size * 0.5
	add_child(_dot)


## Wire the weapon holder: the tally shows after a shot, reload, switch or crate use.
func set_weapons(w: WeaponHolder) -> void:
	weapons = w
	w.ammo_changed.connect(show_tally)


func show_tally() -> void:
	if weapons == null:
		return
	_tally.text = "%d | %d   ✦ %d" % [weapons.rifle.mag, weapons.rifle.reserve, weapons.flare_gun.left]
	_tally_left = tally_fade_time


func on_hit() -> void:
	_spike = hit_spike


func _process(delta: float) -> void:
	_frame += 1
	_t += delta
	_mat.set_shader_parameter("grain_seed", float(_frame % 997))
	var base: float = 0.0
	if player != null:
		var hp: int = player.hp
		if hp >= 1 and hp <= damage_by_hp.size():
			base = damage_by_hp[hp - 1]
		if hp == 1:
			base += pulse_amp * sin(TAU * pulse_hz * _t)
	_spike = maxf(0.0, _spike - hit_spike / hit_decay_time * delta)
	damage = clampf(base + _spike, 0.0, 1.0)
	_mat.set_shader_parameter("damage", damage)
	_mat.set_shader_parameter("fade", fade)
	_tally_left = maxf(0.0, _tally_left - delta)
	_tally.modulate.a = tally_alpha * clampf(_tally_left / tally_fade_time, 0.0, 1.0)
	_dot.visible = weapons != null and not weapons.ads and player != null and player.is_alive()


func telemetry() -> Dictionary:
	return {
		"vignette": vignette_strength,
		"damage_vignette": snappedf(damage, 0.001),
		"grain": grain_amount,
		"tally_alpha": snappedf(_tally.modulate.a, 0.001),
		"tally_text": _tally.text,
	}
