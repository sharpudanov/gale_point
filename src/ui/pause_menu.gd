class_name PauseMenu
extends CanvasLayer
## Esc opens it and pauses the night: Resume, Restart night, Fullscreen, Quit. F11 toggles fullscreen at
## any time. It also makes the UI scale with the window, so the game can be resized or maximised.
## Built only in normal play (no --shot preset), like the Sandbox.

@export var base_size: Vector2i = Vector2i(1600, 900)   ## UI is laid out for this size and scales from it
@export var dim_color: Color = Color(0.02, 0.03, 0.05, 0.72)
@export var text_color: Color = Color(0.86, 0.88, 0.90)
@export var title_size: int = 44
@export var button_size: int = 26
@export var button_width: float = 300.0
@export var fade_time: float = 0.2

var is_open: bool = false
var opens: int = 0
var restarts: int = 0

var _root: Control
var _first: Button
var _fullscreen_button: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _headless():
		var win: Window = get_window()
		win.content_scale_size = base_size
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = dim_color
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)
	var title: Label = Label.new()
	title.text = "Gale Point"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", text_color)
	column.add_child(title)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 18.0)
	column.add_child(gap)
	_first = _button(column, "Resume", close)
	_button(column, "Restart night", restart)
	_fullscreen_button = _button(column, "Fullscreen  (F11)", toggle_fullscreen)
	_button(column, "Quit", _quit)
	var keys: Label = Label.new()
	keys.text = "WASD move   Shift sprint   Mouse aim / fire   Q swap   F shove   E use"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_font_size_override("font_size", 16)
	keys.add_theme_color_override("font_color", Color(text_color, 0.55))
	column.add_child(keys)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("release_mouse"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open:
		return
	is_open = true
	opens += 1
	get_tree().paused = true
	_root.visible = true
	_root.modulate.a = 0.0
	var tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_root, "modulate:a", 1.0, fade_time)
	if not _headless():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_first.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	get_tree().paused = false
	if not _headless():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func restart() -> void:
	restarts += 1
	get_tree().paused = false
	get_tree().reload_current_scene()


func toggle_fullscreen() -> void:
	if _headless():
		return
	var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func telemetry() -> Dictionary:
	return {"paused": is_open, "opens": opens, "restarts": restarts}


func _quit() -> void:
	get_tree().quit()


func _button(parent: Control, label: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(button_width, 0.0)
	b.add_theme_font_size_override("font_size", button_size)
	b.add_theme_color_override("font_color", text_color)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"
