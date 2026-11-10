class_name InputSetup
extends RefCounted
## Builds the input map in code (SPEC §2). project.godot is never edited. No jump: Space is unbound.


static func ensure() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("sprint", KEY_SHIFT)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_key("reload", KEY_R)
	_key("interact", KEY_E)
	_key("weapon_rifle", KEY_1)
	_key("weapon_flare", KEY_2)
	_key("weapon_toggle", KEY_Q)
	_mouse("weapon_toggle", MOUSE_BUTTON_WHEEL_UP)
	_mouse("weapon_toggle", MOUSE_BUTTON_WHEEL_DOWN)
	_key("release_mouse", KEY_ESCAPE)
	_key("restart", KEY_ENTER)
	_key("fullscreen", KEY_F11)
	_key("screenshot", KEY_F12)
	_key("screenshot", KEY_P)
	_key("melee", KEY_F)            # rifle-butt shove
	_key("melee", KEY_V)
	_key("dev_spawn", KEY_F1)       # live sandbox (normal play only, see Sandbox)
	_key("dev_flare", KEY_F2)
	_key("dev_god", KEY_F3)
	_key("dev_wave", KEY_F4)


static func _add_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


static func _key(action: StringName, code: Key) -> void:
	_add_action(action)
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == code:
			return
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = code
	InputMap.action_add_event(action, k)


static func _mouse(action: StringName, button: MouseButton) -> void:
	_add_action(action)
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == button:
			return
	var m: InputEventMouseButton = InputEventMouseButton.new()
	m.button_index = button
	InputMap.action_add_event(action, m)
