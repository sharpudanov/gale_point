class_name PlayerCamera
extends Camera3D
## First-person camera (SPEC §4.4): head bob, wind roll, hit shake, recoil hook, FOV.

@export var fov_hip: float = 72.0
@export var fov_ads: float = 58.0
@export var ads_time: float = 0.2
@export var bob_walk: Vector2 = Vector2(0.030, 1.9)    ## amplitude m, Hz
@export var bob_sprint: Vector2 = Vector2(0.055, 2.6)
@export var bob_lateral: float = 0.5
@export var wind_roll_deg: float = 0.35
@export var wind_roll_hz: float = 0.4
@export var shake_decay: float = 1.5
@export var shake_max_deg: float = 2.5
@export var recoil_recover_time: float = 0.5     ## 95% of a kick is gone after this long...
@export var recoil_residual_add: float = 1.0     ## ...down to a residual that the player has to pull back
@export var recoil_residual_decay: float = 0.5   ## deg/s

var player: Player
var wind_speed: float = 5.0
var ads: bool = false
var recoil_pitch: float = 0.0
var recoil_yaw: float = 0.0
var bob_offset: Vector3 = Vector3.ZERO
var trauma: float = 0.0

var _recoil_residual: float = 0.0
var _bob_phase: float = 0.0
var _bob_amp: float = 0.0
var _t: float = 0.0
var _noise: FastNoiseLite


func _ready() -> void:
	near = 0.01
	far = 600.0
	fov = fov_hip
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = GameRng.next_seed()


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Rifle kick (SPEC §4.5): instant pitch/yaw kick that recovers over recoil_recover_time to a residual.
func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	recoil_pitch += pitch_deg
	recoil_yaw += yaw_deg
	_recoil_residual = minf(_recoil_residual + recoil_residual_add, 2.0 * recoil_residual_add)


func _physics_process(delta: float) -> void:
	_t += delta
	_recoil_residual = maxf(0.0, _recoil_residual - recoil_residual_decay * delta)
	var k: float = 1.0 - exp(-3.0 / recoil_recover_time * delta)
	recoil_pitch = lerpf(recoil_pitch, _recoil_residual, k)
	recoil_yaw = lerpf(recoil_yaw, 0.0, k)
	var speed: float = player.horizontal_speed() if player != null else 0.0
	var on_floor: bool = player.is_on_floor() if player != null else true
	var sprint: bool = player.sprinting if player != null else false
	var params: Vector2 = bob_sprint if sprint else bob_walk
	var ref_speed: float = player.sprint_speed if sprint else (player.walk_speed if player != null else 3.2)
	var move_k: float = clampf(speed / ref_speed, 0.0, 1.0) if on_floor else 0.0
	_bob_amp = lerpf(_bob_amp, params.x * move_k, 1.0 - exp(-8.0 * delta))
	_bob_phase = fmod(_bob_phase + TAU * params.y * delta * maxf(move_k, 0.0), TAU * 2.0)
	bob_offset = Vector3(_bob_amp * bob_lateral * sin(_bob_phase * 0.5), _bob_amp * sin(_bob_phase), 0.0)
	position = bob_offset

	var roll: float = wind_roll_deg * _noise.get_noise_1d(_t * wind_roll_hz) * clampf(wind_speed / 13.0, 0.0, 1.5)
	trauma = maxf(0.0, trauma - shake_decay * delta)
	var sh: float = trauma * trauma * shake_max_deg
	var shake: Vector3 = Vector3(
		_noise.get_noise_2d(_t * 25.0, 10.0),
		_noise.get_noise_2d(_t * 25.0, 20.0),
		_noise.get_noise_2d(_t * 25.0, 30.0)) * sh
	rotation_degrees = Vector3(recoil_pitch + shake.x, recoil_yaw + shake.y, roll + shake.z)

	var target_fov: float = fov_ads if ads else fov_hip
	fov = move_toward(fov, target_fov, absf(fov_hip - fov_ads) / ads_time * delta)
