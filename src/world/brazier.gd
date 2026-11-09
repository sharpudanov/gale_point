class_name Brazier
extends Node3D
## An iron signal brazier on the shore (code-built ironwork: three legs and a basket of tarred coal). Unlit
## until fire reaches it: a burning flare coming to rest within ignite_radius, a fire burst, or a burning
## Drowned stumbling into it. Then it burns for burn_time seconds as a big gameplay light (GameLight), three
## times as long as a flare, which is why it is worth walking out to. Re-fuelled at the start of each wave.

@export var burn_time: float = 60.0
@export var fade_time: float = 5.0
@export var light_radius: float = 11.0
@export var light_dps: float = 12.0
@export var light_energy: float = 4.0
@export var light_range: float = 11.0
@export var ignite_radius: float = 2.5
@export var bowl_height: float = 1.25

var enemies: Enemies
var field: LightField
var audio: Soundscape
var weather: StormWeather
var lit: bool = false
var fuel: float = 1.0          ## 1 = full, 0 = spent until the next wave
var lightings: int = 0

var _burn_left: float = 0.0
var _gl: GameLight
var _light: OmniLight3D
var _flames: GPUParticles3D
var _smoke: GPUParticles3D
var _crackle: AudioStreamPlayer3D
var _coal_mat: StandardMaterial3D
var _noise: FastNoiseLite
var _t: float = 0.0


func _ready() -> void:
	add_to_group(FireSystem.BURNABLE)
	_noise = FastNoiseLite.new()
	_noise.seed = 31
	_noise.frequency = 1.0
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = Color(0.05, 0.047, 0.045)
	iron.metallic = 0.75
	iron.roughness = 0.5
	var leg: CylinderMesh = CylinderMesh.new()
	leg.top_radius = 0.03
	leg.bottom_radius = 0.04
	leg.height = bowl_height + 0.1
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = leg
		mi.material_override = iron
		mi.position = Vector3(cos(a) * 0.22, bowl_height * 0.5, sin(a) * 0.22)
		mi.rotation = Vector3(sin(a) * 0.2, 0.0, -cos(a) * 0.2)
		add_child(mi)
	var bowl: CylinderMesh = CylinderMesh.new()
	bowl.top_radius = 0.45
	bowl.bottom_radius = 0.22
	bowl.height = 0.32
	bowl.cap_top = false
	var bm: MeshInstance3D = MeshInstance3D.new()
	bm.mesh = bowl
	bm.material_override = iron
	bm.position.y = bowl_height
	add_child(bm)
	for h: float in [0.12, 0.3]:
		var band: TorusMesh = TorusMesh.new()
		band.inner_radius = 0.3 + h * 0.45
		band.outer_radius = 0.34 + h * 0.45
		var rm: MeshInstance3D = MeshInstance3D.new()
		rm.mesh = band
		rm.material_override = iron
		rm.position.y = bowl_height - 0.16 + h
		add_child(rm)
	_coal_mat = StandardMaterial3D.new()
	_coal_mat.albedo_color = Color(0.03, 0.028, 0.026)
	_coal_mat.roughness = 0.9
	_coal_mat.emission_enabled = true
	_coal_mat.emission = Color(1.0, 0.45, 0.15)
	_coal_mat.emission_energy_multiplier = 0.0
	var coal: SphereMesh = SphereMesh.new()
	coal.radius = 0.38
	coal.height = 0.3
	var cm: MeshInstance3D = MeshInstance3D.new()
	cm.mesh = coal
	cm.material_override = _coal_mat
	cm.position.y = bowl_height + 0.08
	add_child(cm)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = bowl_height + 0.2
	cs.shape = shape
	cs.position.y = (bowl_height + 0.2) * 0.5
	body.add_child(cs)
	add_child(body)
	_light = FireFx.fire_light(light_energy, light_range, 2.5)
	_light.position.y = bowl_height + 0.7
	_light.visible = false
	add_child(_light)
	_flames = FireFx.flames(0.32, 90, 1.5, 0.4)
	_flames.position.y = bowl_height + 0.15
	_flames.emitting = false
	add_child(_flames)
	var wind: Vector3 = weather.wind() if weather != null else Vector3(2.0, 0.0, 1.0)
	_smoke = FireFx.smoke(0.25, 50, 6.0, wind)
	_smoke.position.y = bowl_height + 0.8
	_smoke.emitting = false
	add_child(_smoke)


## Burnable: fire reached it.
func ignite() -> void:
	if lit or fuel <= 0.0:
		return
	lit = true
	lightings += 1
	_burn_left = burn_time * fuel
	_gl = GameLight.new()
	_gl.name = "BrazierLight"
	_gl.field = field
	_gl.radius = light_radius
	_gl.dps = light_dps
	_gl.ray_height = 0.0
	_gl.position.y = bowl_height + 0.5
	add_child(_gl)
	_light.visible = true
	_flames.emitting = true
	_smoke.emitting = true
	if audio != null and _crackle == null:
		_crackle = audio.make_crackle(self)
		_crackle.position.y = bowl_height


func _put_out() -> void:
	lit = false
	fuel = 0.0
	if _gl != null:
		_gl.queue_free()
		_gl = null
	_light.visible = false
	_flames.emitting = false
	_smoke.emitting = false
	if _crackle != null:
		_crackle.queue_free()
		_crackle = null


## WaveDirector.wave_started: fresh tar and coal (an unlit brazier just stays ready).
func refuel() -> void:
	if not lit:
		fuel = 1.0


func burn_strength() -> float:
	return clampf(_burn_left / maxf(fade_time, 0.01), 0.0, 1.0) if lit else 0.0


func _physics_process(delta: float) -> void:
	if lit:
		_burn_left -= delta
		if _gl != null:
			_gl.strength = burn_strength()
		if _burn_left <= 0.0:
			_put_out()
		return
	if fuel <= 0.0:
		return
	var bowl: Vector3 = global_position + Vector3(0.0, bowl_height, 0.0)
	if field != null:
		for f: Flare in field.flares:
			if f.state == "resting" and f.burn > 0.3 and Vector2(f.global_position.x - bowl.x, f.global_position.z - bowl.z).length() < ignite_radius:
				ignite()
				return
	if enemies != null:
		for d: Drowned in enemies.living():
			if d.burning and Vector2(d.global_position.x - bowl.x, d.global_position.z - bowl.z).length() < 2.0:
				ignite()
				return


func _process(delta: float) -> void:
	_t += delta
	var s: float = burn_strength()
	var f: float = _noise.get_noise_1d(_t * 7.0)
	_light.light_energy = light_energy * s * (1.0 + 0.22 * f)
	_coal_mat.emission_energy_multiplier = 2.5 * s * (1.0 + 0.3 * f)
	_flames.amount_ratio = clampf(s, 0.05, 1.0)
