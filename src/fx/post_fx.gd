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

var player: Player
var damage: float = 0.0
var fade: float = 0.0

var _rect: ColorRect
var _mat: ShaderMaterial
var _frame: int = 0
var _spike: float = 0.0
var _t: float = 0.0


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


func telemetry() -> Dictionary:
	return {
		"vignette": vignette_strength,
		"damage_vignette": snappedf(damage, 0.001),
		"grain": grain_amount,
	}
