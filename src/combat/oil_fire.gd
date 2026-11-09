class_name OilFire
extends GameLight
## A pool of burning oil on the ground: a gameplay light (radius, dps from GameLight) for `life` seconds,
## fading over the last fade_time. Drowned that glide within pool_radius catch fire. Warm OmniLight3D,
## shadows off. Frees itself.

@export var fade_time: float = 2.5

var hub: FireSystem
var life: float = 12.0
var pool_radius: float = 4.0
var energy: float = 3.5

var _t: float = 0.0
var _light: OmniLight3D
var _flames: GPUParticles3D
var _smoke: GPUParticles3D
var _crackle: AudioStreamPlayer3D
var _noise: FastNoiseLite


func _ready() -> void:
	ray_height = 0.6
	_noise = FastNoiseLite.new()
	_noise.seed = 77
	_noise.frequency = 1.0
	_light = FireFx.fire_light(energy, radius, 3.0)
	_light.position.y = 0.8
	add_child(_light)
	_flames = FireFx.flames(pool_radius * 0.55, 90, 1.4, 0.7)
	add_child(_flames)
	var wind: Vector3 = hub.weather.wind() if hub != null and hub.weather != null else Vector3(2.0, 0.0, 1.0)
	_smoke = FireFx.smoke(pool_radius * 0.4, 40, 5.0, wind)
	_smoke.position.y = 1.2
	add_child(_smoke)
	if hub != null and hub.audio != null:
		_crackle = hub.audio.make_crackle(self)


func _physics_process(delta: float) -> void:
	_t += delta
	strength = clampf((life - _t) / maxf(fade_time, 0.01), 0.0, 1.0)
	if strength > 0.2 and hub != null and hub.enemies != null:
		for d: Drowned in hub.enemies.living():
			var p: Vector3 = d.global_position
			if Vector2(p.x - global_position.x, p.z - global_position.z).length() <= pool_radius:
				d.ignite()
	if _t >= life:
		queue_free()


func _process(_delta: float) -> void:
	var f: float = _noise.get_noise_1d(_t * 8.0)
	_light.light_energy = energy * strength * (1.0 + 0.25 * f)
	_flames.amount_ratio = clampf(strength, 0.05, 1.0)
	_flames.emitting = strength > 0.02
	_smoke.emitting = strength > 0.02
	if _crackle != null:
		_crackle.volume_db = -4.0 + linear_to_db(maxf(strength, 0.001))
