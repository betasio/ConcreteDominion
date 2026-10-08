class_name DistrictScenery
extends Node2D
## Cosmetic districts anchored to the established raid map. No game-state writes.
@export var city_map_path: NodePath = NodePath("..")
var city_map: Node2D

const GOLD := Color("#e3b974")
const CRIMSON := Color("#c85c67")
const CYAN := Color("#6fb8c9")
const STEEL := Color("#8496a8")

func _ready() -> void:
	city_map = get_node_or_null(city_map_path) as Node2D
	if city_map != null:
		city_map.view_mode_changed.connect(func(_mode: StringName) -> void: queue_redraw())
	queue_redraw()

func _draw() -> void:
	if city_map == null or city_map.get_view_mode() != &"world":
		return
	_mark_district(Vector2i(4, 6), "DOWNTOWN", GOLD)
	_mark_district(Vector2i(19, 6), "HARBOR", CYAN)
	_mark_district(Vector2i(4, 15), "ENTERTAINMENT", CRIMSON)
	_mark_district(Vector2i(22, 17), "INDUSTRIAL", STEEL)
	_mark_district(Vector2i(19, 15), "NORTHSIDE", CRIMSON)
	_draw_cranes(Vector2i(17, 4))
	_draw_tanks(Vector2i(20, 18))
	_draw_marquee(Vector2i(2, 16))

func _mark_district(cell: Vector2i, label: String, accent: Color) -> void:
	var pos: Vector2 = city_map.iso_to_screen(cell) + Vector2(0, -175)
	draw_rect(Rect2(pos + Vector2(-79, -20), Vector2(158, 28)), Color("#101a26", 0.86))
	draw_line(pos + Vector2(-78, 8), pos + Vector2(78, 8), accent, 2.5)
	draw_string(ThemeDB.fallback_font, pos, label,
			HORIZONTAL_ALIGNMENT_CENTER, 158, 17, accent)

func _draw_cranes(cell: Vector2i) -> void:
	var p: Vector2 = city_map.iso_to_screen(cell)
	for offset in [-76.0, 65.0]:
		var base: Vector2 = p + Vector2(offset, 8)
		draw_line(base, base + Vector2(0, -125), STEEL, 5.0)
		draw_line(base + Vector2(-47, -117), base + Vector2(74, -117), CYAN, 3.0)
		draw_line(base + Vector2(52, -117), base + Vector2(52, -76), STEEL, 2.0)

func _draw_tanks(cell: Vector2i) -> void:
	var p: Vector2 = city_map.iso_to_screen(cell)
	for offset in [-45.0, 18.0]:
		var v: Vector2 = p + Vector2(offset, 0)
		draw_rect(Rect2(v + Vector2(-21, -43), Vector2(42, 35)), Color("#415562"))
		draw_arc(v + Vector2(0, -43), 21, PI, TAU, 24, STEEL, 3.0)
		draw_line(v + Vector2(-21, -8), v + Vector2(21, -8), GOLD, 2.0)

func _draw_marquee(cell: Vector2i) -> void:
	var p: Vector2 = city_map.iso_to_screen(cell) + Vector2(0, -85)
	draw_rect(Rect2(p + Vector2(-55, -24), Vector2(110, 37)), Color("#2b1c32"))
	draw_rect(Rect2(p + Vector2(-55, -24), Vector2(110, 37)), CRIMSON, false, 3.0)
	for i in range(8):
		draw_circle(p + Vector2(-46 + i * 13, -18), 2.4, GOLD)
