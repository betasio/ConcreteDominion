class_name MissionTracker
extends Node

signal changed
signal mission_completed(mission_id: String)

var progression: PlayerProgression
var economy: PlayerEconomy

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
	}
}


func setup(
	player_progression: PlayerProgression,
	player_economy: PlayerEconomy,
	recruitment: RecruitmentQueue,
	construction: ConstructionQueue,
	raid_battle: RaidBattle
) -> void:
	progression = player_progression
	economy = player_economy

	recruitment.recruitment_completed.connect(_on_recruitment_completed)
	construction.construction_completed.connect(_on_construction_completed)
	raid_battle.battle_resolved.connect(_on_battle_resolved)
	progression.leveled_up.connect(_on_level_up)

	_refresh_level_mission()


func _on_recruitment_completed(_troop_type: StringName, amount: int) -> void:
	_add_progress("recruit_crew", amount)


func _on_construction_completed(_target: Node) -> void:
	changed.emit()


func _on_battle_resolved(result: Dictionary) -> void:
	if bool(result.get("victory", false)) and String(result.get("target_id", "")) == "downtown_bank":
		_set_progress("win_downtown", 1)


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
	changed.emit()


func get_mission_lines() -> PackedStringArray:
	var lines := PackedStringArray()

	for mission_id in missions.keys():
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

	changed.emit()
