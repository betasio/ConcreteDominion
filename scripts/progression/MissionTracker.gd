class_name MissionTracker
extends Node

const CHAPTER_1_TASKS := [
	"recruit_crew",
	"win_downtown",
	"reach_level_2",
	"build_garage",
	"build_intel"
]

signal changed
signal mission_completed(mission_id: String)

var progression: PlayerProgression
var economy: PlayerEconomy
var city_map: Node

var missions: Dictionary = {
	"recruit_crew": {
		"title": "Grow the Crew",
		"description": "Recruit 5 troops.",
		"goal": 5,
		"progress": 0,
		"completed": false,
		"reward_xp": 60,
		"reward_cash": 1500
	},
	"win_downtown": {
		"title": "First Score",
		"description": "Win a raid against Downtown Bank.",
		"goal": 1,
		"progress": 0,
		"completed": false,
		"reward_xp": 80,
		"reward_cash": 2500
	},
	"reach_level_2": {
		"title": "Make a Name",
		"description": "Reach account level 2.",
		"goal": 2,
		"progress": 1,
		"completed": false,
		"reward_xp": 40,
		"reward_cash": 2000
	},
	"build_garage": {
		"title": "Wheels Up",
		"description": "Build the Garage.",
		"goal": 1,
		"progress": 0,
		"completed": false,
		"reward_xp": 70,
		"reward_cash": 2500
	},
	"win_midtown": {
		"title": "Midtown Pressure",
		"description": "Defeat Midtown Exchange.",
		"goal": 1,
		"progress": 0,
		"completed": false,
		"reward_xp": 110,
		"reward_cash": 4000
	},
	"build_intel": {
		"title": "Eyes Everywhere",
		"description": "Build the Intel Office.",
		"goal": 1,
		"progress": 0,
		"completed": false,
		"reward_xp": 90,
		"reward_cash": 3000
	},
	"win_northside": {
		"title": "Take Northside",
		"description": "Defeat Northside Turf HQ.",
		"goal": 1,
		"progress": 0,
		"completed": false,
		"reward_xp": 140,
		"reward_cash": 5500
	},
	"win_casino": {
		"title": "Break the House",
		"description": "Defeat Casino Vault.",
		"goal": 1,
		"progress": 0,
		"completed": false,
		"reward_xp": 180,
		"reward_cash": 7000
	},
	"win_financial": {
		"title": "Own the Skyline",
		"description": "Defeat Financial Tower.",
		"goal": 1,
		"progress": 0,
		"completed": false,
		"reward_xp": 220,
		"reward_cash": 9000
	},
	"win_industrial": {
		"title": "Control the Supply",
		"description": "Defeat Industrial Depot.",
		"goal": 1,
		"progress": 0,
		"completed": false,
		"reward_xp": 280,
		"reward_cash": 12000
	},
	"chapter_1_complete": {
		"title": "A Higher Kingdom",
		"description": "Complete the five Chapter 1 operations.",
		"goal": 5,
		"progress": 0,
		"completed": false,
		"reward_xp": 150,
		"reward_cash": 5000
	}
}


func setup(
	player_progression: PlayerProgression,
	player_economy: PlayerEconomy,
	world: Node,
	recruitment: RecruitmentQueue,
	construction: ConstructionQueue,
	raid_battle: RaidBattle
) -> void:
	progression = player_progression
	economy = player_economy
	city_map = world

	recruitment.recruitment_completed.connect(_on_recruitment_completed)
	construction.construction_completed.connect(_on_construction_completed)
	raid_battle.battle_resolved.connect(_on_battle_resolved)
	progression.leveled_up.connect(_on_level_up)

	_refresh_level_mission()
	_refresh_existing_buildings()
	_refresh_chapter_progress()


func _refresh_existing_buildings() -> void:
	if city_map == null:
		return
	if city_map.lot_a.is_built:
		_set_progress("build_garage", 1)
	if city_map.lot_b.is_built:
		_set_progress("build_intel", 1)


func _on_recruitment_completed(_troop_type: StringName, amount: int) -> void:
	_add_progress("recruit_crew", amount)


func _on_construction_completed(target: Node) -> void:
	if target is BuildLot:
		var lot := target as BuildLot
		if lot.is_built and lot.building_name == "Garage":
			_set_progress("build_garage", 1)
		elif lot.is_built and lot.building_name == "Intel Office":
			_set_progress("build_intel", 1)
	_refresh_chapter_progress()
	changed.emit()


func _on_battle_resolved(result: Dictionary) -> void:
	if not bool(result.get("victory", false)):
		return

	match String(result.get("target_id", "")):
		"downtown_bank":
			_set_progress("win_downtown", 1)
		"midtown_exchange":
			_set_progress("win_midtown", 1)
		"northside_hq":
			_set_progress("win_northside", 1)
		"casino_vault":
			_set_progress("win_casino", 1)
		"financial_tower":
			_set_progress("win_financial", 1)
		"industrial_depot":
			_set_progress("win_industrial", 1)


func _on_level_up(_new_level: int) -> void:
	_refresh_level_mission()


func _refresh_level_mission() -> void:
	if progression == null:
		return
	_set_progress("reach_level_2", mini(progression.account_level, 2))


func _add_progress(mission_id: String, amount: int) -> void:
	if not missions.has(mission_id):
		return
	var mission: Dictionary = missions[mission_id]
	if bool(mission["completed"]):
		return
	mission["progress"] = mini(int(mission["goal"]), int(mission["progress"]) + maxi(0, amount))
	_check_complete(mission_id)


func _set_progress(mission_id: String, value: int) -> void:
	if not missions.has(mission_id):
		return
	var mission: Dictionary = missions[mission_id]
	if bool(mission["completed"]):
		return
	mission["progress"] = mini(int(mission["goal"]), maxi(0, value))
	_check_complete(mission_id)


func _check_complete(mission_id: String) -> void:
	var mission: Dictionary = missions[mission_id]

	if int(mission["progress"]) < int(mission["goal"]):
		changed.emit()
		return

	mission["completed"] = true

	if progression != null:
		progression.add_xp(int(mission["reward_xp"]))
	if economy != null:
		economy.add_cash(int(mission["reward_cash"]))

	mission_completed.emit(mission_id)
	if mission_id != "chapter_1_complete":
		_refresh_chapter_progress()
	changed.emit()


func _refresh_chapter_progress() -> void:
	var completed_count := 0
	for mission_id in CHAPTER_1_TASKS:
		if missions.has(mission_id) and bool(missions[mission_id]["completed"]):
			completed_count += 1
	_set_progress("chapter_1_complete", completed_count)


func get_story_chapter_status() -> Dictionary:
	var completed_count := 0
	var next_title := "Chapter complete"
	var next_description := "Your crew is established. Push deeper into the city and take territory."

	for mission_id in CHAPTER_1_TASKS:
		if not missions.has(mission_id):
			continue
		var mission: Dictionary = missions[mission_id]
		if bool(mission["completed"]):
			completed_count += 1
		elif next_title == "Chapter complete":
			next_title = String(mission["title"])
			next_description = String(mission["description"])

	return {
		"title": "A Higher Kingdom",
		"chapter": 1,
		"progress": completed_count,
		"goal": CHAPTER_1_TASKS.size(),
		"complete": bool(missions["chapter_1_complete"]["completed"]),
		"next_title": next_title,
		"next_description": next_description,
		"completion_reward": "$5,000 + 150 XP"
	}


func get_mission_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for mission_id in missions.keys():
		if mission_id == "chapter_1_complete":
			continue
		var mission: Dictionary = missions[mission_id]
		var state := "DONE" if bool(mission["completed"]) else "%d/%d" % [
			int(mission["progress"]),
			int(mission["goal"])
		]
		lines.append("%s — %s" % [String(mission["title"]), state])
	return lines


func get_save_data() -> Dictionary:
	var saved := {}
	for mission_id in missions.keys():
		var mission: Dictionary = missions[mission_id]
		saved[mission_id] = {
			"progress": int(mission["progress"]),
			"completed": bool(mission["completed"])
		}
	return saved


func load_save_data(data: Dictionary) -> void:
	for mission_id in missions.keys():
		if not data.has(mission_id):
			continue
		var saved = data[mission_id]
		if saved is Dictionary:
			missions[mission_id]["progress"] = int(saved.get("progress", missions[mission_id]["progress"]))
			missions[mission_id]["completed"] = bool(saved.get("completed", missions[mission_id]["completed"]))
	_refresh_chapter_progress()
	changed.emit()
