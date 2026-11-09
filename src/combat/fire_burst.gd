class_name FireBurst
extends GameLight
## The glare of a fire burst: lights (and makes shootable) everything within `radius` for about `life`
## seconds, fading. Owns a warm OmniLight3D without shadows. Frees itself.

var life: float = 1.2
var peak_energy: float = 18.0
var light_range: float = 9.0
var visual_time: float = 0.8   ## the visible flash is gone well before the gameplay glare ends
var fog_energy: float = 0.3

var _t: float = 0.0
var _light: OmniLight3D


func _ready() -> void:
	_light = FireFx.fire_light(peak_energy, light_range, fog_energy)
	_light.position.y = 1.0
	add_child(_light)


func _physics_process(delta: float) -> void:
	_t += delta
	var k: float = clampf(1.0 - _t / maxf(life, 0.01), 0.0, 1.0)
	strength = k
	if _t >= life:
		queue_free()


func _process(_delta: float) -> void:
	var k: float = clampf(1.0 - _t / maxf(visual_time, 0.01), 0.0, 1.0)
	_light.light_energy = peak_energy * k * k
	_light.light_volumetric_fog_energy = fog_energy * k * k
