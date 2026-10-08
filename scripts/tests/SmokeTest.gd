extends Node

var failures: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame

	_check_resource("res://scenes/core/Boot.tscn")
	_check_resource("res://scenes/core/Main.tscn")
	_check_resource("res://scenes/ui/PauseMenu.tscn")
	_check_resource("res://scenes/ui/SettingsDiagnosticsUI.tscn")
	_check_resource("res://scenes/ui/CombatStrategyUI.tscn")
	_check_resource("res://scenes/ui/EndgameUI.tscn")
	_check_resource("res://scenes/ui/OnlineFactionUI.tscn")
	_check_resource("res://scenes/ui/OperationResultUI.tscn")
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
		"EndgameManager",
		"OperationResultUI",
		"BattleReportManager",
		"AchievementManager",
		"TutorialManager",
		"AchievementUI",
		"TutorialUI"
	]:
		if game.get_node_or_null(path) == null:
			_fail("Missing Main node: %s" % path)

	var hub := game.get_node_or_null("OnlineFactionUI") as OnlineFactionUI
	if hub == null:
		_fail("Player-facing Faction Hub is missing.")
	else:
		for section in ["Identity", "Wars", "Rivals", "Rankings", "Prestige", "Account"]:
			var tab = hub.get_node_or_null("Root/Panel/Margin/Scroll/VBox/%s" % hub._hub_tab_path(section))
			if not (tab is Button):
				_fail("Faction Hub tab missing: %s" % section)
			else:
				hub._select_hub_section(section)
				if hub.hub_section != section:
					_fail("Faction Hub failed to select %s" % section)
		hub._select_hub_section("Identity")
		if not hub.get_node("Root/Panel/Margin/Scroll/VBox/FactionCard").visible:
			_fail("Faction Hub Identity view did not show its illustrated card.")
		if hub.get_node("Root/Panel/Margin/Scroll/VBox/RecoveryKey").visible:
			_fail("Developer recovery credentials leaked into player-facing Identity tab.")

	var save := game.get_node_or_null("SaveManager") as SaveManager
	if save == null or SaveManager.SAVE_VERSION < 35:
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
		if MissionTracker.CHAPTER_3_TASKS.size() != 5:
			_fail("Chapter 3 objective chain is incomplete.")
		if not missions.missions.has("discover_northside") or not missions.missions.has("chapter_3_choice") or not missions.missions.has("join_faction") or not missions.missions.has("chapter_3_complete"):
			_fail("Chapter 3 Northside/Faction campaign missions are missing.")
		if MissionTracker.CHAPTER_4_TASKS.size() != 5:
			_fail("Chapter 4 objective chain is incomplete.")
		if not missions.missions.has("discover_casino") or not missions.missions.has("chapter_4_choice") or not missions.missions.has("build_data_hub") or not missions.missions.has("chapter_4_complete"):
			_fail("Chapter 4 Velvet Circle campaign missions are missing.")
		if MissionTracker.CHAPTER_5_TASKS.size() != 5:
			_fail("Chapter 5 objective chain is incomplete.")
		if not missions.missions.has("discover_financial") or not missions.missions.has("chapter_5_choice") or not missions.missions.has("capture_faction_objective") or not missions.missions.has("chapter_5_complete"):
			_fail("Chapter 5 Financial District/Faction objective campaign missions are missing.")
		if MissionTracker.CHAPTER_6_TASKS.size() != 5:
			_fail("Chapter 6 objective chain is incomplete.")
		if not missions.missions.has("discover_industrial") or not missions.missions.has("chapter_6_choice") or not missions.missions.has("clear_serpent_convoys") or not missions.missions.has("chapter_6_complete"):
			_fail("Chapter 6 Industrial Belt convoy campaign missions are missing.")
		if game.get_node_or_null("ProgressionUI/Root/Panel/Margin/VBox/ChapterAction") == null:
			_fail("Chapter operation action control is missing.")
		if game.get_node_or_null("ProgressionUI/Root/Panel/Margin/VBox/Approach/Force") == null or game.get_node_or_null("ProgressionUI/Root/Panel/Margin/VBox/Approach/Intel") == null:
			_fail("Chapter strategic choice controls are missing.")

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
	elif world_control.get_rival_family_id("industrial_depot") != "iron_serpents":
		_fail("Industrial Belt is not assigned to the Iron Serpent family.")
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
		if game.get_node_or_null("WorldControlUI/Root/VictoryPanel/Margin/VBox/CampaignArt") == null:
			_fail("District campaign art presentation is missing.")

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
	elif not "convoy_ambush" in family_rules.get_encounter_cycle("industrial_depot"):
		_fail("Industrial Belt is missing Iron Serpent convoy encounters.")

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
		if faction_manager.get_war_rules_lines().size() < 6:
			_fail("Faction War reward/season rules are incomplete.")
		if FactionManager.WAR_STRATEGIES.size() != 3 or FactionManager.WAR_DEFENSE_CYCLE.size() != 3:
			_fail("Faction War strategic counter system is incomplete.")
		if FactionManager.WAR_DOCTRINES.size() != 3 or FactionManager.WAR_DEFENSE_COUNTERS.size() != 3:
			_fail("Faction War preparation doctrine/defense system is incomplete.")
		if FactionManager.WAR_OBJECTIVE_DEFS.size() != 3 or FactionManager.WAR_REWARD_POOLS.size() != 3:
			_fail("Faction War shared objective/reward split system is incomplete.")
		if faction_manager.get_war_readiness_score() < 0 or faction_manager.get_war_readiness_score() > 100:
			_fail("Faction War readiness score is invalid.")
		if faction_manager.get_matchmaking_rating() < 0:
			_fail("Faction matchmaking rating is invalid.")
		if faction_manager.get_territory_cash_multiplier() < 1.0:
			_fail("Faction territory income objective multiplier is invalid.")
		if FactionManager.SEASON_WEEKS != EndgameManager.SEASON_WEEKS:
			_fail("Faction and Dominion season cadence are not synchronized.")
		if faction_manager.season_period < 0:
			_fail("Faction seasonal competition period is invalid.")
		if missions.faction != faction_manager:
			_fail("Chapter Faction integration is not wired.")
		if not faction_manager.territory_captured.is_connected(missions._on_faction_territory_captured):
			_fail("Chapter 5 Faction territory objective signal is not wired.")
		if world_control != null and not world_control.family_encounter_resolved.is_connected(missions._on_family_encounter_resolved):
			_fail("Chapter 6 Rival Family encounter signal is not wired.")
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
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarPrepButtons/Captain") == null or game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarPrepButtons/Doctrine") == null or game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarPrepButtons/Defense") == null:
		_fail("Faction War preparation controls are missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarPreparation") == null:
		_fail("Faction War readiness presentation is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarPlanButtons/Muscle") == null or game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarPlanButtons/Convoy") == null or game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarPlanButtons/Intel") == null:
		_fail("Faction War strategic attack controls are missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarAttackReport") == null:
		_fail("Faction War attack report presentation is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarObjectives") == null:
		_fail("Faction War shared objective presentation is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarParticipation") == null:
		_fail("Faction War member participation presentation is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarDebrief") == null:
		_fail("Faction War debrief history panel is missing.")
	if game.get_node_or_null("FactionUI/Root/Panel/Margin/Scroll/VBox/WarRewardSplit") == null:
		_fail("Faction War participation reward split presentation is missing.")
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

	var endgame := game.get_node_or_null("EndgameManager") as EndgameManager
	if endgame == null:
		_fail("Dominion endgame manager is missing.")
	else:
		var dominion_status := endgame.get_status()
		if EndgameManager.WEEKLY_REQUIRED != 2:
			_fail("Dominion weekly flexibility requirement is invalid.")
		if endgame.get_contract_lines().size() != 3:
			_fail("Dominion weekly contract tracks are incomplete.")
		if int(dominion_status.get("dominion_marks", -1)) < 0:
			_fail("Dominion marks are invalid.")
		if endgame.get_dominion_rank().is_empty():
			_fail("Dominion rank progression is invalid.")
		if EndgameManager.SEASON_MODIFIERS.size() != 4 or EndgameManager.SEASON_IDENTITIES.size() != 4:
			_fail("Dominion seasonal identity/modifier rotation is incomplete.")
		var modifier := endgame.get_current_modifier()
		if String(modifier.get("district_id", "")).is_empty() or String(modifier.get("family_id", "")).is_empty():
			_fail("Dominion citywide modifier is invalid.")
		if endgame.get_season_leaderboard_lines().size() < 4:
			_fail("Dominion seasonal leaderboard is incomplete.")
		if endgame.get_season_reward_summary().is_empty():
			_fail("Dominion seasonal reward tiers are invalid.")
		if endgame.get_season_name().is_empty() or endgame.get_season_subtitle().is_empty():
			_fail("Dominion named season identity is invalid.")
		if endgame.get_last_season_result_text().is_empty():
			_fail("Dominion season result presentation is invalid.")
		if endgame.world_control != world_control or endgame.faction != faction_manager:
			_fail("Dominion runtime dependencies are not wired.")
		if world_control != null and not world_control.family_encounter_resolved.is_connected(endgame._on_family_encounter_resolved):
			_fail("Dominion Rival Family operation tracking is not wired.")
		if faction_manager != null and not faction_manager.war_completed.is_connected(endgame._on_faction_war_completed):
			_fail("Dominion Faction War tracking is not wired.")
	if game.get_node_or_null("EndgameUI/Root/Panel/Margin/Scroll/VBox/RivalOperation") == null:
		_fail("Dominion Rival Family operation UI is missing.")
	if game.get_node_or_null("EndgameUI/Root/Panel/Margin/Scroll/VBox/BossRematch") == null:
		_fail("Dominion boss rematch UI is missing.")
	if game.get_node_or_null("EndgameUI/Root/Panel/Margin/Scroll/VBox/ClaimCache") == null:
		_fail("Dominion reward claim UI is missing.")
	if game.get_node_or_null("EndgameUI/Root/Panel/Margin/Scroll/VBox/Leaderboard") == null:
		_fail("Dominion seasonal leaderboard UI is missing.")
	if game.get_node_or_null("EndgameUI/Root/Panel/Margin/Scroll/VBox/ClaimSeasonReward") == null:
		_fail("Dominion seasonal tier reward UI is missing.")
	if game.get_node_or_null("EndgameUI/Root/Panel/Margin/Scroll/VBox/SeasonBanner") == null:
		_fail("Dominion season banner presentation is missing.")
	if game.get_node_or_null("EndgameUI/Root/Panel/Margin/Scroll/VBox/Prestige") == null or game.get_node_or_null("EndgameUI/Root/Panel/Margin/Scroll/VBox/EquipPrestige") == null:
		_fail("Dominion prestige presentation is missing.")

	var raid_battle := game.get_node_or_null("RaidBattle") as RaidBattle
	var battle_reports := game.get_node_or_null("BattleReportManager") as BattleReportManager
	var operation_results := game.get_node_or_null("OperationResultUI") as OperationResultUI
	if battle_reports == null:
		_fail("Persistent battle report manager is missing.")
	else:
		if BattleReportManager.MAX_REPORTS != 20:
			_fail("Battle report history cap is invalid.")
		if not raid_battle.battle_resolved.is_connected(battle_reports._on_raid_resolved):
			_fail("Raid results are not wired into battle history.")
		if world_control != null and not world_control.operation_resolved.is_connected(battle_reports._on_family_operation_resolved):
			_fail("Rival Family operations are not wired into battle history.")
	if operation_results == null:
		_fail("Premium operation report UI is missing.")
	else:
		if game.get_node_or_null("OperationResultUI/Root/Reports") == null:
			_fail("Battle report history shortcut is missing.")
		if game.get_node_or_null("OperationResultUI/Root/Panel/Margin/VBox/Art") == null:
			_fail("Operation report art presentation is missing.")
		if game.get_node_or_null("OperationResultUI/Root/Panel/Margin/VBox/Grade") == null:
			_fail("Operation report grade presentation is missing.")
		if game.get_node_or_null("OperationResultUI/Root/Panel/Margin/VBox/Advice") == null:
			_fail("Operation report tactical advice is missing.")
		if game.get_node_or_null("OperationResultUI/Root/Panel/Margin/VBox/HistoryNav/Older") == null:
			_fail("Operation report history navigation is missing.")
		if game.get_node_or_null("OperationResultUI/Root/Panel/Margin/VBox/Rematch") == null:
			_fail("Operation report rematch control is missing.")
		if game.get_node_or_null("OperationResultUI/Root/Panel/Margin/VBox/Rewards") == null:
			_fail("Operation report reward reveal is missing.")
		if game.get_node_or_null("OperationResultUI/Root/Panel/Margin/VBox/Progress") == null:
			_fail("Operation report progression feedback is missing.")
		if battle_reports != null and not battle_reports.report_recorded.is_connected(operation_results._on_report_recorded):
			_fail("Battle history is not wired to the premium operation report.")

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
		if not presentation.is_campaign_atlas_ready():
			_fail("Campaign art atlas failed to load.")
		elif presentation.get_campaign_atlas_size() != Vector2i(256, 64):
			_fail("Campaign art atlas has an unexpected size.")
		else:
			for campaign_key in ["darius", "northside", "celeste", "casino"]:
				if presentation.get_campaign_art(campaign_key) == null:
					_fail("Missing campaign art slice: %s" % campaign_key)
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

	var online_ui := game.get_node_or_null("OnlineFactionUI") as OnlineFactionUI
	if online_ui == null or online_ui.client == null:
		_fail("Online Faction developer UI/client is missing.")
	else:
		if not online_ui.client.session_token.is_empty():
			_fail("Online Faction session must not auto-load from plaintext saves.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/Refresh") == null:
			_fail("Online Faction server-sync button is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/Accept") == null:
			_fail("Online invitation accept button is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/RefreshWar") == null:
			_fail("Online Faction War refresh is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/AttackPlans/Intel") == null:
			_fail("Online Faction War attack controls are missing.")
		var identity_card = game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/FactionCard")
		if not (identity_card is FactionIdentityCard):
			_fail("Illustrated Faction identity profile card is missing.")
		else:
			identity_card.set_identity({"name":"Smoke Syndicate","tag":"SMK","emblem":"wolf","banner":"crimson"}, "CHAMPION", 2)
			identity_card.set_rivalry_prestige({"total_rematch_trophies":2,"current_win_streak":3,"best_win_streak":5})
			if identity_card.rivalry_trophies != 2 or identity_card.best_streak != 5:
				_fail("Faction card did not render server rivalry prestige.")
			if identity_card.emblem != "wolf" or identity_card.prestige != "CHAMPION":
				_fail("Faction identity card did not accept valid cosmetic data.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/ApplyIdentity") == null:
			_fail("Online Faction identity controls are missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/ViewFactionProfile") == null:
			_fail("Online public Faction profile controls are missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/RefreshPrestige") == null:
			_fail("Online prestige history refresh is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/PrestigeHistory") == null:
			_fail("Online historical champion display is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/RefreshSeasons") == null:
			_fail("Online seasonal leaderboard refresh is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/SeasonStandings") == null:
			_fail("Online seasonal leaderboard display is missing.")
		if not (game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/PvPMatchup/OurCard") is FactionIdentityCard):
			_fail("Our Faction PvP identity card is missing.")
		if not (game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/PvPMatchup/OpponentCard") is FactionIdentityCard):
			_fail("Opponent Faction PvP identity card is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/RefreshChallenges") == null:
			_fail("Direct rivalry challenge inbox is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/AcceptChallenge") == null:
			_fail("Direct rivalry rematch acceptance is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/RefreshTrophies") == null:
			_fail("Rivalry trophy case refresh is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/TrophyStatus") == null:
			_fail("Rivalry trophy case display is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/RefreshRivalries") == null:
			_fail("PvP rivalry history refresh button is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/RivalryStatus") == null:
			_fail("PvP rivalry history display is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/QueuePvP") == null:
			_fail("Online Faction PvP queue is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/CancelPvP") == null:
			_fail("Online Faction PvP queue cancellation is missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/RecoverAccount") == null:
			_fail("Developer account recovery controls are missing.")
		if game.get_node_or_null("OnlineFactionUI/Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPIntel") == null:
			_fail("Online Faction PvP attack controls are missing.")

	var test_client := OnlineFactionClient.new()
	add_child(test_client)
	test_client.set_session("smoke-test-receipt-isolation")
	test_client._retry_id = "abcdefabcdefabcdefabcdefabcdefab"
	test_client._retry_strategy = "convoy"
	test_client._save_retry_receipt()
	var second_client := OnlineFactionClient.new()
	add_child(second_client)
	second_client.set_session("smoke-test-receipt-isolation")
	if second_client._retry_id != test_client._retry_id or second_client._retry_strategy != "convoy":
		_fail("PvP pending receipt did not persist across client recreation.")
	second_client._clear_retry_receipt()
	test_client.queue_free()
	second_client.queue_free()

	game.queue_free()
	await get_tree().process_frame
	_finish()


func _check_resource(path: String) -> void:
	if not ResourceLoader.exists(path):
		_fail("Missing resource: %s" % path)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[SMOKE] %s" % message)


func _finish() -> void:
	var exit_code := 0 if failures.is_empty() else 1
	if failures.is_empty():
		print("[SMOKE] PASS — core scenes and systems loaded.")
	else:
		print("[SMOKE] FAIL — %d issue(s)." % failures.size())

	for child in get_children():
		child.queue_free()

	get_tree().process_frame.connect(
		func():
			get_tree().process_frame.connect(
				func(): get_tree().quit(exit_code),
				CONNECT_ONE_SHOT
			),
		CONNECT_ONE_SHOT
	)
