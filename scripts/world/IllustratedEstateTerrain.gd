extends Node2D
## Optional illustration-only terrain alignment test. No collision or input.
const IMAGE_PATH := "res://assets/environment/Black-and-Gold Isometric Estate Grounds.png"
@onready var city_map: Node2D = get_parent()

func _ready() -> void:
    visible = bool(ProjectSettings.get_setting("concrete_dominion/preview_illustrated_terrain", false))
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
    image.position = Vector2(72, 447)
    image.scale = Vector2(0.73, 0.73)
    image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/backgrounds/illustrated_estate_alpha.gdshader") as Shader
    image.material = mat
    add_child(image)
    city_map.view_mode_changed.connect(func(mode: StringName) -> void: visible = mode == &"base")
    visible = city_map.get_view_mode() == &"base"
