extends CanvasLayer

signal focus_building_requested(building_type: StringName)

var economy: PlayerEconomy
var troop_roster: TroopRoster
var hospital_queue: HospitalQueue
var construction_queue: ConstructionQueue
var recruitment_queue: RecruitmentQueue
var synergy_raid: SynergyRaid

var selected_building: Building
var selected_lot: BuildLot
var raid_drivers := 0
var raid_spies := 0

@onready var cash_label: Label = $Root/TopBar/Panel/HBox/Cash
@onready var gold_label: Label = $Root/TopBar/Panel/HBox/Gold
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
@onready var raid_roster_label: Label = $Root/RaidPanel/Margin/VBox/Roster
@onready var raid_result_label: Label = $Root/RaidPanel/Margin/VBox/Result
@onready var add_driver_button: Button = $Root/RaidPanel/Margin/VBox/AddDriver
@onready var add_spy_button: Button = $Root/RaidPanel/Margin/VBox/AddSpy


func setup(
	player_economy: PlayerEconomy,
	roster: TroopRoster,
	clinic: HospitalQueue,
	construction: ConstructionQueue,
	recruitment: RecruitmentQueue,
	raid: SynergyRaid
) -> void:
	economy = player_economy
	troop_roster = roster
	hospital_queue = clinic
	construction_queue = construction
	recruitment_queue = recruitment
	synergy_raid = raid

	economy.changed.connect(_refresh_all)
	troop_roster.changed.connect(_refresh_all)
	hospital_queue.queue_changed.connect(_refresh_hospital)
	construction_queue.queue_changed.connect(_refresh_construction)
	construction_queue.construction_completed.connect(_on_construction_completed)
	recruitment_queue.queue_changed.connect(_refresh_recruitment)
	recruitment_queue.recruitment_completed.connect(_on_recruitment_completed)

	$Root/HospitalShortcut.pressed.connect(_on_hospital_shortcut)
	$Root/BarracksShortcut.pressed.connect(_on_barracks_shortcut)
	$Root/RaidShortcut.pressed.connect(_open_raid)

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

	add_driver_button.pressed.connect(_add_driver_support)
	add_spy_button.pressed.connect(_add_spy_support)
	$Root/RaidPanel/Margin/VBox/Calculate.pressed.connect(_calculate_raid)
	$Root/RaidPanel/Margin/VBox/Reset.pressed.connect(_prepare_raid)
	$Root/RaidPanel/Margin/VBox/Close.pressed.connect(_close_raid)

	_refresh_all()


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
	selection_title.text = lot.building_name if lot.is_built else "Empty Build Lot"
	selection_description.text = lot.description
	level_label.visible = lot.is_built
	level_label.text = "Level 1" if lot.is_built else ""
	open_hospital_button.visible = false
	open_barracks_button.visible = false
	upgrade_button.visible = false
	build_button.visible = not lot.is_built
	_refresh_selection()
	selection_panel.visible = true


func _refresh_all() -> void:
	if economy == null:
		return
	cash_label.text = "Cash: $%s" % _format_number(economy.cash)
	gold_label.text = "Gold: %d" % economy.gold
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
		var cash_cost := selected_building.get_upgrade_cash_cost()
		upgrade_button.text = "Upgrade to Lv.%d — $%s" % [selected_building.level + 1, _format_number(cash_cost)]
		upgrade_button.disabled = construction_queue.is_busy() or selected_building.is_constructing or economy.cash < cash_cost

	if selected_lot != null:
		build_button.text = "Build %s — $%s" % [selected_lot.building_name, _format_number(selected_lot.build_cash_cost)]
		build_button.disabled = construction_queue.is_busy() or selected_lot.is_built or economy.cash < selected_lot.build_cash_cost


func _upgrade_selected() -> void:
	if selected_building != null:
		construction_queue.start_upgrade(selected_building)
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
	hospital_queue.add_wounded(&"Enforcer", 12)
	hospital_queue.add_wounded(&"Driver", 4)
	_refresh_hospital()


func _instant_heal() -> void:
	hospital_queue.instant_heal()
	_refresh_all()


func _refresh_hospital() -> void:
	if hospital_queue == null or economy == null:
		return

	if hospital_queue.wounded_queue.is_empty():
		queue_label.text = "Clinic queue is empty. Your crew is ready."
		cost_label.text = "Instant heal cost: 0 Gold"
		instant_button.disabled = true
		return

	var lines: PackedStringArray = []
	for i in range(hospital_queue.wounded_queue.size()):
		var entry: Dictionary = hospital_queue.wounded_queue[i]
		lines.append("%d. %s x%d — %s" % [
			i + 1,
			String(entry["troop_type"]),
			int(entry["amount"]),
			_format_time(float(entry["seconds_remaining"]))
		])

	queue_label.text = "\n".join(lines)
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

	var busy := recruitment_queue.is_busy()
	recruit_enforcer_button.text = "Recruit 5 Enforcers — $%s" % _format_number(recruitment_queue.get_cash_cost(&"Enforcer", 5))
	recruit_driver_button.text = "Recruit 3 Drivers — $%s" % _format_number(recruitment_queue.get_cash_cost(&"Driver", 3))
	recruit_spy_button.text = "Recruit 3 Spies — $%s" % _format_number(recruitment_queue.get_cash_cost(&"Spy", 3))

	recruit_enforcer_button.disabled = busy or economy.cash < recruitment_queue.get_cash_cost(&"Enforcer", 5)
	recruit_driver_button.disabled = busy or economy.cash < recruitment_queue.get_cash_cost(&"Driver", 3)
	recruit_spy_button.disabled = busy or economy.cash < recruitment_queue.get_cash_cost(&"Spy", 3)

	if recruitment_queue.active_job.is_empty():
		recruitment_status.text = "Recruitment queue is ready."
		finish_recruitment_button.visible = false
	else:
		var job := recruitment_queue.active_job
		var finish_cost := recruitment_queue.get_finish_now_cost()
		recruitment_status.text = "Training %s x%d — %s remaining" % [
			String(job["troop_type"]),
			int(job["amount"]),
			_format_time(float(job["seconds_remaining"]))
		]
		finish_recruitment_button.visible = true
		finish_recruitment_button.text = "Finish Training (%d Gold)" % finish_cost
		finish_recruitment_button.disabled = economy.gold < finish_cost


func _open_raid() -> void:
	raid_panel.visible = true
	_prepare_raid()


func _close_raid() -> void:
	raid_panel.visible = false


func _prepare_raid() -> void:
	raid_drivers = 0
	raid_spies = 0
	synergy_raid.clear()
	synergy_raid.join_raid("AllianceBoss", 45, 6000.0, &"frontline")
	raid_result_label.text = "Add support allies, then calculate the raid."
	_refresh_raid()


func _add_driver_support() -> void:
	if raid_drivers >= troop_roster.get_count(&"Driver"):
		return
	raid_drivers += 1
	synergy_raid.join_raid("Driver_%d" % raid_drivers, 12, 0.0, &"driver")
	_refresh_raid()


func _add_spy_support() -> void:
	if raid_spies >= troop_roster.get_count(&"Spy"):
		return
	raid_spies += 1
	synergy_raid.join_raid("Spy_%d" % raid_spies, 14, 0.0, &"spy")
	_refresh_raid()


func _refresh_raid() -> void:
	if synergy_raid == null or troop_roster == null:
		return

	raid_roster_label.text = "Frontline: AllianceBoss (6,000 power)\nYour support: %d Driver(s), %d Spy(s)\nAvailable roster: %d Drivers, %d Spies" % [
		raid_drivers,
		raid_spies,
		troop_roster.get_count(&"Driver"),
		troop_roster.get_count(&"Spy")
	]
	add_driver_button.disabled = raid_drivers >= troop_roster.get_count(&"Driver")
	add_spy_button.disabled = raid_spies >= troop_roster.get_count(&"Spy")


func _calculate_raid() -> void:
	var result := synergy_raid.calculate_raid_damage()
	raid_result_label.text = "Raid damage: %s\nDriver speed bonus: +%d%%\nSpy defense break: +%d%%\nTotal support multiplier: +%d%%" % [
		_format_number(roundi(float(result["damage"]))),
		roundi(float(result["speed_bonus"]) * 100.0),
		roundi(float(result["defense_break_bonus"]) * 100.0),
		roundi(float(result["support_bonus"]) * 100.0)
	]


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
