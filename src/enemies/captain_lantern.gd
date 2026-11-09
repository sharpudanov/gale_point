class_name CaptainLantern
extends ShootableGear
## A Lantern Captain's ship lantern (Poly Haven CC0 "Lantern_01"), hung from an iron hook in its right hand
## and swinging as it glides. It holds a dim cold corpse-light (shading only, no light node), so the
## captain's silhouette reads in the dark. A rifle round through it (or fire reaching the captain) bursts it:
## an oil-fire burst on the spot that sets the captain and everything near it alight.
## Lives under the Drowned's animated body (model space: feet at y = 0, forward = -Z).

const MODEL: String = "res://assets/models/Lantern_01/Lantern_01_1k.gltf"

@export var hook_from: Vector3 = Vector3(0.47, 1.0, -0.62)   ## the right hand
@export var hook_tip: Vector3 = Vector3(0.72, 1.5, -1.05)   ## held out, away from the body
@export var chain_len: float = 0.16
@export var model_scale: float = 2.4          ## the model is a 0.29 m table lantern; a ship's lantern is ~0.7 m
@export var hit_radius: float = 0.3          ## shot sphere around the lantern body (x captain scale)
@export var glow_color: Color = Color(0.55, 0.75, 0.85)
@export var glow_energy: float = 3.0
@export var light_energy: float = 1.6         ## cold, no shadow, not a gameplay light (never registered)
@export var light_range: float = 5.0
@export var halo_size: float = 0.35
@export var halo_alpha: float = 0.35
@export var swing_deg: float = 14.0
@export var swing_hz: float = 0.7
@export var burst_scale: float = 0.9
@export var burst_delay: float = 0.25         ## when fire (not a bullet) reaches it

var captain: Drowned
var intact: bool = true

var _pivot: Node3D
var _hit_centre: Marker3D
var _glow_mat: StandardMaterial3D
var _t: float = 0.0
var _pending: bool = false
var _light: OmniLight3D


func _ready() -> void:
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = Color(0.05, 0.048, 0.045)
	iron.metallic = 0.7
	iron.roughness = 0.55
	# Hook pole from the hand to the tip.
	var pole: MeshInstance3D = MeshInstance3D.new()
	pole.name = "Hook"
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 0.012
	pm.bottom_radius = 0.014
	var span: Vector3 = hook_tip - hook_from
	pm.height = span.length()
	pole.mesh = pm
	pole.material_override = iron
	pole.position = (hook_from + hook_tip) * 0.5
	pole.basis = Basis(Quaternion(Vector3.UP, span.normalized()))
	add_child(pole)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position = hook_tip
	add_child(_pivot)
	var chain: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.006
	cm.bottom_radius = 0.006
	cm.height = chain_len
	chain.mesh = cm
	chain.material_override = iron
	chain.position.y = -chain_len * 0.5
	_pivot.add_child(chain)
	var lantern_h: float = 0.294 * model_scale
	if ResourceLoader.exists(MODEL):
		var scene: PackedScene = load(MODEL) as PackedScene
		var model: Node3D = scene.instantiate() as Node3D
		model.scale = Vector3.ONE * model_scale
		model.position.y = -chain_len - lantern_h
		_pivot.add_child(model)
		for mi: MeshInstance3D in _meshes(model):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Cold corpse-light inside the glass: emission only.
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.1, 0.12, 0.14)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = glow_color
	_glow_mat.emission_energy_multiplier = glow_energy
	var core: MeshInstance3D = MeshInstance3D.new()
	core.name = "Glow"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.035 * model_scale
	sm.height = 0.09 * model_scale
	sm.radial_segments = 10
	sm.rings = 5
	core.mesh = sm
	core.material_override = _glow_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.position.y = -chain_len - lantern_h * 0.45
	_pivot.add_child(core)
	# Faint billboard halo so the lantern reads as a point of interest at 10-30 m.
	var halo_mat: StandardMaterial3D = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.albedo_texture = FireFx._flame_texture()
	halo_mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, halo_alpha)
	var hq: QuadMesh = QuadMesh.new()
	hq.size = Vector2(halo_size, halo_size)
	var halo: MeshInstance3D = MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = hq
	halo.material_override = halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position.y = core.position.y
	_pivot.add_child(halo)
	_light = OmniLight3D.new()
	_light.name = "CorpseLight"
	_light.light_color = glow_color
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 0.6
	_light.position.y = core.position.y
	_pivot.add_child(_light)
	_hit_centre = Marker3D.new()
	_hit_centre.position.y = -chain_len - lantern_h * 0.5
	_pivot.add_child(_hit_centre)


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in n.get_children():
		if c is MeshInstance3D:
			out.append(c as MeshInstance3D)
		out.append_array(_meshes(c))
	return out


func centre() -> Vector3:
	return _hit_centre.global_position


func ray_hit(from: Vector3, dir: Vector3) -> float:
	if not intact or captain == null or not captain.is_alive():
		return -1.0
	return HitGeo.ray_vs_sphere(from, dir, centre(), hit_radius * captain.size_scale)


func on_shot(_point: Vector3, _dir: Vector3) -> void:
	burst_now()


## Fire reached the captain: the oil goes up a moment later.
func burst_later() -> void:
	if not intact or _pending:
		return
	_pending = true
	get_tree().create_timer(burst_delay, false, true).timeout.connect(burst_now)


func burst_now() -> void:
	if not intact or captain == null:
		return
	intact = false
	var at: Vector3 = centre()
	_pivot.visible = false
	var fire: FireSystem = captain.fire_system()
	if fire != null:
		fire.burst(at, burst_scale)
	captain.on_lantern_burst(at)


func _process(delta: float) -> void:
	_t += delta
	if captain == null:
		return
	# Pendulum: a steady sway plus a lag against the captain's speed.
	var lag: float = clampf(captain.speed * 4.0, 0.0, 18.0)
	_pivot.rotation_degrees.x = lag + swing_deg * sin(TAU * swing_hz * _t)
	_pivot.rotation_degrees.z = swing_deg * 0.5 * sin(TAU * swing_hz * 0.7 * _t + 1.1)
	var flick: float = 0.8 + 0.2 * sin(_t * 3.1) * sin(_t * 1.7)
	_glow_mat.emission_energy_multiplier = glow_energy * flick
	_light.light_energy = light_energy * flick
