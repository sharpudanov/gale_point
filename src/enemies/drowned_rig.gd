class_name DrownedRig
extends RefCounted
## The Drowned as an animated body: the Quaternius UAL2 mannequin (CC0, see ASSETS.md) wearing the cloth
## shader, so it walks, flinches and claws instead of gliding. Imported, never modelled here: the only
## added geometry is two eye spheres on the head bone for the searing glow.

const MODEL: String = "res://assets/animations/ual2/ual2.glb"
const CLIP_WALK: StringName = &"Zombie_Walk_Fwd"
const CLIP_IDLE: StringName = &"Zombie_Idle"
const CLIP_HIT: StringName = &"Hit_Knockback"
const CLIP_ATTACK: StringName = &"Zombie_Scratch"
const HEAD_BONE: String = "Head"
## Eye centres in the skeleton's rest space (metres, model faces +Z).
const EYE_POS: Vector3 = Vector3(0.033, 1.66, 0.085)
const EYE_RADIUS: float = 0.013

static var _mat: ShaderMaterial
static var _eye_mat: StandardMaterial3D


static func available() -> bool:
	return ResourceLoader.exists(MODEL)


## The cloth shader without hem motion or tatter cut-outs (both read UV.y as height, which only the
## code-built cloak provides).
static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = DrownedBuilder.cloth_material().duplicate() as ShaderMaterial
		_mat.set_shader_parameter("cloth_motion", 0.0)
		_mat.set_shader_parameter("tatter_threshold", 0.0)
	return _mat


## Body root facing -Z, feet at y = 0, `height` metres tall in the rest pose. Meshes are tagged like
## DrownedBuilder's: meta "cloth" on the body, meta "glow" = "eye" on the eyes.
static func build(height: float) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "DrownedBody"
	var model: Node3D = ModelKit.spawn(MODEL)
	model.name = "Rig"
	root.add_child(model)
	ModelKit.fit_height(model, height)
	model.rotation.y = PI
	for mi: MeshInstance3D in ModelKit.meshes(model):
		mi.material_override = material()
		mi.set_meta("cloth", true)
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone: int = sk.find_bone(HEAD_BONE) if sk != null else -1
	if bone >= 0:
		var head: BoneAttachment3D = BoneAttachment3D.new()
		head.name = "HeadAttach"
		head.bone_name = HEAD_BONE
		sk.add_child(head)
		var to_bone: Transform3D = sk.get_bone_global_rest(bone).affine_inverse()
		if _eye_mat == null:
			_eye_mat = StandardMaterial3D.new()
			_eye_mat.albedo_color = Color(0.02, 0.02, 0.02)
		for side: float in [-1.0, 1.0]:
			var eye: MeshInstance3D = MeshInstance3D.new()
			eye.name = "EyeL" if side < 0.0 else "EyeR"
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = EYE_RADIUS
			sphere.height = EYE_RADIUS * 2.0
			sphere.radial_segments = 8
			sphere.rings = 4
			eye.mesh = sphere
			eye.material_override = _eye_mat
			eye.position = to_bone * Vector3(EYE_POS.x * side, EYE_POS.y, EYE_POS.z)
			eye.set_meta("glow", "eye")
			head.add_child(eye)
	return root
