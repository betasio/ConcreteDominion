extends Node2D
## Illustrated estate foundation. Interactive sites share its artwork transform.
const LAYOUT := preload("res://scripts/world/IllustratedEstateLayout.gd")
const IMAGE_PATH := "res://assets/environment/Black-and-Gold Isometric Estate Grounds.png"
@onready var city_map: Node2D = get_parent()
var shore: Sprite2D

func _ready() -> void:
    visible = bool(ProjectSettings.get_setting("concrete_dominion/preview_illustrated_terrain", true))
    if not visible:
        return
    if not ResourceLoader.exists(IMAGE_PATH):
        push_warning("Illustrated estate terrain PNG not found")
        visible = false
        return
    var texture := load(IMAGE_PATH) as Texture2D
    var image := Sprite2D.new()
    image.name = "TerrainIllustration"
    image.texture = texture
    image.centered = true
    image.position = LAYOUT.ORIGIN
    image.scale = Vector2.ONE * LAYOUT.ART_SCALE
    image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/backgrounds/illustrated_estate_alpha.gdshader") as Shader
    image.material = mat
    shore = Sprite2D.new()
    shore.name = "ShoreWash"
    shore.texture = texture
    shore.position = image.position + Vector2(0,5)
    shore.scale = image.scale
    var surf := ShaderMaterial.new()
    surf.shader = load("res://shaders/backgrounds/estate_shore_wash.gdshader")
    shore.material = surf
    add_child(shore)
    add_child(image)
    # The short entrance bridge must cross the cliff edge onto the existing
    # drive, rather than disappearing behind the original island texture.
    var annex := Sprite2D.new()
    annex.name = "DataHubTerrace"
    annex.texture = load(LAYOUT.ANNEX_PATH) as Texture2D
    annex.centered = false
    annex.position = LAYOUT.artwork_to_world(LAYOUT.PAD_CENTERS[&"BuildLotD"]) - LAYOUT.ANNEX_PAD_PIXEL * LAYOUT.ANNEX_SCALE
    annex.scale = Vector2.ONE * LAYOUT.ANNEX_SCALE
    annex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    add_child(annex)
    city_map.view_mode_changed.connect(func(mode: StringName) -> void: visible = mode == &"base")
    visible = city_map.get_view_mode() == &"base"

func _process(_delta: float) -> void:
    if visible and shore != null:
        var backdrop = city_map.get_node("GoldenBayBackdrop")
        shore.material.set_shader_parameter("animation_time",backdrop.animation_time)
