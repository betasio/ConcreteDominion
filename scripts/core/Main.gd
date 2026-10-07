extends Node

@onready var economy: PlayerEconomy = $PlayerEconomy
@onready var troop_roster: TroopRoster = $TroopRoster
@onready var hospital_queue: HospitalQueue = $HospitalQueue
@onready var construction_queue: ConstructionQueue = $ConstructionQueue
@onready var recruitment_queue: RecruitmentQueue = $RecruitmentQueue
@onready var synergy_raid: SynergyRaid = $SynergyRaid
@onready var raid_battle: RaidBattle = $RaidBattle
@onready var save_manager: SaveManager = $SaveManager
@onready var city_map = $CityMap
@onready var hud = $HUD


func _ready() -> void:
	hospital_queue.setup(economy, troop_roster)
	construction_queue.setup(economy)
	recruitment_queue.setup(economy, troop_roster)
	raid_battle.setup(economy, troop_roster, hospital_queue, synergy_raid)

	save_manager.setup(
		economy,
		troop_roster,
		hospital_queue,
		construction_queue,
		recruitment_queue,
		raid_battle,
		city_map
	)
	save_manager.load_game()

	hud.setup(
		economy,
		troop_roster,
		hospital_queue,
		construction_queue,
		recruitment_queue,
		synergy_raid,
		raid_battle
	)

	city_map.building_selected.connect(_on_building_selected)
	city_map.lot_selected.connect(_on_lot_selected)
	hud.focus_building_requested.connect(city_map.focus_building)


func _on_building_selected(building: Building) -> void:
	hud.show_building(building)


func _on_lot_selected(lot: BuildLot) -> void:
	hud.show_lot(lot)
