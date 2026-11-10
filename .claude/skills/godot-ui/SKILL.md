---
name: godot-ui
description: ALWAYS use when building or changing anything made of Control nodes in this Godot 4.7 project - HUD elements, prompts, the title screen, pause menu, settings, death / dawn / end cards, credits, text, fonts, a Theme, focus or gamepad navigation, fades between screens - and when saving player settings (volume, mouse sensitivity, fullscreen). Gives the code-only UI structure, the pause and focus rules, a settings file pattern, and how to test and review a screen.
---

# UI in pure code (Control nodes, no .tscn)

Read "HUD (no clutter)" in SPEC.md section 2 first. The world carries the information; UI is the
exception and stays small, quiet and cold-coloured.

## Structure
- Today `PostFx` (`CanvasLayer`, layer 10) holds the film pass, the `Reticle`, the ammo tally and the end
  card. Small HUD additions go there as `Control`s. A new screen (title, pause, settings) is its own
  `class_name` script under `res://src/ui/`, a `CanvasLayer` on layer 20 so it sits above the grain.
- Inside: one full-screen root `Control`, then **containers** (`MarginContainer`, `CenterContainer`,
  `VBoxContainer`, `HBoxContainer`). Never position a widget with pixel coordinates.
- One `Theme` built once in code and set on the root: font, sizes, colours. Per-widget overrides
  (`add_theme_font_size_override("font_size", 28)`, `add_theme_color_override("font_color", c)`) only for
  a true one-off.
- HUD controls never take the mouse: `mouse_filter = Control.MOUSE_FILTER_IGNORE` on the root and its children.

```gdscript
func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS          # menus must run while the tree is paused
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme()
	add_child(root)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	centre.add_child(column)
	for entry: String in ["Resume", "Settings", "Quit"]:
		var b: Button = Button.new()
		b.text = entry
		b.pressed.connect(_on_pressed.bind(entry))
		column.add_child(b)
	(column.get_child(0) as Button).grab_focus()     # keyboard and gamepad work from here on
```

## Pause, focus, fades
- Pause: `get_tree().paused = true`, `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`; on resume
  `MOUSE_MODE_CAPTURED`. Game nodes stay at the default process mode so they stop on their own.
- A tween inside a menu: `create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)`.
- The first widget of every screen gets `grab_focus()`. Containers give arrow-key and stick navigation for
  free; `ui_accept` and `ui_cancel` are built in. Esc backs out one level, and from play opens pause.
- Show and hide by fading `modulate.a` (0.3 s for menus, 0.6 to 1.0 s for cards). A card holds for
  1.5 s before its hint line ("Enter: again") fades in, so a held key cannot skip it.
- Text over the storm: at least 20 px at 900p, off-white `(0.86, 0.88, 0.90)`, on a soft dark gradient
  band when the frame behind it is bright. No outlines, no drop-shadow stacks, no warm colours.

## Settings (`user://settings.cfg`)
```gdscript
const PATH: String = "user://settings.cfg"

static func save_value(key: String, value: Variant) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)                                   # a missing file is fine
	cfg.set_value("settings", key, value)
	cfg.save(PATH)

static func load_float(key: String, fallback: float) -> float:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return fallback
	var v: Variant = cfg.get_value("settings", key, fallback)
	return float(v) if v is float or v is int else fallback
```
- Apply: `AudioServer.set_bus_volume_linear(0, volume)`; `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)`
  or `WINDOW_MODE_WINDOWED`; mouse sensitivity and FOV into the `@export`s that already hold them.
- Captures and sims must look the same on every machine: skip loading the file when a `--shot` or
  `--plan` argument is present, and never let a game rule read a setting.

## The shell a shippable game needs
Title (start, settings, quit) -> play -> pause (resume, settings, quit to title) -> death card / dawn card
(restart hint) -> credits (from `ASSETS.md`). Build them one per cycle, as polish.

## Test and review
- Telemetry: `ui.screen` (a string) plus one flag per card, so a plan can press `ui_cancel` and expect
  `ui.screen==pause`.
- One `--shot` preset per screen; `tools/capture.sh <preset>` and read the `strip` for a fade.
- Art-director, one round, with the question "is this legible at a glance and does it leave the frame alone?"
