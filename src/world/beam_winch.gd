class_name BeamWinch
extends Node3D
## The lens winch at the back of the lighthouse (code-built ironwork: drum, frame, crank). Hold E within
## reach for hold_time seconds to throw the beam into overdrive (Lighthouse.start_overdrive): for 10 s it
## drops, widens, burns twice as hot and follows your view. One charge per wave; the drum's brass pawl
## glints while a charge is ready. It sits on the far side of the tower from the door, so using it means
## leaving the doorway.

@export var reach: float = 1.9
@export var hold_time: float = 1.2
@export var max_charges: int = 1
@export var click_every: float = 0.2

var lighthouse: Lighthouse
var player: Player
var audio: Soundscape
var charges: int = 1
var uses: int = 0

var _hold: float = 0.0
var _click_t: float = 0.0
var _crank: Node3D
var _pawl_mat: StandardMaterial3D


func _ready() -> void:
	charges = max_charges
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = Color(0.055, 0.05, 0.048)
	iron.metallic = 0.75
	iron.roughness = 0.5
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.09, 0.065, 0.045)
	wood.roughness = 0.85
	for x: float in [-0.42, 0.42]:
		var post: BoxMesh = BoxMesh.new()
		post.size = Vector3(0.08, 1.0, 0.08)
		var pm: MeshInstance3D = MeshInstance3D.new()
		pm.mesh = post
		pm.material_override = wood
		pm.position = Vector3(x, 0.5, 0.0)
		add_child(pm)
	var drum: CylinderMesh = CylinderMesh.new()
	drum.top_radius = 0.18
	drum.bottom_radius = 0.18
	drum.height = 0.72
	var dm: MeshInstance3D = MeshInstance3D.new()
	dm.mesh = drum
	dm.material_override = iron
	dm.position.y = 0.85
	dm.rotation_degrees.z = 90.0
	add_child(dm)
	# Cable running up the wall toward the lantern room.
	var cable: CylinderMesh = CylinderMesh.new()
	cable.top_radius = 0.008
	cable.bottom_radius = 0.008
	cable.height = 6.0
	var cm: MeshInstance3D = MeshInstance3D.new()
	cm.mesh = cable
	cm.material_override = iron
	cm.position = Vector3(0.0, 3.85, 0.18)
	cm.rotation_degrees.x = -4.0
	add_child(cm)
	_crank = Node3D.new()
	_crank.position = Vector3(0.46, 0.85, 0.0)
	add_child(_crank)
	var arm: BoxMesh = BoxMesh.new()
	arm.size = Vector3(0.04, 0.3, 0.04)
	var am: MeshInstance3D = MeshInstance3D.new()
	am.mesh = arm
	am.material_override = iron
	am.position.y = 0.15
	_crank.add_child(am)
	var handle: CylinderMesh = CylinderMesh.new()
	handle.top_radius = 0.022
	handle.bottom_radius = 0.022
	handle.height = 0.16
	var hm: MeshInstance3D = MeshInstance3D.new()
	hm.mesh = handle
	hm.material_override = wood
	hm.position = Vector3(0.08, 0.3, 0.0)
	hm.rotation_degrees.z = 90.0
	_crank.add_child(hm)
	_pawl_mat = StandardMaterial3D.new()
	_pawl_mat.albedo_color = Color(0.3, 0.24, 0.12)
	_pawl_mat.metallic = 0.9
	_pawl_mat.roughness = 0.3
	var pawl: BoxMesh = BoxMesh.new()
	pawl.size = Vector3(0.05, 0.05, 0.12)
	var pwm: MeshInstance3D = MeshInstance3D.new()
	pwm.mesh = pawl
	pwm.material_override = _pawl_mat
	pwm.position = Vector3(-0.42, 1.05, 0.0)
	add_child(pwm)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.95, 1.0, 0.4)
	cs.shape = shape
	cs.position.y = 0.5
	body.add_child(cs)
	add_child(body)


func in_reach() -> bool:
	return player != null and player.is_alive() and player.global_position.distance_to(global_position) <= reach


## WaveDirector.wave_started.
func recharge() -> void:
	charges = max_charges


func _physics_process(delta: float) -> void:
	var holding: bool = in_reach() and charges > 0 and not player.input_locked and Input.is_action_pressed("interact")
	if not holding:
		_hold = 0.0
		return
	_hold += delta
	_crank.rotation.x -= delta * TAU / hold_time
	_click_t -= delta
	if _click_t <= 0.0 and audio != null:
		_click_t = click_every
		audio.play_reload_click()
	if _hold >= hold_time:
		_hold = 0.0
		charges -= 1
		uses += 1
		if audio != null:
			audio.play_bolt()
		if lighthouse != null:
			lighthouse.start_overdrive(player)


func _process(_delta: float) -> void:
	_pawl_mat.emission_enabled = charges > 0
	_pawl_mat.emission = Color(0.9, 0.7, 0.4)
	_pawl_mat.emission_energy_multiplier = 0.25 if charges > 0 else 0.0


func telemetry() -> Dictionary:
	return {"charges": charges, "uses": uses, "hold": snappedf(_hold, 0.01)}
