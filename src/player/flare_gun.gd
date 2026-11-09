class_name FlareGun
extends Node3D
## Break-action flare pistol (SPEC 4.6): 3 flares, 1.5 s break-open reload after each shot.
## Launches `Flare` nodes into the Projectiles container.

signal ammo_changed

@export var flares_start: int = 3
@export var flares_max: int = 3
@export var reload_time: float = 1.5
@export var launch_speed: float = 32.0
@export var kick_back: float = 0.07
@export var kick_rot_deg: float = 9.0
@export var kick_spring: float = 16.0
@export var kick_damping: float = 0.65
@export var recoil_pitch_deg: float = 1.6
@export var break_open_deg: float = 28.0

## "ready", "reloading", "empty"
var state: String = "ready"
var left: int = 3
var fired: int = 0
var drowned: int = 0

var _camera: PlayerCamera
var _player: Player
var _projectiles: Node3D
var _ocean: Ocean
var _field: LightField
var _audio: Soundscape
var _weather: StormWeather
var _model: Node3D
var _barrels: Node3D
var _hammer: Node3D
var _muzzle: Marker3D
var _reload_t: float = 0.0
var _kick: float = 0.0
var _kick_v: float = 0.0
var _open: float = 0.0


func setup(camera: PlayerCamera, player: Player, projectiles: Node3D, ocean: Ocean, field: LightField, audio: Soundscape, weather: StormWeather) -> void:
	_camera = camera
	_player = player
	_projectiles = projectiles
	_ocean = ocean
	_field = field
	_audio = audio
	_weather = weather


func _ready() -> void:
	left = flares_start
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var gun: Node3D = ViewmodelBuilder.flare_gun()
	_model.add_child(gun)
	_barrels = gun.get_node("Barrels") as Node3D
	_hammer = gun.get_node("Hammer") as Node3D
	_muzzle = gun.get_node("Muzzle") as Marker3D


func try_fire() -> bool:
	if state != "ready" or left <= 0:
		return false
	left -= 1
	fired += 1
	var fwd: Vector3 = -_camera.global_transform.basis.z
	var origin: Vector3 = _muzzle.global_position
	spawn_flare(origin, fwd * launch_speed, 0.0)
	_audio.play_flare_launch(origin)
	_camera.add_recoil(recoil_pitch_deg, 0.0)
	_kick = 1.0
	_kick_v = 0.0
	state = "reloading" if left > 0 else "empty"
	_reload_t = 0.0
	ammo_changed.emit()
	return true


## Also used by --place_flare (age > 0, zero velocity = already resting; no ammo used).
func spawn_flare(pos: Vector3, vel: Vector3, age: float) -> Flare:
	var f: Flare = Flare.new()
	f.name = "Flare"
	f.setup(vel, _ocean, _field, _audio, _weather, age)
	f.sank.connect(_on_flare_sank)
	_projectiles.add_child(f)
	f.global_position = pos
	return f


func _on_flare_sank() -> void:
	drowned += 1


func add_flares(n: int) -> void:
	left = mini(left + n, flares_max)
	if state == "empty" and left > 0:
		state = "reloading"
		_reload_t = 0.0
	ammo_changed.emit()


func cancel_reload() -> void:
	pass  # the break-action reload simply keeps running while holstered


func _physics_process(delta: float) -> void:
	if state == "reloading":
		_reload_t += delta
		if _reload_t >= reload_time:
			state = "ready"
			_audio.play_reload_click()
			ammo_changed.emit()


func _process(delta: float) -> void:
	var accel: float = -kick_spring * kick_spring * _kick - 2.0 * kick_damping * kick_spring * _kick_v
	_kick_v += accel * delta
	_kick += _kick_v * delta
	# Break open during the middle of the reload (hinge down, then close).
	var target_open: float = 0.0
	if state == "reloading":
		var k: float = _reload_t / reload_time
		target_open = smoothstep(0.1, 0.3, k) * (1.0 - smoothstep(0.75, 0.95, k))
	elif state == "empty":
		target_open = 1.0
	_open = lerpf(_open, target_open, 1.0 - exp(-14.0 * delta))
	_barrels.rotation_degrees.x = -break_open_deg * _open
	_hammer.rotation_degrees.x = 10.0 if state == "ready" else -25.0  # cocked back when ready
	_model.position = Vector3(0.0, 0.0, kick_back * _kick)
	_model.rotation_degrees = Vector3(kick_rot_deg * _kick, 0.0, 0.0)
