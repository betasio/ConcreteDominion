extends Node

@onready var economy: PlayerEconomy = $PlayerEconomy
@onready var loot_inventory: LootInventory = $LootInventory
@onready var progression: PlayerProgression = $PlayerProgression
@onready var mission_tracker: MissionTracker = $MissionTracker
@onready var retention: RetentionManager = $RetentionManager
@onready var alliance_manager: AllianceManager = $AllianceManager
@onready var alliance_social: AllianceSocial = $AllianceSocial
@onready var troop_roster: TroopRoster = $TroopRoster
@onready var hospital_queue: HospitalQueue = $HospitalQueue
@onready var construction_queue: ConstructionQueue = $ConstructionQueue
@onready var recruitment_queue: RecruitmentQueue = $RecruitmentQueue
@onready var synergy_raid: SynergyRaid = $SynergyRaid
@onready var raid_battle: RaidBattle = $RaidBattle
@onready var save_manager: SaveManager = $SaveManager
@onready var city_map = $CityMap
@onready var hud = $HUD
@onready var progression_ui: ProgressionUI = $ProgressionUI
@onready var retention_ui: RetentionUI = $RetentionUI


func _ready() -> void:
	progression.setup(loot_inventory)
	synergy_raid.setup(progression)
	city_map.setup_progression(progression)
	alliance_social.setup(alliance_manager)
	hospital_queue.setup(economy, troop_roster)
	construction_queue.setup(economy)
	recruitment_queue.setup(economy, troop_roster)

	raid_battle.setup(
		economy,
		troop_roster,
		hospital_queue,
		synergy_raid,
		loot_inventory,
		alliance_manager,
		progression,
		city_map
	)

	retention.setup(
		economy,
		loot_inventory,
		progression,
		recruitment_queue,
		raid_battle
	)

	raid_battle.battle_started.connect(city_map.launch_convoy_to)
	raid_battle.battle_resolved.connect(city_map.show_raid_impact)

	save_manager.setup(
		economy,
		loot_inventory,
		progression,
		mission_tracker,
		retention,
		alliance_manager,
		alliance_social,
		troop_roster,
		hospital_queue,
		construction_queue,
		recruitment_queue,
		raid_battle,
		city_map
	)
	save_manager.load_game()

	mission_tracker.setup(
		progression,
		economy,
		recruitment_queue,
		construction_queue,
		raid_battle
	)

	if raid_battle.is_active():
		city_map.restore_active_convoy(
			String(raid_battle.active_battle.get("target_id", "")),
			float(raid_battle.active_battle.get("seconds_remaining", 0.0))
		)

	progression_ui.setup(progression, mission_tracker, loot_inventory)
	retention_ui.setup(retention)

	hud.setup(
		economy,
		loot_inventory,
		progression,
		mission_tracker,
		alliance_manager,
		alliance_social,
		troop_roster,
		hospital_queue,
		construction_queue,
		recruitment_queue,
		synergy_raid,
		raid_battle
	)

	city_map.building_selected.connect(_on_building_selected)
	city_map.lot_selected.connect(_on_lot_selected)
	city_map.raid_target_selected.connect(_on_raid_target_selected)
	city_map.view_mode_changed.connect(hud.set_view_mode_display)

	hud.focus_building_requested.connect(city_map.focus_building)
	hud.view_mode_requested.connect(city_map.set_view_mode)
	hud.focus_raid_target_requested.connect(city_map.focus_raid_target_by_id)


func _on_building_selected(building: Building) -> void:
	hud.show_building(building)


func _on_lot_selected(lot: BuildLot) -> void:
	hud.show_lot(lot)


func _on_raid_target_selected(target: RaidTarget) -> void:
	hud.show_raid_target(target)
