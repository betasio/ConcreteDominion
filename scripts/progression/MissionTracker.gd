class_name MissionTracker
extends Node

const CHAPTER_1_TASKS := [
	"recruit_crew",
	"win_downtown",
	"reach_level_2",
	"build_garage",
	"build_intel"
]

const CHAPTER_2_TASKS := [
	"discover_harbor",
	"win_harbor",
	"chapter_2_choice",
	"discover_midtown",
	"win_midtown"
]

const STORY_BEATS := {
	"recruit_crew": {"speaker":"Vex","portrait":"vex","line":"A city does not fear one name. Build the crew first. Then we give it a reason to remember ours."},
	"win_downtown": {"speaker":"Mia","portrait":"mia","line":"Downtown moves money before it moves muscle. Hit the bank clean, fast, and leave them guessing."},
	"reach_level_2": {"speaker":"Noah","portrait":"noah","line":"Noise gets attention. Reputation gets doors opened. Keep the wins coming and the city starts calling us first."},
	"build_garage": {"speaker":"Mia","portrait":"mia","line":"We need wheels that belong to us. A Garage turns every future job into a choice instead of a gamble."},
	"build_intel": {"speaker":"Kira","portrait":"kira","line":"Power without information is just a target. Give me an Intel Office and I will tell you where the city is weakest."},
	"chapter_1_complete": {"speaker":"Vex","portrait":"vex","line":"Now we are not surviving the city. We are shaping it. Harbor is where the real crews start paying attention."},
	"discover_harbor": {"speaker":"Kira","portrait":"kira","line":"The Iron Serpents own the Harbor cameras, manifests, and checkpoints. Reveal the district before we move."},
	"win_harbor": {"speaker":"Mia","portrait":"mia","line":"The Serpents expect a convoy war. Good. Give them the one they prepared for, then take the ground under it."},
	"chapter_2_choice": {"speaker":"Vex","portrait":"vex","line":"We can make the next move loud or invisible. Pick the reputation you want this crew to earn."},
	"discover_midtown": {"speaker":"Noah","portrait":"noah","line":"Midtown is different. The Meridian Boys watch patterns, not streets. Make them look in the wrong direction."},
	"win_midtown": {"speaker":"Kira","portrait":"kira","line":"Their network is exposed. Break the Exchange now and every crew in the city learns we can beat brains as well as muscle."},
	"chapter_2_complete": {"speaker":"Mia","portrait":"mia","line":"Harbor and Midtown both folded. That is not luck anymore. That is a pattern with our name on it."}
}

signal changed
signal mission_completed(mission_id: String)
signal chapter_milestone_reached(milestone: int, reward: Dictionary)
signal strategic_choice_made(choice_id: String)

var progression: PlayerProgression
var economy: PlayerEconomy
var loot: LootInventory
var city_map: Node
var world_control: WorldControlManager

var chapter_milestones_claimed := {"2": false, "4": false}
var chapter_2_choice := ""

var missions: Dictionary = {
	"recruit_crew":{"title":"Grow the Crew","description":"Recruit 5 troops.","goal":5,"progress":0,"completed":false,"reward_xp":60,"reward_cash":1500},
	"win_downtown":{"title":"First Score","description":"Win a raid against Downtown Bank.","goal":1,"progress":0,"completed":false,"reward_xp":80,"reward_cash":2500},
	"reach_level_2":{"title":"Make a Name","description":"Reach account level 2.","goal":2,"progress":1,"completed":false,"reward_xp":40,"reward_cash":2000},
	"build_garage":{"title":"Wheels Up","description":"Build the Garage.","goal":1,"progress":0,"completed":false,"reward_xp":70,"reward_cash":2500},
	"build_intel":{"title":"Eyes Everywhere","description":"Build the Intel Office.","goal":1,"progress":0,"completed":false,"reward_xp":90,"reward_cash":3000},
	"chapter_1_complete":{"title":"A Higher Kingdom","description":"Complete the five Chapter 1 operations.","goal":5,"progress":0,"completed":false,"reward_xp":150,"reward_cash":5000},

	"discover_harbor":{"title":"Open the Harbor","description":"Reveal Harbor District.","goal":1,"progress":0,"completed":false,"reward_xp":55,"reward_cash":2000},
	"win_harbor":{"title":"Break the Serpents","description":"Capture Harbor Bank from the Iron Serpents.","goal":1,"progress":0,"completed":false,"reward_xp":120,"reward_cash":4500},
	"chapter_2_choice":{"title":"Choose the Crew's Method","description":"Choose Force or Intelligence for the next push.","goal":1,"progress":0,"completed":false,"reward_xp":50,"reward_cash":0},
	"discover_midtown":{"title":"Read the Watchers","description":"Reveal Midtown.","goal":1,"progress":0,"completed":false,"reward_xp":70,"reward_cash":2500},
	"win_midtown":{"title":"Blind the Meridian Boys","description":"Capture Midtown Exchange.","goal":1,"progress":0,"completed":false,"reward_xp":150,"reward_cash":6000},
	"chapter_2_complete":{"title":"Enemies Know Your Name","description":"Complete the five Chapter 2 operations.","goal":5,"progress":0,"completed":false,"reward_xp":250,"reward_cash":9000,"reward_gold":10},

	"win_northside":{"title":"Take Northside","description":"Defeat Northside Turf HQ.","goal":1,"progress":0,"completed":false,"reward_xp":140,"reward_cash":5500},
	"win_casino":{"title":"Break the House","description":"Defeat Casino Vault.","goal":1,"progress":0,"completed":false,"reward_xp":180,"reward_cash":7000},
	"win_financial":{"title":"Own the Skyline","description":"Defeat Financial Tower.","goal":1,"progress":0,"completed":false,"reward_xp":220,"reward_cash":9000},
	"win_industrial":{"title":"Control the Supply","description":"Defeat Industrial Depot.","goal":1,"progress":0,"completed":false,"reward_xp":280,"reward_cash":12000}
}


func setup(
	player_progression: PlayerProgression,
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	world: Node,
	control: WorldControlManager,
	recruitment: RecruitmentQueue,
	construction: ConstructionQueue,
	raid_battle: RaidBattle
) -> void:
	progression = player_progression
	economy = player_economy
	loot = loot_inventory
	city_map = world
	world_control = control

	recruitment.recruitment_completed.connect(_on_recruitment_completed)
	construction.construction_completed.connect(_on_construction_completed)
	raid_battle.battle_resolved.connect(_on_battle_resolved)
	progression.leveled_up.connect(_on_level_up)
	if world_control != null:
		world_control.district_discovered.connect(_on_district_discovered)
		world_control.district_captured.connect(_on_district_captured)

	_refresh_level_mission()
	_refresh_existing_buildings()
	_refresh_existing_world_state()
	_refresh_chapter_progress()


func _refresh_existing_buildings() -> void:
	if city_map == null:
		return
	if city_map.lot_a.is_built:
		_set_progress("build_garage", 1)
	if city_map.lot_b.is_built:
		_set_progress("build_intel", 1)


func _refresh_existing_world_state() -> void:
	if world_control == null:
		return
	if world_control.is_discovered("harbor_bank"):
		_set_progress("discover_harbor", 1)
	if world_control.is_owned("harbor_bank"):
		_set_progress("win_harbor", 1)
	if world_control.is_discovered("midtown_exchange"):
		_set_progress("discover_midtown", 1)
	if world_control.is_owned("midtown_exchange"):
		_set_progress("win_midtown", 1)


func _on_district_discovered(district_id: String) -> void:
	match district_id:
		"harbor_bank":
			_set_progress("discover_harbor", 1)
		"midtown_exchange":
			_set_progress("discover_midtown", 1)


func _on_district_captured(district_id: String) -> void:
	match district_id:
		"harbor_bank":
			_set_progress("win_harbor", 1)
		"midtown_exchange":
			_set_progress("win_midtown", 1)


func choose_chapter_2_approach(choice_id: String) -> bool:
	if bool(missions["chapter_2_choice"]["completed"]):
		return false
	if not bool(missions["win_harbor"]["completed"]):
		return false
	if choice_id != "force" and choice_id != "intel":
		return false

	chapter_2_choice = choice_id
	if choice_id == "force":
		_apply_bonus_reward({"cash":2500,"loot":{"Parts":2}})
	else:
		_apply_bonus_reward({"gold":3,"loot":{"Intel":2}})

	_set_progress("chapter_2_choice", 1)
	strategic_choice_made.emit(choice_id)
	return true


func get_chapter_2_choice() -> String:
	return chapter_2_choice


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
		"harbor_bank":
			_set_progress("win_harbor", 1)
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
		progression.add_xp(int(mission.get("reward_xp", 0)))
	if economy != null:
		economy.add_cash(int(mission.get("reward_cash", 0)))
		economy.add_gold(int(mission.get("reward_gold", 0)))

	mission_completed.emit(mission_id)
	if mission_id != "chapter_1_complete" and mission_id != "chapter_2_complete":
		_refresh_chapter_progress()
	changed.emit()


func _refresh_chapter_progress() -> void:
	var chapter_1_count := _count_completed(CHAPTER_1_TASKS)
	_award_chapter_milestones(chapter_1_count)
	_set_progress("chapter_1_complete", chapter_1_count)

	var chapter_2_count := _count_completed(CHAPTER_2_TASKS)
	_set_progress("chapter_2_complete", chapter_2_count)


func _count_completed(task_ids: Array) -> int:
	var count := 0
	for mission_id in task_ids:
		if missions.has(mission_id) and bool(missions[mission_id]["completed"]):
			count += 1
	return count


func _award_chapter_milestones(completed_count: int) -> void:
	if completed_count >= 2 and not bool(chapter_milestones_claimed["2"]):
		chapter_milestones_claimed["2"] = true
		var reward_2 := {"cash":2000,"gold":3,"xp":35,"loot":{"Parts":1}}
		_apply_bonus_reward(reward_2)
		chapter_milestone_reached.emit(2, reward_2)

	if completed_count >= 4 and not bool(chapter_milestones_claimed["4"]):
		chapter_milestones_claimed["4"] = true
		var reward_4 := {"cash":3500,"gold":5,"xp":60,"loot":{"Intel":1}}
		_apply_bonus_reward(reward_4)
		chapter_milestone_reached.emit(4, reward_4)


func _apply_bonus_reward(reward: Dictionary) -> void:
	if economy != null:
		economy.add_cash(int(reward.get("cash", 0)))
		economy.add_gold(int(reward.get("gold", 0)))
	if progression != null:
		progression.add_xp(int(reward.get("xp", 0)))
	if loot != null:
		var reward_loot = reward.get("loot", {})
		if reward_loot is Dictionary:
			loot.add_loot(reward_loot)


func get_story_chapter_status() -> Dictionary:
	if bool(missions["chapter_1_complete"]["completed"]):
		return _build_chapter_status(2, "The City Pushes Back", CHAPTER_2_TASKS, "chapter_2_complete", "$9,000 + 10 Gold + 250 XP")
	return _build_chapter_status(1, "A Higher Kingdom", CHAPTER_1_TASKS, "chapter_1_complete", "$5,000 + 150 XP")


func _build_chapter_status(chapter: int, title: String, task_ids: Array, completion_id: String, completion_reward: String) -> Dictionary:
	var completed_count := 0
	var next_id := ""
	var next_title := "Chapter complete"
	var next_description := "The chapter is complete."

	for mission_id in task_ids:
		var mission: Dictionary = missions[mission_id]
		if bool(mission["completed"]):
			completed_count += 1
		elif next_id.is_empty():
			next_id = mission_id
			next_title = String(mission["title"])
			next_description = String(mission["description"])

	var beat_key := completion_id if next_id.is_empty() else next_id
	var beat: Dictionary = STORY_BEATS.get(beat_key, STORY_BEATS["chapter_1_complete"])

	return {
		"title": title,
		"chapter": chapter,
		"progress": completed_count,
		"goal": task_ids.size(),
		"complete": bool(missions[completion_id]["completed"]),
		"next_id": next_id,
		"next_title": next_title,
		"next_description": next_description,
		"speaker": String(beat["speaker"]),
		"portrait": String(beat["portrait"]),
		"story_line": String(beat["line"]),
		"milestone_2_claimed": bool(chapter_milestones_claimed["2"]),
		"milestone_4_claimed": bool(chapter_milestones_claimed["4"]),
		"choice_required": chapter == 2 and next_id == "chapter_2_choice",
		"choice": chapter_2_choice,
		"completion_reward": completion_reward
	}


func get_mission_lines() -> PackedStringArray:
	var active_tasks: Array = CHAPTER_2_TASKS if bool(missions["chapter_1_complete"]["completed"]) else CHAPTER_1_TASKS
	var lines := PackedStringArray()
	for mission_id in active_tasks:
		var mission: Dictionary = missions[mission_id]
		var state := "DONE" if bool(mission["completed"]) else "%d/%d" % [int(mission["progress"]), int(mission["goal"])]
		lines.append("%s — %s" % [String(mission["title"]), state])
	return lines


func get_save_data() -> Dictionary:
	var saved := {
		"_chapter_meta": {
			"milestones_claimed": chapter_milestones_claimed.duplicate(true),
			"chapter_2_choice": chapter_2_choice
		}
	}
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

	var meta = data.get("_chapter_meta", {})
	if meta is Dictionary:
		var claimed = meta.get("milestones_claimed", {})
		if claimed is Dictionary:
			for milestone in chapter_milestones_claimed.keys():
				chapter_milestones_claimed[milestone] = bool(claimed.get(milestone, chapter_milestones_claimed[milestone]))
		chapter_2_choice = String(meta.get("chapter_2_choice", chapter_2_choice))

	changed.emit()
