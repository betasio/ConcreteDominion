class_name CityAtmosphere
extends Node2D
## Illustrated neutral neighborhoods around solo NPC targets.
@export var city_map_path: NodePath = NodePath("..")
var city_map: Node2D

func _ready() -> void:
	city_map = get_node_or_null(city_map_path) as Node2D
	if city_map != null:
		city_map.view_mode_changed.connect(func(_mode: StringName): queue_redraw())
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func _draw() -> void:
	if city_map == null or city_map.get_view_mode() != &"world":
		return
	var art := preload("res://scripts/world/CityArt.gd").texture(5)
	for y in range(4,20,5):
		for x in range(4,24,5):
			if _near_target(x,y): continue
			var p: Vector2 = city_map.iso_to_screen(Vector2i(x,y))
			draw_texture_rect(art,Rect2(p+Vector2(-125,-188),Vector2(250,238)),false)
	_draw_lamps()


func _near_target(x: int, y: int) -> bool:
	for cell in [Vector2i(4, 6), Vector2i(19, 6), Vector2i(19, 15),
			Vector2i(4, 15), Vector2i(22, 10), Vector2i(4, 10),
			Vector2i(22, 17)]:
		if abs(x - cell.x) <= 1 and abs(y - cell.y) <= 1:
			return true
	return false


func _draw_lamps() -> void:
	for x in range(2, 24, 5):
		for y in range(2, 20, 5):
			var pos: Vector2 = city_map.iso_to_screen(Vector2i(x, y))
			draw_circle(pos + Vector2(0, -9), 11, Color(1, 0.69, 0.34, 0.10))
			draw_circle(pos + Vector2(0, -9), 3, Color("#f6c889"))
