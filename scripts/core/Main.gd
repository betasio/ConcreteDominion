extends Node

@onready var economy: PlayerEconomy = $PlayerEconomy
@onready var hospital_queue: HospitalQueue = $HospitalQueue
@onready var construction_queue: ConstructionQueue = $ConstructionQueue
@onready var city_map = $CityMap
@onready var hud = $HUD


func _ready() -> void:
	hospital_queue.setup(economy)
	construction_queue.setup(economy)
	hud.setup(economy, hospital_queue, construction_queue)

	city_map.building_selected.connect(_on_building_selected)
	city_map.lot_selected.connect(_on_lot_selected)
	hud.focus_building_requested.connect(city_map.focus_building)


func _on_building_selected(building: Building) -> void:
	hud.show_building(building)


func _on_lot_selected(lot: BuildLot) -> void:
	hud.show_lot(lot)
