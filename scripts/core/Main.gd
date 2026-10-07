extends Node

@onready var balance: GameBalance = $GameBalance
@onready var settings: SettingsManager = $SettingsManager
@onready var economy: PlayerEconomy = $PlayerEconomy
@onready var loot_inventory: LootInventory = $LootInventory
@onready var progression: PlayerProgression = $PlayerProgression
@onready var mission_tracker: MissionTracker = $MissionTracker
@onready var retention: RetentionManager = $RetentionManager
@onready var event_manager: EventManager = $EventManager
@onready var player_profile: PlayerProfile = $PlayerProfile
@onready var mailbox: MailboxManager = $MailboxManager
@onready var alliance_manager: AllianceManager = $AllianceManager
@onready var alliance_social: AllianceSocial = $AllianceSocial
@onready var troop_roster: TroopRoster = $TroopRoster
@onready var hospital_queue: HospitalQueue = $HospitalQueue
@onready var construction_queue: ConstructionQueue = $ConstructionQueue
@onready var recruitment_queue: RecruitmentQueue = $RecruitmentQueue
@onready var synergy_raid: SynergyRaid = $SynergyRaid
@onready var combat_loadout: CombatLoadout = $CombatLoadout
@onready var raid_battle: RaidBattle = $RaidBattle
@onready var save_manager: SaveManager = $SaveManager
@onready var city_map = $CityMap
@onready var hud = $HUD
@onready var progression_ui: ProgressionUI = $ProgressionUI
@onready var retention_ui: RetentionUI = $RetentionUI
@onready var profile_ui: ProfileUI = $ProfileUI
@onready var event_ui: EventUI = $EventUI
@onready var combat_strategy_ui: CombatStrategyUI = $CombatStrategyUI
@onready var safe_area_manager: SafeAreaManager = $SafeAreaManager
@onready var settings_ui: SettingsDiagnosticsUI = $SettingsDiagnosticsUI
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var audio_manager: AudioManager = $AudioManager
@onready var ui_focus_manager: UIFocusManager = $UIFocusManager


func _ready() -> void:
	progression.setup(loot_inventory, balance)
	synergy_raid.setup(progression)
	city_map.setup_progression(progression)
	alliance_social.setup(alliance_manager)
	hospital_queue.setup(economy, troop_roster, balance)
	construction_queue.setup(economy, balance)
	recruitment_queue.setup(economy, troop_roster, balance)
	combat_loadout.setup(loot_inventory, progression)

	raid_battle.setup(
		economy,
		troop_roster,
		hospital_queue,
		synergy_raid,
		loot_inventory,
		alliance_manager,
		progression,
		combat_loadout,
		city_map
	)

	retention.setup(
		economy,
		loot_inventory,
		progression,
		recruitment_queue,
		raid_battle
	)

	event_manager.setup(
		economy,
		loot_inventory,
		progression,
		raid_battle
	)

	player_profile.setup(
		progression,
		troop_roster,
		city_map,
		retention
	)

	mailbox.setup(
		economy,
		loot_inventory,
		progression
	)

	raid_battle.battle_started.connect(city_map.launch_convoy_to)
	raid_battle.battle_resolved.connect(_on_raid_resolved_feedback)

	save_manager.setup(
		economy,
		loot_inventory,
		progression,
		mission_tracker,
		retention,
		event_manager,
		combat_loadout,
		player_profile,
		mailbox,
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
	profile_ui.setup(player_profile, mailbox, progression)
	event_ui.setup(event_manager)
	combat_strategy_ui.setup(combat_loadout, loot_inventory, city_map)

	settings.changed.connect(_apply_runtime_settings)
	_apply_runtime_settings()

	var safe_roots: Array[Control] = [
		hud.get_node("Root") as Control,
		progression_ui.get_node("Root") as Control,
		retention_ui.get_node("Root") as Control,
		profile_ui.get_node("Root") as Control,
		event_ui.get_node("Root") as Control,
		combat_strategy_ui.get_node("Root") as Control,
		settings_ui.get_node("Root") as Control
	]
	safe_area_manager.setup(safe_roots)
	settings_ui.setup(settings, save_manager, balance, safe_roots)
	pause_menu.setup(save_manager)
	ui_focus_manager.setup(self)
	audio_manager.setup(self)
	retention.login_reward_claimed.connect(func(_reward): audio_manager.play_reward())
	retention.achievement_unlocked.connect(func(_achievement_id): audio_manager.play_reward())
	event_manager.milestone_claimed.connect(func(_points): audio_manager.play_reward())
	mission_tracker.mission_completed.connect(func(_mission_id): audio_manager.play_reward())

	hud.setup(
		economy,
		loot_inventory,
		alliance_manager,
		alliance_social,
		troop_roster,
		hospital_queue,
		construction_queue,
		recruitment_queue,
		synergy_raid,
		raid_battle,
		settings
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



func _apply_runtime_settings() -> void:
	settings.apply_runtime_settings()
	if city_map != null and city_map.camera != null:
		city_map.camera.edge_pan_enabled = settings.edge_pan_enabled


func _on_raid_resolved_feedback(result: Dictionary) -> void:
	if settings.reduced_motion:
		pass
	else:
		city_map.show_raid_impact(result)

	audio_manager.play_raid_result(bool(result.get("victory", false)))
	settings.pulse_haptic(70 if bool(result.get("victory", false)) else 110, 1.0 if bool(result.get("victory", false)) else 0.6)
