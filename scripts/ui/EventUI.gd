class_name EventUI
extends CanvasLayer

const SKIN := preload("res://scripts/ui/EstateSkin.gd")
var event_manager: EventManager
var text_catalog: LocalizedText
var event_progress: ProgressBar

@onready var shortcut: Button = $Root/Shortcut
@onready var panel: PanelContainer = $Root/Panel
@onready var title_label: Label = $Root/Panel/Margin/VBox/Title
@onready var timer_label: Label = $Root/Panel/Margin/VBox/Timer
@onready var marks_label: Label = $Root/Panel/Margin/VBox/Marks
@onready var milestones_box: VBoxContainer = $Root/Panel/Margin/VBox/Milestones


func setup(manager: EventManager, localized_text: LocalizedText) -> void:
	event_manager = manager
	text_catalog = localized_text
	_create_event_header()
	$Root/Panel/Margin/VBox/Close.text = text_catalog.text("UI_CLOSE")
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

	shortcut.text = "%s • %d Marks" % [text_catalog.text("UI_EVENT"), event_manager.event_marks]
	title_label.text = event_manager.event_name
	marks_label.text = "%s: %d" % [text_catalog.text("UI_EVENT_MARKS"), event_manager.event_marks]
	event_progress.value = event_manager.event_marks
	_refresh_timer()

	for child in milestones_box.get_children():
		child.queue_free()

	for milestone in event_manager.get_milestones():
		var required := int(milestone["marks"])
		var button := Button.new()
		var claimed := event_manager.claimed_milestones.has(required)
		var status := "CLAIMED" if claimed else ("CLAIM REWARD" if event_manager.can_claim_milestone(required) else "%d MARKS TO GO" % maxi(0,required-event_manager.event_marks))
		button.text = "%d Marks · %s\n%s" % [required,status,_reward_text(milestone["reward"])]
		button.icon = SKIN.icon("rewards")
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",48)
		button.add_theme_constant_override("h_separation",14)
		button.custom_minimum_size.y = 82
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.set_meta("event_reward","claimed" if claimed else ("claimable" if event_manager.can_claim_milestone(required) else "locked"))
		SKIN.style_button(button)
		button.disabled = not event_manager.can_claim_milestone(required)
		button.pressed.connect(func(): _claim(required))
		milestones_box.add_child(button)


func _refresh_timer() -> void:
	var remaining := event_manager.get_seconds_remaining()
	var days := floori(remaining / 86400.0)
	var hours := floori(fmod(remaining, 86400.0) / 3600.0)
	timer_label.text = "%s: %dd %dh" % [text_catalog.text("UI_TIME_REMAINING"), days, hours]


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


func _create_event_header() -> void:
	var column := title_label.get_parent()
	var hero := PanelContainer.new()
	hero.name = "EventHeader"
	hero.set_meta("estate_hero",true)
	column.add_child(hero)
	column.move_child(hero,0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	hero.add_child(row)
	var art := TextureRect.new()
	art.texture = SKIN.icon("events")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(82,96)
	row.add_child(art)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var eyebrow := Label.new()
	eyebrow.text = "LIMITED-TIME EVENT"
	eyebrow.add_theme_color_override("font_color",Color("#dfb47b"))
	text.add_child(eyebrow)
	title_label.reparent(text)
	timer_label.reparent(text)

	event_progress = ProgressBar.new()
	event_progress.name = "EventProgress"
	event_progress.max_value = int(event_manager.get_milestones().back().marks)
	event_progress.show_percentage = false
	event_progress.custom_minimum_size.y = 10
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#101820")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#c29754")
	event_progress.add_theme_stylebox_override("background",track)
	event_progress.add_theme_stylebox_override("fill",fill)
	column.add_child(event_progress)
	column.move_child(event_progress,marks_label.get_index()+1)
