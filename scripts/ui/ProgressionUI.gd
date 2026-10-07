class_name ProgressionUI
extends CanvasLayer

var progression: PlayerProgression
var missions: MissionTracker
var loot: LootInventory
var text_catalog: LocalizedText

@onready var shortcut: Button = $Root/Shortcut
@onready var panel: PanelContainer = $Root/Panel
@onready var level_label: Label = $Root/Panel/Margin/VBox/Level
@onready var xp_label: Label = $Root/Panel/Margin/VBox/XP
@onready var unlocks_label: Label = $Root/Panel/Margin/VBox/Unlocks
@onready var missions_label: Label = $Root/Panel/Margin/VBox/Missions
@onready var enforcer_button: Button = $Root/Panel/Margin/VBox/EnforcerUpgrade
@onready var driver_button: Button = $Root/Panel/Margin/VBox/DriverUpgrade
@onready var spy_button: Button = $Root/Panel/Margin/VBox/SpyUpgrade


func setup(
	player_progression: PlayerProgression,
	mission_tracker: MissionTracker,
	loot_inventory: LootInventory,
	localized_text: LocalizedText
) -> void:
	progression = player_progression
	missions = mission_tracker
	loot = loot_inventory
	text_catalog = localized_text
	$Root/Panel/Margin/VBox/Close.text = text_catalog.text("UI_CLOSE")

	progression.changed.connect(_refresh)
	missions.changed.connect(_refresh)
	loot.changed.connect(_refresh)

	shortcut.pressed.connect(_toggle_panel)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle_panel)
	enforcer_button.pressed.connect(func(): _upgrade(&"Enforcer"))
	driver_button.pressed.connect(func(): _upgrade(&"Driver"))
	spy_button.pressed.connect(func(): _upgrade(&"Spy"))

	_refresh()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	_refresh()


func _upgrade(role: StringName) -> void:
	progression.upgrade_specialist(role)
	_refresh()


func _refresh() -> void:
	if progression == null:
		return

	shortcut.text = "LV.%d  %s" % [progression.account_level, text_catalog.text("UI_PROGRESSION")]
	level_label.text = "%s %d" % [text_catalog.text("UI_ACCOUNT_LEVEL"), progression.account_level]
	xp_label.text = "%s: %d / %d" % [text_catalog.text("UI_XP"),
		progression.current_xp,
		progression.get_xp_for_next_level()
	]

	unlocks_label.text = text_catalog.text("UI_UNLOCKS_TITLE") + "\nLv.2 — Harbor District + Garage\nLv.3 — Midtown + Intel Office\nLv.4 — Northside + Scrapyard\nLv.5 — High Roller Strip + Data Hub\nLv.6 — Financial District\nLv.7 — Industrial Belt"

	missions_label.text = text_catalog.text("UI_MISSIONS") + "\n" + "\n".join(missions.get_mission_lines())

	_refresh_upgrade_button(enforcer_button, &"Enforcer")
	_refresh_upgrade_button(driver_button, &"Driver")
	_refresh_upgrade_button(spy_button, &"Spy")


func _refresh_upgrade_button(button: Button, role: StringName) -> void:
	var level := progression.get_specialist_level(role)
	var cost := progression.get_upgrade_cost(role)
	button.text = "%s Lv.%d → Lv.%d   %s" % [
		String(role),
		level,
		level + 1,
		_format_cost(cost)
	]
	button.disabled = not progression.can_upgrade_specialist(role)


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return text_catalog.text("UI_NO_COST")

	var parts := PackedStringArray()
	for item_name in cost.keys():
		var amount := int(cost[item_name])
		if amount > 0:
			parts.append("%s x%d" % [String(item_name), amount])

	return ", ".join(parts)
