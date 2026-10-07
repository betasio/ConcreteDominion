extends Node2D

signal building_selected(building: Building)

@export var grid_width: int = 18
@export var grid_height: int = 18
@export var tile_width: float = 128.0
@export var tile_height: float = 64.0

@onready var camera: Camera2D = $StrategyCamera
@onready var safehouse: Building = $Buildings/Safehouse
@onready var hospital: Building = $Buildings/Hospital

var selected_building: Building

var _road_color := Color(0.17, 0.19, 0.21)
var _lot_color_a := Color(0.22, 0.25, 0.23)
var _lot_color_b := Color(0.25, 0.28, 0.26)
var _line_color := Color(0.38, 0.42, 0.39, 0.55)


func _ready() -> void:
	safehouse.position = iso_to_screen(Vector2i(8, 8))
	hospital.position = iso_to_screen(Vector2i(11, 8))

	safehouse.selected.connect(_select_building)
	hospital.selected.connect(_select_building)
	queue_redraw()


func _draw() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var center := iso_to_screen(Vector2i(x, y))
			var is_road := x % 5 == 2 or y % 5 == 2
			var color := _road_color if is_road else (_lot_color_a if (x + y) % 2 == 0 else _lot_color_b)
			_draw_diamond(center, color)


func iso_to_screen(cell: Vector2i) -> Vector2:
	var origin := Vector2(0.0, -grid_height * tile_height * 0.25)
	return origin + Vector2(
		(cell.x - cell.y) * tile_width * 0.5,
		(cell.x + cell.y) * tile_height * 0.5
	)


func focus_building(building_type: StringName) -> void:
	var target: Building
	if building_type == &"hospital":
		target = hospital
	elif building_type == &"safehouse":
		target = safehouse
	else:
		return

	_select_building(target)
	camera.position = target.position + Vector2(0, -40)


func _select_building(building: Building) -> void:
	if selected_building != null:
		selected_building.set_selected(false)

	selected_building = building
	selected_building.set_selected(true)
	building_selected.emit(building)


func _draw_diamond(center: Vector2, fill: Color) -> void:
	var half_w := tile_width * 0.5
	var half_h := tile_height * 0.5
	var points := PackedVector2Array([
		center + Vector2(0, -half_h),
		center + Vector2(half_w, 0),
		center + Vector2(0, half_h),
		center + Vector2(-half_w, 0)
	])
	draw_colored_polygon(points, fill)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), _line_color, 1.5)
