class_name CityAtmosphere
extends Node2D
## Decorative isometric skyline detail. No resources, collision, or game state.
## Reuses CityMap's grid and changes treatment between home turf and city view.

@export var city_map_path: NodePath = NodePath("..")
var city_map: Node2D
var phase: float = 0.0

const NIGHT := Color("#131d29")
const GLASS := Color("#304455")
const LIGHT := Color("#ebbd73")
const NEON := Color("#bd534d")
const ROOF := Color("#35404b")


func _ready() -> void:
	city_map = get_node_or_null(city_map_path) as Node2D
	if city_map != null:
		city_map.view_mode_changed.connect(func(_mode: StringName) -> void: queue_redraw())
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	phase = fmod(phase + delta, 7.0)
	if city_map != null and city_map.get_view_mode() == &"world":
		queue_redraw()


func _draw() -> void:
	if city_map == null:
		return
	var world: bool = city_map.get_view_mode() == &"world"
	# Buildings are deliberately placed away from interactive raid locations
	# and the player-owned building lots; every silhouette is non-interactive.
	for y in range(1, 20):
		for x in range(1, 24):
			if x % 5 == 2 or y % 5 == 2:
				continue
			if not world and x >= 6 and x <= 17 and y >= 5 and y <= 16:
				continue
			if world and _near_target(x, y):
				continue
			if (x * 17 + y * 11) % 4 == 0:
				continue
			var pos: Vector2 = city_map.iso_to_screen(Vector2i(x, y))
			var seed: int = (x * 31 + y * 19) % 7
			var height: float = float(20 + seed * 10)
			_draw_tower(pos, height, seed, world)
	_draw_lamps()


func _near_target(x: int, y: int) -> bool:
	for cell in [Vector2i(4, 6), Vector2i(19, 6), Vector2i(19, 15),
			Vector2i(4, 15), Vector2i(22, 10), Vector2i(4, 10),
			Vector2i(22, 17)]:
		if abs(x - cell.x) <= 1 and abs(y - cell.y) <= 1:
			return true
	return false


func _draw_tower(base: Vector2, height: float, seed: int, world: bool) -> void:
	var width: float = 18.0 + float(seed % 3) * 6.0
	var depth: float = width * 0.52
	var top := base + Vector2(0.0, -height)
	var front := PackedVector2Array([
		top + Vector2(0, depth), top + Vector2(width, 0),
		base + Vector2(width, 0), base + Vector2(0, depth)])
	var side := PackedVector2Array([
		top + Vector2(-width, 0), top + Vector2(0, depth),
		base + Vector2(0, depth), base + Vector2(-width, 0)])
	var roof := PackedVector2Array([
		top + Vector2(0, -depth), top + Vector2(width, 0),
		top + Vector2(0, depth), top + Vector2(-width, 0)])
	draw_colored_polygon(side, NIGHT.lightened(float(seed % 3) * 0.065))
	draw_colored_polygon(front, GLASS.darkened(float(seed % 4) * 0.06))
	draw_colored_polygon(roof, ROOF)
	draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[3], roof[0]]),
			Color("#526174"), 1.3)
	for floor_index in range(1, int(height / 13.0)):
		var offset: float = float(floor_index) * 12.0
		var lit: bool = (seed + floor_index) % 3 == 0
		var alpha: float = 0.74 if lit else 0.23
		draw_line(top + Vector2(5, depth - offset),
				top + Vector2(width - 4, 3 - offset),
				(LIGHT if lit else Color("#8198a4")) * Color(1, 1, 1, alpha), 1.8)
	if world and seed == 6:
		draw_line(top + Vector2(0, -depth), top + Vector2(0, -depth - 18),
				NEON, 2.0)
		draw_circle(top + Vector2(0, -depth - 18), 2.6,
				NEON.lerp(LIGHT, 0.5 + sin(phase * 2.2) * 0.3))


func _draw_lamps() -> void:
	for x in range(2, 24, 5):
		for y in range(2, 20, 5):
			var pos: Vector2 = city_map.iso_to_screen(Vector2i(x, y))
			draw_circle(pos + Vector2(0, -9), 11, Color(1, 0.69, 0.34, 0.10))
			draw_circle(pos + Vector2(0, -9), 3, Color("#f6c889"))
