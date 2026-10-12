extends Node
## Run with a fresh XDG_DATA_HOME: this audit deliberately corrupts its own save.
var failures: PackedStringArray = []
var save_count := 0
const GUIDE = preload("res://scripts/progression/ObjectiveGuide.gd")
const CHAPTERS = [MissionTracker.CHAPTER_1_TASKS, MissionTracker.CHAPTER_2_TASKS, MissionTracker.CHAPTER_3_TASKS, MissionTracker.CHAPTER_4_TASKS, MissionTracker.CHAPTER_5_TASKS, MissionTracker.CHAPTER_6_TASKS]

func _ready() -> void:
	call_deferred("_audit")

func _audit() -> void:
	# Refuse to touch an existing player save if called without an isolated home.
	if FileAccess.file_exists(SaveManager.SAVE_PATH) or FileAccess.file_exists(SaveManager.BACKUP_PATH):
		push_error("Run GameFunctionalityAudit with a fresh XDG_DATA_HOME.")
		get_tree().quit(1)
		return
	var game = load("res://scenes/core/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var saver: SaveManager = game.save_manager
	saver.save_completed.connect(func(): save_count += 1)
	_check(saver.save_game(), "Initial save failed")
	var before := save_count
	for i in range(30):
		saver.mark_dirty()
		saver._process(0.1)
	_check(save_count >= before+2, "Continuous changes starved autosave")
	_check(not saver._read_save_dictionary(SaveManager.SAVE_PATH).is_empty(), "Primary save is not valid JSON")
	_check(not FileAccess.file_exists(SaveManager.SAVE_PATH+".tmp"), "Successful save left a temporary file")
	# A failed attempt retains pending changes and waits before retrying.
	saver.economy = null
	saver.mark_dirty()
	saver._process(10.0)
	_check(saver._dirty and saver._autosave_timer >= 1.0, "Failed save discarded changes or retries every frame")
	saver.economy = game.economy
	saver._process(1.1)
	_check(not saver._dirty, "Recovered writer did not retry pending changes")
	game.economy.cash = 12345
	_check(saver.save_game(), "Backup seed failed")
	game.economy.cash = 23456
	_check(saver.save_game(), "Second save failed")
	var corrupt := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string("{}")
	corrupt.close()
	_check(saver.load_game() and game.economy.cash == 12345, "Backup did not recover previous balance")
	_check(saver._dirty, "Loaded/offline state was not scheduled for persistence")
	saver._process(1.1)
	_check(int(saver._read_save_dictionary(SaveManager.BACKUP_PATH).economy.cash) == 12345, "Corrupt primary overwrote good backup")
	var target: RaidTarget = game.city_map.get_raid_target_by_id("downtown_bank")
	game.loot_inventory.items["Intel"] = 0
	game.combat_loadout.selected_consumable = &"intel_boost"
	game.hud.show_raid_target(target)
	game.combat_loadout.changed.emit()
	_check(game.hud.launch_raid_button.disabled and game.hud.raid_status_label.text.contains("1 Intel"), "Missing consumable was shown as launch-ready")
	_check(not game.raid_battle.start_battle(target,0,0), "Raid launched with an unavailable consumable")
	game.combat_loadout.selected_consumable = &"none"
	game.combat_loadout.changed.emit()
	_check(not game.hud.launch_raid_button.disabled, "No-consumable loadout did not restore readiness")
	game.combat_loadout.selected_consumable = &"intel_boost"
	game.loot_inventory.add_item("Intel",1)
	_check(not game.hud.launch_raid_button.disabled, "Collecting missing Intel did not refresh readiness")
	_check(game.loot_inventory.get_count("Intel") == 1 and not game.raid_battle.is_active(), "Readiness checks spent Intel or launched combat")
	game.combat_loadout.selected_consumable = &"none"
	var estate = game.get_node("EstateHUD")
	for chapter_index in range(CHAPTERS.size()):
		for mission_id in CHAPTERS[chapter_index]:
			_set_objective(game.mission_tracker, chapter_index, mission_id)
			var cash_before: int = game.economy.cash
			var loot_before: Dictionary = game.loot_inventory.get_save_data()
			game.progression_ui._refresh()
			var action := GUIDE.action(mission_id)
			if game.progression_ui.next_objective_button.visible:
				game.progression_ui.next_objective_button.pressed.emit()
			else:
				estate.mission_button.pressed.emit()
			match action.kind:
				"training":
					_check(game.hud.barracks_panel.visible and not game.hud.selection_panel.visible, "Training shortcut stacked panels")
				"lot":
					_check(game.hud.selection_panel.visible and game.hud.selected_lot == game.city_map.get_persistent_target(action.target), "Wrong construction site: "+mission_id)
				"raid":
					var raid: RaidTarget = game.city_map.get_raid_target_by_id(action.target)
					_check(raid != null, "Missing chapter raid: "+mission_id)
					if raid != null and raid.visible:
						_check(game.city_map.camera.zoom.is_equal_approx(Vector2(0.72,0.72)), "Raid focus kept estate zoom")
						_check(game.hud.raid_panel.visible and game.hud.selected_raid_target == raid, "Wrong raid: "+mission_id)
					else:
						_check(game.get_node("WorldControlUI").panel.visible, "Undiscovered raid bypassed discovery")
				"panel":
					_check(game.get_node(action.target).panel.visible, "Wrong chapter destination: "+mission_id)
			_check(game.economy.cash == cash_before and game.loot_inventory.get_save_data() == loot_before and not game.raid_battle.is_active(), "Navigation spent resources or launched a raid: "+mission_id)
	if failures.is_empty():
		print("[FUNCTIONALITY AUDIT] PASS — continuous autosave, atomic save/backup recovery, consumable readiness and all 30 chapter routes")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _set_objective(tracker: MissionTracker, chapter_index: int, mission_id: String) -> void:
	for entry in tracker.missions.values():
		entry["completed"] = false
	for previous in range(chapter_index):
		tracker.missions["chapter_%d_complete" % (previous+1)]["completed"] = true
	for task in CHAPTERS[chapter_index]:
		if task == mission_id:
			break
		tracker.missions[task]["completed"] = true

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
