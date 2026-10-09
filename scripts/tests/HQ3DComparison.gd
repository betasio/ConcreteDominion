extends Node3D
## Optional isolated 3D comparison. Does not change live 2D/2.5D turf.
## Place source models in res://assets/buildings/3d/ before opening this scene.
const MASTER_PATH := "res://assets/buildings/3d/HQ.glb"
const MOBILE_PATH := "res://assets/buildings/3d/HQ Mobile.glb"

func _ready() -> void:
	_add_model(MASTER_PATH, Vector3(-1.45, 0, 0))
	_add_model(MOBILE_PATH, Vector3(1.45, 0, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.7
	add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#202b33")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#a8b9c5")
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.9
	camera.position = Vector3(3.2, 2.3, 6.8)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.2, 0.0), Vector3.UP)
	camera.current = true

func _add_model(asset_path: String, position_3d: Vector3) -> void:
	if not ResourceLoader.exists(asset_path):
		push_warning("HQ comparison missing model: " + asset_path)
		return
	var source := load(asset_path) as PackedScene
	if source == null:
		push_warning("Unable to load model: " + asset_path)
		return
	var holder := Node3D.new()
	holder.position = position_3d
	add_child(holder)
	var model := source.instantiate() as Node3D
	if model == null:
		push_warning("GLB did not instantiate as Node3D: " + asset_path)
		return
	# Meshy model is centered on its origin; seat lowest point on the floor.
	model.position.y = 0.4233
	holder.add_child(model)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(2.12, 0.06, 1.55)
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.position.y = -0.05
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#36454d")
	floor_instance.material_override = stone
	holder.add_child(floor_instance)
	var caption := Label3D.new()
	caption.text = "MASTER · 1.58M tris" if asset_path == MASTER_PATH else "MOBILE · 49.9K tris"
	caption.font_size = 36
	caption.pixel_size = 0.0028
	caption.position = Vector3(0, -0.22, 0.88)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holder.add_child(caption)
