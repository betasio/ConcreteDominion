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

const ROLE_LEADER := "Leader"
const ROLE_UNDERBOSS := "Underboss"
const ROLE_OFFICER := "Officer"
const ROLE_MEMBER := "Member"

const DAILY_REQUIRED := 3
const WAR_DURATION_SECONDS := 24.0 * 60.0 * 60.0
const RALLY_DURATION_SECONDS := 10.0 * 60.0

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
	changed.emit()


func _process(delta: float) -> void:
	var did_change := false
	if not active_rally.is_empty():
		active_rally["seconds_remaining"] = maxf(0.0, float(active_rally.get("seconds_remaining", 0.0)) - delta)
		if float(active_rally["seconds_remaining"]) <= 0.0:
			active_rally.clear()
		did_change = true

	if not active_war.is_empty() and String(active_war.get("status", "active")) == "active":
		active_war["seconds_remaining"] = maxf(0.0, float(active_war.get("seconds_remaining", 0.0)) - delta)
		if float(active_war["seconds_remaining"]) <= 0.0:
			active_war["status"] = "complete"
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
	faction_level = 2
	faction_xp = 80
	treasury_cash = 12500
	members = [
		{"id":"player_ace","name":"Ace","role":ROLE_LEADER,"power":12800,"contribution":420,"online":true},
		{"id":"player_nova","name":"Nova","role":ROLE_OFFICER,"power":9100,"contribution":310,"online":true},
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


func get_local_role() -> String:
	for member in members:
		if String(member.get("id", "")) == local_member_id:
			return String(member.get("role", ROLE_MEMBER))
	return ""


func can_manage_research() -> bool:
	return get_local_role() in [ROLE_LEADER, ROLE_UNDERBOSS, ROLE_OFFICER]


func can_start_rally() -> bool:
	return has_faction() and get_local_role() in [ROLE_LEADER, ROLE_UNDERBOSS, ROLE_OFFICER]


func can_start_war() -> bool:
	return has_faction() and get_local_role() in [ROLE_LEADER, ROLE_UNDERBOSS]


func get_permissions_summary() -> String:
	var role := get_local_role()
	if role == ROLE_LEADER:
		return "Leader — manage research, rallies, wars, ranks, and Faction direction."
	if role == ROLE_UNDERBOSS:
		return "Underboss — manage research, rallies, and Faction wars."
	if role == ROLE_OFFICER:
		return "Officer — manage research and start rallies."
	return "Member — contribute, join rallies, earn gifts, and fight in wars."


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


func start_prototype_war() -> bool:
	if not can_start_war() or not active_war.is_empty():
		return false
	active_war = {
		"opponent_id": "prototype_red_hands",
		"opponent_name": "Red Hands",
		"seconds_remaining": WAR_DURATION_SECONDS,
		"our_score": 0,
		"their_score": 0,
		"attacks_remaining": 3,
		"status": "active"
	}
	war_started.emit("Red Hands")
	changed.emit()
	return true


func perform_prototype_war_attack() -> Dictionary:
	if active_war.is_empty() or String(active_war.get("status", "")) != "active":
		return {}
	var attacks := int(active_war.get("attacks_remaining", 0))
	if attacks <= 0:
		return {}

	var contribution := 0
	for member in members:
		if String(member.get("id", "")) == local_member_id:
			contribution = int(member.get("contribution", 0))
			break

	var our_points := 100 + faction_level * 15 + int(research["raid_coordination"]) * 20 + mini(100, contribution / 5)
	var their_points := 95 + faction_level * 10
	active_war["our_score"] = int(active_war.get("our_score", 0)) + our_points
	active_war["their_score"] = int(active_war.get("their_score", 0)) + their_points
	active_war["attacks_remaining"] = attacks - 1
	_add_local_contribution(20)
	award_faction_xp(15)
	if our_points > their_points:
		gift_charges += 1
		faction_gift_earned.emit()
	changed.emit()

	return {
		"our_points": our_points,
		"their_points": their_points,
		"victory": our_points > their_points
	}


func get_war_summary() -> String:
	if active_war.is_empty():
		return "No active Faction War."
	var status := String(active_war.get("status", "active"))
	return "%s • %s • Score %d–%d • Attacks %d • %s" % [
		String(active_war.get("opponent_name", "Opponent")),
		status.to_upper(),
		int(active_war.get("our_score", 0)),
		int(active_war.get("their_score", 0)),
		int(active_war.get("attacks_remaining", 0)),
		_format_time(float(active_war.get("seconds_remaining", 0.0)))
	]


func get_war_rules_lines() -> PackedStringArray:
	return PackedStringArray([
		"24-hour war window",
		"3 attacks per member in the prototype ruleset",
		"Attack score scales with Faction level, contribution, and Raid Coordination",
		"Winning attacks generate shared gift chests",
		"Live PvP matchmaking and server authority will replace prototype simulation"
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
		"active_war": active_war.duplicate(true)
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

	var saved_rally = data.get("active_rally", {})
	active_rally = saved_rally.duplicate(true) if saved_rally is Dictionary else {}
	if not active_rally.is_empty():
		active_rally["seconds_remaining"] = maxf(0.0, float(active_rally.get("seconds_remaining", 0.0)) - maxf(0.0, offline_seconds))
		if float(active_rally["seconds_remaining"]) <= 0.0:
			active_rally.clear()

	var saved_war = data.get("active_war", {})
	active_war = saved_war.duplicate(true) if saved_war is Dictionary else {}
	if not active_war.is_empty() and String(active_war.get("status", "active")) == "active":
		active_war["seconds_remaining"] = maxf(0.0, float(active_war.get("seconds_remaining", 0.0)) - maxf(0.0, offline_seconds))
		if float(active_war["seconds_remaining"]) <= 0.0:
			active_war["status"] = "complete"

	_refresh_daily_period()
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
