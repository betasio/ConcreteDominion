class_name StreetLife
extends Node2D
## Low-cost decorative environment. No collision, input, or game-state mutations.
@export var city_map_path: NodePath = NodePath("..")
var city_map: Node2D
var tick := 0.0

func _ready() -> void:
	city_map = get_node_or_null(city_map_path) as Node2D
	if city_map != null:
		city_map.view_mode_changed.connect(func(_mode: StringName) -> void: queue_redraw())
	set_process(true)

func _process(delta: float) -> void:
	tick = fmod(tick + delta, 1000.0)
	# Throttle decorative updates on mobile: ~10 frames/second.
	if int(tick * 10.0) != int((tick - delta) * 10.0):
		queue_redraw()

func _draw() -> void:
	if city_map == null or city_map.get_view_mode() != &"world":
		return
	var world: bool = city_map.get_view_mode() == &"world"
	for y in range(2, 20, 5):
		for x in range(2, 24, 5):
			var pos: Vector2 = city_map.iso_to_screen(Vector2i(x, y))
			_draw_intersection(pos)
	for y in range(2, 20, 5):
		for x in range(4, 24, 5):
			var road: Vector2 = city_map.iso_to_screen(Vector2i(x, y))
			var phase: float = fmod(tick * (17.0 + float((x + y) % 3) * 5.0), 110.0)
			_draw_car(road + Vector2(phase - 55.0, (phase - 55.0) * 0.5), (x + y) % 3 == 0)
	if world:
		for cell in [Vector2i(8, 3), Vector2i(15, 8), Vector2i(9, 18)]:
			_draw_neon_sign(city_map.iso_to_screen(cell))

func _draw_intersection(pos: Vector2) -> void:
	# Thin lane separators, zebra crossing and warm signal glow.
	for offset in [-13.0, 0.0, 13.0]:
		draw_line(pos + Vector2(-30, offset * 0.5 - 3),
				pos + Vector2(-17, offset * 0.5 + 4), Color("#aeb9b1", 0.48), 2.2)
	draw_circle(pos + Vector2(25, -17), 9, Color(0.95, 0.53, 0.26, 0.10))
	draw_line(pos + Vector2(25, 2), pos + Vector2(25, -17), Color("#45545d"), 2.0)
	draw_circle(pos + Vector2(25, -17), 2.6, Color("#eeb46b"))

func _draw_car(pos: Vector2, red: bool) -> void:
	var body := Color("#a84a4b") if red else Color("#273f55")
	var points := PackedVector2Array([
		pos + Vector2(-14, -4), pos + Vector2(3, -12),
		pos + Vector2(16, -5), pos + Vector2(0, 3)])
	draw_colored_polygon(points, body)
	draw_line(pos + Vector2(-8, -5), pos + Vector2(1, -9), Color("#9aafbd"), 2.0)
	draw_line(pos + Vector2(10, -5), pos + Vector2(15, -3), Color("#f1ca83"), 2.0)
	draw_circle(pos + Vector2(0, 4), 7, Color(0.05, 0.07, 0.12, 0.27))

func _draw_neon_sign(pos: Vector2) -> void:
	var sign := Rect2(pos + Vector2(-28, -80), Vector2(56, 15))
	draw_rect(sign, Color("#162432"), true)
	draw_rect(sign, Color("#bb574b"), false, 2.0)
	draw_line(sign.position + Vector2(7, 8), sign.position + Vector2(49, 8),
			Color("#e9ad79", 0.7 + 0.2 * sin(tick * 2.0)), 2.0)
