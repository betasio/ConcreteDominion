class_name FactionManager
extends Node

signal changed
signal faction_created(faction_name: String)
signal faction_joined(faction_name: String)
signal faction_left
signal faction_leveled_up(new_level: int)
signal research_upgraded(research_id: String, new_level: int)

const ROLE_LEADER := "Leader"
const ROLE_UNDERBOSS := "Underboss"
const ROLE_OFFICER := "Officer"
const ROLE_MEMBER := "Member"

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
		{"id":local_member_id,"name":"You","role":ROLE_MEMBER,"power":0,"contribution":0,"online":true}
	]
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
	changed.emit()
	faction_left.emit()
	return true


func get_local_role() -> String:
	for member in members:
		if String(member.get("id", "")) == local_member_id:
			return String(member.get("role", ROLE_MEMBER))
	return ""


func get_xp_for_next_level() -> int:
	return 200 + (faction_level - 1) * 150


func award_faction_xp(amount: int) -> void:
	if not has_faction() or amount <= 0:
		return
	faction_xp += amount
	while faction_xp >= get_xp_for_next_level():
		faction_xp -= get_xp_for_next_level()
		faction_level += 1
		faction_leveled_up.emit(faction_level)
	changed.emit()


func donate_cash(amount: int, economy: PlayerEconomy) -> bool:
	if not has_faction() or economy == null or amount <= 0 or economy.cash < amount:
		return false
	if not economy.spend_cash(amount):
		return false

	treasury_cash += amount
	award_faction_xp(maxi(1, amount / 500))
	for member in members:
		if String(member.get("id", "")) == local_member_id:
			member["contribution"] = int(member.get("contribution", 0)) + amount
			break
	changed.emit()
	return true


func get_research_cost(research_id: String) -> int:
	var level := int(research.get(research_id, -1))
	if level < 0 or level >= 5:
		return 0
	return 5000 + level * 5000


func can_upgrade_research(research_id: String) -> bool:
	var cost := get_research_cost(research_id)
	return has_faction() and cost > 0 and treasury_cash >= cost and get_local_role() in [ROLE_LEADER, ROLE_UNDERBOSS, ROLE_OFFICER]


func upgrade_research(research_id: String) -> bool:
	if not can_upgrade_research(research_id):
		return false
	var cost := get_research_cost(research_id)
	treasury_cash -= cost
	research[research_id] = int(research[research_id]) + 1
	research_upgraded.emit(research_id, int(research[research_id]))
	changed.emit()
	return true


func get_research_summary() -> PackedStringArray:
	return PackedStringArray([
		"Construction Help Lv.%d — member help timers +%d%%" % [int(research["construction_help"]), int(research["construction_help"]) * 3],
		"Raid Coordination Lv.%d — future faction rally bonus +%d%%" % [int(research["raid_coordination"]), int(research["raid_coordination"]) * 2],
		"Territory Income Lv.%d — future faction territory yield +%d%%" % [int(research["territory_income"]), int(research["territory_income"]) * 2]
	])


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
	return "[%s] %s • Faction Lv.%d • XP %d/%d • Treasury $%s" % [
		faction_tag,
		faction_name,
		faction_level,
		faction_xp,
		get_xp_for_next_level(),
		_format_number(treasury_cash)
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
		"research": research.duplicate(true)
	}


func load_save_data(data: Dictionary) -> void:
	faction_id = String(data.get("faction_id", faction_id))
	faction_name = String(data.get("faction_name", faction_name))
	faction_tag = String(data.get("faction_tag", faction_tag))
	faction_level = maxi(1, int(data.get("faction_level", faction_level)))
	faction_xp = maxi(0, int(data.get("faction_xp", faction_xp)))
	treasury_cash = maxi(0, int(data.get("treasury_cash", treasury_cash)))

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

	changed.emit()


func _format_number(value: int) -> String:
	var raw := str(value)
	var output := ""
	while raw.length() > 3:
		output = "," + raw.right(3) + output
		raw = raw.left(raw.length() - 3)
	return raw + output
