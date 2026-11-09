class_name Player
extends CharacterBody3D
## First-person player (SPEC §4.4): walk, sprint, mouse look, no jump, shore block, HP.

signal died

@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.6
@export var accel: float = 14.0
@export var gravity: float = 9.81
@export var eye_height: float = 1.62
@export var capsule_radius: float = 0.35
@export var capsule_height: float = 1.75
@export var mouse_sens_deg: float = 0.12
@export var pitch_limit_deg: float = 85.0
@export var max_hp: int = 3
@export var invuln_time: float = 1.5
@export var interact_radius: float = 1.8
@export var shore_lookahead: float = 0.45
@export var inside_radius: float = 2.6

var island: Island
var head: Node3D
var camera: PlayerCamera
var hp: int = 3
var god: bool = false
var sprinting: bool = false
var in_light: bool = false
var invuln_left: float = 0.0
## Shot presets are deterministic captures: real mouse/keys over the window must not move the camera.
var input_locked: bool = false

var _yaw_deg: float = 180.0
var _pitch_deg: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = capsule_radius
	shape.height = capsule_height
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = capsule_height * 0.5
	add_child(cs)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = eye_height
	add_child(head)
	camera = PlayerCamera.new()
	camera.name = "PlayerCamera"
	camera.player = self
	head.add_child(camera)
	camera.current = true
	hp = max_hp


func setup(isl: Island, start_xz: Vector2, look: Vector2, god_mode: bool) -> void:
	island = isl
	god = god_mode
	position = Vector3(start_xz.x, isl.height_at(start_xz.x, start_xz.y) + 0.05, start_xz.y)
	_yaw_deg = look.x
	_pitch_deg = clampf(look.y, -pitch_limit_deg, pitch_limit_deg)
	_apply_look()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_yaw_deg -= mm.relative.x * mouse_sens_deg
		_pitch_deg = clampf(_pitch_deg - mm.relative.y * mouse_sens_deg, -pitch_limit_deg, pitch_limit_deg)
		_apply_look()
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_look() -> void:
	rotation_degrees.y = _yaw_deg
	if head != null:
		head.rotation_degrees.x = _pitch_deg


func _physics_process(delta: float) -> void:
	invuln_left = maxf(0.0, invuln_left - delta)
	var alive: bool = is_alive() and not input_locked
	var iv: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back") if alive else Vector2.ZERO
	var dir: Vector3 = (global_transform.basis * Vector3(iv.x, 0.0, iv.y))
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.ZERO
	sprinting = alive and Input.is_action_pressed("sprint") and Input.is_action_pressed("move_forward") and is_on_floor()
	var target: Vector3 = dir * (sprint_speed if sprinting else walk_speed)
	var hv: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * delta)
	hv = _shore_block(hv)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= gravity * delta
	move_and_slide()


## The player can't walk onto ground lower than Island.shore_block_height: remove the seaward
## component of the velocity when the ground just ahead is too low.
func _shore_block(hv: Vector3) -> Vector3:
	if island == null or hv.length() < 0.001:
		return hv
	var ahead: Vector3 = global_position + hv.normalized() * shore_lookahead
	if island.height_at(ahead.x, ahead.z) >= island.shore_block_height:
		return hv
	var down2: Vector2 = island.downhill(ahead.x, ahead.z)
	var down: Vector3 = Vector3(down2.x, 0.0, down2.y)
	var outward: float = hv.dot(down)
	if outward > 0.0:
		hv -= down * outward
	return hv


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_alive() -> bool:
	return hp > 0


func is_inside_lighthouse() -> bool:
	return Vector2(global_position.x, global_position.z).length() < inside_radius and global_position.y > 4.5


## Damage hook for M3 (contacts / tower reach).
func take_hit() -> void:
	if not is_alive() or invuln_left > 0.0:
		return
	invuln_left = invuln_time
	camera.add_trauma(0.6)
	if god:
		return
	hp -= 1
	if hp <= 0:
		died.emit()


func yaw_deg() -> float:
	return fposmod(_yaw_deg, 360.0)


func pitch_deg() -> float:
	return _pitch_deg


func telemetry() -> Dictionary:
	var p: Vector3 = global_position
	return {
		"pos": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
		"yaw_deg": snappedf(yaw_deg(), 0.001),
		"pitch_deg": snappedf(_pitch_deg, 0.001),
		"speed": snappedf(horizontal_speed(), 0.001),
		"on_floor": is_on_floor(),
		"sprinting": sprinting,
		"hp": hp,
		"max_hp": max_hp,
		"alive": is_alive(),
		"invuln": invuln_left > 0.0,
		"in_light": in_light,
		"inside_lighthouse": is_inside_lighthouse(),
	}
