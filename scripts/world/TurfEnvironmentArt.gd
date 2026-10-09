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
	# Group the large illustrated pieces around the edge rather than
	# scattering tiny props across central roads and building labels.
	var west: Vector2 = city_map.lot_c.position
	var east: Vector2 = city_map.lot_d.position
	# Large dressed cliff assets belong on the visible *outer* estate edge.
	# The previous small pieces floated near the interior buildings.
	# Anchor a continuous-looking frontage to the lower service boundary.
	var cliff_center: Vector2 = (west + east) * 0.5
	_stamp_cliff("cliff_straight", west + Vector2(-129, 145), 213.0)
	_stamp_cliff("wall_straight", cliff_center + Vector2(-115, 189), 217.0)
	# Bridge the visible void between central gate masonry and east cliff.
	# Place below the Data Hub foundation and leave its label unobstructed.
	_stamp_cliff("cliff_straight", east + Vector2(-80, 172), 155.0)
	_stamp_cliff("cliff_straight", east + Vector2(126, 146), 210.0)
	# Avoid separate cliff islands beside the HQ: the Safehouse is already
	# established by its own raised podium and the natural estate silhouette.
	# Retain only grounded landscaping along the middle security terrace.
	_stamp("hedge_barrier", city_map.barracks.position + Vector2(121, 89), 88.0)
	# The imported front_gate.png is the illustrated roadway ramp.
	_stamp("front_gate", middle.lerp(lower, 0.57) + Vector2(-12, 20), 129.0)

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

func _stamp_cliff(key: String, foot: Vector2, width: float) -> void:
	# A low rocky footing ties each illustrated cliff to the dark plateau
	# without introducing detached geometric platforms or road obstructions.
	if not sprites.has(key):
		return
	var half: float = width * 0.45
	var apron := PackedVector2Array([
		foot + Vector2(-half, -23),
		foot + Vector2(half, -23),
		foot + Vector2(half + 14.0, 8.0),
		foot + Vector2(-half - 14.0, 8.0)
	])
	draw_colored_polygon(apron, Color("#27373a", 0.94))
	draw_line(apron[3], apron[2], Color("#52615b", 0.36), 2.0)
	_stamp(key, foot, width)
