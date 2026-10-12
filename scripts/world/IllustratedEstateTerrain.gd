extends Node2D
const LAYOUT := preload("res://scripts/world/IllustratedEstateLayout.gd")
const IMAGE_PATH := "res://assets/environment/complete_estate_coast.png"
var shore: Sprite2D
func _ready() -> void:
	if not ProjectSettings.get_setting("concrete_dominion/preview_illustrated_terrain",true):
		visible = false
		return
	var approach := Sprite2D.new()
	approach.name = "SouthApproach"
	approach.texture = load("res://assets/environment/estate_south_approach.png")
	approach.position = Vector2(LAYOUT.ORIGIN.x, LAYOUT.ROAD_END - LAYOUT.SOUTH_APPROACH_HEIGHT * 0.5)
	approach.scale = Vector2(LAYOUT.TEXTURE_SIZE.x * LAYOUT.ART_SCALE, LAYOUT.SOUTH_APPROACH_HEIGHT) / approach.texture.get_size()
	approach.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(approach)
	shore = Sprite2D.new()
	shore.name = "TerrainIllustration"
	shore.texture = load(IMAGE_PATH)
	shore.position = LAYOUT.ORIGIN
	shore.scale = Vector2.ONE * LAYOUT.ART_SCALE
	shore.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/backgrounds/estate_water.gdshader")
	material.set_shader_parameter("feather_edges",true)
	material.set_shader_parameter("south_overlap",LAYOUT.SOUTH_OVERLAP / (LAYOUT.TEXTURE_SIZE.y * LAYOUT.ART_SCALE))
	shore.material = material
	add_child(shore)
	get_parent().view_mode_changed.connect(func(mode): visible = mode == &"base")
func _process(_delta: float) -> void:
	if visible and shore != null:
		shore.material.set_shader_parameter("animation_time",get_parent().get_node("GoldenBayBackdrop").animation_time)
