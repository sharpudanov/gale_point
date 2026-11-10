class_name BellBuoys
extends Node3D
## Offshore sea-bell buoys (DESIGN_LOG iteration 1): a ring of rusted iron bell buoys riding the swell. When
## the WaveDirector warns of a wave, the buoy nearest that wave's sector tolls once per wave number (wave 3 =
## three strokes), so the player hears where the next wave will rise before it does. Each stroke swings the
## bell and flashes a small cold lamp (emission plus a tiny light without shadows).

const METAL_DIR: String = "res://assets/textures/rusty_metal_02/rusty_metal_02_%s_1k.jpg"

@export var buoy_scale: float = 1.6
@export var stroke_gap: float = 1.2
@export var swing_deg: float = 25.0
@export var swing_decay: float = 2.2
@export var float_offset: float = -0.35       ## hull sits this far into the water
@export var tilt_gain: float = 0.6            ## how much the hull follows the wave slope
@export var lamp_color: Color = Color(0.72, 0.8, 0.9)
@export var lamp_idle_energy: float = 2.5
@export var lamp_flash_energy: float = 9.0
@export var lamp_light_energy: float = 8.0     ## toll flash
@export var lamp_idle_light: float = 5.0     ## marker blink
@export var lamp_light_range: float = 18.0
@export var blink_period: float = 3.0         ## idle navigation blink...
@export var blink_on: float = 1.2             ## ...seconds lit per period
@export var flash_decay: float = 0.8          ## 1/s fade of the toll flash

var ocean: Ocean
var audio: Soundscape
var tolls: int = 0
var strokes: int = 0
var last_buoy: int = -1

var _buoys: Array[Node3D] = []
var _bells: Array[Node3D] = []
var _lamp_mats: Array[StandardMaterial3D] = []
var _lamp_lights: Array[OmniLight3D] = []
var _swing: PackedFloat32Array = PackedFloat32Array()
var _flash: PackedFloat32Array = PackedFloat32Array()
var _pending: Array[Dictionary] = []   ## {buoy, t}
var _t: float = 0.0


func setup(oc: Ocean, snd: Soundscape) -> void:
	ocean = oc
	audio = snd


func _ready() -> void:
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.17, 0.15)
	if ResourceLoader.exists(METAL_DIR % "diff"):
		iron.albedo_texture = load(METAL_DIR % "diff") as Texture2D
	iron.metallic = 0.6
	iron.roughness = 0.6
	var hull_mat: StandardMaterial3D = iron.duplicate() as StandardMaterial3D
	hull_mat.albedo_color = Color(0.42, 0.3, 0.24)   # weathered oxide paint, lighter than the sea
	var bronze: StandardMaterial3D = StandardMaterial3D.new()
	bronze.albedo_color = Color(0.22, 0.19, 0.13)
	bronze.metallic = 0.85
	bronze.roughness = 0.4
	var pts: PackedVector2Array = MapLayout.buoy_points()   # map/layout.tscn
	for i: int in pts.size():
		var b: Node3D = Node3D.new()
		b.name = "Buoy%d" % i
		b.position = Vector3(pts[i].x, 0.0, pts[i].y)
		b.scale = Vector3.ONE * buoy_scale
		add_child(b)
		# Hull: a squat float with a cone skirt.
		var hull: CylinderMesh = CylinderMesh.new()
		hull.top_radius = 0.9
		hull.bottom_radius = 1.1
		hull.height = 0.9
		_mesh(b, hull, hull_mat, Vector3(0.0, 0.2, 0.0))
		var skirt: CylinderMesh = CylinderMesh.new()
		skirt.top_radius = 0.55
		skirt.bottom_radius = 0.9
		skirt.height = 0.35
		_mesh(b, skirt, hull_mat, Vector3(0.0, 0.82, 0.0))
		# Cage: four iron posts and a top ring.
		var post: CylinderMesh = CylinderMesh.new()
		post.top_radius = 0.035
		post.bottom_radius = 0.045
		post.height = 2.3
		for k: int in 4:
			var pa: float = TAU * float(k) / 4.0 + PI * 0.25
			var mi: MeshInstance3D = _mesh(b, post, iron, Vector3(cos(pa) * 0.42, 2.0, sin(pa) * 0.42))
			mi.rotation = Vector3(sin(pa) * 0.12, 0.0, -cos(pa) * 0.12)
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.26
		ring.outer_radius = 0.32
		_mesh(b, ring, iron, Vector3(0.0, 3.1, 0.0))
		# Bell on a pivot under the top ring.
		var pivot: Node3D = Node3D.new()
		pivot.name = "BellPivot"
		pivot.position.y = 3.0
		b.add_child(pivot)
		var bell: CylinderMesh = CylinderMesh.new()
		bell.top_radius = 0.16
		bell.bottom_radius = 0.3
		bell.height = 0.42
		_mesh(pivot, bell, bronze, Vector3(0.0, -0.3, 0.0))
		var lip: TorusMesh = TorusMesh.new()
		lip.inner_radius = 0.27
		lip.outer_radius = 0.33
		_mesh(pivot, lip, bronze, Vector3(0.0, -0.5, 0.0))
		# Lamp on the very top.
		var lamp_mat: StandardMaterial3D = StandardMaterial3D.new()
		lamp_mat.albedo_color = Color(0.15, 0.16, 0.17)
		lamp_mat.emission_enabled = true
		lamp_mat.emission = lamp_color
		lamp_mat.emission_energy_multiplier = lamp_idle_energy
		lamp_mat.disable_fog = true   # the marker must cut through the sea haze
		var lamp: SphereMesh = SphereMesh.new()
		lamp.radius = 0.14
		lamp.height = 0.28
		var lm: MeshInstance3D = _mesh(b, lamp, lamp_mat, Vector3(0.0, 3.35, 0.0))
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = lamp_color
		light.light_energy = 0.0
		light.omni_range = lamp_light_range
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 1.5
		light.position.y = 3.4
		b.add_child(light)
		_buoys.append(b)
		_bells.append(pivot)
		_lamp_mats.append(lamp_mat)
		_lamp_lights.append(light)
		_swing.append(0.0)
		_flash.append(0.0)


func _mesh(parent: Node3D, m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Buoy positions (XZ is fixed; y rides the swell). Map view and LayoutCheck.
func points() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for b: Node3D in _buoys:
		out.append(b.position)
	return out


## Index of the buoy closest to the XZ angle `center` (radians).
func nearest(center: float) -> int:
	var best: int = 0
	var best_d: float = INF
	for i: int in _buoys.size():
		var a: float = atan2(_buoys[i].position.z, _buoys[i].position.x)
		var d: float = absf(angle_difference(a, center))
		if d < best_d:
			best_d = d
			best = i
	return best


## Hooked to WaveDirector.wave_warning: `wave` strokes from the buoy nearest the sector.
func on_wave_warning(wave: int, center: float) -> void:
	toll(nearest(center), maxi(1, wave))


func toll(buoy: int, stroke_count: int) -> void:
	if buoy < 0 or buoy >= _buoys.size():
		return
	tolls += 1
	last_buoy = buoy
	for k: int in stroke_count:
		_pending.append({"buoy": buoy, "t": _t + stroke_gap * k})


func _physics_process(delta: float) -> void:
	_t += delta
	for i: int in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		if _t >= float(p["t"]):
			var b: int = int(p["buoy"])
			_pending.remove_at(i)
			strokes += 1
			_swing[b] = 1.0
			_flash[b] = 1.0
			if audio != null:
				audio.play_bell(_buoys[b].global_position + Vector3(0.0, 3.0, 0.0), b)


func _process(delta: float) -> void:
	for i: int in _buoys.size():
		var b: Node3D = _buoys[i]
		if ocean != null:
			var x: float = b.position.x
			var z: float = b.position.z
			var h: float = ocean.get_height(x, z)
			b.position.y = h + float_offset
			var hx: float = ocean.get_height(x + 1.0, z) - h
			var hz: float = ocean.get_height(x, z + 1.0) - h
			b.rotation = Vector3(atan(hz) * tilt_gain, 0.0, -atan(hx) * tilt_gain)
		_swing[i] = _swing[i] * exp(-swing_decay * delta)
		_bells[i].rotation_degrees.x = swing_deg * _swing[i] * sin(_t * 9.0)
		_flash[i] = maxf(0.0, _flash[i] - delta * flash_decay)
		var blink: float = 1.0 if fposmod(_t + float(i) * 0.7, blink_period) < blink_on else 0.0
		_lamp_mats[i].emission_energy_multiplier = lamp_idle_energy * blink + lamp_flash_energy * _flash[i]
		_lamp_lights[i].light_energy = maxf(lamp_light_energy * _flash[i] * _flash[i], lamp_idle_light * blink)
		_lamp_lights[i].visible = _lamp_lights[i].light_energy > 0.01


func telemetry() -> Dictionary:
	return {"tolls": tolls, "strokes": strokes, "last_buoy": last_buoy, "pending": _pending.size()}
