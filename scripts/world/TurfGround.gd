class_name TurfGround
extends Node2D
## Decorative landscaping and property pads below the interactive building layer.
## Never handles input and does not change economy, ownership, or save data.
@export var city_map_path: NodePath = NodePath("..")
var city_map: Node2D

func _ready() -> void:
	city_map = get_node_or_null(city_map_path) as Node2D
	if city_map != null:
		city_map.view_mode_changed.connect(func(_mode: StringName) -> void: queue_redraw())
	queue_redraw()

func _draw() -> void:
	if city_map == null or city_map.get_view_mode() != &"base":
		return
	var properties: Array[Vector2i] = [
		Vector2i(10, 10), Vector2i(13, 10), Vector2i(10, 7),
		Vector2i(10, 13), Vector2i(13, 13), Vector2i(7, 13),
		Vector2i(16, 13)
	]
	for cell in properties:
		_draw_pad(city_map.iso_to_screen(cell), cell == Vector2i(10, 10))
	# Distinct property boundaries and shared driveways frame the compound.
	var gate: Vector2 = city_map.iso_to_screen(Vector2i(8, 10))
	var hq: Vector2 = city_map.iso_to_screen(Vector2i(10, 10))
	draw_line(gate + Vector2(0, 13), hq + Vector2(0, 25), Color("#947c5b", 0.65), 17.0)
	draw_line(gate + Vector2(0, 13), hq + Vector2(0, 25), Color("#38434d"), 13.0)
	for cell in [Vector2i(6, 10), Vector2i(7, 10), Vector2i(8, 10)]:
		_draw_bollard(city_map.iso_to_screen(cell) + Vector2(-27, -8))

func _draw_pad(pos: Vector2, headquarters: bool) -> void:
	var width := 121.0 if headquarters else 94.0
	var depth := 66.0 if headquarters else 52.0
	var points := PackedVector2Array([
		pos + Vector2(0, -depth),
		pos + Vector2(width, -6),
		pos + Vector2(0, depth - 12),
		pos + Vector2(-width, -6)
	])
	draw_colored_polygon(points, Color("#18242d") if headquarters else Color("#222e35"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
			Color("#d5aa63", 0.79) if headquarters else Color("#72818a", 0.6), 2.3, true)
	# Low gold perimeter markers add depth without obscuring selection hitboxes.
	for corner in [points[1], points[3]]:
		draw_circle(corner + Vector2(0, -8), 4.0, Color("#e4bb74", 0.7))

func _draw_bollard(pos: Vector2) -> void:
	draw_line(pos, pos + Vector2(0, -16), Color("#43505a"), 4.0)
	draw_circle(pos + Vector2(0, -16), 3.0, Color("#e8ba72"))
