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

const CHAPTER_3_TASKS := [
	"reach_level_4",
	"discover_northside",
	"chapter_3_choice",
	"win_northside",
	"join_faction"
]

const CHAPTER_4_TASKS := [
	"reach_level_5",
	"discover_casino",
	"chapter_4_choice",
	"build_data_hub",
	"win_casino"
]

const CHAPTER_5_TASKS := [
	"reach_level_6",
	"discover_financial",
	"chapter_5_choice",
	"capture_faction_objective",
	"win_financial"
]

const CHAPTER_6_TASKS := [
	"reach_level_7",
	"discover_industrial",
	"chapter_6_choice",
	"clear_serpent_convoys",
	"win_industrial"
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
	"chapter_2_complete": {"speaker":"Mia","portrait":"mia","line":"Harbor and Midtown both folded. That is not luck anymore. That is a pattern with our name on it."},
	"reach_level_4": {"speaker":"Noah","portrait":"noah","line":"Northside does not respect ambition. It respects proof. Build enough weight that Knox cannot dismiss us as another lucky crew."},
	"discover_northside": {"speaker":"Kira","portrait":"kira","line":"Darius Knox runs Northside like a checkpoint. I want his routes, watchers, and fallback rooms before we touch the first door."},
	"chapter_3_choice": {"speaker":"Vex","portrait":"vex","line":"Knox expects fear. We can answer with pressure or patience. Choose how this Family wants to be remembered."},
	"win_northside": {"speaker":"Mia","portrait":"mia","line":"Northside is ready. Knox wants a straight fight because he thinks that is where he wins. Make him regret choosing the ground."},
	"join_faction": {"speaker":"Vex","portrait":"vex","line":"One Family can own blocks. Factions decide who owns the city. Find allies now, while everyone knows our name."},
	"chapter_3_complete": {"speaker":"Noah","portrait":"noah","line":"Northside fell and we are no longer operating alone. The city has stopped asking whether we belong. Now it asks how far we go."},
	"reach_level_5": {"speaker":"Vex","portrait":"vex","line":"Northside gave us muscle. The Velvet Circle deals in access, money, and secrets. We need enough weight to enter their rooms without asking permission."},
	"discover_casino": {"speaker":"Celeste Marrow","portrait":"celeste","line":"Everyone has a price. In my city, I decide what it is."},
	"chapter_4_choice": {"speaker":"Vex","portrait":"vex","line":"Celeste built a kingdom out of favors. We can buy our way inside or learn which secrets make the doors open for free."},
	"build_data_hub": {"speaker":"Kira","portrait":"kira","line":"Give me a Data Hub and the Velvet Circle stops being mysterious. Every guest list, payment trail, and private room becomes a map."},
	"win_casino": {"speaker":"Mia","portrait":"mia","line":"The house only wins while everyone agrees to play by its rules. Tonight we rewrite them."},
	"chapter_4_complete": {"speaker":"Vex","portrait":"vex","line":"The Velvet Circle controlled the room. Now the room waits for us to speak."},
	"reach_level_6": {"speaker":"Noah","portrait":"noah","line":"The Financial District is not defended by muscle. It is defended by contracts, favors, and people who never touch the dirt. We need enough weight to make those protections nervous."},
	"discover_financial": {"speaker":"Celeste Marrow","portrait":"celeste","line":"The casino was a room. The Financial District is the house. You are still playing my game."},
	"chapter_5_choice": {"speaker":"Vex","portrait":"vex","line":"We can hit their balance sheets in public or cut their confidence in private. Pick the pressure that makes the whole district move."},
	"capture_faction_objective": {"speaker":"Noah","portrait":"noah","line":"Before we touch the Tower, prove our Faction can hold something together. Shared ground means shared leverage."},
	"win_financial": {"speaker":"Kira","portrait":"kira","line":"The Tower is isolated. Accounts are frozen, exits are mapped, and their security teams are watching the wrong floors."},
	"chapter_5_complete": {"speaker":"Mia","portrait":"mia","line":"We did not just take a building. We took the place where everyone kept score."},
	"reach_level_7": {"speaker":"Mia","portrait":"driver","line":"The Industrial Belt runs on trucks, fuel, and fear. Viktor Sable built the Iron Serpents around movement. We beat him by owning the road."},
	"discover_industrial": {"speaker":"Kira","portrait":"kira","line":"The Depot is only the center. The real system is the convoy network around it. Reveal every route before we commit."},
	"chapter_6_choice": {"speaker":"Vex","portrait":"vex","line":"We can choke their supply lines or hijack them and turn their own network into ours. Either way, the Serpents stop moving on their terms."},
	"clear_serpent_convoys": {"speaker":"Mia","portrait":"driver","line":"Two convoy wins. No shortcuts. Make their drivers second-guess every route into the Belt."},
	"win_industrial": {"speaker":"Viktor Sable","portrait":"driver","line":"Roads belong to whoever can keep them. Come prove you can."},
	"chapter_6_complete": {"speaker":"Vex","portrait":"vex","line":"The Serpents lost the roads, the Depot, and the myth that nobody could stop them. Supply now answers to us."}
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
var faction: FactionManager

var chapter_milestones_claimed := {"2": false, "4": false}
var chapter_2_choice := ""
var chapter_3_choice := ""
var chapter_4_choice := ""
var chapter_5_choice := ""
var chapter_6_choice := ""

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

	"reach_level_4":{"title":"Carry Real Weight","description":"Reach account level 4.","goal":4,"progress":1,"completed":false,"reward_xp":80,"reward_cash":3000},
	"discover_northside":{"title":"Map Knox's Ground","description":"Reveal Northside.","goal":1,"progress":0,"completed":false,"reward_xp":90,"reward_cash":3500},
	"chapter_3_choice":{"title":"Set the Northside Doctrine","description":"Choose Pressure or Patience for the Northside push.","goal":1,"progress":0,"completed":false,"reward_xp":70,"reward_cash":0},
	"win_northside":{"title":"Break the General","description":"Capture Northside Turf HQ from Darius Knox.","goal":1,"progress":0,"completed":false,"reward_xp":180,"reward_cash":7000},
	"join_faction":{"title":"Find Bigger Allies","description":"Create or join a player Faction.","goal":1,"progress":0,"completed":false,"reward_xp":120,"reward_cash":4000,"reward_gold":5},
	"chapter_3_complete":{"title":"No Longer Small","description":"Complete the five Chapter 3 operations.","goal":5,"progress":0,"completed":false,"reward_xp":350,"reward_cash":12000,"reward_gold":15},

	"reach_level_5":{"title":"Enter the High Rooms","description":"Reach account level 5.","goal":5,"progress":1,"completed":false,"reward_xp":100,"reward_cash":4000},
	"discover_casino":{"title":"Find the Velvet Door","description":"Reveal Casino Vault.","goal":1,"progress":0,"completed":false,"reward_xp":110,"reward_cash":4500},
	"chapter_4_choice":{"title":"Choose Your Leverage","description":"Choose Buy In or Blackmail against the Velvet Circle.","goal":1,"progress":0,"completed":false,"reward_xp":90,"reward_cash":0},
	"build_data_hub":{"title":"Own the Guest List","description":"Build the Data Hub.","goal":1,"progress":0,"completed":false,"reward_xp":130,"reward_cash":5000},
	"win_casino":{"title":"Break the House","description":"Capture Casino Vault from Celeste Marrow.","goal":1,"progress":0,"completed":false,"reward_xp":220,"reward_cash":9000},
	"chapter_4_complete":{"title":"The Velvet Circle","description":"Complete the five Chapter 4 operations.","goal":5,"progress":0,"completed":false,"reward_xp":450,"reward_cash":16000,"reward_gold":20},

	"reach_level_6":{"title":"Carry City Weight","description":"Reach account level 6.","goal":6,"progress":1,"completed":false,"reward_xp":120,"reward_cash":5000},
	"discover_financial":{"title":"See the Money Move","description":"Reveal Financial District.","goal":1,"progress":0,"completed":false,"reward_xp":130,"reward_cash":5500},
	"chapter_5_choice":{"title":"Choose the Pressure","description":"Choose Hostile Takeover or Market Leak.","goal":1,"progress":0,"completed":false,"reward_xp":110,"reward_cash":0},
	"capture_faction_objective":{"title":"Prove Shared Control","description":"Capture a Faction territory objective.","goal":1,"progress":0,"completed":false,"reward_xp":160,"reward_cash":6500,"reward_gold":5},
	"win_financial":{"title":"Own the Skyline","description":"Capture Financial Tower.","goal":1,"progress":0,"completed":false,"reward_xp":280,"reward_cash":12000},
	"chapter_5_complete":{"title":"The Ledger Burns","description":"Complete the five Chapter 5 operations.","goal":5,"progress":0,"completed":false,"reward_xp":550,"reward_cash":22000,"reward_gold":25},

	"reach_level_7":{"title":"Build a War Machine","description":"Reach account level 7.","goal":7,"progress":1,"completed":false,"reward_xp":140,"reward_cash":6000},
	"discover_industrial":{"title":"Map the Supply Lines","description":"Reveal Industrial Belt.","goal":1,"progress":0,"completed":false,"reward_xp":150,"reward_cash":6500},
	"chapter_6_choice":{"title":"Choose the Road War","description":"Choose Blockade or Hijack against the Iron Serpents.","goal":1,"progress":0,"completed":false,"reward_xp":130,"reward_cash":0},
	"clear_serpent_convoys":{"title":"Break the Convoys","description":"Win 2 Iron Serpent convoy ambush encounters.","goal":2,"progress":0,"completed":false,"reward_xp":220,"reward_cash":9000,"reward_gold":5},
	"win_industrial":{"title":"Control the Supply","description":"Capture Industrial Depot from Viktor Sable.","goal":1,"progress":0,"completed":false,"reward_xp":360,"reward_cash":15000},
	"chapter_6_complete":{"title":"Roads of Iron","description":"Complete the five Chapter 6 operations.","goal":5,"progress":0,"completed":false,"reward_xp":700,"reward_cash":30000,"reward_gold":30}
}


func setup(
	player_progression: PlayerProgression,
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	world: Node,
	control: WorldControlManager,
	faction_manager: FactionManager,
	recruitment: RecruitmentQueue,
	construction: ConstructionQueue,
	raid_battle: RaidBattle
) -> void:
	progression = player_progression
	economy = player_economy
	loot = loot_inventory
	city_map = world
	world_control = control
	faction = faction_manager

	recruitment.recruitment_completed.connect(_on_recruitment_completed)
	construction.construction_completed.connect(_on_construction_completed)
	raid_battle.battle_resolved.connect(_on_battle_resolved)
	progression.leveled_up.connect(_on_level_up)
	if world_control != null:
		world_control.district_discovered.connect(_on_district_discovered)
		world_control.district_captured.connect(_on_district_captured)
		world_control.family_encounter_resolved.connect(_on_family_encounter_resolved)
	if faction != null:
		faction.faction_created.connect(_on_faction_joined)
		faction.faction_joined.connect(_on_faction_joined)
		faction.territory_captured.connect(_on_faction_territory_captured)

	_refresh_level_mission()
	_refresh_existing_buildings()
	_refresh_existing_world_state()
	_refresh_faction_state()
	_refresh_chapter_progress()


func _refresh_existing_buildings() -> void:
	if city_map == null:
		return
	if city_map.lot_a.is_built:
		_set_progress("build_garage", 1)
	if city_map.lot_b.is_built:
		_set_progress("build_intel", 1)
	if city_map.lot_d != null and city_map.lot_d.is_built:
		_set_progress("build_data_hub", 1)


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
	if world_control.is_discovered("northside_hq"):
		_set_progress("discover_northside", 1)
	if world_control.is_owned("northside_hq"):
		_set_progress("win_northside", 1)
	if world_control.is_discovered("casino_vault"):
		_set_progress("discover_casino", 1)
	if world_control.is_owned("casino_vault"):
		_set_progress("win_casino", 1)
	if world_control.is_discovered("financial_tower"):
		_set_progress("discover_financial", 1)
	if world_control.is_owned("financial_tower"):
		_set_progress("win_financial", 1)
	if world_control.is_discovered("industrial_depot"):
		_set_progress("discover_industrial", 1)
	if world_control.is_owned("industrial_depot"):
		_set_progress("win_industrial", 1)


func _on_district_discovered(district_id: String) -> void:
	match district_id:
		"harbor_bank":
			_set_progress("discover_harbor", 1)
		"midtown_exchange":
			_set_progress("discover_midtown", 1)
		"northside_hq":
			_set_progress("discover_northside", 1)
		"casino_vault":
			_set_progress("discover_casino", 1)
		"financial_tower":
			_set_progress("discover_financial", 1)
		"industrial_depot":
			_set_progress("discover_industrial", 1)


func _on_district_captured(district_id: String) -> void:
	match district_id:
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


func choose_chapter_3_approach(choice_id: String) -> bool:
	if bool(missions["chapter_3_choice"]["completed"]):
		return false
	if not bool(missions["discover_northside"]["completed"]):
		return false
	if choice_id != "pressure" and choice_id != "patience":
		return false

	chapter_3_choice = choice_id
	if choice_id == "pressure":
		_apply_bonus_reward({"cash":4000,"loot":{"Parts":3}})
	else:
		_apply_bonus_reward({"gold":4,"loot":{"Intel":3}})

	_set_progress("chapter_3_choice", 1)
	strategic_choice_made.emit(choice_id)
	return true


func get_chapter_3_choice() -> String:
	return chapter_3_choice


func choose_chapter_4_approach(choice_id: String) -> bool:
	if bool(missions["chapter_4_choice"]["completed"]):
		return false
	if not bool(missions["discover_casino"]["completed"]):
		return false
	if choice_id != "buy_in" and choice_id != "blackmail":
		return false

	chapter_4_choice = choice_id
	if choice_id == "buy_in":
		_apply_bonus_reward({"cash":6000,"gold":3})
	else:
		_apply_bonus_reward({"gold":5,"loot":{"Intel":4}})

	_set_progress("chapter_4_choice", 1)
	strategic_choice_made.emit(choice_id)
	return true


func get_chapter_4_choice() -> String:
	return chapter_4_choice


func choose_chapter_5_approach(choice_id: String) -> bool:
	if bool(missions["chapter_5_choice"]["completed"]):
		return false
	if not bool(missions["discover_financial"]["completed"]):
		return false
	if choice_id != "takeover" and choice_id != "market_leak":
		return false

	chapter_5_choice = choice_id
	if choice_id == "takeover":
		_apply_bonus_reward({"cash":8000,"loot":{"Parts":4}})
	else:
		_apply_bonus_reward({"gold":6,"loot":{"Intel":5}})

	_set_progress("chapter_5_choice", 1)
	strategic_choice_made.emit(choice_id)
	return true


func get_chapter_5_choice() -> String:
	return chapter_5_choice


func choose_chapter_6_approach(choice_id: String) -> bool:
	if bool(missions["chapter_6_choice"]["completed"]):
		return false
	if not bool(missions["discover_industrial"]["completed"]):
		return false
	if choice_id != "blockade" and choice_id != "hijack":
		return false

	chapter_6_choice = choice_id
	if choice_id == "blockade":
		_apply_bonus_reward({"cash":10000,"loot":{"Parts":5}})
	else:
		_apply_bonus_reward({"gold":8,"loot":{"Intel":3,"Parts":3}})

	_set_progress("chapter_6_choice", 1)
	strategic_choice_made.emit(choice_id)
	return true


func get_chapter_6_choice() -> String:
	return chapter_6_choice


func _refresh_faction_state() -> void:
	if faction == null:
		return
	if faction.has_faction():
		_set_progress("join_faction", 1)
	if faction.get_owned_territory_count() > 0:
		_set_progress("capture_faction_objective", 1)


func _on_faction_joined(_faction_name: String) -> void:
	_set_progress("join_faction", 1)


func _on_faction_territory_captured(_territory_id: String) -> void:
	_set_progress("capture_faction_objective", 1)


func _on_family_encounter_resolved(district_id: String, encounter_type: String, victory: bool) -> void:
	if not victory or encounter_type != "convoy_ambush" or world_control == null:
		return
	if world_control.get_rival_family_id(district_id) != "iron_serpents":
		return
	_add_progress("clear_serpent_convoys", 1)


func _on_recruitment_completed(_troop_type: StringName, amount: int) -> void:
	_add_progress("recruit_crew", amount)


func _on_construction_completed(target: Node) -> void:
	if target is BuildLot:
		var lot := target as BuildLot
		if lot.is_built and lot.building_name == "Garage":
			_set_progress("build_garage", 1)
		elif lot.is_built and lot.building_name == "Intel Office":
			_set_progress("build_intel", 1)
		elif lot.is_built and lot.building_name == "Data Hub":
			_set_progress("build_data_hub", 1)
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
	_set_progress("reach_level_4", mini(progression.account_level, 4))
	_set_progress("reach_level_5", mini(progression.account_level, 5))
	_set_progress("reach_level_6", mini(progression.account_level, 6))
	_set_progress("reach_level_7", mini(progression.account_level, 7))


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
	if mission_id != "chapter_1_complete" and mission_id != "chapter_2_complete" and mission_id != "chapter_3_complete" and mission_id != "chapter_4_complete" and mission_id != "chapter_5_complete" and mission_id != "chapter_6_complete":
		_refresh_chapter_progress()
	changed.emit()


func _refresh_chapter_progress() -> void:
	var chapter_1_count := _count_completed(CHAPTER_1_TASKS)
	_award_chapter_milestones(chapter_1_count)
	_set_progress("chapter_1_complete", chapter_1_count)

	var chapter_2_count := _count_completed(CHAPTER_2_TASKS)
	_set_progress("chapter_2_complete", chapter_2_count)

	var chapter_3_count := _count_completed(CHAPTER_3_TASKS)
	_set_progress("chapter_3_complete", chapter_3_count)

	var chapter_4_count := _count_completed(CHAPTER_4_TASKS)
	_set_progress("chapter_4_complete", chapter_4_count)

	var chapter_5_count := _count_completed(CHAPTER_5_TASKS)
	_set_progress("chapter_5_complete", chapter_5_count)

	var chapter_6_count := _count_completed(CHAPTER_6_TASKS)
	_set_progress("chapter_6_complete", chapter_6_count)


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
	if bool(missions["chapter_5_complete"]["completed"]):
		return _build_chapter_status(6, "Roads of Iron", CHAPTER_6_TASKS, "chapter_6_complete", "$30,000 + 30 Gold + 700 XP")
	if bool(missions["chapter_4_complete"]["completed"]):
		return _build_chapter_status(5, "The Ledger Burns", CHAPTER_5_TASKS, "chapter_5_complete", "$22,000 + 25 Gold + 550 XP")
	if bool(missions["chapter_3_complete"]["completed"]):
		return _build_chapter_status(4, "The Velvet Circle", CHAPTER_4_TASKS, "chapter_4_complete", "$16,000 + 20 Gold + 450 XP")
	if bool(missions["chapter_2_complete"]["completed"]):
		return _build_chapter_status(3, "Blood in Northside", CHAPTER_3_TASKS, "chapter_3_complete", "$12,000 + 15 Gold + 350 XP")
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
		"choice_required": (chapter == 2 and next_id == "chapter_2_choice") or (chapter == 3 and next_id == "chapter_3_choice") or (chapter == 4 and next_id == "chapter_4_choice") or (chapter == 5 and next_id == "chapter_5_choice") or (chapter == 6 and next_id == "chapter_6_choice"),
		"choice": chapter_6_choice if chapter == 6 else (chapter_5_choice if chapter == 5 else (chapter_4_choice if chapter == 4 else (chapter_3_choice if chapter == 3 else chapter_2_choice))),
		"completion_reward": completion_reward
	}


func get_mission_lines() -> PackedStringArray:
	var active_tasks: Array = CHAPTER_1_TASKS
	if bool(missions["chapter_5_complete"]["completed"]):
		active_tasks = CHAPTER_6_TASKS
	elif bool(missions["chapter_4_complete"]["completed"]):
		active_tasks = CHAPTER_5_TASKS
	elif bool(missions["chapter_3_complete"]["completed"]):
		active_tasks = CHAPTER_4_TASKS
	elif bool(missions["chapter_2_complete"]["completed"]):
		active_tasks = CHAPTER_3_TASKS
	elif bool(missions["chapter_1_complete"]["completed"]):
		active_tasks = CHAPTER_2_TASKS
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
			"chapter_2_choice": chapter_2_choice,
			"chapter_3_choice": chapter_3_choice,
			"chapter_4_choice": chapter_4_choice,
			"chapter_5_choice": chapter_5_choice,
			"chapter_6_choice": chapter_6_choice
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
		chapter_3_choice = String(meta.get("chapter_3_choice", chapter_3_choice))
		chapter_4_choice = String(meta.get("chapter_4_choice", chapter_4_choice))
		chapter_5_choice = String(meta.get("chapter_5_choice", chapter_5_choice))
		chapter_6_choice = String(meta.get("chapter_6_choice", chapter_6_choice))

	changed.emit()
