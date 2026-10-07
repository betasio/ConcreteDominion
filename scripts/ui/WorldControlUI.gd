class_name WorldControlUI
extends CanvasLayer

var control: WorldControlManager
var city_map: Node

@onready var panel: PanelContainer = $Root/Panel
@onready var income_label: Label = $Root/Panel/Margin/VBox/Income
@onready var districts_label: Label = $Root/Panel/Margin/VBox/Districts
@onready var discovery_label: Label = $Root/Panel/Margin/VBox/Discovery
@onready var patrol_label: Label = $Root/Panel/Margin/VBox/Patrol
@onready var tasks_label: Label = $Root/Panel/Margin/VBox/Tasks
@onready var collect_button: Button = $Root/Panel/Margin/VBox/Collect
@onready var intel_button: Button = $Root/Panel/Margin/VBox/DiscoverIntel
@onready var command_button: Button = $Root/Panel/Margin/VBox/CommandScan
@onready var patrol_button: Button = $Root/Panel/Margin/VBox/ResolvePatrol


func setup(manager: WorldControlManager, world: Node) -> void:
	control = manager
	city_map = world
	control.changed.connect(_refresh)
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle)
	collect_button.pressed.connect(_collect)
	intel_button.pressed.connect(_discover)
	command_button.pressed.connect(_command_scan)
	patrol_button.pressed.connect(_resolve_patrol)
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


func _resolve_patrol() -> void:
	var result := control.resolve_patrol()
	if not result.is_empty():
		patrol_label.text = "%s — Power %.0f / %.0f — %s" % [
			"PATROL CLEARED" if bool(result["victory"]) else "PATROL HELD",
			float(result["player_power"]),
			float(result["required_power"]),
			"+$%d" % int(result["cash_reward"]) if bool(result["victory"]) else "1 Enforcer wounded"
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

	if control.active_patrol.is_empty():
		patrol_label.text = "PATROL\nNo active threat."
		patrol_button.disabled = true
	else:
		patrol_label.text = "PATROL\n%s — Threat Power %d" % [
			String(control.active_patrol["district_name"]),
			int(control.active_patrol["power"])
		]
		patrol_button.disabled = false

	tasks_label.text = "ALLIANCE TASKS\n" + "\n".join(control.get_task_lines())
