class_name FactionManager
extends Node

signal changed
signal faction_created(faction_name: String)
signal faction_joined(faction_name: String)
signal faction_left
signal faction_leveled_up(new_level: int)
signal research_upgraded(research_id: String, new_level: int)
signal daily_reward_claimed
signal faction_gift_earned
signal rally_started(target_id: String)
signal war_started(opponent_name: String)
signal territory_captured(territory_id: String)
signal member_role_changed(member_id: String, role: String)
signal member_removed(member_id: String)
signal war_completed(won: bool, season_points_awarded: int)

const ROLE_LEADER := "Leader"
const ROLE_UNDERBOSS := "Underboss"
const ROLE_OFFICER := "Officer"
const ROLE_MEMBER := "Member"

const DAILY_REQUIRED := 3
const WAR_DURATION_SECONDS := 24.0 * 60.0 * 60.0
const RALLY_DURATION_SECONDS := 10.0 * 60.0
const MAX_MEMBERS_BASE := 20
const SEASON_WEEKS := 4
const WAR_STRATEGIES := {
	"muscle": {
		"name":"Muscle Push",
		"counter":"watchful",
		"base_multiplier":1.00,
		"counter_bonus":35,
		"mismatch_penalty":8,
		"summary":"Reliable pressure. Best against WATCHFUL defenses."
	},
	"convoy": {
		"name":"Convoy Break",
		"counter":"fortified",
		"base_multiplier":0.96,
		"counter_bonus":45,
		"mismatch_penalty":10,
		"summary":"Route-control strike. Best against FORTIFIED defenses."
	},
	"intel": {
		"name":"Intel Cut",
		"counter":"mobile",
		"base_multiplier":0.92,
		"counter_bonus":55,
		"mismatch_penalty":12,
		"summary":"High-value disruption. Best against MOBILE defenses."
	}
}
const WAR_DEFENSE_CYCLE := ["watchful", "fortified", "mobile"]
const WAR_OBJECTIVE_DEFS := {
	"counter_network": {
		"name":"Counter Network",
		"goal":2,
		"score_bonus":40,
		"summary":"Land 2 correct attack-plan counters."
	},
	"round_control": {
		"name":"Round Control",
		"goal":2,
		"score_bonus":45,
		"summary":"Win 2 of the 3 attack rounds."
	},
	"mobilize": {
		"name":"Mobilize the Faction",
		"goal":300,
		"score_bonus":35,
		"summary":"Generate 300 combined war contribution."
	}
}
const WAR_REWARD_POOLS := {
	"BRONZE":4000,
	"SILVER":8000,
	"GOLD":12000
}
const WAR_DOCTRINES := {
	"disciplined": {
		"name":"Disciplined",
		"attack_multiplier":1.00,
		"counter_bonus_multiplier":1.20,
		"mismatch_multiplier":1.00,
		"incoming_modifier":0,
		"summary":"Stronger counter hits. Best when your officers read the enemy correctly."
	},
	"aggressive": {
		"name":"Aggressive",
		"attack_multiplier":1.08,
		"counter_bonus_multiplier":1.00,
		"mismatch_multiplier":1.00,
		"incoming_modifier":8,
		"summary":"Higher attack score, but the opponent scores harder in return."
	},
	"adaptive": {
		"name":"Adaptive",
		"attack_multiplier":1.00,
		"counter_bonus_multiplier":1.00,
		"mismatch_multiplier":0.45,
		"incoming_modifier":0,
		"summary":"Cuts the penalty for a missed counter. Safer when the read is uncertain."
	}
}
const WAR_DEFENSE_COUNTERS := {
	"watchful":"intel",
	"fortified":"muscle",
	"mobile":"convoy"
}

var economy: PlayerEconomy
var loot: LootInventory

var faction_id := ""
var faction_name := ""
var faction_tag := ""
var faction_level := 1
var faction_xp := 0
var treasury_cash := 0
var local_member_id := "local_player"

var members: Array[Dictionary] = []
var research: Dictionary = {
	"construction_help": 0,
	"raid_coordination": 0,
	"territory_income": 0
}

var daily_period := -1
var daily_claimed := false
var daily_mastery_claimed := false
var daily_tasks: Dictionary = {
	"recruit": {"title":"Build the Ranks","goal":5,"progress":0},
	"raid": {"title":"Win a Family Raid","goal":1,"progress":0},
	"construction": {"title":"Improve the Family","goal":1,"progress":0},
	"donate": {"title":"Back the Faction","goal":5000,"progress":0}
}

var gift_charges := 0
var active_rally: Dictionary = {}
var active_war: Dictionary = {}
var war_preparation: Dictionary = {
	"captain_id":"",
	"defense":"fortified",
	"doctrine":"disciplined"
}

var season_period := -1
var season_points := 0
var season_wins := 0
var _season_check_accumulator := 0.0
var war_reward_claimed := false
var pending_invites: Array[Dictionary] = []

var faction_territory: Dictionary = {
	"dockyard_exchange": {
		"name":"Dockyard Exchange",
		"required_level":2,
		"power":1500,
		"owned":false,
		"season_points":60,
		"treasury_reward":3000
	},
	"midtown_signal": {
		"name":"Midtown Signal Tower",
		"required_level":3,
		"power":2300,
		"owned":false,
		"season_points":90,
		"treasury_reward":5000
	},
	"financial_courthouse": {
		"name":"Financial Courthouse",
		"required_level":4,
		"power":3400,
		"owned":false,
		"season_points":140,
		"treasury_reward":8000
	}
}


func setup(
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	recruitment: RecruitmentQueue,
	construction: ConstructionQueue,
	raid_battle: RaidBattle
) -> void:
	economy = player_economy
	loot = loot_inventory
	recruitment.recruitment_completed.connect(_on_recruitment_completed)
	construction.construction_completed.connect(_on_construction_completed)
	raid_battle.battle_resolved.connect(_on_battle_resolved)
	_refresh_daily_period()
	_refresh_season_period()
	changed.emit()


func _process(delta: float) -> void:
	var did_change := false
	_season_check_accumulator += delta
	if _season_check_accumulator >= 30.0:
		_season_check_accumulator = 0.0
		_refresh_season_period()
	if not active_rally.is_empty():
		active_rally["seconds_remaining"] = maxf(0.0, float(active_rally.get("seconds_remaining", 0.0)) - delta)
		if float(active_rally["seconds_remaining"]) <= 0.0:
			active_rally.clear()
			did_change = true

	if not active_war.is_empty() and String(active_war.get("status", "active")) == "active":
		active_war["seconds_remaining"] = maxf(0.0, float(active_war.get("seconds_remaining", 0.0)) - delta)
		if float(active_war["seconds_remaining"]) <= 0.0:
			_complete_war()
			did_change = true

	if did_change:
		changed.emit()


func has_faction() -> bool:
	return not faction_id.is_empty()


func create_faction(name: String, tag: String) -> bool:
	if has_faction():
		return false

	var clean_name := name.strip_edges().left(24)
	var clean_tag := tag.strip_edges().to_upper().left(4)
	if clean_name.length() < 3 or clean_tag.length() < 2:
		return false

	faction_id = "local_%s" % clean_tag.to_lower()
	faction_name = clean_name
	faction_tag = clean_tag
	faction_level = 1
	faction_xp = 0
	treasury_cash = 0
	members = [{
		"id": local_member_id,
		"name": "You",
		"role": ROLE_LEADER,
		"power": 0,
		"contribution": 0,
		"online": true
	}]
	_reset_faction_activity()
	changed.emit()
	faction_created.emit(faction_name)
	return true


func join_prototype_faction() -> bool:
	if has_faction():
		return false

	faction_id = "prototype_black_crown"
	faction_name = "Black Crown"
	faction_tag = "CROWN"
	faction_level = 3
	faction_xp = 120
	treasury_cash = 18000
	members = [
		{"id":"player_ace","name":"Ace","role":ROLE_LEADER,"power":12800,"contribution":420,"online":true},
		{"id":"player_nova","name":"Nova","role":ROLE_OFFICER,"power":9100,"contribution":310,"online":true},
		{"id":"player_ghost","name":"Ghost","role":ROLE_MEMBER,"power":7600,"contribution":190,"online":false},
		{"id":local_member_id,"name":"You","role":ROLE_UNDERBOSS,"power":0,"contribution":0,"online":true}
	]
	_reset_faction_activity()
	changed.emit()
	faction_joined.emit(faction_name)
	return true


func leave_faction() -> bool:
	if not has_faction():
		return false
	if get_local_role() == ROLE_LEADER and members.size() > 1:
		return false

	faction_id = ""
	faction_name = ""
	faction_tag = ""
	faction_level = 1
	faction_xp = 0
	treasury_cash = 0
	members.clear()
	research = {
		"construction_help": 0,
		"raid_coordination": 0,
		"territory_income": 0
	}
	_reset_faction_activity()
	changed.emit()
	faction_left.emit()
	return true


func _reset_faction_activity() -> void:
	daily_period = _get_day_index()
	daily_claimed = false
	daily_mastery_claimed = false
	for task_id in daily_tasks.keys():
		daily_tasks[task_id]["progress"] = 0
	gift_charges = 0
	active_rally.clear()
	active_war.clear()
	pending_invites.clear()
	season_points = 0
	season_wins = 0
	war_reward_claimed = false
	for territory_id in faction_territory.keys():
		faction_territory[territory_id]["owned"] = false


func _get_season_index() -> int:
	var day := floori(Time.get_unix_time_from_system() / 86400.0)
	var week := floori(float(day) / 7.0)
	return floori(float(week) / float(SEASON_WEEKS))


func _refresh_season_period() -> void:
	var current := _get_season_index()
	if season_period < 0:
		season_period = current
		return
	if season_period == current:
		return

	season_period = current
	season_points = 0
	season_wins = 0
	war_reward_claimed = false
	for territory_id in faction_territory.keys():
		faction_territory[territory_id]["owned"] = false
	changed.emit()


func get_local_role() -> String:
	for member in members:
		if String(member.get("id", "")) == local_member_id:
			return String(member.get("role", ROLE_MEMBER))
	return ""


func can_manage_members() -> bool:
	return get_local_role() in [ROLE_LEADER, ROLE_UNDERBOSS]


func can_manage_research() -> bool:
	return get_local_role() in [ROLE_LEADER, ROLE_UNDERBOSS, ROLE_OFFICER]


func can_start_rally() -> bool:
	return has_faction() and get_local_role() in [ROLE_LEADER, ROLE_UNDERBOSS, ROLE_OFFICER]


func can_start_war() -> bool:
	return has_faction() and get_local_role() in [ROLE_LEADER, ROLE_UNDERBOSS]


func _find_member(member_id: String) -> Dictionary:
	for member in members:
		if String(member.get("id", "")) == member_id:
			return member
	return {}


func _ensure_war_preparation() -> void:
	if not WAR_DOCTRINES.has(String(war_preparation.get("doctrine", ""))):
		war_preparation["doctrine"] = "disciplined"
	if String(war_preparation.get("defense", "")) not in WAR_DEFENSE_CYCLE:
		war_preparation["defense"] = "fortified"
	var captain_id := String(war_preparation.get("captain_id", ""))
	if captain_id.is_empty() or _find_member(captain_id).is_empty():
		war_preparation["captain_id"] = local_member_id if not _find_member(local_member_id).is_empty() else (String(members[0].get("id", "")) if not members.is_empty() else "")


func cycle_war_captain() -> bool:
	if not has_faction() or members.is_empty() or not active_war.is_empty():
		return false
	_ensure_war_preparation()
	var current := String(war_preparation.get("captain_id", ""))
	var current_index := -1
	for i in range(members.size()):
		if String(members[i].get("id", "")) == current:
			current_index = i
			break
	war_preparation["captain_id"] = String(members[(current_index + 1) % members.size()].get("id", ""))
	changed.emit()
	return true


func cycle_war_defense() -> bool:
	if not has_faction() or not active_war.is_empty():
		return false
	_ensure_war_preparation()
	var current := String(war_preparation.get("defense", "fortified"))
	var index := WAR_DEFENSE_CYCLE.find(current)
	war_preparation["defense"] = String(WAR_DEFENSE_CYCLE[(maxi(0, index) + 1) % WAR_DEFENSE_CYCLE.size()])
	changed.emit()
	return true


func cycle_war_doctrine() -> bool:
	if not has_faction() or not active_war.is_empty():
		return false
	_ensure_war_preparation()
	var ids := ["disciplined", "aggressive", "adaptive"]
	var current := String(war_preparation.get("doctrine", "disciplined"))
	var index := ids.find(current)
	war_preparation["doctrine"] = ids[(maxi(0, index) + 1) % ids.size()]
	changed.emit()
	return true


func get_war_captain_bonus(captain_id: String = "") -> int:
	var id := captain_id if not captain_id.is_empty() else String(war_preparation.get("captain_id", ""))
	var captain := _find_member(id)
	if captain.is_empty():
		return 0
	var power_bonus := mini(12, maxi(0, int(captain.get("power", 0))) / 2000)
	var contribution_bonus := mini(8, maxi(0, int(captain.get("contribution", 0))) / 75)
	var online_bonus := 4 if bool(captain.get("online", false)) else 0
	return power_bonus + contribution_bonus + online_bonus


func get_war_readiness_score() -> int:
	_ensure_war_preparation()
	var score := 50
	score += mini(15, int(research.get("raid_coordination", 0)) * 3)
	score += mini(10, get_owned_territory_count() * 4)
	score += mini(25, get_war_captain_bonus())
	return clampi(score, 0, 100)


func get_war_preparation_summary() -> String:
	_ensure_war_preparation()
	var captain := _find_member(String(war_preparation.get("captain_id", "")))
	var captain_name := String(captain.get("name", "Unassigned"))
	var doctrine_id := String(war_preparation.get("doctrine", "disciplined"))
	var doctrine: Dictionary = WAR_DOCTRINES.get(doctrine_id, WAR_DOCTRINES["disciplined"])
	return "READINESS %d/100 • Captain %s (+%d) • %s doctrine • %s defense" % [
		get_war_readiness_score(),
		captain_name,
		get_war_captain_bonus(),
		String(doctrine.get("name", doctrine_id)).to_upper(),
		String(war_preparation.get("defense", "fortified")).to_upper()
	]


func get_war_doctrine_summary() -> String:
	_ensure_war_preparation()
	var doctrine_id := String(war_preparation.get("doctrine", "disciplined"))
	var doctrine: Dictionary = WAR_DOCTRINES.get(doctrine_id, WAR_DOCTRINES["disciplined"])
	return "%s — %s" % [String(doctrine.get("name", doctrine_id)), String(doctrine.get("summary", ""))]


func get_permissions_summary() -> String:
	var role := get_local_role()
	if role == ROLE_LEADER:
		return "Leader — manage members, research, rallies, wars, ranks, and Faction direction."
	if role == ROLE_UNDERBOSS:
		return "Underboss — manage members, research, rallies, and Faction wars."
	if role == ROLE_OFFICER:
		return "Officer — manage research and start rallies."
	return "Member — contribute, join rallies, earn gifts, and fight in wars."


func get_member_limit() -> int:
	return MAX_MEMBERS_BASE + maxi(0, faction_level - 1) * 2


func invite_prototype_member() -> bool:
	if not has_faction() or not can_manage_members() or members.size() + pending_invites.size() >= get_member_limit():
		return false
	var invite_id := "invite_%d" % (pending_invites.size() + 1)
	pending_invites.append({
		"id": invite_id,
		"name": "Prospect %d" % (pending_invites.size() + 1),
		"power": 5000 + pending_invites.size() * 700
	})
	changed.emit()
	return true


func accept_next_prototype_invite() -> bool:
	if pending_invites.is_empty() or members.size() >= get_member_limit():
		return false
	var invite: Dictionary = pending_invites.pop_front()
	members.append({
		"id": String(invite["id"]),
		"name": String(invite["name"]),
		"role": ROLE_MEMBER,
		"power": int(invite["power"]),
		"contribution": 0,
		"online": true
	})
	changed.emit()
	return true


func promote_prototype_member() -> bool:
	if not can_manage_members():
		return false
	for member in members:
		var member_id := String(member.get("id", ""))
		if member_id == local_member_id or String(member.get("role", "")) != ROLE_MEMBER:
			continue
		member["role"] = ROLE_OFFICER
		member_role_changed.emit(member_id, ROLE_OFFICER)
		changed.emit()
		return true
	return false


func remove_prototype_member() -> bool:
	if not can_manage_members():
		return false
	for i in range(members.size() - 1, -1, -1):
		var member: Dictionary = members[i]
		var member_id := String(member.get("id", ""))
		if member_id == local_member_id or String(member.get("role", "")) == ROLE_LEADER:
			continue
		members.remove_at(i)
		member_removed.emit(member_id)
		changed.emit()
		return true
	return false


func get_xp_for_next_level() -> int:
	return 200 + (faction_level - 1) * 150


func award_faction_xp(amount: int) -> void:
	if not has_faction() or amount <= 0:
		return
	faction_xp += amount
	while faction_xp >= get_xp_for_next_level():
		faction_xp -= get_xp_for_next_level()
		faction_level += 1
		gift_charges += 1
		faction_gift_earned.emit()
		faction_leveled_up.emit(faction_level)
	changed.emit()


func _add_local_contribution(points: int) -> void:
	if points <= 0:
		return
	for member in members:
		if String(member.get("id", "")) == local_member_id:
			member["contribution"] = int(member.get("contribution", 0)) + points
			return


func donate_cash(amount: int, player_economy: PlayerEconomy = null) -> bool:
	var wallet := player_economy if player_economy != null else economy
	if not has_faction() or wallet == null or amount <= 0 or wallet.cash < amount:
		return false
	if not wallet.spend_cash(amount):
		return false

	treasury_cash += amount
	var contribution_points := maxi(1, amount / 500)
	_add_local_contribution(contribution_points)
	_add_daily_progress("donate", amount)
	award_faction_xp(contribution_points)
	changed.emit()
	return true


func get_research_cost(research_id: String) -> int:
	var level := int(research.get(research_id, -1))
	if level < 0 or level >= 5:
		return 0
	return 5000 + level * 5000


func can_upgrade_research(research_id: String) -> bool:
	var cost := get_research_cost(research_id)
	return has_faction() and cost > 0 and treasury_cash >= cost and can_manage_research()


func upgrade_research(research_id: String) -> bool:
	if not can_upgrade_research(research_id):
		return false
	var cost := get_research_cost(research_id)
	treasury_cash -= cost
	research[research_id] = int(research[research_id]) + 1
	research_upgraded.emit(research_id, int(research[research_id]))
	changed.emit()
	return true


func get_construction_time_multiplier() -> float:
	return maxf(0.85, 1.0 - float(research["construction_help"]) * 0.03)


func get_rally_power_multiplier() -> float:
	return 1.0 + float(research["raid_coordination"]) * 0.02


func get_territory_income_multiplier() -> float:
	return 1.0 + float(research["territory_income"]) * 0.02


func get_research_summary() -> PackedStringArray:
	return PackedStringArray([
		"Construction Help Lv.%d — Family construction time -%d%%" % [int(research["construction_help"]), int(research["construction_help"]) * 3],
		"Raid Coordination Lv.%d — Faction rally power +%d%%" % [int(research["raid_coordination"]), int(research["raid_coordination"]) * 2],
		"Territory Income Lv.%d — owned-district income +%d%%" % [int(research["territory_income"]), int(research["territory_income"]) * 2]
	])


func _get_day_index() -> int:
	return floori(Time.get_unix_time_from_system() / 86400.0)


func _refresh_daily_period() -> void:
	var today := _get_day_index()
	if daily_period == today:
		return
	daily_period = today
	daily_claimed = false
	daily_mastery_claimed = false
	for task_id in daily_tasks.keys():
		daily_tasks[task_id]["progress"] = 0


func _add_daily_progress(task_id: String, amount: int) -> void:
	if not has_faction() or not daily_tasks.has(task_id):
		return
	_refresh_daily_period()
	var task: Dictionary = daily_tasks[task_id]
	task["progress"] = mini(int(task["goal"]), int(task["progress"]) + maxi(0, amount))
	changed.emit()


func _daily_completed_count() -> int:
	var completed := 0
	for task_id in daily_tasks.keys():
		var task: Dictionary = daily_tasks[task_id]
		if int(task["progress"]) >= int(task["goal"]):
			completed += 1
	return completed


func get_daily_status() -> Dictionary:
	_refresh_daily_period()
	return {
		"completed": _daily_completed_count(),
		"required": DAILY_REQUIRED,
		"total": daily_tasks.size(),
		"claimable": _daily_completed_count() >= DAILY_REQUIRED and not daily_claimed,
		"mastery_claimable": _daily_completed_count() >= daily_tasks.size() and not daily_mastery_claimed,
		"claimed": daily_claimed,
		"mastery_claimed": daily_mastery_claimed
	}


func get_daily_lines() -> PackedStringArray:
	_refresh_daily_period()
	var lines := PackedStringArray()
	for task_id in ["recruit", "raid", "construction", "donate"]:
		var task: Dictionary = daily_tasks[task_id]
		lines.append("%s — %d/%d%s" % [
			String(task["title"]),
			int(task["progress"]),
			int(task["goal"]),
			" ✓" if int(task["progress"]) >= int(task["goal"]) else ""
		])
	return lines


func claim_daily_reward() -> bool:
	if not has_faction():
		return false
	var status := get_daily_status()
	if not bool(status["claimable"]):
		return false

	daily_claimed = true
	_add_local_contribution(25)
	award_faction_xp(35)
	gift_charges += 1
	if economy != null:
		economy.add_cash(2500)
	if loot != null:
		loot.add_item("Parts", 1)
	daily_reward_claimed.emit()
	faction_gift_earned.emit()
	changed.emit()
	return true


func claim_daily_mastery() -> bool:
	if not has_faction():
		return false
	var status := get_daily_status()
	if not bool(status["mastery_claimable"]):
		return false

	daily_mastery_claimed = true
	_add_local_contribution(15)
	award_faction_xp(20)
	if economy != null:
		economy.add_gold(2)
	if loot != null:
		loot.add_item("Intel", 1)
	changed.emit()
	return true


func claim_gift_chest() -> bool:
	if not has_faction() or gift_charges <= 0 or economy == null or loot == null:
		return false
	gift_charges -= 1
	economy.add_cash(1500 + faction_level * 250)
	economy.add_gold(1)
	loot.add_item("Parts", 1)
	changed.emit()
	return true


func start_rally(target_id: String, target_name: String) -> bool:
	if not can_start_rally() or target_id.is_empty() or not active_rally.is_empty():
		return false
	active_rally = {
		"target_id": target_id,
		"target_name": target_name,
		"seconds_remaining": RALLY_DURATION_SECONDS,
		"capacity": 5 + int(research["raid_coordination"]),
		"joined": [local_member_id],
		"power_multiplier": get_rally_power_multiplier()
	}
	rally_started.emit(target_id)
	changed.emit()
	return true


func clear_rally() -> void:
	if active_rally.is_empty():
		return
	active_rally.clear()
	changed.emit()


func get_rally_summary() -> String:
	if active_rally.is_empty():
		return "No active Faction rally."
	return "%s • %d/%d joined • +%d%% coordination • %s remaining" % [
		String(active_rally.get("target_name", "Target")),
		(active_rally.get("joined", []) as Array).size(),
		int(active_rally.get("capacity", 5)),
		roundi((float(active_rally.get("power_multiplier", 1.0)) - 1.0) * 100.0),
		_format_time(float(active_rally.get("seconds_remaining", 0.0)))
	]


func get_total_member_power() -> int:
	var total := 0
	for member in members:
		total += maxi(0, int(member.get("power", 0)))
	return total


func get_next_territory_id() -> String:
	for territory_id in ["dockyard_exchange", "midtown_signal", "financial_courthouse"]:
		var territory: Dictionary = faction_territory[territory_id]
		if not bool(territory["owned"]) and faction_level >= int(territory["required_level"]):
			return territory_id
	return ""


func can_capture_next_territory() -> bool:
	var territory_id := get_next_territory_id()
	if territory_id.is_empty() or not can_start_rally():
		return false
	var territory: Dictionary = faction_territory[territory_id]
	return get_total_member_power() * get_rally_power_multiplier() >= float(territory["power"])


func capture_next_territory() -> bool:
	var territory_id := get_next_territory_id()
	if territory_id.is_empty() or not can_capture_next_territory():
		return false

	var territory: Dictionary = faction_territory[territory_id]
	territory["owned"] = true
	season_points += int(territory["season_points"])
	treasury_cash += int(territory["treasury_reward"])
	award_faction_xp(30)
	gift_charges += 1
	faction_gift_earned.emit()
	territory_captured.emit(territory_id)
	changed.emit()
	return true


func get_territory_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for territory_id in ["dockyard_exchange", "midtown_signal", "financial_courthouse"]:
		var territory: Dictionary = faction_territory[territory_id]
		var state := "OWNED" if bool(territory["owned"]) else ("LOCKED" if faction_level < int(territory["required_level"]) else "TARGET")
		lines.append("%s — %s — Power %s — +%d season pts" % [
			String(territory["name"]),
			state,
			_format_number(int(territory["power"])),
			int(territory["season_points"])
		])
	return lines


func get_owned_territory_count() -> int:
	var count := 0
	for territory_id in faction_territory.keys():
		if bool(faction_territory[territory_id]["owned"]):
			count += 1
	return count


func get_territory_cash_multiplier() -> float:
	return 1.0 + float(get_owned_territory_count()) * 0.03


func get_matchmaking_candidates() -> Array[Dictionary]:
	if not has_faction():
		return []
	var rating := get_matchmaking_rating()
	return [
		{"id":"prototype_red_hands","name":"Red Hands","rating":rating - 35,"members":18},
		{"id":"prototype_night_union","name":"Night Union","rating":rating + 10,"members":21},
		{"id":"prototype_royal_five","name":"Royal Five","rating":rating + 55,"members":17}
	]


func get_matchmaking_rating() -> int:
	return faction_level * 250 + get_total_member_power() / 100 + season_points


func get_rankings() -> Array[Dictionary]:
	if not has_faction():
		return []
	var ours := {"name":faction_name,"tag":faction_tag,"points":season_points}
	var rows: Array[Dictionary] = [
		{"name":"Night Union","tag":"NITE","points":maxi(40, season_points + 90)},
		{"name":"Red Hands","tag":"RED","points":maxi(30, season_points + 35)},
		ours,
		{"name":"Royal Five","tag":"R5","points":maxi(0, season_points - 25)}
	]
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["points"]) > int(b["points"]))
	return rows


func get_ranking_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var rank := 1
	for row in get_rankings():
		lines.append("#%d [%s] %s — %d pts" % [rank, String(row["tag"]), String(row["name"]), int(row["points"])])
		rank += 1
	return lines


func get_season_tier() -> String:
	if season_points >= 700:
		return "DIAMOND"
	if season_points >= 400:
		return "GOLD"
	if season_points >= 200:
		return "SILVER"
	return "BRONZE"


func get_season_summary() -> String:
	_refresh_season_period()
	return "%s • %d season points • %d war win(s) • %d territory objective(s)" % [
		get_season_tier(),
		season_points,
		season_wins,
		get_owned_territory_count()
	]


func start_prototype_war() -> bool:
	if not can_start_war() or not active_war.is_empty():
		return false
	var candidates := get_matchmaking_candidates()
	if candidates.is_empty():
		return false
	var opponent: Dictionary = candidates[0]
	_ensure_war_preparation()
	active_war = {
		"opponent_id": String(opponent["id"]),
		"opponent_name": String(opponent["name"]),
		"opponent_rating": int(opponent["rating"]),
		"seconds_remaining": WAR_DURATION_SECONDS,
		"our_score": 0,
		"their_score": 0,
		"attacks_remaining": 3,
		"status": "active",
		"result": "",
		"reward_tier": "",
		"attack_cursor": 0,
		"attack_history": [],
		"last_attack": {},
		"captain_id": String(war_preparation.get("captain_id", "")),
		"captain_bonus": get_war_captain_bonus(),
		"defense_stance": String(war_preparation.get("defense", "fortified")),
		"doctrine": String(war_preparation.get("doctrine", "disciplined")),
		"readiness": get_war_readiness_score(),
		"objectives": _create_war_objectives(),
		"member_contributions": _create_war_member_contributions(),
		"objective_score_bonus": 0,
		"completed_objectives": 0,
		"reward_split": {}
	}
	war_reward_claimed = false
	war_started.emit(String(opponent["name"]))
	changed.emit()
	return true


func get_current_war_defense() -> String:
	if active_war.is_empty():
		return ""
	var cursor := maxi(0, int(active_war.get("attack_cursor", 0)))
	var opponent_seed: int = absi(String(active_war.get("opponent_id", "")).hash()) % WAR_DEFENSE_CYCLE.size()
	return String(WAR_DEFENSE_CYCLE[(opponent_seed + cursor) % WAR_DEFENSE_CYCLE.size()])


func get_war_strategy_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for strategy_id in ["muscle", "convoy", "intel"]:
		var strategy: Dictionary = WAR_STRATEGIES[strategy_id]
		lines.append("%s — %s" % [String(strategy["name"]), String(strategy["summary"])])
	return lines


func get_last_war_attack_summary() -> String:
	if active_war.is_empty():
		return "No war attack report yet."
	var last = active_war.get("last_attack", {})
	if not (last is Dictionary) or last.is_empty():
		return "Enemy stance: %s • choose a counter-plan." % get_current_war_defense().to_upper()
	return "%s vs %s • %s • Defense %s • %d–%d pts%s%s" % [
		String(last.get("strategy_name", "Attack")),
		String(last.get("enemy_defense", "")).to_upper(),
		"COUNTER HIT" if bool(last.get("countered", false)) else "NO COUNTER",
		"HELD" if bool(last.get("defense_countered", false)) else "BREACHED",
		int(last.get("our_points", 0)),
		int(last.get("their_points", 0)),
		" • ROUND WON" if bool(last.get("victory", false)) else " • ROUND LOST",
		" • +%d OBJECTIVE SCORE" % int(last.get("objective_bonus", 0)) if int(last.get("objective_bonus", 0)) > 0 else ""
	]


func get_war_attack_history_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if active_war.is_empty():
		return lines
	var history = active_war.get("attack_history", [])
	if not (history is Array):
		return lines
	for i in range(history.size()):
		var attack: Dictionary = history[i]
		lines.append("#%d %s vs %s — %d:%d%s" % [
			i + 1,
			String(attack.get("strategy_name", "Attack")),
			String(attack.get("enemy_defense", "")).to_upper(),
			int(attack.get("our_points", 0)),
			int(attack.get("their_points", 0)),
			(" • ATTACK COUNTER" if bool(attack.get("countered", false)) else "") + (" • DEFENSE COUNTER" if bool(attack.get("defense_countered", false)) else "")
		])
	return lines


func get_war_objective_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if active_war.is_empty():
		return lines
	var objectives = active_war.get("objectives", {})
	if not (objectives is Dictionary):
		return lines
	for objective_id in ["counter_network", "round_control", "mobilize"]:
		if not objectives.has(objective_id):
			continue
		var objective: Dictionary = objectives[objective_id]
		lines.append("%s — %d/%d%s • +%d war score" % [
			String(objective.get("name", "Objective")),
			int(objective.get("progress", 0)),
			int(objective.get("goal", 1)),
			" ✓" if bool(objective.get("completed", false)) else "",
			int(objective.get("score_bonus", 0))
		])
	return lines


func get_war_participation_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if active_war.is_empty():
		return lines
	var contributions = active_war.get("member_contributions", {})
	if not (contributions is Dictionary):
		return lines
	var rows: Array[Dictionary] = []
	for member in members:
		var member_id := String(member.get("id", ""))
		rows.append({
			"name":String(member.get("name", "Member")),
			"role":String(member.get("role", ROLE_MEMBER)),
			"points":maxi(0, int(contributions.get(member_id, 0))),
			"local":member_id == local_member_id
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["points"]) > int(b["points"]))
	for row in rows:
		lines.append("%s%s • %s • %d war contribution" % [
			"YOU • " if bool(row["local"]) else "",
			String(row["name"]),
			String(row["role"]),
			int(row["points"])
		])
	return lines


func get_war_reward_split_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if active_war.is_empty():
		return lines
	var split = active_war.get("reward_split", {})
	if not (split is Dictionary) or split.is_empty():
		return PackedStringArray(["Participation split is calculated when the war ends."])
	var contributions = active_war.get("member_contributions", {})
	for member in members:
		var member_id := String(member.get("id", ""))
		if not split.has(member_id):
			continue
		lines.append("%s%s — $%s share • %d contribution" % [
			"YOU • " if member_id == local_member_id else "",
			String(member.get("name", "Member")),
			_format_number(int(split.get(member_id, 0))),
			int(contributions.get(member_id, 0)) if contributions is Dictionary else 0
		])
	return lines


func _get_war_contribution_total() -> int:
	if active_war.is_empty():
		return 0
	var contributions = active_war.get("member_contributions", {})
	if not (contributions is Dictionary):
		return 0
	var total := 0
	for value in contributions.values():
		total += maxi(0, int(value))
	return total


func _add_war_member_contribution(member_id: String, amount: int) -> void:
	if active_war.is_empty() or amount <= 0:
		return
	var contributions = active_war.get("member_contributions", {})
	if not (contributions is Dictionary):
		contributions = {}
	contributions[member_id] = maxi(0, int(contributions.get(member_id, 0))) + amount
	active_war["member_contributions"] = contributions


func _simulate_war_member_support(round_index: int) -> int:
	var total := 0
	for member in members:
		var member_id := String(member.get("id", ""))
		if member_id == local_member_id or not bool(member.get("online", false)):
			continue
		var role_bonus := 0
		match String(member.get("role", ROLE_MEMBER)):
			ROLE_LEADER, ROLE_UNDERBOSS:
				role_bonus = 10
			ROLE_OFFICER:
				role_bonus = 5
		var power_component := mini(50, maxi(0, int(member.get("power", 0))) / 400)
		var deterministic_bonus := posmod(member_id.hash() + round_index * 17, 11)
		var contribution := 20 + power_component + role_bonus + deterministic_bonus
		_add_war_member_contribution(member_id, contribution)
		total += contribution
	return total


func _update_war_objectives(result: Dictionary, local_contribution: int, support_contribution: int) -> int:
	if active_war.is_empty():
		return 0
	var objectives = active_war.get("objectives", {})
	if not (objectives is Dictionary):
		objectives = _create_war_objectives()
	var objective_bonus := 0

	if objectives.has("counter_network") and bool(result.get("countered", false)):
		var counter_objective: Dictionary = objectives["counter_network"]
		counter_objective["progress"] = mini(int(counter_objective["goal"]), int(counter_objective.get("progress", 0)) + 1)

	if objectives.has("round_control") and bool(result.get("victory", false)):
		var round_objective: Dictionary = objectives["round_control"]
		round_objective["progress"] = mini(int(round_objective["goal"]), int(round_objective.get("progress", 0)) + 1)

	if objectives.has("mobilize"):
		var mobilize: Dictionary = objectives["mobilize"]
		mobilize["progress"] = mini(int(mobilize["goal"]), _get_war_contribution_total())

	for objective_id in ["counter_network", "round_control", "mobilize"]:
		if not objectives.has(objective_id):
			continue
		var objective: Dictionary = objectives[objective_id]
		if bool(objective.get("completed", false)):
			continue
		if int(objective.get("progress", 0)) < int(objective.get("goal", 1)):
			continue
		objective["completed"] = true
		objective_bonus += int(objective.get("score_bonus", 0))

	active_war["objectives"] = objectives
	if objective_bonus > 0:
		active_war["objective_score_bonus"] = int(active_war.get("objective_score_bonus", 0)) + objective_bonus
		active_war["completed_objectives"] = _get_completed_war_objectives()
	return objective_bonus


func _get_completed_war_objectives() -> int:
	if active_war.is_empty():
		return 0
	var objectives = active_war.get("objectives", {})
	if not (objectives is Dictionary):
		return 0
	var completed := 0
	for objective in objectives.values():
		if objective is Dictionary and bool(objective.get("completed", false)):
			completed += 1
	return completed


func perform_war_attack(strategy_id: String) -> Dictionary:
	if active_war.is_empty() or String(active_war.get("status", "")) != "active":
		return {}
	if not WAR_STRATEGIES.has(strategy_id):
		return {}
	var attacks := int(active_war.get("attacks_remaining", 0))
	if attacks <= 0:
		return {}

	var contribution := 0
	for member in members:
		if String(member.get("id", "")) == local_member_id:
			contribution = int(member.get("contribution", 0))
			break

	var strategy: Dictionary = WAR_STRATEGIES[strategy_id]
	var doctrine_id := String(active_war.get("doctrine", "disciplined"))
	var doctrine: Dictionary = WAR_DOCTRINES.get(doctrine_id, WAR_DOCTRINES["disciplined"])
	var enemy_defense := get_current_war_defense()
	var countered := enemy_defense == String(strategy.get("counter", ""))
	var territory_bonus := get_owned_territory_count() * 10
	var readiness_bonus := maxi(0, int(active_war.get("readiness", 50)) - 50) / 5
	var captain_bonus := int(active_war.get("captain_bonus", 0))
	var base_points := 100 + faction_level * 15 + int(research["raid_coordination"]) * 20 + mini(100, contribution / 5) + territory_bonus + readiness_bonus + captain_bonus
	var our_points := roundi(float(base_points) * float(strategy.get("base_multiplier", 1.0)) * float(doctrine.get("attack_multiplier", 1.0)))
	if countered:
		our_points += roundi(float(strategy.get("counter_bonus", 0)) * float(doctrine.get("counter_bonus_multiplier", 1.0)))
	else:
		our_points = maxi(1, our_points - roundi(float(strategy.get("mismatch_penalty", 0)) * float(doctrine.get("mismatch_multiplier", 1.0))))

	var their_points := 95 + faction_level * 10 + int(active_war.get("opponent_rating", 0)) / 100
	var defense_modifier := 0
	match enemy_defense:
		"fortified":
			defense_modifier = 12
		"mobile":
			defense_modifier = 6
		"watchful":
			defense_modifier = 9
	their_points += defense_modifier + int(doctrine.get("incoming_modifier", 0))
	var enemy_attack := ["muscle", "convoy", "intel"][int(active_war.get("attack_cursor", 0)) % 3]
	var our_defense := String(active_war.get("defense_stance", "fortified"))
	var defense_countered := String(WAR_DEFENSE_COUNTERS.get(our_defense, "")) == enemy_attack
	if defense_countered:
		their_points = maxi(1, their_points - 28)

	var result := {
		"strategy_id":strategy_id,
		"strategy_name":String(strategy.get("name", strategy_id)),
		"enemy_defense":enemy_defense,
		"countered":countered,
		"defense_countered":defense_countered,
		"enemy_attack":enemy_attack,
		"doctrine":doctrine_id,
		"captain_bonus":captain_bonus,
		"readiness":int(active_war.get("readiness", 50)),
		"our_points":our_points,
		"their_points":their_points,
		"victory":our_points > their_points,
		"objective_bonus":0,
		"support_contribution":0
	}

	var local_war_contribution := 80 + (25 if countered else 0) + (15 if bool(result["victory"]) else 0)
	_add_war_member_contribution(local_member_id, local_war_contribution)
	var support_contribution := _simulate_war_member_support(int(active_war.get("attack_cursor", 0)))
	result["support_contribution"] = support_contribution
	var objective_bonus := _update_war_objectives(result, local_war_contribution, support_contribution)
	result["objective_bonus"] = objective_bonus

	active_war["our_score"] = int(active_war.get("our_score", 0)) + our_points + objective_bonus
	active_war["their_score"] = int(active_war.get("their_score", 0)) + their_points
	active_war["attacks_remaining"] = attacks - 1
	active_war["attack_cursor"] = int(active_war.get("attack_cursor", 0)) + 1
	active_war["last_attack"] = result.duplicate(true)
	var history = active_war.get("attack_history", [])
	if not (history is Array):
		history = []
	history.append(result.duplicate(true))
	while history.size() > 3:
		history.pop_front()
	active_war["attack_history"] = history

	_add_local_contribution(20)
	award_faction_xp(15)

	if bool(result["victory"]):
		gift_charges += 1
		faction_gift_earned.emit()

	if int(active_war["attacks_remaining"]) <= 0:
		_complete_war()

	changed.emit()
	return result


func perform_prototype_war_attack() -> Dictionary:
	return perform_war_attack("muscle")


func _complete_war() -> void:
	if active_war.is_empty() or String(active_war.get("status", "")) == "complete":
		return
	active_war["status"] = "complete"
	var won := int(active_war.get("our_score", 0)) > int(active_war.get("their_score", 0))
	active_war["result"] = "VICTORY" if won else "DEFEAT"
	var completed_objectives := _get_completed_war_objectives()
	active_war["completed_objectives"] = completed_objectives
	var awarded_points := (120 if won else 35) + completed_objectives * (15 if won else 10)
	if won:
		season_wins += 1
		active_war["reward_tier"] = "GOLD" if completed_objectives >= 2 else "SILVER"
	else:
		active_war["reward_tier"] = "BRONZE"
	season_points += awarded_points
	active_war["reward_split"] = _build_war_reward_split(String(active_war.get("reward_tier", "BRONZE")))
	war_reward_claimed = false
	war_completed.emit(won, awarded_points)


func _build_war_reward_split(tier: String) -> Dictionary:
	var pool := int(WAR_REWARD_POOLS.get(tier, WAR_REWARD_POOLS["BRONZE"]))
	var contributions = active_war.get("member_contributions", {})
	if not (contributions is Dictionary) or contributions.is_empty():
		return {local_member_id:pool}

	var positive_rows: Array[Dictionary] = []
	var total := 0
	for member in members:
		var member_id := String(member.get("id", ""))
		var points := maxi(0, int(contributions.get(member_id, 0)))
		if points <= 0:
			continue
		positive_rows.append({"id":member_id,"points":points})
		total += points

	if positive_rows.is_empty() or total <= 0:
		return {local_member_id:pool}

	var split := {}
	var distributed := 0
	var top_member_id := String(positive_rows[0]["id"])
	var top_points := int(positive_rows[0]["points"])
	for row in positive_rows:
		var member_id := String(row["id"])
		var points := int(row["points"])
		if points > top_points:
			top_points = points
			top_member_id = member_id
		var share := floori(float(pool) * float(points) / float(total))
		split[member_id] = share
		distributed += share
	split[top_member_id] = int(split.get(top_member_id, 0)) + (pool - distributed)
	return split


func can_claim_war_reward() -> bool:
	return not active_war.is_empty() and String(active_war.get("status", "")) == "complete" and not war_reward_claimed


func claim_war_reward() -> bool:
	if not can_claim_war_reward() or economy == null or loot == null:
		return false
	war_reward_claimed = true
	var tier := String(active_war.get("reward_tier", "BRONZE"))
	var reward_split = active_war.get("reward_split", {})
	var participation_cash := int(reward_split.get(local_member_id, 0)) if reward_split is Dictionary else 0
	match tier:
		"GOLD":
			economy.add_cash(8000 + participation_cash)
			economy.add_gold(6)
			loot.add_loot({"Parts":3,"Intel":2})
		"SILVER":
			economy.add_cash(5000 + participation_cash)
			economy.add_gold(3)
			loot.add_loot({"Parts":2,"Intel":1})
		_:
			economy.add_cash(2500 + participation_cash)
			economy.add_gold(1)
			loot.add_item("Parts", 1)
	changed.emit()
	return true


func clear_completed_war() -> bool:
	if active_war.is_empty() or String(active_war.get("status", "")) != "complete" or not war_reward_claimed:
		return false
	active_war.clear()
	changed.emit()
	return true


func get_war_summary() -> String:
	if active_war.is_empty():
		return "No active Faction War."
	var status := String(active_war.get("status", "active"))
	var extra := ""
	if status == "complete":
		extra = " • %s • %s reward" % [String(active_war.get("result", "")), String(active_war.get("reward_tier", "BRONZE"))]
	return "%s • %s • Score %d–%d • Attacks %d • Readiness %d • %s%s" % [
		String(active_war.get("opponent_name", "Opponent")),
		status.to_upper(),
		int(active_war.get("our_score", 0)),
		int(active_war.get("their_score", 0)),
		int(active_war.get("attacks_remaining", 0)),
		int(active_war.get("readiness", 50)),
		_format_time(float(active_war.get("seconds_remaining", 0.0))),
		extra
	]


func get_war_rules_lines() -> PackedStringArray:
	return PackedStringArray([
		"24-hour war window with server-ready opponent/rating fields",
		"3 attacks per member in the prototype ruleset",
		"Choose Muscle, Convoy, or Intel for each attack; each plan counters a visible enemy stance",
		"Score scales with Faction level, contribution, Raid Coordination, held objectives, and counter choice",
		"Complete shared war objectives for up to +120 bonus war score and extra season points",
		"Member war contribution determines the split of a separate participation cash pool",
		"Victory starts at 120 season points; completed objectives add more season progress",
		"Bronze/Silver/Gold reward tiers are claimable after war completion",
		"Live matchmaking and server authority will replace prototype opponents"
	])


func _on_recruitment_completed(_troop_type: StringName, amount: int) -> void:
	_add_daily_progress("recruit", amount)
	_add_local_contribution(maxi(1, amount))


func _on_construction_completed(_target: Node) -> void:
	_add_daily_progress("construction", 1)
	_add_local_contribution(8)


func _on_battle_resolved(result: Dictionary) -> void:
	if not bool(result.get("victory", false)):
		return
	_add_daily_progress("raid", 1)
	_add_local_contribution(12)


func get_member_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for member in members:
		lines.append("%s • %s • Power %s • Contribution %s%s" % [
			String(member.get("name", "Member")),
			String(member.get("role", ROLE_MEMBER)),
			_format_number(int(member.get("power", 0))),
			_format_number(int(member.get("contribution", 0))),
			" • ONLINE" if bool(member.get("online", false)) else ""
		])
	return lines


func get_invite_summary() -> String:
	return "%d pending invite(s) • %d/%d member slots used" % [
		pending_invites.size(),
		members.size(),
		get_member_limit()
	]


func get_summary() -> String:
	if not has_faction():
		return "No Faction joined."
	return "[%s] %s • Faction Lv.%d • XP %d/%d • Treasury $%s • Gifts %d" % [
		faction_tag,
		faction_name,
		faction_level,
		faction_xp,
		get_xp_for_next_level(),
		_format_number(treasury_cash),
		gift_charges
	]


func get_save_data() -> Dictionary:
	return {
		"faction_id": faction_id,
		"faction_name": faction_name,
		"faction_tag": faction_tag,
		"faction_level": faction_level,
		"faction_xp": faction_xp,
		"treasury_cash": treasury_cash,
		"members": members.duplicate(true),
		"research": research.duplicate(true),
		"daily_period": daily_period,
		"daily_claimed": daily_claimed,
		"daily_mastery_claimed": daily_mastery_claimed,
		"daily_tasks": daily_tasks.duplicate(true),
		"gift_charges": gift_charges,
		"active_rally": active_rally.duplicate(true),
		"active_war": active_war.duplicate(true),
		"war_reward_claimed": war_reward_claimed,
		"season_period": season_period,
		"season_points": season_points,
		"season_wins": season_wins,
		"pending_invites": pending_invites.duplicate(true),
		"war_preparation": war_preparation.duplicate(true),
		"faction_territory": faction_territory.duplicate(true)
	}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	faction_id = String(data.get("faction_id", faction_id))
	faction_name = String(data.get("faction_name", faction_name))
	faction_tag = String(data.get("faction_tag", faction_tag))
	faction_level = maxi(1, int(data.get("faction_level", faction_level)))
	faction_xp = maxi(0, int(data.get("faction_xp", faction_xp)))
	treasury_cash = maxi(0, int(data.get("treasury_cash", treasury_cash)))
	daily_period = int(data.get("daily_period", daily_period))
	daily_claimed = bool(data.get("daily_claimed", daily_claimed))
	daily_mastery_claimed = bool(data.get("daily_mastery_claimed", daily_mastery_claimed))
	gift_charges = maxi(0, int(data.get("gift_charges", gift_charges)))
	war_reward_claimed = bool(data.get("war_reward_claimed", war_reward_claimed))
	season_period = int(data.get("season_period", season_period))
	season_points = maxi(0, int(data.get("season_points", season_points)))
	season_wins = maxi(0, int(data.get("season_wins", season_wins)))

	var saved_members = data.get("members", [])
	if saved_members is Array:
		members.clear()
		for member in saved_members:
			if member is Dictionary:
				members.append(member.duplicate(true))

	var saved_research = data.get("research", {})
	if saved_research is Dictionary:
		for research_id in research.keys():
			research[research_id] = clampi(int(saved_research.get(research_id, research[research_id])), 0, 5)

	var saved_daily = data.get("daily_tasks", {})
	if saved_daily is Dictionary:
		for task_id in daily_tasks.keys():
			if saved_daily.has(task_id) and saved_daily[task_id] is Dictionary:
				daily_tasks[task_id]["progress"] = clampi(
					int(saved_daily[task_id].get("progress", 0)),
					0,
					int(daily_tasks[task_id]["goal"])
				)

	var saved_preparation = data.get("war_preparation", {})
	if saved_preparation is Dictionary:
		war_preparation["captain_id"] = String(saved_preparation.get("captain_id", war_preparation["captain_id"]))
		war_preparation["defense"] = String(saved_preparation.get("defense", war_preparation["defense"]))
		war_preparation["doctrine"] = String(saved_preparation.get("doctrine", war_preparation["doctrine"]))
	_ensure_war_preparation()

	var saved_invites = data.get("pending_invites", [])
	pending_invites.clear()
	if saved_invites is Array:
		for invite in saved_invites:
			if invite is Dictionary:
				pending_invites.append(invite.duplicate(true))

	var saved_territory = data.get("faction_territory", {})
	if saved_territory is Dictionary:
		for territory_id in faction_territory.keys():
			if saved_territory.has(territory_id) and saved_territory[territory_id] is Dictionary:
				faction_territory[territory_id]["owned"] = bool(saved_territory[territory_id].get("owned", false))

	var saved_rally = data.get("active_rally", {})
	active_rally = saved_rally.duplicate(true) if saved_rally is Dictionary else {}
	if not active_rally.is_empty():
		active_rally["seconds_remaining"] = maxf(0.0, float(active_rally.get("seconds_remaining", 0.0)) - maxf(0.0, offline_seconds))
		if float(active_rally["seconds_remaining"]) <= 0.0:
			active_rally.clear()

	var saved_war = data.get("active_war", {})
	active_war = saved_war.duplicate(true) if saved_war is Dictionary else {}
	if not active_war.is_empty():
		if not active_war.has("attack_cursor"):
			active_war["attack_cursor"] = 0
		if not active_war.has("attack_history") or not (active_war["attack_history"] is Array):
			active_war["attack_history"] = []
		if not active_war.has("last_attack") or not (active_war["last_attack"] is Dictionary):
			active_war["last_attack"] = {}
		if not active_war.has("objectives") or not (active_war["objectives"] is Dictionary):
			active_war["objectives"] = _create_war_objectives()
		else:
			var loaded_objectives: Dictionary = active_war["objectives"]
			for objective_id in WAR_OBJECTIVE_DEFS.keys():
				if not loaded_objectives.has(objective_id) or not (loaded_objectives[objective_id] is Dictionary):
					loaded_objectives[objective_id] = _create_war_objectives()[objective_id]
		if not active_war.has("member_contributions") or not (active_war["member_contributions"] is Dictionary):
			active_war["member_contributions"] = _create_war_member_contributions()
		else:
			var loaded_contributions: Dictionary = active_war["member_contributions"]
			for member in members:
				var member_id := String(member.get("id", ""))
				loaded_contributions[member_id] = maxi(0, int(loaded_contributions.get(member_id, 0)))
		if not active_war.has("objective_score_bonus"):
			active_war["objective_score_bonus"] = 0
		if not active_war.has("completed_objectives"):
			active_war["completed_objectives"] = _get_completed_war_objectives()
		if not active_war.has("reward_split") or not (active_war["reward_split"] is Dictionary):
			active_war["reward_split"] = {}
		if not active_war.has("captain_id"):
			active_war["captain_id"] = String(war_preparation.get("captain_id", ""))
		if not active_war.has("captain_bonus"):
			active_war["captain_bonus"] = get_war_captain_bonus(String(active_war["captain_id"]))
		if not active_war.has("defense_stance") or String(active_war["defense_stance"]) not in WAR_DEFENSE_CYCLE:
			active_war["defense_stance"] = String(war_preparation.get("defense", "fortified"))
		if not active_war.has("doctrine") or not WAR_DOCTRINES.has(String(active_war["doctrine"])):
			active_war["doctrine"] = String(war_preparation.get("doctrine", "disciplined"))
		if not active_war.has("readiness"):
			active_war["readiness"] = get_war_readiness_score()
	if not active_war.is_empty() and String(active_war.get("status", "active")) == "active":
		active_war["seconds_remaining"] = maxf(0.0, float(active_war.get("seconds_remaining", 0.0)) - maxf(0.0, offline_seconds))
		if float(active_war["seconds_remaining"]) <= 0.0:
			_complete_war()

	_refresh_daily_period()
	_refresh_season_period()
	changed.emit()


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var secs := total % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]


func _format_number(value: int) -> String:
	var raw := str(value)
	var output := ""
	while raw.length() > 3:
		output = "," + raw.right(3) + output
		raw = raw.left(raw.length() - 3)
	return raw + output
