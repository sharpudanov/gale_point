extends SceneTree
## Image helper for the harness (headless, no GPU): lets Claude see many frames in ONE image and lets
## scripts detect visual changes without a model.
##   sheet out=<png> [cols=4] [cell=384x216] [scale=3] <label>=<png> ...   labelled grid
##   diff  <a.png> <b.png> [out=<png>] [cell=512x288] [la=BEFORE] [lb=AFTER]   metrics (+ a|b|diff x4 image)
##   stat  <png>                                                             brightness of one frame
##   shots dir=<captures dir> base=<baseline dir> out=<dir> [tol=0.5] [ctol=2.0] <preset> ...
##         per preset: mid frame vs its baseline -> SAME / CHANGED / NEW / BLANK / MISSING, a pair image
##         for every CHANGED one, and one labelled contact sheet of all mid frames
## Paths are OS paths or project-relative. Result lines start with IMG_SHEET / IMG_DIFF / IMG_STAT / SHOT.
## mad = mean absolute difference in percent of full scale; changed = percent of pixels that moved clearly.

const BG: Color = Color(0.035, 0.035, 0.04)
const METRIC_W: int = 240
const CHANGED_STEP: int = 20   ## a pixel counts as changed when a channel moves by more than this (0..255)
## 3x5 pixel font, row by row.
const GLYPHS: Dictionary = {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
	"I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
	"Q": "010101101111011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111",
	"0": "111101101101111", "1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
	"4": "101101111001001", "5": "111100110001110", "6": "011100111101111", "7": "111001010010010",
	"8": "111101111101111", "9": "111101111001110",
	"_": "000000000000111", "-": "000000111000000", ".": "000000000000010", "=": "000111000111000",
	":": "000010000010000", "/": "001001010100100", "%": "101001010100101", "+": "000010111010000",
	"|": "010010010010010", "#": "101111101111101",
}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: tools/img.sh sheet|diff|stat|shots ... (see tools/img.gd)")
		quit(2)
		return
	var opts: Dictionary = {}
	var rest: PackedStringArray = []
	for i: int in range(1, args.size()):
		var a: String = args[i]
		var eq: int = a.find("=")
		if eq > 0 and a.substr(0, eq) in ["out", "cols", "cell", "scale", "la", "lb", "dir", "base", "tol", "ctol"]:
			opts[a.substr(0, eq)] = a.substr(eq + 1)
		else:
			rest.append(a)
	var code: int = 0
	match args[0]:
		"sheet":
			code = _cmd_sheet(opts, rest)
		"diff":
			code = _cmd_diff(opts, rest)
		"stat":
			code = _cmd_stat(rest)
		"shots":
			code = _cmd_shots(opts, rest)
		_:
			print("IMG_ERROR unknown command '%s'" % args[0])
			code = 2
	quit(code)


# --- commands -------------------------------------------------------------------------------------

func _cmd_sheet(opts: Dictionary, items: PackedStringArray) -> int:
	var labels: PackedStringArray = []
	var paths: PackedStringArray = []
	for item: String in items:
		var eq: int = item.rfind("=")   # the label itself may contain '=' (sweeps: fog_density=0.012=<png>)
		labels.append(item.substr(0, eq) if eq > 0 else item.get_file().get_basename())
		paths.append(item.substr(eq + 1) if eq > 0 else item)
	if paths.is_empty() or not opts.has("out"):
		print("IMG_ERROR sheet needs out=<png> and at least one <label>=<png>")
		return 2
	var out: String = str(opts["out"])
	var cell: Vector2i = _size(str(opts.get("cell", "384x216")))
	var sheet: Image = _grid(labels, paths, int(str(opts.get("cols", "4"))), cell, int(str(opts.get("scale", "3"))))
	if not _save(sheet, out):
		return 1
	print("IMG_SHEET %s  %dx%d  cells=%d" % [_abs(out), sheet.get_width(), sheet.get_height(), paths.size()])
	return 0


func _cmd_diff(opts: Dictionary, rest: PackedStringArray) -> int:
	if rest.size() < 2:
		print("IMG_ERROR diff needs two images")
		return 2
	var a: Image = _load(rest[0])
	var b: Image = _load(rest[1])
	if a == null or b == null:
		return 1
	var m: Vector2 = _metrics(a, b)
	var line: String = "IMG_DIFF mad=%.2f changed=%.1f" % [m.x, m.y]
	if opts.has("out"):
		var cell: Vector2i = _size(str(opts.get("cell", "512x288")))
		var pair: Image = _pair(a, b, cell, str(opts.get("la", "BEFORE")), str(opts.get("lb", "AFTER")))
		if _save(pair, str(opts["out"])):
			line += "  pair=%s" % _abs(str(opts["out"]))
	print(line)
	return 0


func _cmd_stat(rest: PackedStringArray) -> int:
	if rest.is_empty():
		print("IMG_ERROR stat needs an image")
		return 2
	var img: Image = _load(rest[0])
	if img == null:
		return 1
	var s: Vector2 = _stat(img)
	print("IMG_STAT mean=%.4f dark=%.1f size=%dx%d" % [s.x, s.y, img.get_width(), img.get_height()])
	return 0


func _cmd_shots(opts: Dictionary, presets: PackedStringArray) -> int:
	var dir: String = str(opts.get("dir", ".captures"))
	var base: String = str(opts.get("base", ".captures/_base"))
	var out: String = str(opts.get("out", ".captures/_shots"))
	var tol: float = str(opts.get("tol", "0.5")).to_float()
	var ctol: float = str(opts.get("ctol", "2.0")).to_float()
	DirAccess.make_dir_recursive_absolute(_abs(out))
	var labels: PackedStringArray = []
	var paths: PackedStringArray = []
	for preset: String in presets:
		var mid: String = _mid_frame(dir.path_join(preset))
		if mid.is_empty():
			print("SHOT %-14s MISSING  (no frames in %s)" % [preset, dir.path_join(preset)])
			labels.append("%s MISSING" % preset)
			paths.append("")
			continue
		var img: Image = _load(mid)
		if img == null:
			continue
		var status: String = "NEW"
		var extra: String = ""
		var stat: Vector2 = _stat(img)
		var base_path: String = base.path_join(preset + ".png")
		if stat.x < 0.004:
			status = "BLANK"
			extra = "mean=%.4f" % stat.x
		elif FileAccess.file_exists(_abs(base_path)):
			var ref: Image = _load(base_path)
			var m: Vector2 = _metrics(ref, img)
			status = "CHANGED" if (m.x > tol or m.y > ctol) else "SAME"
			extra = "mad=%.2f changed=%.1f" % [m.x, m.y]
			if status == "CHANGED":
				var pair_path: String = out.path_join(preset + ".pair.png")
				if _save(_pair(ref, img, Vector2i(512, 288), "BASELINE", "NOW"), pair_path):
					extra += "  pair=%s" % _abs(pair_path)
		print("SHOT %-14s %-8s %s" % [preset, status, extra])
		labels.append(preset if status == "SAME" or status == "NEW" else "%s %s" % [preset, status])
		paths.append(mid)
	var sheet_path: String = out.path_join("sheet.png")
	if not paths.is_empty() and _save(_grid(labels, paths, 4, Vector2i(384, 216), 3), sheet_path):
		print("IMG_SHEET %s  (row by row: %s)" % [_abs(sheet_path), ", ".join(presets)])
	return 0


# --- building blocks ------------------------------------------------------------------------------

func _grid(labels: PackedStringArray, paths: PackedStringArray, cols: int, cell: Vector2i, text_scale: int) -> Image:
	cols = clampi(cols, 1, maxi(paths.size(), 1))
	var rows: int = ceili(float(paths.size()) / float(cols))
	var sheet: Image = Image.create_empty(cols * cell.x, rows * cell.y, false, Image.FORMAT_RGB8)
	sheet.fill(BG)
	for i: int in paths.size():
		var origin: Vector2i = Vector2i((i % cols) * cell.x, (i / cols) * cell.y)
		var img: Image = _load(paths[i]) if not paths[i].is_empty() else null
		if img == null:
			sheet.fill_rect(Rect2i(origin, cell), Color(0.25, 0.04, 0.04))
		else:
			_blit_fit(sheet, img, Rect2i(origin, cell))
		_label(sheet, labels[i], origin + Vector2i(4, 4), text_scale)
	return sheet


## a | b | amplified difference, each in one cell.
func _pair(a: Image, b: Image, cell: Vector2i, label_a: String, label_b: String) -> Image:
	var out: Image = Image.create_empty(cell.x * 3, cell.y, false, Image.FORMAT_RGB8)
	out.fill(BG)
	var sa: Image = _fit(a, cell)
	var sb: Image = _fit(b, cell)
	if sb.get_size() != sa.get_size():
		sb.resize(sa.get_width(), sa.get_height(), Image.INTERPOLATE_BILINEAR)
	var off: Vector2i = (cell - sa.get_size()) / 2
	out.blit_rect(sa, Rect2i(Vector2i.ZERO, sa.get_size()), off)
	out.blit_rect(sb, Rect2i(Vector2i.ZERO, sb.get_size()), Vector2i(cell.x, 0) + off)
	var da: PackedByteArray = sa.get_data()
	var db: PackedByteArray = sb.get_data()
	var dd: PackedByteArray = PackedByteArray()
	dd.resize(da.size())
	for i: int in da.size():
		dd[i] = mini(absi(da[i] - db[i]) * 4, 255)
	var diff: Image = Image.create_from_data(sa.get_width(), sa.get_height(), false, Image.FORMAT_RGB8, dd)
	out.blit_rect(diff, Rect2i(Vector2i.ZERO, diff.get_size()), Vector2i(cell.x * 2, 0) + off)
	_label(out, label_a, Vector2i(4, 4), 3)
	_label(out, label_b, Vector2i(cell.x + 4, 4), 3)
	_label(out, "DIFF X4", Vector2i(cell.x * 2 + 4, 4), 3)
	return out


## x = mean absolute difference (% of full scale), y = % of pixels with a clear change.
func _metrics(a: Image, b: Image) -> Vector2:
	var h: int = maxi(1, roundi(float(METRIC_W) * float(a.get_height()) / float(a.get_width())))
	var sa: Image = a.duplicate() as Image
	var sb: Image = b.duplicate() as Image
	sa.resize(METRIC_W, h, Image.INTERPOLATE_BILINEAR)
	sb.resize(METRIC_W, h, Image.INTERPOLATE_BILINEAR)
	var da: PackedByteArray = sa.get_data()
	var db: PackedByteArray = sb.get_data()
	var total: int = 0
	var changed: int = 0
	var pixels: int = METRIC_W * h
	for p: int in pixels:
		var i: int = p * 3
		var d0: int = absi(da[i] - db[i])
		var d1: int = absi(da[i + 1] - db[i + 1])
		var d2: int = absi(da[i + 2] - db[i + 2])
		total += d0 + d1 + d2
		if maxi(d0, maxi(d1, d2)) > CHANGED_STEP:
			changed += 1
	return Vector2(float(total) / float(pixels * 3) / 255.0 * 100.0, float(changed) / float(pixels) * 100.0)


## x = mean brightness (0..1), y = % of pixels that are almost black.
func _stat(img: Image) -> Vector2:
	var h: int = maxi(1, roundi(float(METRIC_W) * float(img.get_height()) / float(img.get_width())))
	var s: Image = img.duplicate() as Image
	s.resize(METRIC_W, h, Image.INTERPOLATE_BILINEAR)
	var d: PackedByteArray = s.get_data()
	var total: int = 0
	var dark: int = 0
	var pixels: int = METRIC_W * h
	for p: int in pixels:
		var i: int = p * 3
		var v: int = d[i] + d[i + 1] + d[i + 2]
		total += v
		if v < 24:
			dark += 1
	return Vector2(float(total) / float(pixels * 3) / 255.0, float(dark) / float(pixels) * 100.0)


func _fit(img: Image, cell: Vector2i) -> Image:
	var k: float = minf(float(cell.x) / float(img.get_width()), float(cell.y) / float(img.get_height()))
	var out: Image = img.duplicate() as Image
	out.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	return out


func _blit_fit(dst: Image, img: Image, rect: Rect2i) -> void:
	var s: Image = _fit(img, rect.size)
	dst.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), rect.position + (rect.size - s.get_size()) / 2)


func _label(img: Image, text: String, at: Vector2i, s: int) -> void:
	var t: String = text.to_upper()
	var width: int = t.length() * 4 * s + s
	img.fill_rect(Rect2i(at, Vector2i(width, 7 * s)).intersection(Rect2i(Vector2i.ZERO, img.get_size())), Color(0.0, 0.0, 0.0))
	for ci: int in t.length():
		var glyph: String = str(GLYPHS.get(t[ci], ""))
		if glyph.is_empty():
			continue
		for bit: int in 15:
			if glyph[bit] == "1":
				var px: Vector2i = at + Vector2i(s + ci * 4 * s + (bit % 3) * s, s + (bit / 3) * s)
				img.fill_rect(Rect2i(px, Vector2i(s, s)).intersection(Rect2i(Vector2i.ZERO, img.get_size())), Color(1.0, 1.0, 1.0))


func _mid_frame(dir: String) -> String:
	var d: DirAccess = DirAccess.open(_abs(dir))
	if d == null:
		return ""
	var frames: PackedStringArray = []
	for f: String in d.get_files():
		if f.begins_with("f") and f.ends_with(".png"):
			frames.append(f)
	if frames.is_empty():
		return ""
	frames.sort()
	return dir.path_join(frames[frames.size() / 2])


func _size(text: String) -> Vector2i:
	var parts: PackedStringArray = text.split("x")
	return Vector2i(parts[0].to_int(), parts[1].to_int()) if parts.size() == 2 else Vector2i(384, 216)


func _abs(path: String) -> String:
	return path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)


func _load(path: String) -> Image:
	var img: Image = Image.load_from_file(_abs(path))
	if img == null or img.is_empty():
		print("IMG_ERROR cannot load %s" % path)
		return null
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(img: Image, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(_abs(path).get_base_dir())
	if img.save_png(_abs(path)) != OK:
		print("IMG_ERROR cannot write %s" % path)
		return false
	return true
