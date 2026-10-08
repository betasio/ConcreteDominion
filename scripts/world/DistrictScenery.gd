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
	_draw_financial_plaza(Vector2i(9, 3))
	_draw_northside_checkpoint(Vector2i(17, 17))
	_draw_harbor_containers(Vector2i(16, 5))

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


func _draw_financial_plaza(cell: Vector2i) -> void:
	var p: Vector2 = city_map.iso_to_screen(cell)
	# A layered art-deco plaza silhouette distinguishes the financial district.
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-73, -10), p + Vector2(0, -46),
		p + Vector2(73, -10), p + Vector2(0, 26)]), Color("#243643"))
	for index in range(5):
		var x: float = -44.0 + float(index) * 22.0
		draw_line(p + Vector2(x, -34), p + Vector2(x, -66), GOLD, 3.0)
	draw_line(p + Vector2(-58, -68), p + Vector2(58, -68), GOLD, 4.0)
	draw_circle(p + Vector2(0, -81), 8.0, GOLD)


func _draw_northside_checkpoint(cell: Vector2i) -> void:
	var p: Vector2 = city_map.iso_to_screen(cell)
	# Defensive gates and barricades are cosmetic, not attack targets.
	for side in [-1.0, 1.0]:
		var x: float = side * 55.0
		draw_rect(Rect2(p + Vector2(x - 10, -46), Vector2(20, 55)), Color("#384754"))
		draw_line(p + Vector2(x - 12, -47), p + Vector2(x + 12, -47), CRIMSON, 4.0)
	draw_line(p + Vector2(-44, -22), p + Vector2(44, -22), STEEL, 5.0)
	for index in range(5):
		var x: float = -36.0 + float(index) * 18.0
		draw_line(p + Vector2(x, -28), p + Vector2(x + 12, -16), CRIMSON, 3.0)


func _draw_harbor_containers(cell: Vector2i) -> void:
	var p: Vector2 = city_map.iso_to_screen(cell)
	for index in range(3):
		var offset := Vector2(float(index) * 36.0 - 55.0, float(index % 2) * -14.0)
		var color := Color("#42596a") if index != 1 else Color("#8b4c4a")
		draw_rect(Rect2(p + offset + Vector2(-17, -35), Vector2(32, 28)), color)
		for bar in range(3):
			var x: float = -12.0 + float(bar) * 10.0
			draw_line(p + offset + Vector2(x, -33), p + offset + Vector2(x, -10), STEEL, 1.5)
