class_name FrameSnapper
extends Node
## Harness: saves chosen rendered frames as PNG and quits after the last one (tools/capture.sh).
##   -- --snap=<dir> --snap_frames=0,30,59
## Run with --fixed-fps so frame N is always the same instant. Much faster than Movie Maker, which
## encodes every frame: only the frames somebody will look at are written.
## Files are named like Movie Maker's (f00000030.png) so the rest of the harness is unchanged.

var dir_path: String = ""
var frames: PackedInt32Array = []
var saved: int = 0

var _frame: int = 0


func setup(dir: String, frame_list: String) -> void:
	dir_path = dir if dir.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(dir)
	for part: String in frame_list.split(",", false):
		if part.is_valid_int() and not frames.has(part.to_int()):
			frames.append(part.to_int())
	frames.sort()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if frames.is_empty():
		push_error("FrameSnapper: --snap_frames is empty")
		return
	DirAccess.make_dir_recursive_absolute(dir_path)
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)


func _on_frame_drawn() -> void:
	if frames.has(_frame):
		var img: Image = get_viewport().get_texture().get_image()
		if img == null or img.is_empty():
			push_error("FrameSnapper: frame %d could not be read back" % _frame)
		else:
			img.convert(Image.FORMAT_RGB8)
			img.save_png(dir_path.path_join("f%08d.png" % _frame))
		saved += 1
		if saved >= frames.size():
			get_tree().quit()
	_frame += 1
