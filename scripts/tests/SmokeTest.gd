extends Node

var failures: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame

	_check_resource("res://scenes/core/Boot.tscn")
	_check_resource("res://scenes/core/Main.tscn")
	_check_resource("res://scenes/ui/PauseMenu.tscn")
	_check_resource("res://scenes/ui/SettingsDiagnosticsUI.tscn")
	_check_resource("res://scenes/ui/CombatStrategyUI.tscn")
	_check_resource("res://scenes/ui/WorldControlUI.tscn")
	_check_resource("res://scenes/tests/DataValidation.tscn")
	_check_resource("res://scenes/tests/BalanceAudit.tscn")
	_check_resource("res://scenes/tests/ProjectResourceAudit.tscn")
	_check_resource("res://scenes/tests/GameplayRegressionAudit.tscn")
	_check_resource("res://scenes/tests/ArtCoverageAudit.tscn")

	var main_scene := load("res://scenes/core/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene could not be loaded.")
		_finish()
		return

	var game := main_scene.instantiate()
	add_child(game)
	await get_tree().process_frame

	for path in [
		"GameBalance",
		"SettingsManager",
		"SaveManager",
		"MissionTracker",
		"CityMap",
		"HUD",
		"PauseMenu",
		"AudioManager",
		"UIFocusManager",
		"FacilityEffects",
		"CoreBuildingEffects",
		"StoreManager",
		"StoreUI",
		"WorldControlManager",
		"WorldControlUI",
		"ResourceProductionManager",
		"LocalizedText",
		"PresentationCatalog",
		"UIArtStyler",
		"RivalFamilyRules",
		"FactionManager",
		"AchievementManager",
		"TutorialManager",
		"AchievementUI",
		"TutorialUI"
	]:
		if game.get_node_or_null(path) == null:
			_fail("Missing Main node: %s" % path)

	var save := game.get_node_or_null("SaveManager") as SaveManager
	if save == null or SaveManager.SAVE_VERSION < 24:
		_fail("Save schema is not production-ready.")

	var balance := game.get_node_or_null("GameBalance") as GameBalance
	if balance == null or balance.get_recruitment_definition(&"Driver").is_empty():
		_fail("GameBalance recruitment table missing Driver.")
	if balance == null or balance.get_facility_value("garage_driver_support_per_level", 0.0) <= 0.0:
		_fail("GameBalance facility tuning is missing.")
	if balance == null or balance.get_core_building_value("clinic_healing_reduction_per_level", 0.0) <= 0.0:
		_fail("GameBalance core-building tuning is missing.")
	if balance == null or balance.get_speedup_chunk_seconds() != 300:
		_fail("Production speed-up chunk should be 300 seconds.")

	var recruitment := game.get_node_or_null("RecruitmentQueue") as RecruitmentQueue
	if recruitment == null or recruitment.get_queue_capacity() < 1:
		_fail("Recruitment queue capacity is invalid.")

	var missions := game.get_node_or_null("MissionTracker") as MissionTracker
	if missions == null:
		_fail("MissionTracker is missing.")
	else:
		var chapter := missions.get_story_chapter_status()
		if String(chapter.get("title", "")) != "A Higher Kingdom" or int(chapter.get("chapter", 0)) != 1:
			_fail("Chapter 1 story configuration is invalid.")
		if int(chapter.get("goal", 0)) != 5 or String(chapter.get("next_title", "")).is_empty():
			_fail("Chapter 1 objective chain is incomplete.")
		if String(chapter.get("speaker", "")).is_empty() or String(chapter.get("story_line", "")).is_empty():
			_fail("Chapter 1 character story beat is missing.")
		if game.get_node_or_null("ProgressionUI/Root/Panel/Margin/VBox/Chapter") == null:
			_fail("Chapter 1 progression presentation is missing.")
		if game.get_node_or_null("ProgressionUI/Root/Panel/Margin/VBox/StoryBeat/Portrait") == null:
			_fail("Chapter 1 story portrait presentation is missing.")
		if game.get_node_or_null("ProgressionUI/Root/Panel/Margin/VBox/Milestones") == null:
			_fail("Chapter 1 milestone reward presentation is missing.")
		if MissionTracker.CHAPTER_2_TASKS.size() != 5:
			_fail("Chapter 2 objective chain is incomplete.")
		if not missions.missions.has("win_harbor") or not missions.missions.has("win_midtown") or not missions.missions.has("chapter_2_complete"):
			_fail("Chapter 2 Harbor/Midtown campaign missions are missing.")
		if game.get_node_or_null("ProgressionUI/Root/Panel/Margin/VBox/Approach/Force") == null or game.get_node_or_null("ProgressionUI/Root/Panel/Margin/VBox/Approach/Intel") == null:
			_fail("Chapter 2 strategic choice controls are missing.")

	var retention := game.get_node_or_null("RetentionManager") as RetentionManager
	if retention == null:
		_fail("RetentionManager is missing.")
	else:
		var daily := retention.get_daily_status()
		var weekly := retention.get_weekly_status()
		if int(daily.get("required_contracts", 0)) != 2 or int(daily.get("construction_goal", 0)) != 1:
			_fail("Daily flexible contract configuration is invalid.")
		if int(weekly.get("required_contracts", 0)) != 2 or int(weekly.get("construction_goal", 0)) != 3:
			_fail("Weekly flexible contract configuration is invalid.")
		if game.get_node_or_null("RetentionUI/Root/Panel/Margin/VBox/ClaimComeback") == null:
			_fail("Comeback reward control is missing.")

	var alliance := game.get_node_or_null("AllianceManager") as AllianceManager
	if alliance == null or alliance.get_xp_for_next_level() <= 0:
		_fail("Alliance progression is invalid.")

	var world_control := game.get_node_or_null("WorldControlManager") as WorldControlManager
	if world_control == null or not world_control.is_discovered("downtown_bank"):
		_fail("World-control discovery defaults are invalid.")
	elif world_control.get_rivalry_label("harbor_bank") != "COLD":
		_fail("Family rivalry baseline is invalid.")
	elif world_control.get_rivalry_reward_multiplier("harbor_bank") < 1.0:
		_fail("Family rivalry reward scaling is invalid.")
	else:
		var harbor_dossier := world_control.get_faction_dossier("harbor_bank")
		if String(harbor_dossier.get("boss", "")).is_empty() or String(harbor_dossier.get("perk", "")).is_empty():
			_fail("Harbor rival dossier is incomplete.")
		if world_control.get_rivalry_lines().is_empty():
			_fail("Rivalry dossier list is empty.")
		if game.get_node_or_null("WorldControlUI/Root/Panel/Margin/VBox/Rivalries") == null:
			_fail("Rivalry dossier UI is missing.")
		if game.get_node_or_null("WorldControlUI/Root/VictoryPanel/Margin/VBox/Summary") == null:
			_fail("District victory presentation is missing.")

	var resources := game.get_node_or_null("ResourceProductionManager") as ResourceProductionManager
	if resources == null:
		_fail("Resource production manager is missing.")

	var text_catalog := game.get_node_or_null("LocalizedText") as LocalizedText
	if text_catalog == null or not text_catalog.has_key("ACH_DOMINION"):
		_fail("Localization catalog is invalid.")
	elif not text_catalog.has_key("UI_TERRITORY_TITLE") or not text_catalog.has_key("UI_STORE_TITLE"):
		_fail("High-traffic UI localization keys are missing.")
	elif not text_catalog.has_key("TUTORIAL_WELCOME_TITLE") or not text_catalog.has_key("UI_TACTICS"):
		_fail("Tutorial/secondary UI localization keys are missing.")

	var family_rules := game.get_node_or_null("RivalFamilyRules") as RivalFamilyRules
	if family_rules == null or family_rules.get_encounter_cycle("harbor_bank").is_empty():
		_fail("Rival Family rules are invalid.")
	elif family_rules.get_boss_name("harbor_bank").is_empty() or family_rules.get_boss_name("midtown_exchange").is_empty():
		_fail("Named Rival Family bosses are missing.")
	elif family_rules.get_perk_summary("harbor_bank").is_empty():
		_fail("Rival Family gameplay identity is missing.")

	var faction_manager := game.get_node_or_null("FactionManager") as FactionManager
	if faction_manager == null:
		_fail("Player Faction manager is missing.")
	elif faction_manager.get_xp_for_next_level() <= 0:
		_fail("Player Faction progression is invalid.")
	else:
		if FactionManager.DAILY_REQUIRED != 3 or faction_manager.get_daily_lines().size() != 4:
			_fail("Faction daily operations are invalid.")
		if faction_manager.get_war_rules_lines().size() < 4:
			_fail("Faction War ruleset is incomplete.")
		if faction_manager.get_construction_time_multiplier() > 1.0 or faction_manager.get_territory_income_multiplier() < 1.0:
			_fail("Faction research multipliers are invalid.")
		if faction_manager.get_territory_lines().size() != 3:
			_fail("Faction territory objective rules are incomplete.")
		if faction_manager.get_war_rules_lines().size() < 5:
			_fail("Faction War reward/season rules are incomplete.")
		if faction_manager.get_matchmaking_rating() < 0:
			_fail("Faction matchmaking rating is invalid.")
		if faction_manager.get_territory_cash_multiplier() < 1.0:
			_fail("Faction territory income objective multiplier is invalid.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/CreateBox/Create") == null:
		_fail("Player Faction creation UI is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/DailyButtons/ClaimDaily") == null:
		_fail("Faction daily mission UI is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/Gift") == null:
		_fail("Faction gift chest UI is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/RallyButtons/StartRally") == null:
		_fail("Faction rally UI is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarButtons/StartWar") == null:
		_fail("Faction War UI is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/MemberAdmin/Invite") == null:
		_fail("Faction member administration UI is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/CaptureTerritory") == null:
		_fail("Faction territory objective UI is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/Rankings") == null:
		_fail("Faction season rankings UI is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/Matchmaking") == null:
		_fail("Faction matchmaking preview UI is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarRewardButtons/ClaimWarReward") == null:
		_fail("Faction War reward claim UI is missing.")

	var achievement_manager := game.get_node_or_null("AchievementManager") as AchievementManager
	if achievement_manager == null:
		_fail("Achievement manager is missing.")

	var tutorial_manager := game.get_node_or_null("TutorialManager") as TutorialManager
	if tutorial_manager == null or tutorial_manager.current_step < TutorialManager.STEP_WELCOME:
		_fail("Tutorial manager is invalid.")

	var presentation := game.get_node_or_null("PresentationCatalog") as PresentationCatalog
	if presentation == null:
		_fail("Presentation catalog is missing.")
	elif not presentation.is_city_atlas_ready():
		_fail("Approved city art atlas failed to decode: %s" % presentation.get_atlas_error())
	elif presentation.get_city_atlas_size() != Vector2i(320, 160):
		_fail("Approved city art atlas has an unexpected size.")
	else:
		for art_key in ["safehouse", "hospital", "barracks", "Garage", "Intel Office", "Scrapyard", "Data Hub", "raid_target"]:
			if presentation.get_texture(art_key) == null:
				_fail("Missing approved art slice: %s" % art_key)

	if presentation != null:
		if not presentation.is_decor_atlas_ready():
			_fail("Approved UI/street presentation atlas failed to load.")
		elif presentation.get_decor_atlas_size() != Vector2i(256, 160):
			_fail("Approved UI/street presentation atlas has an unexpected size.")
		else:
			for decor_key in ["ui_panel", "ui_bar", "ui_button_dark", "ui_button_gold", "road_intersection", "road_straight"]:
				if presentation.get_decor_texture(decor_key) == null:
					_fail("Missing approved presentation slice: %s" % decor_key)

	var construction := game.get_node_or_null("ConstructionQueue") as ConstructionQueue
	if construction == null:
		_fail("ConstructionQueue script is not active.")
	elif construction.faction != faction_manager:
		_fail("Faction construction research is not wired.")
	if world_control != null and world_control.faction != faction_manager:
		_fail("Faction territory research is not wired.")

	var ui_styler := game.get_node_or_null("UIArtStyler") as UIArtStyler
	if ui_styler == null:
		_fail("UI art styler script is not active.")
	else:
		var top_panel := game.get_node_or_null("HUD/Root/TopBar/Panel") as PanelContainer
		var base_button := game.get_node_or_null("HUD/Root/ViewBar/Base") as Button
		if top_panel == null or not (top_panel.get_theme_stylebox("panel") is StyleBoxTexture):
			_fail("Approved panel art is not applied at runtime.")
		if base_button == null or not (base_button.get_theme_stylebox("normal") is StyleBoxTexture):
			_fail("Approved button art is not applied at runtime.")

	var city := game.get_node_or_null("CityMap")
	if city == null or city.get_node_or_null("TurfOverlay") == null:
		_fail("Turf ownership overlay is missing.")
	elif not (city.get_node("TurfOverlay") is TurfOverlay):
		_fail("TurfOverlay script is not active.")
	elif city.lot_c == null or city.lot_d == null:
		_fail("Resource-production build lots are missing.")

	_finish()


func _check_resource(path: String) -> void:
	if not ResourceLoader.exists(path):
		_fail("Missing resource: %s" % path)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[SMOKE] %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("[SMOKE] PASS — core scenes and systems loaded.")
		get_tree().quit(0)
	else:
		print("[SMOKE] FAIL — %d issue(s)." % failures.size())
		get_tree().quit(1)
