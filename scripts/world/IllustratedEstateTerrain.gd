extends Node2D
const LAYOUT := preload("res://scripts/world/IllustratedEstateLayout.gd")
const IMAGE_PATH := "res://assets/environment/expanded_estate.png"
var shore: Sprite2D
func _ready() -> void:
	if not ProjectSettings.get_setting("concrete_dominion/preview_illustrated_terrain",true):
		visible = false
		return
	shore = Sprite2D.new()
	shore.name = "TerrainIllustration"
	shore.texture = load(IMAGE_PATH)
	shore.position = LAYOUT.ORIGIN
	shore.scale = Vector2.ONE * LAYOUT.ART_SCALE
	shore.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/backgrounds/estate_water.gdshader")
	material.set_shader_parameter("feather_edges",true)
	shore.material = material
	add_child(shore)
	get_parent().view_mode_changed.connect(func(mode): visible = mode == &"base")
func _process(_delta: float) -> void:
	if visible and shore != null:
		shore.material.set_shader_parameter("animation_time",get_parent().get_node("GoldenBayBackdrop").animation_time)
