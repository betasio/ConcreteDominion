extends Node2D
## Isometric coastal surroundings, fixed in the same world as the estate.
const IMAGE_PATH := "res://assets/backgrounds/coastal_estate/isometric_bay.png"
const SHADER_PATH := "res://shaders/backgrounds/golden_bay_distance.gdshader"
@onready var city_map: Node2D = get_parent()
var panorama: Sprite2D
var ocean: Polygon2D
var motion_enabled := true
var animation_time := 0.0

func _ready() -> void:
	z_index = -90
	ocean = Polygon2D.new()
	ocean.name = "OpenWater"
	ocean.polygon = PackedVector2Array([Vector2(-6000,-4000),Vector2(6000,-4000),Vector2(6000,5000),Vector2(-6000,5000)])
	var water := ShaderMaterial.new()
	water.shader = load(SHADER_PATH)
	water.set_shader_parameter("backplate",false)
	ocean.material = water
	add_child(ocean)
	panorama = Sprite2D.new()
	panorama.name = "GoldenBayPanorama"
	panorama.texture = load(IMAGE_PATH)
	panorama.position = Vector2(118,560)
	panorama.scale = Vector2.ONE*1.8
	panorama.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var coast := ShaderMaterial.new()
	coast.shader = load(SHADER_PATH)
	panorama.material = coast
	add_child(panorama)
	city_map.view_mode_changed.connect(_on_view_mode_changed)
	_on_view_mode_changed(city_map.get_view_mode())

func _process(delta: float) -> void:
	if not visible or not motion_enabled:
		return
	animation_time += delta
	panorama.material.set_shader_parameter("animation_time",animation_time)
	ocean.material.set_shader_parameter("animation_time",animation_time)

func _on_view_mode_changed(mode: StringName) -> void:
	visible = mode == &"base"

func set_reduced_motion(enabled: bool) -> void:
	motion_enabled = not enabled
