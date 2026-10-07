extends CanvasLayer

signal focus_building_requested(building_type: StringName)

var hospital_queue: HospitalQueue

@onready var gold_label: Label = $Root/TopBar/Panel/HBox/Gold
@onready var selection_panel: PanelContainer = $Root/SelectionPanel
@onready var selection_title: Label = $Root/SelectionPanel/Margin/VBox/Title
@onready var selection_description: Label = $Root/SelectionPanel/Margin/VBox/Description
@onready var open_hospital_button: Button = $Root/SelectionPanel/Margin/VBox/OpenHospital
@onready var hospital_panel: PanelContainer = $Root/HospitalPanel
@onready var queue_label: Label = $Root/HospitalPanel/Margin/VBox/Queue
@onready var cost_label: Label = $Root/HospitalPanel/Margin/VBox/Cost
@onready var instant_button: Button = $Root/HospitalPanel/Margin/VBox/InstantHeal


func setup(queue: HospitalQueue) -> void:
	hospital_queue = queue
	hospital_queue.queue_changed.connect(_refresh_hospital)
	hospital_queue.treatment_completed.connect(_on_treatment_completed)

	$Root/HospitalShortcut.pressed.connect(_on_hospital_shortcut)
	$Root/SelectionPanel/Margin/VBox/Close.pressed.connect(_close_selection)
	open_hospital_button.pressed.connect(_open_hospital)
	$Root/HospitalPanel/Margin/VBox/SimulateBattle.pressed.connect(_simulate_battle)
	instant_button.pressed.connect(_instant_heal)
	$Root/HospitalPanel/Margin/VBox/Close.pressed.connect(_close_hospital)

	_refresh_hospital()


func show_building(building: Building) -> void:
	selection_title.text = building.display_name
	selection_description.text = building.description
	open_hospital_button.visible = building.building_type == &"hospital"
	selection_panel.visible = true

	if building.building_type == &"hospital":
		_open_hospital()


func _on_hospital_shortcut() -> void:
	focus_building_requested.emit(&"hospital")
	_open_hospital()


func _open_hospital() -> void:
	hospital_panel.visible = true
	_refresh_hospital()


func _close_hospital() -> void:
	hospital_panel.visible = false


func _close_selection() -> void:
	selection_panel.visible = false


func _simulate_battle() -> void:
	hospital_queue.add_wounded(&"Enforcer", 12)
	hospital_queue.add_wounded(&"Driver", 4)
	_refresh_hospital()


func _instant_heal() -> void:
	hospital_queue.instant_heal()
	_refresh_hospital()


func _on_treatment_completed(_entry: Dictionary) -> void:
	_refresh_hospital()


func _refresh_hospital() -> void:
	if hospital_queue == null:
		return

	gold_label.text = "Gold: %d" % hospital_queue.premium_currency

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
	instant_button.disabled = hospital_queue.premium_currency < cost


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%02d:%02d" % [floori(total / 60.0), total % 60]
