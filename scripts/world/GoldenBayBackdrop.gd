extends Node2D
## Distant city/bay skyline for base view only. No collision or input.
const IMAGE_PATH := "res://assets/backgrounds/coastal_estate/ConcreteDominion_Golden_Bay_Background.png"
const SHADER_PATH := "res://shaders/backgrounds/golden_bay_distance.gdshader"
@onready var city_map: Node2D = get_parent()
var panorama: Sprite2D
var motion_enabled := true
var animation_time := 0.0

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
    sprite.position = Vector2(0, 310)
    sprite.scale = Vector2(1.35, 1.35)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var material := ShaderMaterial.new()
    material.shader = load(SHADER_PATH) as Shader
    sprite.material = material
    add_child(sprite)
    panorama = sprite
    city_map.view_mode_changed.connect(_on_view_mode_changed)
    _on_view_mode_changed(city_map.get_view_mode())

func _process(delta: float) -> void:
    if not visible or panorama == null:
        return
    if motion_enabled:
        animation_time += delta
        panorama.material.set_shader_parameter("animation_time",animation_time)
    var camera := get_viewport().get_camera_2d()
    if camera == null:
        return
    var center := camera.get_screen_center_position()
    # Quiet parallax, with enough cover for phone aspect ratios and all legal
    # camera positions. Never reveal a hard panorama edge during zoom or pan.
    var world_view := get_viewport_rect().size / camera.zoom
    var parallax := 0.06 if motion_enabled else 0.0
    panorama.position = center - (center-Vector2(118,350))*parallax - Vector2(0,world_view.y*0.08)
    var required := world_view + (center - panorama.position).abs() * 2.0
    var texture_size := panorama.texture.get_size()
    var cover := maxf(1.35, maxf(required.x / texture_size.x, required.y / texture_size.y))
    panorama.scale = Vector2.ONE * cover

func _draw() -> void:
    # Fill beyond the finite panorama so 4X camera zoom/pan never reveals
    # the viewport's default gray clear color below or beside the estate.
    draw_rect(Rect2(Vector2(-3600, -2600), Vector2(7200, 5400)), Color("#101c29"))
    # Water-depth bands are deliberately quiet; the panorama supplies detail.
    draw_rect(Rect2(Vector2(-3600, 460), Vector2(7200, 2300)), Color("#102836", 0.62))

func _on_view_mode_changed(mode: StringName) -> void:
    visible = mode == &"base"

func set_reduced_motion(enabled: bool) -> void:
    motion_enabled = not enabled
