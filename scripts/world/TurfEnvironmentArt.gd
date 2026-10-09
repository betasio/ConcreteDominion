class_name TurfEnvironmentArt
extends Node2D
## Optional illustrated environment layer. All source PNGs are transparent
## assets in res://assets/environment/. Procedural platforms remain the fallback.
@export var city_map_path: NodePath = NodePath("..")
const ART_ROOT := "res://assets/environment/"
var city_map: Node2D
var sprites: Dictionary = {}

func _ready() -> void:
	city_map = get_node_or_null(city_map_path) as Node2D
	for key in ["cliff_straight", "cliff_outer_corner", "cliff_inner_corner",
			"wall_straight", "wall_corner", "ramp", "stairs", "front_gate",
			"courtyard", "garden_strip", "rock_embankment", "luxury_fence",
			"cypress_planter", "hedge_barrier", "flower_planter", "ornamental_tree",
			"tall_lamp", "bollard", "square_light", "security_post", "fence_panel",
			"fountain", "service_yard", "industrial_yard", "courtyard_benches"]:
		var path: String = ART_ROOT + key + ".png"
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			if texture != null:
				sprites[key] = texture
	if city_map != null:
		city_map.view_mode_changed.connect(func(_mode: StringName) -> void: queue_redraw())
	queue_redraw()

func _draw() -> void:
	if city_map == null or city_map.get_view_mode() != &"base":
		return
	var hq: Vector2 = city_map.safehouse.position
	var middle: Vector2 = (city_map.hospital.position + city_map.barracks.position) * 0.5
	var lower: Vector2 = city_map.lot_a.position
	# Render behind interactable buildings; each piece follows live positions.
	# Footprint-size sprites are intentionally restricted to clear corridors.
	# Do not cover Safehouse art, label, or the interactive HQ threshold.
	# The central transition is handled by procedural steps underneath.
	_stamp("ramp", middle.lerp(lower, 0.56) + Vector2(-15, 18), 85.0)
	_stamp("front_gate", hq + Vector2(-63, 265), 113.0)
	_stamp("rock_embankment", hq + Vector2(-275, 71), 165.0)
	_stamp("cliff_outer_corner", hq + Vector2(270, -30), 145.0)
	_stamp("garden_strip", hq + Vector2(-165, 82), 112.0)
	_stamp("garden_strip", hq + Vector2(187, 77), 112.0)
	_stamp("cypress_planter", hq + Vector2(-198, -35), 80.0)
	_stamp("hedge_barrier", hq + Vector2(183, 16), 73.0)
	_stamp("security_post", hq + Vector2(-185, 260), 85.0)
	_stamp("service_yard", city_map.lot_a.position + Vector2(-107, 80), 81.0)
	_stamp("industrial_yard", city_map.lot_c.position + Vector2(-108, 68), 90.0)
	_stamp("courtyard_benches", city_map.lot_d.position + Vector2(99, 62), 86.0)

func _stamp(key: String, center: Vector2, target_width: float) -> void:
	if not sprites.has(key):
		return
	var texture: Texture2D = sprites[key]
	var size: Vector2 = texture.get_size()
	if size.x <= 0.0:
		return
	var scale_factor := target_width / size.x
	var rendered := size * scale_factor
	# Ground-relative registration: bottom of asset aligns to placement point.
	draw_texture_rect(texture, Rect2(center - Vector2(rendered.x * 0.5,
			rendered.y), rendered), false)
