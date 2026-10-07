class_name ProgressionUI
extends CanvasLayer

var progression: PlayerProgression
var missions: MissionTracker
var loot: LootInventory
var text_catalog: LocalizedText
var presentation_catalog: PresentationCatalog

@onready var shortcut: Button = $Root/Shortcut
@onready var panel: PanelContainer = $Root/Panel
@onready var level_label: Label = $Root/Panel/Margin/VBox/Level
@onready var xp_label: Label = $Root/Panel/Margin/VBox/XP
@onready var chapter_label: Label = $Root/Panel/Margin/VBox/Chapter
@onready var story_portrait: TextureRect = $Root/Panel/Margin/VBox/StoryBeat/Portrait
@onready var story_speaker: Label = $Root/Panel/Margin/VBox/StoryBeat/Copy/Speaker
@onready var story_line: Label = $Root/Panel/Margin/VBox/StoryBeat/Copy/Line
@onready var approach_box: HBoxContainer = $Root/Panel/Margin/VBox/Approach
@onready var force_button: Button = $Root/Panel/Margin/VBox/Approach/Force
@onready var intel_button: Button = $Root/Panel/Margin/VBox/Approach/Intel
@onready var milestones_label: Label = $Root/Panel/Margin/VBox/Milestones
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
	presentation_catalog = get_parent().get_node_or_null("PresentationCatalog") as PresentationCatalog
	$Root/Panel/Margin/VBox/Close.text = text_catalog.text("UI_CLOSE")
	_apply_portrait_art()

	progression.changed.connect(_refresh)
	missions.changed.connect(_refresh)
	loot.changed.connect(_refresh)

	shortcut.pressed.connect(_toggle_panel)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle_panel)
	enforcer_button.pressed.connect(func(): _upgrade(&"Enforcer"))
	driver_button.pressed.connect(func(): _upgrade(&"Driver"))
	spy_button.pressed.connect(func(): _upgrade(&"Spy"))
	force_button.pressed.connect(func(): _choose_approach("force"))
	intel_button.pressed.connect(func(): _choose_approach("intel"))

	_refresh()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	_refresh()


func _upgrade(role: StringName) -> void:
	progression.upgrade_specialist(role)
	_refresh()


func _choose_approach(choice_id: String) -> void:
	var chapter := missions.get_story_chapter_status()
	var chapter_number := int(chapter.get("chapter", 1))
	if chapter_number == 4:
		missions.choose_chapter_4_approach("buy_in" if choice_id == "force" else "blackmail")
	elif chapter_number == 3:
		missions.choose_chapter_3_approach("pressure" if choice_id == "force" else "patience")
	else:
		missions.choose_chapter_2_approach(choice_id)
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

	var chapter := missions.get_story_chapter_status()
	_refresh_story_beat(chapter)
	if bool(chapter["complete"]):
		chapter_label.text = "CHAPTER %d • %s\nCOMPLETE — %d/%d operations. The city war is open.\nCompletion reward: %s" % [
			int(chapter["chapter"]), String(chapter["title"]), int(chapter["progress"]), int(chapter["goal"]), String(chapter["completion_reward"])
		]
	else:
		chapter_label.text = "CHAPTER %d • %s\n%d/%d operations complete\nNEXT: %s — %s\nCompletion reward: %s" % [
			int(chapter["chapter"]), String(chapter["title"]), int(chapter["progress"]), int(chapter["goal"]), String(chapter["next_title"]), String(chapter["next_description"]), String(chapter["completion_reward"])
		]

	approach_box.visible = bool(chapter.get("choice_required", false))
	force_button.disabled = not approach_box.visible
	intel_button.disabled = not approach_box.visible
	if int(chapter["chapter"]) == 4:
		force_button.text = "BUY IN • $6,000 + 3 Gold"
		intel_button.text = "BLACKMAIL • 5 Gold + Intel x4"
	elif int(chapter["chapter"]) == 3:
		force_button.text = "PRESSURE • $4,000 + Parts x3"
		intel_button.text = "PATIENCE • 4 Gold + Intel x3"
	else:
		force_button.text = "FORCE • $2,500 + Parts x2"
		intel_button.text = "INTEL • 3 Gold + Intel x2"

	if int(chapter["chapter"]) == 1:
		milestones_label.text = "CHAPTER PAYOUTS\n%s  2/5 — $2,000 + 3 Gold + 35 XP + Parts x1\n%s  4/5 — $3,500 + 5 Gold + 60 XP + Intel x1" % [
			"✓" if bool(chapter["milestone_2_claimed"]) else "○",
			"✓" if bool(chapter["milestone_4_claimed"]) else "○"
		]
	elif int(chapter["chapter"]) == 2:
		var choice := String(chapter.get("choice", ""))
		milestones_label.text = "RIVAL CAMPAIGN\nIron Serpents: Harbor • Meridian Boys: Midtown\nApproach: %s • Chapter reward: %s" % [
			"UNDECIDED" if choice.is_empty() else choice.to_upper(),
			String(chapter["completion_reward"])
		]
	elif int(chapter["chapter"]) == 3:
		var chapter_3_choice := String(chapter.get("choice", ""))
		milestones_label.text = "NORTHSIDE CAMPAIGN\nDarius Knox • Northside Crew\nDoctrine: %s • Final objective: join/create a player Faction\nChapter reward: %s" % [
			"UNDECIDED" if chapter_3_choice.is_empty() else chapter_3_choice.to_upper(),
			String(chapter["completion_reward"])
		]
	else:
		var chapter_4_choice := String(chapter.get("choice", ""))
		milestones_label.text = "VELVET CIRCLE CAMPAIGN\nCeleste Marrow • Casino Vault\nLeverage: %s • Data Hub required before the final score\nChapter reward: %s" % [
			"UNDECIDED" if chapter_4_choice.is_empty() else chapter_4_choice.to_upper().replace("_", " "),
			String(chapter["completion_reward"])
		]

	unlocks_label.text = text_catalog.text("UI_UNLOCKS_TITLE") + "\nLv.2 — Harbor District + Garage\nLv.3 — Midtown + Intel Office\nLv.4 — Northside + Scrapyard\nLv.5 — High Roller Strip + Data Hub\nLv.6 — Financial District\nLv.7 — Industrial Belt"

	missions_label.text = text_catalog.text("UI_MISSIONS") + "\n" + "\n".join(missions.get_mission_lines())

	_refresh_upgrade_button(enforcer_button, &"Enforcer")
	_refresh_upgrade_button(driver_button, &"Driver")
	_refresh_upgrade_button(spy_button, &"Spy")


func _refresh_story_beat(chapter: Dictionary) -> void:
	story_speaker.text = String(chapter.get("speaker", "Vex")).to_upper()
	story_line.text = "“%s”" % String(chapter.get("story_line", ""))
	if presentation_catalog != null:
		var portrait_key := String(chapter.get("portrait", "vex"))
		var portrait := presentation_catalog.get_character_portrait(portrait_key)
		if portrait == null:
			portrait = presentation_catalog.get_campaign_art(portrait_key)
		story_portrait.texture = portrait


func _apply_portrait_art() -> void:
	if presentation_catalog == null:
		return

	var vex_portrait := presentation_catalog.get_character_portrait("vex")
	if vex_portrait != null:
		shortcut.icon = vex_portrait
		shortcut.expand_icon = true

	for entry in [
		[enforcer_button, &"enforcer"],
		[driver_button, &"driver"],
		[spy_button, &"spy"]
	]:
		var button := entry[0] as Button
		var portrait := presentation_catalog.get_unit_portrait(entry[1])
		if portrait != null:
			button.icon = portrait
			button.expand_icon = true


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
