class_name WorldControlUI
extends CanvasLayer

var control: WorldControlManager
var city_map: Node
var resources: ResourceProductionManager
var text_catalog: LocalizedText

@onready var panel: PanelContainer = $Root/Panel
@onready var income_label: Label = $Root/Panel/Margin/VBox/Income
@onready var districts_label: Label = $Root/Panel/Margin/VBox/Districts
@onready var rivalries_label: Label = $Root/Panel/Margin/VBox/Rivalries
@onready var discovery_label: Label = $Root/Panel/Margin/VBox/Discovery
@onready var patrol_label: Label = $Root/Panel/Margin/VBox/Patrol
@onready var tasks_label: Label = $Root/Panel/Margin/VBox/Tasks
@onready var resource_label: Label = $Root/Panel/Margin/VBox/Resources
@onready var collect_resources_button: Button = $Root/Panel/Margin/VBox/CollectResources
@onready var collect_button: Button = $Root/Panel/Margin/VBox/Collect
@onready var intel_button: Button = $Root/Panel/Margin/VBox/DiscoverIntel
@onready var command_button: Button = $Root/Panel/Margin/VBox/CommandScan
@onready var patrol_button: Button = $Root/Panel/Margin/VBox/ResolvePatrol
@onready var victory_panel: PanelContainer = $Root/VictoryPanel
@onready var victory_title: Label = $Root/VictoryPanel/Margin/VBox/Title
@onready var victory_boss: Label = $Root/VictoryPanel/Margin/VBox/Boss
@onready var victory_summary: Label = $Root/VictoryPanel/Margin/VBox/Summary
@onready var victory_close: Button = $Root/VictoryPanel/Margin/VBox/Close


func setup(manager: WorldControlManager, world: Node, resource_manager: ResourceProductionManager, localized_text: LocalizedText) -> void:
	control = manager
	city_map = world
	resources = resource_manager
	text_catalog = localized_text
	$Root/Shortcut.text = text_catalog.text("UI_TERRITORY")
	$Root/Panel/Margin/VBox/Title.text = text_catalog.text("UI_TERRITORY_TITLE")
	$Root/Panel/Margin/VBox/DiscoverIntel.text = text_catalog.text("UI_REVEAL_INTEL")
	$Root/Panel/Margin/VBox/CollectResources.text = text_catalog.text("UI_COLLECT_RESOURCES")
	$Root/Panel/Margin/VBox/ResolvePatrol.text = text_catalog.text("UI_CLEAR_PATROL")
	$Root/Panel/Margin/VBox/Close.text = text_catalog.text("UI_CLOSE")
	control.changed.connect(_refresh)
	control.district_discovered.connect(_show_boss_intro)
	control.district_captured.connect(_show_district_victory)
	resources.changed.connect(_refresh)
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle)
	collect_button.pressed.connect(_collect)
	intel_button.pressed.connect(_discover)
	command_button.pressed.connect(_command_scan)
	patrol_button.pressed.connect(_resolve_patrol)
	collect_resources_button.pressed.connect(_collect_resources)
	victory_close.pressed.connect(_close_victory_panel)
	_refresh()


func _process(_delta: float) -> void:
	if panel.visible:
		_refresh()


func _toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		collect_button.grab_focus.call_deferred()
	_refresh()


func _collect() -> void:
	control.collect_income()
	_refresh()


func _discover() -> void:
	control.discover_next_with_intel()
	_refresh()


func _command_scan() -> void:
	control.command_scan()
	_refresh()


func _collect_resources() -> void:
	resources.collect()
	_refresh()


func _show_boss_intro(district_id: String) -> void:
	var dossier := control.get_faction_dossier(district_id)
	if dossier.is_empty():
		return
	victory_title.text = "RIVAL REVEALED • %s" % String(dossier["district"]).to_upper()
	victory_boss.text = "%s — %s\n%s" % [
		String(dossier["boss"]),
		String(dossier["boss_title"]),
		String(dossier["faction"]).to_upper()
	]
	victory_summary.text = "“%s”\n\n%s\nPreferred encounter: %s\nCurrent feud: %s %d/10 • reward bonus +%d%%" % [
		String(dossier["boss_quote"]),
		String(dossier["perk"]),
		String(dossier["preferred_encounter"]).replace("_", " ").capitalize(),
		String(dossier["rivalry"]),
		int(dossier["rivalry_score"]),
		int(dossier["feud_bonus_percent"])
	]
	victory_close.text = "Enter District"
	victory_panel.visible = true
	victory_close.grab_focus.call_deferred()


func _show_district_victory(district_id: String) -> void:
	var summary := control.get_capture_victory_summary(district_id)
	if summary.is_empty():
		return
	victory_title.text = "DISTRICT TAKEN • %s" % String(summary["district"]).to_upper()
	victory_boss.text = "%s DEFEATED\n%s" % [
		String(summary["boss"]),
		String(summary["faction"]).to_upper()
	]
	victory_summary.text = "%s\n\nRival status: %s %d/10\nFuture feud encounters now pay +%d%% from rivalry, before faction modifiers." % [
		String(summary["victory_line"]),
		String(summary["rivalry"]),
		int(summary["rivalry_score"]),
		int(summary["feud_bonus_percent"])
	]
	victory_close.text = "Claim Turf"
	victory_panel.visible = true
	victory_close.grab_focus.call_deferred()


func _close_victory_panel() -> void:
	victory_panel.visible = false
	panel.visible = true
	_refresh()


func _resolve_patrol() -> void:
	var result := control.resolve_patrol()
	if not result.is_empty():
		patrol_label.text = "%s — %s — %s Power %.0f / %.0f — %s" % [
			"ENCOUNTER CLEARED" if bool(result["victory"]) else "ENCOUNTER HELD",
			String(result["encounter_type"]).replace("_", " ").capitalize(),
			String(result["role"]),
			float(result["player_power"]),
			float(result["required_power"]),
			"+$%d" % int(result["cash_reward"]) if bool(result["victory"]) else "Specialist wounded"
		]
	_refresh()


func _refresh() -> void:
	if control == null:
		return

	income_label.text = text_catalog.text("UI_TURF_INCOME") + "\nRate: $%d/hr\nBanked: $%d / 8h cap" % [
		control.get_income_per_hour(),
		floori(control.production_bank)
	]
	collect_button.text = "Collect $%d" % floori(control.production_bank)
	collect_button.disabled = control.production_bank < 1.0

	districts_label.text = text_catalog.text("UI_DISTRICTS") + "\n" + "\n".join(control.get_district_lines())
	rivalries_label.text = "RIVAL DOSSIERS\n" + "\n".join(control.get_rivalry_lines())
	discovery_label.text = text_catalog.text("UI_NEXT_DISCOVERY") + "\n%s" % control.get_next_discovery_summary()
	intel_button.disabled = not control.has_discoverable_target()

	var scan_remaining := ceili(control.command_scan_remaining)
	command_button.text = text_catalog.text("UI_COMMAND_SCAN") if scan_remaining <= 0 else "Command Scan — %ds" % scan_remaining
	command_button.disabled = scan_remaining > 0 or not control.has_discoverable_target()

	resource_label.text = text_catalog.text("UI_RESOURCE_FACILITIES") + "\n%s" % resources.get_summary()
	collect_resources_button.disabled = resources.parts_bank < 1.0 and resources.intel_bank < 1.0

	if control.active_patrol.is_empty():
		patrol_label.text = text_catalog.text("UI_RIVAL_ENCOUNTER") + "\n" + text_catalog.text("UI_NO_THREAT")
		patrol_button.disabled = true
	else:
		patrol_label.text = text_catalog.text("UI_RIVAL_ENCOUNTER") + "\n%s • %s\n%s requires %s power: %d" % [
			String(control.active_patrol["district_name"]),
			String(control.active_patrol["faction"]) + " • " + String(control.active_patrol.get("trait", "")),
			String(control.active_patrol["type"]).replace("_", " ").capitalize(),
			String(control.active_patrol["role"]),
			int(control.active_patrol["power"])
		]
		patrol_button.disabled = false

	var cycle := ceili(control.get_task_cycle_remaining())
	tasks_label.text = text_catalog.text("UI_ALLIANCE_TASKS") + " — refresh %02d:%02d:%02d\n%s" % [
		floori(float(cycle) / 3600.0),
		floori(float(cycle % 3600) / 60.0),
		cycle % 60,
		"\n".join(control.get_task_lines())
	]
