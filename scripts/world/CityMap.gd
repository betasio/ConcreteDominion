extends Node2D

signal building_selected(building: Building)
signal lot_selected(lot: BuildLot)

@export var grid_width: int = 18
@export var grid_height: int = 18
@export var tile_width: float = 128.0
@export var tile_height: float = 64.0

@onready var camera: Camera2D = $StrategyCamera
@onready var safehouse: Building = $Buildings/Safehouse
@onready var hospital: Building = $Buildings/Hospital
@onready var barracks: Building = $Buildings/Barracks
@onready var lot_a: BuildLot = $Buildings/BuildLotA
@onready var lot_b: BuildLot = $Buildings/BuildLotB

var selected_target: Node
var _road_color := Color(0.17, 0.19, 0.21)
var _lot_color_a := Color(0.22, 0.25, 0.23)
var _lot_color_b := Color(0.25, 0.28, 0.26)
var _line_color := Color(0.38, 0.42, 0.39, 0.55)

func _ready() -> void:
	safehouse.position = iso_to_screen(Vector2i(8, 8))
	hospital.position = iso_to_screen(Vector2i(11, 8))
	barracks.position = iso_to_screen(Vector2i(8, 5))
	lot_a.position = iso_to_screen(Vector2i(8, 11))
	lot_b.position = iso_to_screen(Vector2i(11, 11))

	safehouse.selected.connect(_select_building)
	hospital.selected.connect(_select_building)
	barracks.selected.connect(_select_building)
	lot_a.selected.connect(_select_lot)
	lot_b.selected.connect(_select_lot)
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
	return origin + Vector2((cell.x - cell.y) * tile_width * 0.5, (cell.x + cell.y) * tile_height * 0.5)

func focus_building(building_type: StringName) -> void:
	var target: Building
	if building_type == &"hospital":
		target = hospital
	elif building_type == &"safehouse":
		target = safehouse
	elif building_type == &"barracks":
		target = barracks
	else:
		return

	_select_building(target)
	camera.position = target.position + Vector2(0, -40)

func _clear_selection() -> void:
	if selected_target != null and selected_target.has_method("set_selected"):
		selected_target.call("set_selected", false)

func _select_building(building: Building) -> void:
	_clear_selection()
	selected_target = building
	building.set_selected(true)
	building_selected.emit(building)

func _select_lot(lot: BuildLot) -> void:
	_clear_selection()
	selected_target = lot
	lot.set_selected(true)
	lot_selected.emit(lot)

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
