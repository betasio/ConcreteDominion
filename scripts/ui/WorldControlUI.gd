class_name WorldControlUI
extends CanvasLayer

var control: WorldControlManager
var city_map: Node
var resources: ResourceProductionManager

@onready var panel: PanelContainer = $Root/Panel
@onready var income_label: Label = $Root/Panel/Margin/VBox/Income
@onready var districts_label: Label = $Root/Panel/Margin/VBox/Districts
@onready var discovery_label: Label = $Root/Panel/Margin/VBox/Discovery
@onready var patrol_label: Label = $Root/Panel/Margin/VBox/Patrol
@onready var tasks_label: Label = $Root/Panel/Margin/VBox/Tasks
@onready var resource_label: Label = $Root/Panel/Margin/VBox/Resources
@onready var collect_resources_button: Button = $Root/Panel/Margin/VBox/CollectResources
@onready var collect_button: Button = $Root/Panel/Margin/VBox/Collect
@onready var intel_button: Button = $Root/Panel/Margin/VBox/DiscoverIntel
@onready var command_button: Button = $Root/Panel/Margin/VBox/CommandScan
@onready var patrol_button: Button = $Root/Panel/Margin/VBox/ResolvePatrol


func setup(manager: WorldControlManager, world: Node, resource_manager: ResourceProductionManager) -> void:
	control = manager
	city_map = world
	resources = resource_manager
	control.changed.connect(_refresh)
	resources.changed.connect(_refresh)
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle)
	collect_button.pressed.connect(_collect)
	intel_button.pressed.connect(_discover)
	command_button.pressed.connect(_command_scan)
	patrol_button.pressed.connect(_resolve_patrol)
	collect_resources_button.pressed.connect(_collect_resources)
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

	income_label.text = "TURF INCOME\nRate: $%d/hr\nBanked: $%d / 8h cap" % [
		control.get_income_per_hour(),
		floori(control.production_bank)
	]
	collect_button.text = "Collect $%d" % floori(control.production_bank)
	collect_button.disabled = control.production_bank < 1.0

	districts_label.text = "DISTRICTS\n" + "\n".join(control.get_district_lines())
	discovery_label.text = "NEXT DISCOVERY\n%s" % control.get_next_discovery_summary()
	intel_button.disabled = control.get_next_discovery_summary() == "No eligible fogged district."

	var scan_remaining := ceili(control.command_scan_remaining)
	command_button.text = "Safehouse Command Scan" if scan_remaining <= 0 else "Command Scan — %ds" % scan_remaining
	command_button.disabled = scan_remaining > 0 or control.get_next_discovery_summary() == "No eligible fogged district."

	resource_label.text = "RESOURCE FACILITIES\n%s" % resources.get_summary()
	collect_resources_button.disabled = resources.parts_bank < 1.0 and resources.intel_bank < 1.0

	if control.active_patrol.is_empty():
		patrol_label.text = "RIVAL ENCOUNTER\nNo active threat."
		patrol_button.disabled = true
	else:
		patrol_label.text = "RIVAL ENCOUNTER\n%s • %s\n%s requires %s power: %d" % [
			String(control.active_patrol["district_name"]),
			String(control.active_patrol["faction"]) + " • " + String(control.active_patrol.get("trait", "")),
			String(control.active_patrol["type"]).replace("_", " ").capitalize(),
			String(control.active_patrol["role"]),
			int(control.active_patrol["power"])
		]
		patrol_button.disabled = false

	var cycle := ceili(control.get_task_cycle_remaining())
	tasks_label.text = "ALLIANCE TASKS — refresh %02d:%02d:%02d\n%s" % [
		floori(float(cycle) / 3600.0),
		floori(float(cycle % 3600) / 60.0),
		cycle % 60,
		"\n".join(control.get_task_lines())
	]
