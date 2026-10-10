@tool
extends Node2D
## Animated scenic panorama preview; not part of the playable estate yet.
const ROOT := "res://assets/backgrounds/coastal_estate/"
const SHADERS := "res://shaders/backgrounds/"
@export_range(0.2, 3.0, 0.05) var scenery_scale := 1.0:
    set(value):
        scenery_scale = value
        scale = Vector2.ONE * value
@export var animate_water := true
@export var animate_clouds := true
@export var animate_lights := true
@export var animate_mist := true

func _ready() -> void:
    _setup_layers()
    scale = Vector2.ONE * scenery_scale

func _setup_layers() -> void:
    for child in get_children():
        if child.name.begins_with("Generated_"):
            child.queue_free()
    if not ResourceLoader.exists(ROOT + "coastal_estate_wide.png"):
        push_warning("CoastalEstateAnimated: panorama PNG not uploaded yet")
        return
    var art := load(ROOT + "coastal_estate_wide.png") as Texture2D
    if art == null:
        push_warning("CoastalEstateAnimated: invalid panorama texture")
        return
    _sprite("Generated_Base", art, null, null, 0)
    if animate_water:
        _sprite("Generated_Water", art, "water_shimmer.gdshader", "water_mask.png", 1)
    if animate_clouds:
        _sprite("Generated_Sky", art, "sky_drift.gdshader", "sky_mask.png", 2)
    if animate_mist:
        _sprite("Generated_Mist", art, "mist_drift.gdshader", "mist_mask.png", 3)
    if animate_lights:
        _sprite("Generated_Lights", art, "city_lights.gdshader", "lights_mask.png", 4)

func _sprite(label: String, art: Texture2D, shader_name: Variant, mask_name: Variant, order: int) -> void:
    var sprite := Sprite2D.new()
    sprite.name = label
    sprite.texture = art
    sprite.centered = false
    sprite.z_index = order
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    if shader_name != null:
        if not ResourceLoader.exists(SHADERS + str(shader_name)) or not ResourceLoader.exists(ROOT + str(mask_name)):
            push_warning("CoastalEstateAnimated: missing shader or mask for " + label)
            return
        var shader := load(SHADERS + str(shader_name)) as Shader
        var mat := ShaderMaterial.new()
        mat.shader = shader
        mat.set_shader_parameter("region_mask", load(ROOT + str(mask_name)))
        sprite.material = mat
    add_child(sprite)
