class_name EventUI
extends CanvasLayer

var event_manager: EventManager

@onready var shortcut: Button = $Root/Shortcut
@onready var panel: PanelContainer = $Root/Panel
@onready var title_label: Label = $Root/Panel/Margin/VBox/Title
@onready var timer_label: Label = $Root/Panel/Margin/VBox/Timer
@onready var marks_label: Label = $Root/Panel/Margin/VBox/Marks
@onready var milestones_box: VBoxContainer = $Root/Panel/Margin/VBox/Milestones


func setup(manager: EventManager) -> void:
	event_manager = manager
	event_manager.changed.connect(_refresh)
	shortcut.pressed.connect(_toggle_panel)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle_panel)
	_refresh()


func _process(_delta: float) -> void:
	if event_manager != null and panel.visible:
		_refresh_timer()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	_refresh()


func _refresh() -> void:
	if event_manager == null:
		return

	shortcut.text = "EVENT • %d Marks" % event_manager.event_marks
	title_label.text = event_manager.event_name
	marks_label.text = "Event Marks: %d" % event_manager.event_marks
	_refresh_timer()

	for child in milestones_box.get_children():
		child.queue_free()

	for milestone in event_manager.get_milestones():
		var required := int(milestone["marks"])
		var button := Button.new()
		button.text = "%d Marks — %s" % [
			required,
			_reward_text(milestone["reward"])
		]
		button.disabled = not event_manager.can_claim_milestone(required)
		button.pressed.connect(func(): _claim(required))
		milestones_box.add_child(button)


func _refresh_timer() -> void:
	var remaining := event_manager.get_seconds_remaining()
	var days := floori(remaining / 86400.0)
	var hours := floori(fmod(remaining, 86400.0) / 3600.0)
	timer_label.text = "Time remaining: %dd %dh" % [days, hours]


func _claim(required: int) -> void:
	event_manager.claim_milestone(required)
	_refresh()


func _reward_text(reward: Dictionary) -> String:
	var parts := PackedStringArray()

	if int(reward.get("cash", 0)) > 0:
		parts.append("$%d" % int(reward["cash"]))
	if int(reward.get("gold", 0)) > 0:
		parts.append("%d Gold" % int(reward["gold"]))
	if int(reward.get("xp", 0)) > 0:
		parts.append("%d XP" % int(reward["xp"]))

	var reward_loot = reward.get("loot", {})
	if reward_loot is Dictionary:
		for item_name in reward_loot.keys():
			parts.append("%s x%d" % [String(item_name), int(reward_loot[item_name])])

	return ", ".join(parts)
