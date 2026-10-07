extends Node2D

signal building_selected(building: Building)
signal lot_selected(lot: BuildLot)
signal raid_target_selected(target: RaidTarget)
signal view_mode_changed(mode: StringName)

const CONVOY_SCENE := preload("res://scenes/world/ConvoyVisual.tscn")
const RAID_IMPACT_SCENE := preload("res://scenes/effects/RaidImpactVFX.tscn")

@export var grid_width: int = 24
@export var grid_height: int = 20
@export var tile_width: float = 128.0
@export var tile_height: float = 64.0

@onready var camera: Camera2D = $StrategyCamera
@onready var buildings_layer: Node2D = $Buildings
@onready var raid_targets_layer: Node2D = $RaidTargets
@onready var convoy_layer: Node2D = $Convoys
@onready var effects_layer: Node2D = $Effects
@onready var safehouse: Building = $Buildings/Safehouse
@onready var hospital: Building = $Buildings/Hospital
@onready var barracks: Building = $Buildings/Barracks
@onready var lot_a: BuildLot = $Buildings/BuildLotA
@onready var lot_b: BuildLot = $Buildings/BuildLotB
@onready var downtown_bank: RaidTarget = $RaidTargets/DowntownBank
@onready var harbor_bank: RaidTarget = $RaidTargets/HarborBank
@onready var northside_hq: RaidTarget = $RaidTargets/NorthsideHQ
@onready var casino_vault: RaidTarget = $RaidTargets/CasinoVault
@onready var financial_tower: RaidTarget = $RaidTargets/FinancialTower
@onready var midtown_exchange: RaidTarget = $RaidTargets/MidtownExchange
@onready var industrial_depot: RaidTarget = $RaidTargets/IndustrialDepot

var selected_target: Node
var active_convoy: ConvoyVisual
var view_mode: StringName = &"base"
var progression: PlayerProgression

var _road_color := Color(0.17, 0.19, 0.21)
var _lot_color_a := Color(0.22, 0.25, 0.23)
var _lot_color_b := Color(0.25, 0.28, 0.26)
var _line_color := Color(0.38, 0.42, 0.39, 0.55)


func setup_progression(player_progression: PlayerProgression) -> void:
	progression = player_progression
	for target in get_raid_targets():
		target.setup_progression(progression)


func _ready() -> void:
	safehouse.position = iso_to_screen(Vector2i(10, 10))
	hospital.position = iso_to_screen(Vector2i(13, 10))
	barracks.position = iso_to_screen(Vector2i(10, 7))
	lot_a.position = iso_to_screen(Vector2i(10, 13))
	lot_b.position = iso_to_screen(Vector2i(13, 13))

	downtown_bank.position = iso_to_screen(Vector2i(4, 6))
	harbor_bank.position = iso_to_screen(Vector2i(19, 6))
	northside_hq.position = iso_to_screen(Vector2i(19, 15))
	casino_vault.position = iso_to_screen(Vector2i(4, 15))
	financial_tower.position = iso_to_screen(Vector2i(22, 10))
	midtown_exchange.position = iso_to_screen(Vector2i(4, 10))
	industrial_depot.position = iso_to_screen(Vector2i(22, 17))

	safehouse.selected.connect(_select_building)
	hospital.selected.connect(_select_building)
	barracks.selected.connect(_select_building)
	lot_a.selected.connect(_select_lot)
	lot_b.selected.connect(_select_lot)

	for target in get_raid_targets():
		target.selected.connect(_select_raid_target)

	set_view_mode(&"base")
	queue_redraw()


func set_view_mode(mode: StringName) -> void:
	if mode != &"base" and mode != &"world":
		return

	view_mode = mode
	_clear_selection()

	if view_mode == &"base":
		buildings_layer.visible = true
		raid_targets_layer.visible = false
		convoy_layer.visible = false
		effects_layer.visible = false
		camera.position = safehouse.position + Vector2(0, 60)
		camera.zoom = Vector2(1.0, 1.0)
	else:
		buildings_layer.visible = false
		raid_targets_layer.visible = true
		convoy_layer.visible = true
		effects_layer.visible = true
		camera.position = Vector2(0, 140)
		camera.zoom = Vector2(0.72, 0.72)

	view_mode_changed.emit(view_mode)


func get_view_mode() -> StringName:
	return view_mode


func get_persistent_buildings() -> Array:
	return [safehouse, hospital, barracks, lot_a, lot_b]


func get_raid_targets() -> Array:
	return [downtown_bank, harbor_bank, midtown_exchange, northside_hq, casino_vault, financial_tower, industrial_depot]


func get_raid_target_by_id(target_id: String) -> RaidTarget:
	for target in get_raid_targets():
		if target.get_target_id() == target_id:
			return target
	return null


func focus_raid_target_by_id(target_id: String) -> void:
	var target := get_raid_target_by_id(target_id)
	if target == null:
		return

	if view_mode != &"world":
		set_view_mode(&"world")
	if not target.visible:
		return

	focus_raid_target(target)


func launch_convoy_to(target_id: String, travel_time: float) -> void:
	var target := get_raid_target_by_id(target_id)
	if target == null:
		return

	if active_convoy != null and is_instance_valid(active_convoy):
		active_convoy.queue_free()

	active_convoy = CONVOY_SCENE.instantiate()
	convoy_layer.add_child(active_convoy)
	active_convoy.setup_path(_get_convoy_route(target_id), travel_time)


func restore_active_convoy(target_id: String, remaining_time: float) -> void:
	if remaining_time <= 0.0:
		return
	launch_convoy_to(target_id, remaining_time)


func show_raid_impact(result: Dictionary) -> void:
	var target := get_raid_target_by_id(String(result.get("target_id", "")))
	if target == null:
		return

	var effect: RaidImpactVFX = RAID_IMPACT_SCENE.instantiate()
	effects_layer.add_child(effect)
	effect.position = target.position + Vector2(0, -65)
	effect.setup(bool(result.get("victory", false)))


func _get_convoy_route(target_id: String) -> PackedVector2Array:
	var cells: Array[Vector2i] = [Vector2i(10, 10), Vector2i(12, 10), Vector2i(12, 7)]

	match target_id:
		"downtown_bank":
			cells.append_array([Vector2i(7, 7), Vector2i(7, 6), Vector2i(4, 6)])
		"harbor_bank":
			cells.append_array([Vector2i(17, 7), Vector2i(19, 7), Vector2i(19, 6)])
		"northside_hq":
			cells.append_array([Vector2i(12, 12), Vector2i(17, 12), Vector2i(17, 15), Vector2i(19, 15)])
		"casino_vault":
			cells.append_array([Vector2i(7, 7), Vector2i(7, 12), Vector2i(4, 12), Vector2i(4, 15)])
		"financial_tower":
			cells.append_array([Vector2i(17, 7), Vector2i(22, 7), Vector2i(22, 10)])
		"midtown_exchange":
			cells.append_array([Vector2i(7, 7), Vector2i(7, 10), Vector2i(4, 10)])
		"industrial_depot":
			cells.append_array([Vector2i(17, 12), Vector2i(22, 12), Vector2i(22, 17)])
		_:
			var target := get_raid_target_by_id(target_id)
			if target != null:
				return PackedVector2Array([
					safehouse.position + Vector2(0, -35),
					target.position + Vector2(0, -35)
				])

	var route := PackedVector2Array()
	for cell in cells:
		route.append(iso_to_screen(cell) + Vector2(0, -35))
	return route


func get_persistent_target(target_id: String) -> Node:
	match target_id:
		"safehouse":
			return safehouse
		"hospital":
			return hospital
		"barracks":
			return barracks
		"lot_garage":
			return lot_a
		"lot_intel":
			return lot_b
		_:
			return null


func get_target_id(target: Node) -> String:
	if target == safehouse:
		return "safehouse"
	if target == hospital:
		return "hospital"
	if target == barracks:
		return "barracks"
	if target == lot_a:
		return "lot_garage"
	if target == lot_b:
		return "lot_intel"
	return ""


func get_save_data() -> Dictionary:
	var raid_target_data := {}
	for target in get_raid_targets():
		raid_target_data[target.get_target_id()] = target.get_save_data()

	return {
		"safehouse_level": safehouse.level,
		"hospital_level": hospital.level,
		"barracks_level": barracks.level,
		"garage_built": lot_a.is_built,
		"garage_level": lot_a.level,
		"intel_built": lot_b.is_built,
		"intel_level": lot_b.level,
		"raid_targets": raid_target_data,
		"view_mode": String(view_mode)
	}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	safehouse.restore_progress(int(data.get("safehouse_level", safehouse.level)))
	hospital.restore_progress(int(data.get("hospital_level", hospital.level)))
	barracks.restore_progress(int(data.get("barracks_level", barracks.level)))
	lot_a.restore_progress(bool(data.get("garage_built", lot_a.is_built)), int(data.get("garage_level", 1)))
	lot_b.restore_progress(bool(data.get("intel_built", lot_b.is_built)), int(data.get("intel_level", 1)))

	var raid_target_data = data.get("raid_targets", {})
	if raid_target_data is Dictionary:
		for target in get_raid_targets():
			target.load_save_data(
				raid_target_data.get(target.get_target_id(), {}),
				offline_seconds
			)

	set_view_mode(StringName(data.get("view_mode", "base")))


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
	if view_mode != &"base":
		set_view_mode(&"base")

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


func focus_raid_target(target: RaidTarget) -> void:
	if view_mode != &"world":
		set_view_mode(&"world")

	_select_raid_target(target)
	camera.position = target.position + Vector2(0, -40)


func _clear_selection() -> void:
	if selected_target != null and selected_target.has_method("set_selected"):
		selected_target.call("set_selected", false)
	selected_target = null


func _select_building(building: Building) -> void:
	if view_mode != &"base":
		return

	_clear_selection()
	selected_target = building
	building.set_selected(true)
	building_selected.emit(building)


func _select_lot(lot: BuildLot) -> void:
	if view_mode != &"base":
		return

	_clear_selection()
	selected_target = lot
	lot.set_selected(true)
	lot_selected.emit(lot)


func _select_raid_target(target: RaidTarget) -> void:
	if view_mode != &"world":
		return

	_clear_selection()
	selected_target = target
	target.set_selected(true)
	raid_target_selected.emit(target)


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
	draw_polyline(
		PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
		_line_color,
		1.5
	)
