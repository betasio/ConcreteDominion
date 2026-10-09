extends Node2D
## Isometric render of the imported 3D HQ. Parent stays the normal selectable Building.
## Uses a dedicated transparent viewport so it can sit on a 2D Godot map.
const MODEL_PATH := "res://assets/buildings/3d/HQ_Mobile.glb"
const RENDER_SIZE := Vector2i(640, 480)

func _ready() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		push_warning("HQ hybrid preview: model missing")
		return
	var viewport := SubViewport.new()
	viewport.name = "HQ3DViewport"
	viewport.size = RENDER_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.own_world_3d = true
	add_child(viewport)

	var stage := Node3D.new()
	stage.name = "HQStage"
	viewport.add_child(stage)
	var scene := load(MODEL_PATH) as PackedScene
	if scene == null:
		push_warning("HQ hybrid preview: cannot load model")
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		push_warning("HQ hybrid preview: invalid Node3D model")
		return
	model.position.y = 0.4233
	stage.add_child(model)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -36.0, 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 115, 0)
	fill.light_energy = 0.35
	fill.light_color = Color("#c0d2df")
	stage.add_child(fill)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#aeb8b6")
	env.ambient_light_energy = 0.48
	env_node.environment = env
	stage.add_child(env_node)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.78
	camera.position = Vector3(3.5, 2.75, 6.2)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.14, 0), Vector3.UP)
	camera.current = true

	var sprite := Sprite2D.new()
	sprite.name = "RenderedHQ"
	sprite.texture = viewport.get_texture()
	sprite.position = Vector2(0, -55)
	sprite.scale = Vector2(0.43, 0.43)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.show_behind_parent = true
	add_child(sprite)
