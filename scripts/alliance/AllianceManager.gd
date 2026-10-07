class_name AllianceManager
extends Node

signal changed
signal alliance_leveled_up(new_level: int)

const ROLE_FRONTLINE := &"frontline"
const ROLE_DRIVER := &"driver"
const ROLE_SPY := &"spy"

var members: Array[Dictionary] = []
var raid_slots: Array[Dictionary] = []

var alliance_level := 1
var alliance_xp := 0


func _ready() -> void:
	if members.is_empty():
		_create_mock_alliance()
	if raid_slots.is_empty():
		reset_raid_slots()


func _create_mock_alliance() -> void:
	members = [
		{"id":"boss_01","name":"Vex","level":45,"power":8000.0,"preferred_role":ROLE_FRONTLINE,"online":true,"is_local":false},
		{"id":"driver_ally_01","name":"Mia","level":17,"power":850.0,"preferred_role":ROLE_DRIVER,"online":true,"is_local":false},
		{"id":"spy_ally_01","name":"Noah","level":14,"power":720.0,"preferred_role":ROLE_SPY,"online":true,"is_local":false},
		{"id":"driver_ally_02","name":"Kira","level":12,"power":610.0,"preferred_role":ROLE_DRIVER,"online":false,"is_local":false},
		{"id":"local_player","name":"You","level":12,"power":0.0,"preferred_role":ROLE_DRIVER,"online":true,"is_local":true}
	]


func get_xp_for_next_level() -> int:
	return 120 + (alliance_level - 1) * 100


func get_frontline_power_multiplier() -> float:
	return 1.0 + float(alliance_level - 1) * 0.02


func get_progression_summary() -> String:
	return "Alliance Lv.%d — XP %d/%d — NPC frontline +%d%% — Slots %d" % [
		alliance_level,
		alliance_xp,
		get_xp_for_next_level(),
		roundi((get_frontline_power_multiplier() - 1.0) * 100.0),
		raid_slots.size()
	]


func award_alliance_xp(amount: int) -> void:
	if amount <= 0:
		return
	alliance_xp += amount
	while alliance_xp >= get_xp_for_next_level():
		alliance_xp -= get_xp_for_next_level()
		alliance_level += 1
		_rebuild_slots_preserving_assignments()
		alliance_leveled_up.emit(alliance_level)
	changed.emit()


func award_raid_result(result: Dictionary) -> void:
	if not bool(result.get("victory", false)):
		return

	var earned := 20
	match String(result.get("target_id", "")):
		"harbor_bank":
			earned = 28
		"midtown_exchange":
			earned = 34
		"northside_hq":
			earned = 42
		"casino_vault":
			earned = 52
		"financial_tower":
			earned = 64
		"industrial_depot":
			earned = 78

	award_alliance_xp(earned)


func reset_raid_slots() -> void:
	raid_slots = _desired_slots()
	auto_fill_online_allies()
	changed.emit()


func _desired_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = [
		{"slot":0,"role":ROLE_FRONTLINE,"member_id":"boss_01"},
		{"slot":1,"role":ROLE_DRIVER,"member_id":""},
		{"slot":2,"role":ROLE_SPY,"member_id":""},
		{"slot":3,"role":ROLE_DRIVER,"member_id":""}
	]
	if alliance_level >= 2:
		slots.append({"slot":slots.size(),"role":ROLE_SPY,"member_id":""})
	if alliance_level >= 4:
		slots.append({"slot":slots.size(),"role":ROLE_DRIVER,"member_id":""})
	return slots


func _rebuild_slots_preserving_assignments() -> void:
	var assigned: Dictionary = {}
	for slot in raid_slots:
		var member_id := String(slot.get("member_id", ""))
		if member_id != "":
			assigned[member_id] = StringName(slot.get("role", ROLE_DRIVER))

	raid_slots = _desired_slots()

	for member_id in assigned.keys():
		if member_id == "boss_01":
			continue
		var role := StringName(assigned[member_id])
		for slot in raid_slots:
			if StringName(slot["role"]) == role and String(slot["member_id"]) == "":
				slot["member_id"] = member_id
				break

	auto_fill_online_allies()


func auto_fill_online_allies() -> void:
	for slot in raid_slots:
		if String(slot["member_id"]) != "":
			continue
		var role := StringName(slot["role"])
		for member in members:
			if not bool(member["online"]) or bool(member["is_local"]):
				continue
			if StringName(member["preferred_role"]) != role:
				continue
			if is_member_assigned(String(member["id"])):
				continue
			slot["member_id"] = String(member["id"])
			break


func get_member(member_id: String) -> Dictionary:
	for member in members:
		if String(member["id"]) == member_id:
			return member
	return {}


func get_members() -> Array[Dictionary]:
	return members


func get_raid_slots() -> Array[Dictionary]:
	return raid_slots


func is_member_assigned(member_id: String) -> bool:
	for slot in raid_slots:
		if String(slot["member_id"]) == member_id:
			return true
	return false


func assign_member_to_slot(slot_index: int, member_id: String) -> bool:
	if slot_index < 0 or slot_index >= raid_slots.size():
		return false
	var member := get_member(member_id)
	if member.is_empty() or not bool(member["online"]):
		return false
	var required_role := StringName(raid_slots[slot_index]["role"])
	var preferred_role := StringName(member["preferred_role"])
	if required_role != ROLE_FRONTLINE and preferred_role != required_role:
		return false

	for slot in raid_slots:
		if String(slot["member_id"]) == member_id:
			slot["member_id"] = ""

	raid_slots[slot_index]["member_id"] = member_id
	changed.emit()
	return true


func assign_local_player(role: StringName) -> bool:
	var local_member := get_member("local_player")
	if local_member.is_empty():
		return false

	clear_local_player(false)

	for i in range(raid_slots.size()):
		if StringName(raid_slots[i]["role"]) == role and String(raid_slots[i]["member_id"]) == "":
			raid_slots[i]["member_id"] = "local_player"
			changed.emit()
			return true

	for i in range(raid_slots.size() - 1, -1, -1):
		if StringName(raid_slots[i]["role"]) == role and role != ROLE_FRONTLINE:
			raid_slots[i]["member_id"] = "local_player"
			changed.emit()
			return true

	return false


func clear_local_player(refill: bool = true) -> void:
	for slot in raid_slots:
		if String(slot["member_id"]) == "local_player":
			slot["member_id"] = ""
	if refill:
		auto_fill_online_allies()
		changed.emit()


func set_member_online(member_id: String, online: bool) -> void:
	for member in members:
		if String(member["id"]) == member_id:
			member["online"] = online
			if not online:
				for slot in raid_slots:
					if String(slot["member_id"]) == member_id:
						slot["member_id"] = ""
			auto_fill_online_allies()
			changed.emit()
			return


func toggle_member_online(member_id: String) -> void:
	var member := get_member(member_id)
	if member.is_empty():
		return
	set_member_online(member_id, not bool(member["online"]))


func build_participant_snapshot(local_driver_count: int, local_spy_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for slot in raid_slots:
		var member_id := String(slot["member_id"])
		if member_id == "":
			continue

		var member := get_member(member_id)
		if member.is_empty() or not bool(member["online"]):
			continue

		var role := StringName(slot["role"])
		var base_power := float(member["power"])
		var unit_count := 0

		if not bool(member["is_local"]) and role == ROLE_FRONTLINE:
			base_power *= get_frontline_power_multiplier()

		if bool(member["is_local"]):
			if role == ROLE_DRIVER:
				unit_count = local_driver_count
			elif role == ROLE_SPY:
				unit_count = local_spy_count

		result.append({
			"player_id": member_id,
			"name": String(member["name"]),
			"level": int(member["level"]),
			"base_power": base_power,
			"role": role,
			"unit_count": unit_count,
			"is_local": bool(member["is_local"])
		})

	return result


func get_save_data() -> Dictionary:
	var online_states := {}
	for member in members:
		if not bool(member["is_local"]):
			online_states[String(member["id"])] = bool(member["online"])
	return {
		"online_states": online_states,
		"raid_slots": raid_slots.duplicate(true),
		"alliance_level": alliance_level,
		"alliance_xp": alliance_xp
	}


func load_save_data(data: Dictionary) -> void:
	alliance_level = maxi(1, int(data.get("alliance_level", alliance_level)))
	alliance_xp = maxi(0, int(data.get("alliance_xp", alliance_xp)))

	var states = data.get("online_states", {})
	if states is Dictionary:
		for member in members:
			var member_id := String(member["id"])
			if states.has(member_id):
				member["online"] = bool(states[member_id])

	var saved_slots = data.get("raid_slots", [])
	if saved_slots is Array and not saved_slots.is_empty():
		raid_slots.clear()
		for slot in saved_slots:
			if slot is Dictionary:
				raid_slots.append(slot.duplicate(true))
		_rebuild_slots_preserving_assignments()
	else:
		reset_raid_slots()

	changed.emit()
