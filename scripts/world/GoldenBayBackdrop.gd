extends Node2D
## Distant city/bay skyline for base view only. No collision or input.
const IMAGE_PATH := "res://assets/backgrounds/coastal_estate/ConcreteDominion_Golden_Bay_Background.png"
const SHADER_PATH := "res://shaders/backgrounds/golden_bay_distance.gdshader"
@onready var city_map: Node2D = get_parent()

func _ready() -> void:
    z_index = -90
    if not ResourceLoader.exists(IMAGE_PATH):
        push_warning("Golden Bay skyline PNG not found")
        return
    var texture := load(IMAGE_PATH) as Texture2D
    if texture == null:
        push_warning("Golden Bay skyline PNG failed to load")
        return
    var sprite := Sprite2D.new()
    sprite.name = "GoldenBayPanorama"
    sprite.texture = texture
    sprite.centered = true
    sprite.position = Vector2(0, -50)
    sprite.scale = Vector2(1.35, 1.35)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var material := ShaderMaterial.new()
    material.shader = load(SHADER_PATH) as Shader
    sprite.material = material
    add_child(sprite)
    city_map.view_mode_changed.connect(_on_view_mode_changed)
    _on_view_mode_changed(city_map.get_view_mode())

func _on_view_mode_changed(mode: StringName) -> void:
    visible = mode == &"base"
