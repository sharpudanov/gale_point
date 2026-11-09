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
@export_group("End card")
@export var death_fade_time: float = 1.5
@export var card_text_death: String = "The light went out."
@export var card_text_dawn: String = "Dawn."
@export var card_color: Color = Color(0.78, 0.80, 0.84)
@export var card_alpha: float = 0.6
@export var card_font_size: int = 46
@export var card_top: float = 0.30     ## card band, fraction of the screen height (clear sky above the horizon)
@export var card_bottom: float = 0.42
@export var card_fade_time: float = 2.0
@export_group("Tally")
@export var tally_color: Color = Color(0.82, 0.84, 0.88)
@export var tally_alpha: float = 0.95
@export var tally_fade_time: float = 2.0
@export var tally_font_size: int = 34
@export var tally_margin: Vector2 = Vector2(48.0, 40.0)

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
var _reticle: Reticle
var _markers: Dictionary = {"lit": 0, "kill": 0, "dark": 0}
var _tally_left: float = 0.0
var _card: Label
var _card_t: float = -1.0       ## seconds since the card began fading in; < 0 = hidden
var _dead_t: float = -1.0       ## seconds since death; < 0 = alive


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
	_reticle = Reticle.new()
	_reticle.name = "Reticle"
	add_child(_reticle)
	_card = Label.new()
	_card.name = "EndCard"
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_theme_font_override("font", _serif_font())
	_card.add_theme_font_size_override("font_size", card_font_size)
	_card.add_theme_color_override("font_color", card_color)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_theme_color_override("font_shadow_color", Color(0.05, 0.07, 0.10, 0.55))
	_card.add_theme_constant_override("shadow_offset_y", 2)
	_card.add_theme_constant_override("shadow_outline_size", 4)
	_card.modulate.a = 0.0
	add_child(_card)


## Wire the weapon holder: the tally shows after a shot, reload, switch or crate use.
func set_weapons(w: WeaponHolder) -> void:
	weapons = w
	w.ammo_changed.connect(show_tally)
	w.rifle.hit_marker.connect(_on_hit_marker)


## A rifle shot hit an enemy: flash the matching marker around the reticle.
func _on_hit_marker(kind: String) -> void:
	_markers[kind] = int(_markers[kind]) + 1
	_reticle.flash(kind)


func show_tally() -> void:
	if weapons == null:
		return
	_tally.text = "%d | %d   ✦ %d" % [weapons.rifle.mag, weapons.rifle.reserve, weapons.flare_gun.left]
	_tally_left = tally_fade_time


func on_hit() -> void:
	_spike = hit_spike


## The player died: fade to black over death_fade_time, then the card fades in.
func on_died() -> void:
	if _dead_t < 0.0:
		_dead_t = 0.0
		_card.text = card_text_death


## The night is over (NightClock.won): the "Dawn." card fades in over card_fade_time. No black fade.
func on_won() -> void:
	if _dead_t < 0.0 and _card_t < 0.0:
		_card.text = card_text_dawn
		_card.anchor_top = card_top      # the dawn card sits in the sky, above the horizon seam
		_card.anchor_bottom = card_bottom
		_card.offset_top = 0.0
		_card.offset_bottom = 0.0
		_card_t = 0.0


## An end card reads as "ready to restart" once it is fully shown.
func card_visible() -> bool:
	return _card_t >= 0.0


func _unhandled_input(event: InputEvent) -> void:
	if card_visible() and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


static func _serif_font() -> Font:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Times New Roman", "Palatino Linotype", "serif"])
	return f


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
	if _dead_t >= 0.0:
		_dead_t += delta
		fade = clampf(_dead_t / death_fade_time, 0.0, 1.0)
		if _dead_t >= death_fade_time and _card_t < 0.0:
			_card_t = 0.0
	if _card_t >= 0.0:
		_card_t += delta
		_card.modulate.a = card_alpha * clampf(_card_t / card_fade_time, 0.0, 1.0)
	_mat.set_shader_parameter("fade", fade)
	_tally_left = maxf(0.0, _tally_left - delta)
	_tally.modulate.a = tally_alpha * clampf(_tally_left / tally_fade_time, 0.0, 1.0)
	_reticle.visible = weapons != null and player != null and player.is_alive()
	_reticle.ads = weapons != null and weapons.ads


func telemetry() -> Dictionary:
	return {
		"vignette": vignette_strength,
		"damage_vignette": snappedf(damage, 0.001),
		"fade": snappedf(fade, 0.001),
		"card": _card.text if card_visible() else "",
		"grain": grain_amount,
		"tally_alpha": snappedf(_tally.modulate.a, 0.001),
		"tally_text": _tally.text,
		"reticle": ("hidden" if not _reticle.visible else ("ads" if _reticle.ads else "hip")),
		"hit_markers": _markers.duplicate(),
		"marker_active": _reticle.marker_active(),
	}
