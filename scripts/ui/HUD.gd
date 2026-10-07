extends CanvasLayer

signal focus_building_requested(building_type: StringName)
signal view_mode_requested(mode: StringName)
signal focus_raid_target_requested(target_id: String)

var economy: PlayerEconomy
var loot_inventory: LootInventory
var troop_roster: TroopRoster
var hospital_queue: HospitalQueue
var construction_queue: ConstructionQueue
var recruitment_queue: RecruitmentQueue
var synergy_raid: SynergyRaid
var alliance_manager: AllianceManager
var alliance_social: AllianceSocial
var raid_battle: RaidBattle
var settings_manager: SettingsManager
var presentation_catalog: PresentationCatalog
var city_map: Node
var core_effects: CoreBuildingEffects
var progression: PlayerProgression

var selected_building: Building
var selected_lot: BuildLot
var selected_raid_target: RaidTarget
var raid_drivers := 0
var raid_spies := 0

@onready var cash_label: Label = $Root/TopBar/Panel/HBox/Cash
@onready var gold_label: Label = $Root/TopBar/Panel/HBox/Gold
@onready var loot_label: Label = $Root/TopBar/Panel/HBox/Loot
@onready var selection_panel: PanelContainer = $Root/SelectionPanel
@onready var selection_title: Label = $Root/SelectionPanel/Margin/VBox/Title
@onready var selection_description: Label = $Root/SelectionPanel/Margin/VBox/Description
@onready var level_label: Label = $Root/SelectionPanel/Margin/VBox/Level
@onready var upgrade_button: Button = $Root/SelectionPanel/Margin/VBox/Upgrade
@onready var build_button: Button = $Root/SelectionPanel/Margin/VBox/Build
@onready var open_hospital_button: Button = $Root/SelectionPanel/Margin/VBox/OpenHospital
@onready var open_barracks_button: Button = $Root/SelectionPanel/Margin/VBox/OpenBarracks

@onready var hospital_panel: PanelContainer = $Root/HospitalPanel
@onready var queue_label: Label = $Root/HospitalPanel/Margin/VBox/Queue
@onready var cost_label: Label = $Root/HospitalPanel/Margin/VBox/Cost
@onready var instant_button: Button = $Root/HospitalPanel/Margin/VBox/InstantHeal

@onready var construction_bar: PanelContainer = $Root/ConstructionBar
@onready var construction_label: Label = $Root/ConstructionBar/Margin/HBox/Status
@onready var finish_button: Button = $Root/ConstructionBar/Margin/HBox/FinishNow

@onready var barracks_panel: PanelContainer = $Root/BarracksPanel
@onready var roster_label: Label = $Root/BarracksPanel/Margin/VBox/Roster
@onready var recruitment_status: Label = $Root/BarracksPanel/Margin/VBox/RecruitmentStatus
@onready var recruit_enforcer_button: Button = $Root/BarracksPanel/Margin/VBox/RecruitEnforcer
@onready var recruit_driver_button: Button = $Root/BarracksPanel/Margin/VBox/RecruitDriver
@onready var recruit_spy_button: Button = $Root/BarracksPanel/Margin/VBox/RecruitSpy
@onready var finish_recruitment_button: Button = $Root/BarracksPanel/Margin/VBox/FinishRecruitment

@onready var raid_panel: PanelContainer = $Root/RaidPanel
@onready var raid_target_label: Label = $Root/RaidPanel/Margin/VBox/Target
@onready var alliance_roster_label: Label = $Root/RaidPanel/Margin/VBox/AllianceRoster
@onready var alliance_slots_label: Label = $Root/RaidPanel/Margin/VBox/AllianceSlots
@onready var raid_roster_label: Label = $Root/RaidPanel/Margin/VBox/Roster
@onready var raid_status_label: Label = $Root/RaidPanel/Margin/VBox/Status
@onready var raid_result_label: Label = $Root/RaidPanel/Margin/VBox/Result
@onready var add_driver_button: Button = $Root/RaidPanel/Margin/VBox/AddDriver
@onready var add_spy_button: Button = $Root/RaidPanel/Margin/VBox/AddSpy
@onready var preview_raid_button: Button = $Root/RaidPanel/Margin/VBox/Calculate
@onready var launch_raid_button: Button = $Root/RaidPanel/Margin/VBox/Launch

@onready var base_button: Button = $Root/ViewBar/Base
@onready var world_button: Button = $Root/ViewBar/World
@onready var alliance_panel: PanelContainer = $Root/AlliancePanel
@onready var alliance_feed_label: Label = $Root/AlliancePanel/Margin/VBox/Feed
@onready var invite_status_label: Label = $Root/AlliancePanel/Margin/VBox/InviteStatus
@onready var invite_button: Button = $Root/AlliancePanel/Margin/VBox/CreateInvite
@onready var invite_driver_button: Button = $Root/AlliancePanel/Margin/VBox/JoinDriver
@onready var invite_spy_button: Button = $Root/AlliancePanel/Margin/VBox/JoinSpy
@onready var alliance_profiles: HFlowContainer = $Root/AlliancePanel/Margin/VBox/Profiles
@onready var result_overlay: PanelContainer = $Root/ResultOverlay
@onready var result_overlay_title: Label = $Root/ResultOverlay/Margin/VBox/Title
@onready var result_overlay_body: Label = $Root/ResultOverlay/Margin/VBox/Body


func setup(
	player_economy: PlayerEconomy,
	loot: LootInventory,
	alliance: AllianceManager,
	social: AllianceSocial,
	roster: TroopRoster,
	clinic: HospitalQueue,
	construction: ConstructionQueue,
	recruitment: RecruitmentQueue,
	raid: SynergyRaid,
	battle: RaidBattle,
	world: Node,
	building_effects: CoreBuildingEffects,
	player_progression: PlayerProgression,
	settings: SettingsManager = null
) -> void:
	economy = player_economy
	loot_inventory = loot
	alliance_manager = alliance
	alliance_social = social
	troop_roster = roster
	hospital_queue = clinic
	construction_queue = construction
	recruitment_queue = recruitment
	synergy_raid = raid
	raid_battle = battle
	city_map = world
	core_effects = building_effects
	progression = player_progression
	settings_manager = settings
	presentation_catalog = get_parent().get_node_or_null("PresentationCatalog") as PresentationCatalog

	economy.changed.connect(_refresh_all)
	loot_inventory.changed.connect(_refresh_all)
	troop_roster.changed.connect(_refresh_all)
	hospital_queue.queue_changed.connect(_refresh_hospital)
	construction_queue.queue_changed.connect(_refresh_construction)
	construction_queue.construction_completed.connect(_on_construction_completed)
	recruitment_queue.queue_changed.connect(_refresh_recruitment)
	recruitment_queue.recruitment_completed.connect(_on_recruitment_completed)
	alliance_manager.changed.connect(_on_alliance_changed)
	alliance_social.changed.connect(_refresh_alliance_social)
	raid_battle.changed.connect(_refresh_raid)
	raid_battle.battle_resolved.connect(_on_raid_resolved)

	$Root/HospitalShortcut.pressed.connect(_on_hospital_shortcut)
	$Root/BarracksShortcut.pressed.connect(_on_barracks_shortcut)
	$Root/RaidShortcut.pressed.connect(_open_raid)
	$Root/AllianceShortcut.pressed.connect(_open_alliance_panel)
	base_button.pressed.connect(func(): view_mode_requested.emit(&"base"))
	world_button.pressed.connect(func(): view_mode_requested.emit(&"world"))

	$Root/SelectionPanel/Margin/VBox/Close.pressed.connect(_close_selection)
	open_hospital_button.pressed.connect(_open_hospital)
	open_barracks_button.pressed.connect(_open_barracks)
	upgrade_button.pressed.connect(_upgrade_selected)
	build_button.pressed.connect(_build_selected_lot)

	$Root/HospitalPanel/Margin/VBox/SimulateBattle.pressed.connect(_simulate_battle)
	instant_button.pressed.connect(_instant_heal)
	$Root/HospitalPanel/Margin/VBox/Close.pressed.connect(_close_hospital)
	finish_button.pressed.connect(_finish_construction)

	recruit_enforcer_button.pressed.connect(func(): _recruit(&"Enforcer", 5))
	recruit_driver_button.pressed.connect(func(): _recruit(&"Driver", 3))
	recruit_spy_button.pressed.connect(func(): _recruit(&"Spy", 3))
	finish_recruitment_button.pressed.connect(_finish_recruitment)
	$Root/BarracksPanel/Margin/VBox/Close.pressed.connect(_close_barracks)

	add_driver_button.pressed.connect(_join_driver_slot)
	add_spy_button.pressed.connect(_join_spy_slot)
	$Root/RaidPanel/Margin/VBox/ToggleKira.pressed.connect(_toggle_kira_online)
	preview_raid_button.pressed.connect(_calculate_raid)
	launch_raid_button.pressed.connect(_launch_raid)
	$Root/RaidPanel/Margin/VBox/Reset.pressed.connect(_prepare_raid)
	$Root/RaidPanel/Margin/VBox/Close.pressed.connect(_close_raid)

	invite_button.pressed.connect(_create_raid_invite)
	invite_driver_button.pressed.connect(func(): _join_social_invite(&"driver"))
	invite_spy_button.pressed.connect(func(): _join_social_invite(&"spy"))
	$Root/AlliancePanel/Margin/VBox/PostMessage.pressed.connect(_post_alliance_message)
	$Root/AlliancePanel/Margin/VBox/Close.pressed.connect(_close_alliance_panel)
	$Root/ResultOverlay/Margin/VBox/Close.pressed.connect(_close_result_overlay)

	_apply_portrait_art()
	_refresh_all()
	_refresh_alliance_social()
	_refresh_alliance_profiles()
	set_view_mode_display(city_map.get_view_mode() if city_map != null else &"base")


func show_building(building: Building) -> void:
	selected_building = building
	selected_lot = null
	selection_title.text = building.display_name
	selection_description.text = building.description
	level_label.visible = true
	level_label.text = "Level %d" % building.level
	open_hospital_button.visible = building.building_type == &"hospital"
	open_barracks_button.visible = building.building_type == &"barracks"
	upgrade_button.visible = true
	build_button.visible = false
	_refresh_selection()
	selection_panel.visible = true

	if building.building_type == &"hospital":
		_open_hospital()
	elif building.building_type == &"barracks":
		_open_barracks()


func show_lot(lot: BuildLot) -> void:
	selected_lot = lot
	selected_building = null
	selected_raid_target = null
	selection_title.text = lot.building_name if lot.is_built else "Empty Build Lot"
	selection_description.text = lot.description
	level_label.visible = lot.is_built
	level_label.text = "Level %d" % lot.level if lot.is_built else ""
	open_hospital_button.visible = false
	open_barracks_button.visible = false
	upgrade_button.visible = lot.is_built
	build_button.visible = not lot.is_built
	_refresh_selection()
	selection_panel.visible = true


func set_view_mode_display(mode: StringName) -> void:
	var is_base := mode == &"base"
	base_button.disabled = is_base
	world_button.disabled = not is_base

	$Root/HospitalShortcut.visible = is_base
	$Root/BarracksShortcut.visible = is_base
	$Root/RaidShortcut.visible = not is_base

	if is_base:
		raid_panel.visible = false
	else:
		selection_panel.visible = false
		hospital_panel.visible = false
		barracks_panel.visible = false


func _refresh_all() -> void:
	if economy == null:
		return
	cash_label.text = "Cash: $%s" % _format_number(economy.cash)
	gold_label.text = "Gold: %d" % economy.gold
	loot_label.text = "Loot P:%d I:%d C:%d" % [
		loot_inventory.get_count("Parts"),
		loot_inventory.get_count("Intel"),
		loot_inventory.get_count("Contraband")
	]
	_refresh_hospital()
	_refresh_construction()
	_refresh_recruitment()
	_refresh_selection()
	if raid_panel.visible:
		_refresh_raid()


func _refresh_selection() -> void:
	if construction_queue == null:
		return

	if selected_building != null:
		level_label.text = "Level %d%s" % [
			selected_building.level,
			" (upgrading)" if selected_building.is_constructing else ""
		]
		selection_description.text = "%s\n\n%s" % [
			selected_building.description,
			core_effects.get_building_effect_summary(selected_building) if core_effects != null else ""
		]
		var cash_cost := selected_building.get_upgrade_cash_cost()
		if selected_building.level >= selected_building.max_level:
			upgrade_button.text = "MAX LEVEL"
			upgrade_button.disabled = true
		else:
			upgrade_button.text = "Upgrade to Lv.%d — $%s" % [selected_building.level + 1, _format_number(cash_cost)]
			upgrade_button.disabled = construction_queue.is_busy() or selected_building.is_constructing or economy.cash < cash_cost

	if selected_lot != null:
		var unlocked := progression.is_building_unlocked(selected_lot.building_name) if progression != null else true
		var required_level := progression.get_building_unlock_level(selected_lot.building_name)

		if selected_lot.is_built:
			level_label.text = "Level %d%s" % [
				selected_lot.level,
				" (upgrading)" if selected_lot.is_constructing else ""
			]
			selection_description.text = "%s\n\n%s" % [
				selected_lot.description,
				selected_lot.get_effect_summary()
			]
			var facility_cost := selected_lot.get_upgrade_cash_cost()
			if selected_lot.level >= selected_lot.max_level:
				upgrade_button.text = "MAX LEVEL"
				upgrade_button.disabled = true
			else:
				upgrade_button.text = "Upgrade to Lv.%d — $%s" % [
					selected_lot.level + 1,
					_format_number(facility_cost)
				]
				upgrade_button.disabled = (
					construction_queue.is_busy()
					or selected_lot.is_constructing
					or economy.cash < facility_cost
				)
			build_button.visible = false
		else:
			selection_description.text = selected_lot.description
			if unlocked:
				build_button.text = "Build %s — $%s" % [
					selected_lot.building_name,
					_format_number(selected_lot.build_cash_cost)
				]
			else:
				build_button.text = "%s unlocks at Account Lv.%d" % [
					selected_lot.building_name,
					required_level
				]

			build_button.disabled = (
				not unlocked
				or construction_queue.is_busy()
				or economy.cash < selected_lot.build_cash_cost
			)


func _upgrade_selected() -> void:
	if selected_building != null:
		construction_queue.start_upgrade(selected_building)
	elif selected_lot != null and selected_lot.is_built:
		construction_queue.start_facility_upgrade(selected_lot)
	_refresh_all()


func _build_selected_lot() -> void:
	if selected_lot != null:
		construction_queue.start_lot_build(selected_lot)
		_refresh_all()


func _refresh_construction() -> void:
	if construction_queue == null or construction_queue.active_job.is_empty():
		construction_bar.visible = false
		_refresh_selection()
		return

	construction_bar.visible = true
	var job := construction_queue.active_job
	var finish_cost := construction_queue.get_finish_now_cost()
	construction_label.text = "Building: %s — %s remaining" % [
		String(job["label"]),
		_format_time(float(job["seconds_remaining"]))
	]
	finish_button.text = "Finish Now (%d Gold)" % finish_cost
	finish_button.disabled = economy.gold < finish_cost
	_refresh_selection()


func _finish_construction() -> void:
	construction_queue.finish_now()
	_refresh_all()


func _on_construction_completed(_target: Node) -> void:
	_refresh_all()


func _on_hospital_shortcut() -> void:
	focus_building_requested.emit(&"hospital")
	_open_hospital()


func _open_hospital() -> void:
	hospital_panel.visible = true
	_refresh_hospital()


func _close_hospital() -> void:
	hospital_panel.visible = false


func _simulate_battle() -> void:
	var enforcer_wounds := mini(4, troop_roster.get_count(&"Enforcer"))
	var driver_wounds := mini(1, troop_roster.get_count(&"Driver"))
	if enforcer_wounds > 0:
		hospital_queue.send_to_hospital(&"Enforcer", enforcer_wounds)
	if driver_wounds > 0:
		hospital_queue.send_to_hospital(&"Driver", driver_wounds)
	_refresh_hospital()


func _instant_heal() -> void:
	hospital_queue.instant_heal()
	_refresh_all()


func _refresh_hospital() -> void:
	if hospital_queue == null or economy == null:
		return

	if hospital_queue.wounded_queue.is_empty():
		var slots: int = core_effects.get_clinic_slots() if core_effects != null else 1
		queue_label.text = "Clinic queue is empty. Your crew is ready.\nTreatment slots: %d" % slots
		cost_label.text = "Instant heal cost: 0 Gold"
		instant_button.disabled = true
		return

	var lines: PackedStringArray = []
	for i in range(hospital_queue.wounded_queue.size()):
		var entry: Dictionary = hospital_queue.wounded_queue[i]
		lines.append("%d. %s x%d — %s — %s" % [
			i + 1,
			String(entry["troop_type"]),
			int(entry["amount"]),
			String(entry.get("severity", "Standard")),
			_format_time(float(entry["seconds_remaining"]))
		])

	var clinic_slots: int = core_effects.get_clinic_slots() if core_effects != null else 1
	queue_label.text = "Treatment slots: %d\n%s" % [clinic_slots, "\n".join(lines)]
	var cost := hospital_queue.get_instant_heal_cost()
	cost_label.text = "Instant heal cost: %d Gold" % cost
	instant_button.disabled = economy.gold < cost


func _on_barracks_shortcut() -> void:
	focus_building_requested.emit(&"barracks")
	_open_barracks()


func _open_barracks() -> void:
	barracks_panel.visible = true
	_refresh_recruitment()


func _close_barracks() -> void:
	barracks_panel.visible = false


func _recruit(troop_type: StringName, amount: int) -> void:
	recruitment_queue.recruit(troop_type, amount)
	_refresh_all()


func _finish_recruitment() -> void:
	recruitment_queue.finish_now()
	_refresh_all()


func _on_recruitment_completed(_troop_type: StringName, _amount: int) -> void:
	_refresh_all()


func _refresh_recruitment() -> void:
	if recruitment_queue == null or troop_roster == null or economy == null:
		return

	roster_label.text = "Enforcers: %d   Drivers: %d   Spies: %d" % [
		troop_roster.get_count(&"Enforcer"),
		troop_roster.get_count(&"Driver"),
		troop_roster.get_count(&"Spy")
	]

	var queue_full := recruitment_queue.get_queue_size() >= recruitment_queue.get_queue_capacity()
	recruit_enforcer_button.text = "Recruit 5 Enforcers — $%s" % _format_number(recruitment_queue.get_cash_cost(&"Enforcer", 5))
	recruit_driver_button.text = "Recruit 3 Drivers — $%s" % _format_number(recruitment_queue.get_cash_cost(&"Driver", 3))
	recruit_spy_button.text = "Recruit 3 Spies — $%s" % _format_number(recruitment_queue.get_cash_cost(&"Spy", 3))

	recruit_enforcer_button.disabled = queue_full or economy.cash < recruitment_queue.get_cash_cost(&"Enforcer", 5)
	recruit_driver_button.disabled = queue_full or economy.cash < recruitment_queue.get_cash_cost(&"Driver", 3)
	recruit_spy_button.disabled = queue_full or economy.cash < recruitment_queue.get_cash_cost(&"Spy", 3)

	if recruitment_queue.active_job.is_empty():
		recruitment_status.text = "Recruitment queue is ready. Slots: %d" % recruitment_queue.get_queue_capacity()
		finish_recruitment_button.visible = false
	else:
		var job := recruitment_queue.active_job
		var finish_cost := recruitment_queue.get_finish_now_cost()
		recruitment_status.text = "Training %s x%d — %s remaining\nQueue: %d/%d (%d waiting)" % [
			String(job["troop_type"]),
			int(job["amount"]),
			_format_time(float(job["seconds_remaining"])),
			recruitment_queue.get_queue_size(),
			recruitment_queue.get_queue_capacity(),
			recruitment_queue.queued_jobs.size()
		]
		finish_recruitment_button.visible = true
		finish_recruitment_button.text = "Finish Training (%d Gold)" % finish_cost
		finish_recruitment_button.disabled = economy.gold < finish_cost


func show_raid_target(target: RaidTarget) -> void:
	selected_building = null
	selected_lot = null
	selected_raid_target = target

	if not target.changed.is_connected(_refresh_raid):
		target.changed.connect(_refresh_raid)

	raid_panel.visible = true

	if raid_battle.is_active():
		raid_drivers = int(raid_battle.active_battle.get("local_drivers", 0))
		raid_spies = int(raid_battle.active_battle.get("local_spies", 0))
	else:
		_prepare_raid()

	_refresh_raid()


func _open_raid() -> void:
	raid_panel.visible = true

	if raid_battle.is_active():
		selected_raid_target = city_map.get_raid_target_by_id(
			String(raid_battle.active_battle.get("target_id", ""))
		)
		raid_drivers = int(raid_battle.active_battle.get("local_drivers", 0))
		raid_spies = int(raid_battle.active_battle.get("local_spies", 0))
	elif selected_raid_target == null:
		var targets: Array = city_map.get_raid_targets() if city_map != null else []
		for target in targets:
			if target.visible and target.is_available():
				selected_raid_target = target
				break
		if selected_raid_target == null and not targets.is_empty():
			selected_raid_target = targets[0]
		_prepare_raid()
	else:
		_prepare_raid()

	_refresh_raid()


func _close_raid() -> void:
	raid_panel.visible = false


func _prepare_raid() -> void:
	if raid_battle != null and raid_battle.is_active():
		return

	raid_drivers = 0
	raid_spies = 0
	alliance_manager.clear_local_player()
	_rebuild_synergy_from_alliance()
	raid_result_label.text = "Choose your role, review the alliance slots, then launch."
	_refresh_raid()


func _join_driver_slot() -> void:
	if raid_battle.is_active() or troop_roster.get_count(&"Driver") <= 0:
		return

	if alliance_manager.assign_local_player(&"driver"):
		raid_drivers = 1
		raid_spies = 0
		_rebuild_synergy_from_alliance()
	_refresh_raid()


func _join_spy_slot() -> void:
	if raid_battle.is_active() or troop_roster.get_count(&"Spy") <= 0:
		return

	if alliance_manager.assign_local_player(&"spy"):
		raid_drivers = 0
		raid_spies = 1
		_rebuild_synergy_from_alliance()
	_refresh_raid()


func _toggle_kira_online() -> void:
	if raid_battle.is_active():
		return

	alliance_manager.toggle_member_online("driver_ally_02")
	_rebuild_synergy_from_alliance()
	_refresh_raid()


func _rebuild_synergy_from_alliance() -> void:
	synergy_raid.clear()
	var snapshot := alliance_manager.build_participant_snapshot(
		raid_drivers,
		raid_spies
	)

	for participant in snapshot:
		var role := StringName(participant["role"])

		if bool(participant["is_local"]):
			if role == &"driver" and raid_drivers <= 0:
				continue
			if role == &"spy" and raid_spies <= 0:
				continue

		synergy_raid.join_raid(
			String(participant["player_id"]),
			int(participant["level"]),
			float(participant["base_power"]),
			role,
			String(participant["name"])
		)


func _refresh_raid() -> void:
	if synergy_raid == null or troop_roster == null or raid_battle == null or alliance_manager == null:
		return

	var active := raid_battle.is_active()

	if active:
		var active_id := String(raid_battle.active_battle.get("target_id", ""))
		selected_raid_target = city_map.get_raid_target_by_id(active_id) if city_map != null else null

	if selected_raid_target == null:
		raid_target_label.text = "No raid target selected."
		raid_status_label.text = "Click a Bank or Turf HQ on the city map."
		add_driver_button.disabled = true
		add_spy_button.disabled = true
		preview_raid_button.disabled = true
		launch_raid_button.disabled = true
		$Root/RaidPanel/Margin/VBox/Reset.disabled = true
		return

	var loot_preview := _format_loot(selected_raid_target.get_loot_preview())
	raid_target_label.text = "TARGET: %s\nDistrict: %s   HP: %s   Difficulty: %s\nModifier: %s — %s\nWeakness: %s (+%d%% when present)\nReward: $%s + %d XP + %s\nUnlock: Account Lv.%d" % [
		selected_raid_target.get_display_name(),
		selected_raid_target.get_district_name(),
		_format_number(roundi(selected_raid_target.get_max_hp())),
		selected_raid_target.get_difficulty(),
		selected_raid_target.get_modifier_name(),
		selected_raid_target.get_modifier_description(),
		String(selected_raid_target.get_weakness_role()),
		roundi(selected_raid_target.get_weakness_bonus() * 100.0),
		_format_number(selected_raid_target.get_reward_cash()),
		selected_raid_target.get_reward_xp(),
		loot_preview,
		selected_raid_target.get_required_account_level()
	]

	_refresh_alliance_labels()

	var target_available := selected_raid_target.is_available()
	var local_assigned := alliance_manager.is_member_assigned("local_player")
	add_driver_button.text = "Join Driver Slot" if raid_drivers == 0 else "Driver Slot: You"
	add_spy_button.text = "Join Spy Slot" if raid_spies == 0 else "Spy Slot: You"
	add_driver_button.disabled = active or not target_available or troop_roster.get_count(&"Driver") <= 0 or raid_drivers > 0
	add_spy_button.disabled = active or not target_available or troop_roster.get_count(&"Spy") <= 0 or raid_spies > 0
	preview_raid_button.disabled = active or not target_available
	launch_raid_button.disabled = active or not target_available
	$Root/RaidPanel/Margin/VBox/Reset.disabled = active or not target_available
	$Root/RaidPanel/Margin/VBox/ToggleKira.disabled = active

	if local_assigned:
		raid_roster_label.text = "Your specialist commitment: %s\nAvailable roster: %d Drivers, %d Spies" % [
			"Driver" if raid_drivers > 0 else "Spy",
			troop_roster.get_count(&"Driver"),
			troop_roster.get_count(&"Spy")
		]
	else:
		raid_roster_label.text = "You are not currently assigned to a raid slot.\nAvailable roster: %d Drivers, %d Spies" % [
			troop_roster.get_count(&"Driver"),
			troop_roster.get_count(&"Spy")
		]

	if active:
		raid_status_label.text = "Raid convoy launching... %s" % _format_time(float(raid_battle.active_battle["seconds_remaining"]))
		launch_raid_button.text = "Raid In Progress"
	elif not selected_raid_target.is_unlocked():
		raid_status_label.text = "LOCKED — reach Account Lv.%d." % selected_raid_target.get_required_account_level()
		launch_raid_button.text = "Target Locked"
	elif not target_available:
		raid_status_label.text = "Target respawning in %s" % _format_time(selected_raid_target.cooldown_remaining)
		launch_raid_button.text = "Target Unavailable"
	else:
		raid_status_label.text = "Ready to launch."
		launch_raid_button.text = "Launch Alliance Raid"

	if not active and not raid_battle.last_result.is_empty():
		_show_raid_result(raid_battle.last_result)


func _refresh_alliance_labels() -> void:
	var member_lines: PackedStringArray = []

	for member in alliance_manager.get_members():
		var state := "ONLINE" if bool(member["online"]) else "OFFLINE"
		member_lines.append("%s — Lv.%d — %s — %s" % [
			String(member["name"]),
			int(member["level"]),
			String(member["preferred_role"]).capitalize(),
			state
		])

	alliance_roster_label.text = "ALLIANCE\n" + "\n".join(member_lines)

	var slot_lines: PackedStringArray = []
	for slot in alliance_manager.get_raid_slots():
		var member_id := String(slot["member_id"])
		var member_name := "Empty"
		if member_id != "":
			var member := alliance_manager.get_member(member_id)
			member_name = String(member.get("name", member_id))

		slot_lines.append("%s: %s" % [
			String(slot["role"]).capitalize(),
			member_name
		])

	alliance_slots_label.text = "RAID SLOTS\n" + "\n".join(slot_lines)


func _calculate_raid() -> void:
	if selected_raid_target == null:
		return

	var preview := raid_battle.preview_battle(
		selected_raid_target,
		raid_drivers,
		raid_spies
	)

	if preview.is_empty():
		raid_result_label.text = "Unable to build a valid raid preview."
		return

	var raid_math: Dictionary = preview["raid_math"]
	var contribution_text := _format_contributions(
		raid_math.get("contributions", {}),
		preview.get("participants", [])
	)

	var weakness_text := "COUNTER MATCHED" if bool(preview["weakness_matched"]) else "Counter missing"
	var equipment_text := "active" if bool(preview["equipment_matched"]) else "not matched"

	raid_result_label.text = "Projected Grade: %s\nFinal damage: %s / %s HP\nSupport: +%d%%   %s\nPreset: %s   Equipment: %s (%s)\nConsumable: %s   Reward x%.2f   Injury risk x%.2f\n%s" % [
		String(preview["grade"]),
		_format_number(roundi(float(preview["damage"]))),
		_format_number(roundi(float(preview["target_hp"]))),
		roundi(float(raid_math["support_bonus"]) * 100.0),
		weakness_text,
		String(preview["preset"]),
		String(preview["equipment_role"]),
		equipment_text,
		String(preview["consumable"]),
		float(preview["reward_multiplier"]),
		float(preview["wound_multiplier"]),
		contribution_text
	]


func _launch_raid() -> void:
	if selected_raid_target == null:
		return

	if raid_battle.start_battle(selected_raid_target, raid_drivers, raid_spies):
		raid_result_label.text = "Alliance convoy moving on %s..." % selected_raid_target.get_display_name()
		_refresh_raid()


func _on_raid_resolved(result: Dictionary) -> void:
	_show_raid_result(result)
	_show_result_overlay(result)
	_refresh_all()


func _show_raid_result(result: Dictionary) -> void:
	var victory := bool(result.get("victory", false))
	var outcome := "VICTORY" if victory else "DEFEAT"
	var loot_text := _format_loot(result.get("loot", {}))
	var split_text := _format_reward_splits(
		result.get("reward_splits", {}),
		result.get("participants", [])
	)

	raid_result_label.text = "%s — Grade %s — %s\nDamage: %s / %s HP\nPlan: %s   Consumable: %s\nCounter: %s   Injury severity: %s\nAlliance reward pool: $%s\nYour Cash: $%s   XP: +%d   Loot: %s\n%s\nWounded: %d Enforcer(s), %d Driver(s), %d Spy(s)" % [
		outcome,
		String(result.get("grade", "D")),
		String(result.get("target_name", "Target")),
		_format_number(roundi(float(result.get("damage", 0.0)))),
		_format_number(roundi(float(result.get("target_hp", 0.0)))),
		String(result.get("preset", "Balanced")),
		String(result.get("consumable", "None")),
		"Matched" if bool(result.get("weakness_matched", false)) else "Missed",
		String(result.get("injury_severity", "None")),
		_format_number(int(result.get("reward_pool", 0))),
		_format_number(int(result.get("local_cash_reward", 0))),
		int(result.get("xp_reward", 0)),
		loot_text,
		split_text,
		int(result.get("wounded_enforcers", 0)),
		int(result.get("wounded_drivers", 0)),
		int(result.get("wounded_spies", 0))
	]


func _format_contributions(contributions: Dictionary, participants: Array) -> String:
	var lines: PackedStringArray = ["Contribution preview:"]

	for participant in participants:
		var player_id := String(participant.get("player_id", ""))
		if player_id == "" or not contributions.has(player_id):
			continue

		lines.append("%s (%s): %s" % [
			String(participant.get("name", player_id)),
			String(participant.get("role", "")).capitalize(),
			_format_number(roundi(float(contributions[player_id])))
		])

	return "\n".join(lines)


func _format_reward_splits(splits: Dictionary, participants: Array) -> String:
	if splits.is_empty():
		return "No reward shares."

	var names := {}
	for participant in participants:
		names[String(participant.get("player_id", ""))] = String(
			participant.get("name", participant.get("player_id", ""))
		)

	var lines: PackedStringArray = ["Reward shares:"]
	for player_id in splits.keys():
		lines.append("%s: $%s" % [
			String(names.get(String(player_id), player_id)),
			_format_number(int(splits[player_id]))
		])

	return "\n".join(lines)


func _close_selection() -> void:
	selection_panel.visible = false


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%02d:%02d" % [floori(total / 60.0), total % 60]


func _format_number(value: int) -> String:
	var text := str(value)
	var output := ""
	while text.length() > 3:
		output = "," + text.right(3) + output
		text = text.left(text.length() - 3)
	return text + output


func _format_loot(loot: Dictionary) -> String:
	if loot.is_empty():
		return "No loot"

	var parts: PackedStringArray = []
	for item_name in loot.keys():
		parts.append("%s x%d" % [String(item_name), int(loot[item_name])])
	return ", ".join(parts)



func _open_alliance_panel() -> void:
	alliance_panel.visible = true
	_refresh_alliance_social()


func _close_alliance_panel() -> void:
	alliance_panel.visible = false


func _create_raid_invite() -> void:
	if selected_raid_target == null:
		var targets: Array = city_map.get_raid_targets() if city_map != null else []
		for target in targets:
			if target.is_available():
				selected_raid_target = target
				break

	if selected_raid_target == null:
		return

	alliance_social.create_raid_invite(
		selected_raid_target.get_target_id(),
		selected_raid_target.get_display_name()
	)
	_refresh_alliance_social()


func _join_social_invite(role: StringName) -> void:
	if alliance_social.active_invite.is_empty():
		return

	if role == &"driver" and troop_roster.get_count(&"Driver") <= 0:
		return

	if role == &"spy" and troop_roster.get_count(&"Spy") <= 0:
		return

	if alliance_social.join_local_invite(role):
		raid_drivers = 1 if role == &"driver" else 0
		raid_spies = 1 if role == &"spy" else 0
		var target_id := alliance_social.get_invite_target_id()
		if target_id != "":
			focus_raid_target_requested.emit(target_id)
		_rebuild_synergy_from_alliance()
		_refresh_raid()
		_refresh_alliance_social()


func _post_alliance_message() -> void:
	alliance_social.post_message("Ready for the next hit.")
	_refresh_alliance_social()


func _refresh_alliance_social() -> void:
	if alliance_social == null:
		return

	alliance_feed_label.text = "%s\n\n%s" % [alliance_manager.get_progression_summary(), alliance_social.get_feed_text()]

	if alliance_social.active_invite.is_empty():
		invite_status_label.text = "No active raid invite."
		invite_driver_button.disabled = true
		invite_spy_button.disabled = true
		return

	var joined_names := alliance_social.get_invite_joined_names()
	var joined_text := "None" if joined_names.is_empty() else ", ".join(joined_names)

	invite_status_label.text = "RAID INVITE: %s\nExpires in %s\nJoined: %s" % [
		alliance_social.get_invite_target_name(),
		_format_time(alliance_social.get_invite_seconds_remaining()),
		joined_text
	]

	invite_driver_button.disabled = troop_roster.get_count(&"Driver") <= 0
	invite_spy_button.disabled = troop_roster.get_count(&"Spy") <= 0



func _on_alliance_changed() -> void:
	_refresh_raid()
	_refresh_alliance_profiles()


func _apply_portrait_art() -> void:
	if presentation_catalog == null:
		return

	var enforcer_icon := presentation_catalog.get_unit_portrait(&"enforcer")
	var driver_icon := presentation_catalog.get_unit_portrait(&"driver")
	var spy_icon := presentation_catalog.get_unit_portrait(&"spy")

	if enforcer_icon != null:
		recruit_enforcer_button.icon = enforcer_icon
		recruit_enforcer_button.expand_icon = true
	if driver_icon != null:
		recruit_driver_button.icon = driver_icon
		recruit_driver_button.expand_icon = true
		add_driver_button.icon = driver_icon
		add_driver_button.expand_icon = true
		invite_driver_button.icon = driver_icon
		invite_driver_button.expand_icon = true
	if spy_icon != null:
		recruit_spy_button.icon = spy_icon
		recruit_spy_button.expand_icon = true
		add_spy_button.icon = spy_icon
		add_spy_button.expand_icon = true
		invite_spy_button.icon = spy_icon
		invite_spy_button.expand_icon = true


func _refresh_alliance_profiles() -> void:
	if alliance_profiles == null or alliance_manager == null:
		return

	for child in alliance_profiles.get_children():
		child.queue_free()

	for member in alliance_manager.get_members():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(130, 112)
		alliance_profiles.add_child(card)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		card.add_child(margin)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		margin.add_child(box)

		if presentation_catalog != null and not bool(member["is_local"]):
			var portrait := TextureRect.new()
			portrait.custom_minimum_size = Vector2(104, 68)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.texture = presentation_catalog.get_character_portrait(String(member["name"]).to_lower())
			if portrait.texture != null:
				box.add_child(portrait)

		var name_label := Label.new()
		name_label.text = String(member["name"])
		name_label.add_theme_font_size_override("font_size", 18)
		box.add_child(name_label)

		var role_label := Label.new()
		role_label.text = "Lv.%d • %s" % [
			int(member["level"]),
			String(member["preferred_role"]).capitalize()
		]
		box.add_child(role_label)

		var power_label := Label.new()
		var power := roundi(float(member["power"]))
		power_label.text = "Power %s" % _format_number(power)
		box.add_child(power_label)

		var state_label := Label.new()
		state_label.text = "● ONLINE" if bool(member["online"]) else "○ OFFLINE"
		box.add_child(state_label)


func _show_result_overlay(result: Dictionary) -> void:
	var victory := bool(result.get("victory", false))
	result_overlay_title.text = "%s • GRADE %s" % [
		"RAID VICTORY" if victory else "RAID DEFEAT",
		String(result.get("grade", "D"))
	]

	var loot_text := _format_loot(result.get("loot", {}))
	result_overlay_body.text = "%s\n\nDamage: %s / %s HP\nYour Cash: $%s   XP: +%d\nLoot: %s\nPlan: %s   Counter: %s\nInjury severity: %s\nSupport bonus: +%d%%\n\n%s" % [
		String(result.get("target_name", "Target")),
		_format_number(roundi(float(result.get("damage", 0.0)))),
		_format_number(roundi(float(result.get("target_hp", 0.0)))),
		_format_number(int(result.get("local_cash_reward", 0))),
		int(result.get("xp_reward", 0)),
		loot_text,
		String(result.get("preset", "Balanced")),
		"Matched" if bool(result.get("weakness_matched", false)) else "Missed",
		String(result.get("injury_severity", "None")),
		roundi(float(result.get("support_bonus", 0.0)) * 100.0),
		_format_reward_splits(
			result.get("reward_splits", {}),
			result.get("participants", [])
		)
	]

	result_overlay.visible = true

	if settings_manager != null and settings_manager.reduced_motion:
		result_overlay.modulate.a = 1.0
		result_overlay.scale = Vector2.ONE
	else:
		result_overlay.modulate.a = 0.0
		result_overlay.scale = Vector2(0.90, 0.90)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(result_overlay, "modulate:a", 1.0, 0.22)
		tween.tween_property(result_overlay, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_result_overlay() -> void:
	result_overlay.visible = false
