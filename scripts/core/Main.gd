extends Node

@onready var city_map = $CityMap
@onready var hospital_queue: HospitalQueue = $HospitalQueue
@onready var hud = $HUD


func _ready() -> void:
	hud.setup(hospital_queue)
	city_map.building_selected.connect(_on_building_selected)
	hud.focus_building_requested.connect(city_map.focus_building)


func _on_building_selected(building: Building) -> void:
	hud.show_building(building)
