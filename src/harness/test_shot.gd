class_name TestShot
extends RefCounted
## Harness self-test scene for `tools/capture.sh test`: proves the code-built render path
## (camera, sun + shadows, procedural sky, PBR material) works. Not game content.


static func build(parent: Node3D) -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	parent.add_child(env)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	parent.add_child(sun)

	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	ground.mesh = plane
	parent.add_child(ground)

	var cube: MeshInstance3D = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.35, 0.15)
	mat.roughness = 0.4
	cube.material_override = mat
	cube.position = Vector3(0.0, 0.5, 0.0)
	cube.rotation_degrees = Vector3(0.0, 25.0, 0.0)
	parent.add_child(cube)

	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(2.5, 2.0, 3.5)
	parent.add_child(cam)
	cam.look_at(Vector3(0.0, 0.4, 0.0))
	cam.current = true
