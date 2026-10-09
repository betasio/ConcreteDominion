extends Node3D
## Isolated visual QA for the imported Meshy HQ. Live turf stays untouched.
const MASTER_PATH := "res://assets/buildings/3d/HQ.glb"
const MOBILE_PATH := "res://assets/buildings/3d/HQ_Mobile.glb"

func _ready() -> void:
	var dual := ResourceLoader.exists(MASTER_PATH)
	if dual:
		_add_model(MASTER_PATH, Vector3(-1.45, 0.0, 0.0))
		_add_model(MOBILE_PATH, Vector3(1.45, 0.0, 0.0))
	else:
		_add_model(MOBILE_PATH, Vector3.ZERO)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54.0, -38.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-32.0, 120.0, 0.0)
	fill.light_energy = 0.35
	fill.light_color = Color("#b6cfdf")
	fill.shadow_enabled = false
	add_child(fill)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#18242a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bbc6c5")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.65 if not dual else 4.6
	camera.position = Vector3(3.8, 3.0, 6.8)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.22, 0.0), Vector3.UP)
	camera.current = true

func _add_model(asset_path: String, position_3d: Vector3) -> void:
	if not ResourceLoader.exists(asset_path):
		push_warning("HQ comparison missing model: " + asset_path)
		return
	var source := load(asset_path) as PackedScene
	if source == null:
		push_warning("Unable to load HQ: " + asset_path)
		return
	var holder := Node3D.new()
	holder.position = position_3d
	add_child(holder)

	var model := source.instantiate() as Node3D
	if model == null:
		push_warning("GLB is not a Node3D: " + asset_path)
		return
	model.position.y = 0.4233
	holder.add_child(model)

	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("#242f2b")
	earth.roughness = 0.98
	var turf := StandardMaterial3D.new()
	turf.albedo_color = Color("#293b32")
	turf.roughness = 0.98
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#434747")
	stone.roughness = 0.9
	var dark_stone := StandardMaterial3D.new()
	dark_stone.albedo_color = Color("#1e2528")
	dark_stone.roughness = 0.87
	_box(holder, "Cliff base", Vector3(2.45, 0.32, 2.12), Vector3(0, -0.21, 0), earth)
	_box(holder, "Grass terrace", Vector3(2.34, 0.08, 2.01), Vector3(0, -0.01, 0), turf)
	# A solid plate across the terrace obscured the GLB base and washed out white.
	# Four narrow retaining trims preserve the original mesh and its materials.
	_box(holder, "North retaining cap", Vector3(2.26, 0.04, 0.075), Vector3(0, 0.046, -1.015), stone)
	_box(holder, "South retaining cap", Vector3(2.26, 0.04, 0.075), Vector3(0, 0.046, 1.015), stone)
	_box(holder, "West retaining cap", Vector3(0.075, 0.04, 1.96), Vector3(-1.135, 0.046, 0), stone)
	_box(holder, "East retaining cap", Vector3(0.075, 0.04, 1.96), Vector3(1.135, 0.046, 0), stone)
	# Keep the GLB's own base visible; only flank its entry with a short approach.
	_box(holder, "Entry drive", Vector3(0.40, 0.02, 0.46), Vector3(0, 0.065, 1.22), dark_stone)
	_box(holder, "Drive gold inset", Vector3(0.012, 0.023, 0.43), Vector3(-0.14, 0.078, 1.22), stone)
	_box(holder, "Drive gold inset right", Vector3(0.012, 0.023, 0.43), Vector3(0.14, 0.078, 1.22), stone)

func _box(parent: Node3D, label_text: String, dimensions: Vector3, location: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label_text
	var cube := BoxMesh.new()
	cube.size = dimensions
	instance.mesh = cube
	instance.position = location
	instance.material_override = material
	parent.add_child(instance)
