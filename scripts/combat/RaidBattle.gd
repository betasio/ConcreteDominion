class_name RaidBattle
extends Node

signal changed
signal battle_started(target_id: String, travel_time: float)
signal battle_resolved(result: Dictionary)

@export var launch_countdown_seconds: float = 5.0
@export_range(0.0, 1.0, 0.05) var equal_reward_pool_share: float = 0.50

var economy: PlayerEconomy
var roster: TroopRoster
var hospital: HospitalQueue
var synergy: SynergyRaid
var loot_inventory: LootInventory
var alliance: AllianceManager
var progression: PlayerProgression
var loadout: CombatLoadout
var core_effects: CoreBuildingEffects
var city_map: Node

var active_battle: Dictionary = {}
var last_result: Dictionary = {}
var _last_displayed_second := -1
var _offline_resolution_overrun := 0.0


func setup(
	player_economy: PlayerEconomy,
	troop_roster: TroopRoster,
	hospital_queue: HospitalQueue,
	synergy_raid: SynergyRaid,
	loot: LootInventory,
	alliance_manager: AllianceManager,
	player_progression: PlayerProgression,
	combat_loadout: CombatLoadout,
	building_effects: CoreBuildingEffects,
	world: Node
) -> void:
	economy = player_economy
	roster = troop_roster
	hospital = hospital_queue
	synergy = synergy_raid
	loot_inventory = loot
	alliance = alliance_manager
	progression = player_progression
	loadout = combat_loadout
	core_effects = building_effects
	city_map = world


func _process(delta: float) -> void:
	if active_battle.is_empty():
		return

	active_battle["seconds_remaining"] = maxf(
		0.0,
		float(active_battle["seconds_remaining"]) - delta
	)

	var shown := ceili(float(active_battle["seconds_remaining"]))
	if shown != _last_displayed_second:
		_last_displayed_second = shown
		changed.emit()

	if float(active_battle["seconds_remaining"]) <= 0.0:
		_resolve_active_battle()


func is_active() -> bool:
	return not active_battle.is_empty()


func preview_battle(target: RaidTarget, local_driver_count: int, local_spy_count: int) -> Dictionary:
	if target == null or alliance == null or synergy == null or loadout == null:
		return {}

	local_driver_count = clampi(local_driver_count, 0, roster.get_count(&"Driver"))
	local_spy_count = clampi(local_spy_count, 0, roster.get_count(&"Spy"))

	var participants := alliance.build_participant_snapshot(local_driver_count, local_spy_count)
	_rebuild_synergy(participants)

	var raid_math := synergy.calculate_raid_damage()
	if float(raid_math["frontline_power"]) <= 0.0:
		return {}

	var target_data := target.get_battle_data()
	var weakness_role := StringName(target_data.get("weakness_role", ""))
	var weakness_matched := _role_is_present(weakness_role, raid_math)
	var weakness_multiplier := 1.0 + (
		float(target_data.get("weakness_bonus", 0.0)) if weakness_matched else 0.0
	)

	var equipment_role := loadout.equipped_role
	var equipment_matched := _role_is_present(equipment_role, raid_math)
	var equipment_multiplier := (
		loadout.get_role_equipment_multiplier(equipment_role)
		if equipment_matched
		else 1.0
	)

	var damage := float(raid_math["damage"])
	damage *= loadout.get_damage_multiplier()
	damage *= loadout.get_consumable_damage_multiplier()
	damage *= weakness_multiplier
	damage *= equipment_multiplier

	var target_hp := float(target_data.get("hp", target.get_max_hp()))

	return {
		"damage": damage,
		"target_hp": target_hp,
		"raid_math": raid_math,
		"participants": participants,
		"weakness_role": String(weakness_role),
		"weakness_matched": weakness_matched,
		"weakness_multiplier": weakness_multiplier,
		"equipment_role": String(equipment_role),
		"equipment_matched": equipment_matched,
		"equipment_multiplier": equipment_multiplier,
		"preset": loadout.get_preset_name(),
		"preset_damage_multiplier": loadout.get_damage_multiplier(),
		"reward_multiplier": loadout.get_reward_multiplier(),
		"wound_multiplier": loadout.get_wound_multiplier() * loadout.get_consumable_wound_multiplier(),
		"consumable": loadout.get_consumable_name(),
		"grade": _calculate_grade(damage, target_hp)
	}


func start_battle(target: RaidTarget, local_driver_count: int, local_spy_count: int) -> bool:
	if is_active() or target == null or not target.is_available() or not target.is_unlocked():
		return false
	if economy == null or roster == null or hospital == null or synergy == null or alliance == null or loadout == null:
		return false
	if not loadout.can_use_selected_consumable():
		return false

	var target_data := target.get_battle_data()
	var preview := preview_battle(target, local_driver_count, local_spy_count)
	if preview.is_empty():
		return false

	if not loadout.consume_selected_consumable():
		return false

	var raid_math: Dictionary = preview["raid_math"]

	active_battle = {
		"target_id": String(target_data["id"]),
		"target_name": String(target_data["name"]),
		"target_hp": float(target_data["hp"]),
		"reward_cash": int(target_data["reward_cash"]),
		"reward_xp": int(target_data.get("reward_xp", 0)),
		"difficulty": String(target_data["difficulty"]),
		"loot": (target_data.get("loot", {}) as Dictionary).duplicate(true),
		"local_drivers": local_driver_count,
		"local_spies": local_spy_count,
		"participants": (preview["participants"] as Array).duplicate(true),
		"calculated_damage": float(preview["damage"]),
		"contributions": (raid_math.get("contributions", {}) as Dictionary).duplicate(true),
		"support_bonus": float(raid_math["support_bonus"]),
		"weakness_role": String(preview["weakness_role"]),
		"weakness_matched": bool(preview["weakness_matched"]),
		"equipment_role": String(preview["equipment_role"]),
		"equipment_matched": bool(preview["equipment_matched"]),
		"preset": String(preview["preset"]),
		"consumable": String(preview["consumable"]),
		"reward_multiplier": float(preview["reward_multiplier"]),
		"wound_multiplier": float(preview["wound_multiplier"]),
		"grade": String(preview["grade"]),
		"seconds_remaining": launch_countdown_seconds
	}

	last_result.clear()
	_last_displayed_second = -1
	_offline_resolution_overrun = 0.0
	battle_started.emit(String(active_battle["target_id"]), launch_countdown_seconds)
	changed.emit()
	return true


func _resolve_active_battle() -> void:
	if active_battle.is_empty():
		return

	var damage := float(active_battle.get("calculated_damage", 0.0))
	var target_hp := float(active_battle["target_hp"])
	var victory := damage >= target_hp
	var reward_multiplier := float(active_battle.get("reward_multiplier", 1.0))
	var safehouse_multiplier := core_effects.get_raid_cash_multiplier() if core_effects != null else 1.0
	var reward_pool := roundi(float(active_battle["reward_cash"]) * reward_multiplier * safehouse_multiplier) if victory else 0
	var contributions: Dictionary = active_battle.get("contributions", {})
	var awarded_loot: Dictionary = {}

	var reward_splits := _calculate_reward_splits(
		reward_pool,
		contributions,
		active_battle.get("participants", [])
	)

	var local_cash_reward := int(reward_splits.get("local_player", 0))
	var local_participated := _local_player_participated()
	var xp_reward := 0

	if victory:
		if local_cash_reward > 0:
			economy.add_cash(local_cash_reward)

		if local_participated and progression != null:
			xp_reward = roundi(float(active_battle.get("reward_xp", 0)) * reward_multiplier)
			progression.add_xp(xp_reward)

		awarded_loot = (active_battle.get("loot", {}) as Dictionary).duplicate(true)

		if local_participated and loot_inventory != null:
			loot_inventory.add_loot(awarded_loot)
		else:
			awarded_loot.clear()

		var defeated_target: RaidTarget = city_map.get_raid_target_by_id(String(active_battle["target_id"]))
		if defeated_target != null:
			defeated_target.start_cooldown(_offline_resolution_overrun)

	var wounds := _apply_local_wounds(victory)

	last_result = {
		"victory": victory,
		"grade": String(active_battle.get("grade", _calculate_grade(damage, target_hp))),
		"target_id": String(active_battle["target_id"]),
		"target_name": String(active_battle["target_name"]),
		"target_hp": target_hp,
		"damage": damage,
		"reward_pool": reward_pool,
		"local_cash_reward": local_cash_reward,
		"xp_reward": xp_reward,
		"reward_splits": reward_splits,
		"contributions": contributions.duplicate(true),
		"participants": (active_battle.get("participants", []) as Array).duplicate(true),
		"loot": awarded_loot,
		"wounded_enforcers": int(wounds["Enforcer"]),
		"wounded_drivers": int(wounds["Driver"]),
		"wounded_spies": int(wounds["Spy"]),
		"injury_severity": String(wounds["severity"]),
		"support_bonus": float(active_battle.get("support_bonus", 0.0)),
		"weakness_role": String(active_battle.get("weakness_role", "")),
		"weakness_matched": bool(active_battle.get("weakness_matched", false)),
		"equipment_role": String(active_battle.get("equipment_role", "")),
		"equipment_matched": bool(active_battle.get("equipment_matched", false)),
		"preset": String(active_battle.get("preset", "Balanced")),
		"consumable": String(active_battle.get("consumable", "None"))
	}

	active_battle.clear()
	_last_displayed_second = -1
	_offline_resolution_overrun = 0.0
	battle_resolved.emit(last_result)
	changed.emit()


func _apply_local_wounds(victory: bool) -> Dictionary:
	var result := {"Enforcer": 0, "Driver": 0, "Spy": 0, "severity": "None"}
	var role := _get_local_role()
	if role == &"":
		return result

	var difficulty_multiplier := 1.0
	match String(active_battle.get("difficulty", "")):
		"Hard":
			difficulty_multiplier = 1.10
		"Elite":
			difficulty_multiplier = 1.25
		"Boss":
			difficulty_multiplier = 1.40
		"Mythic":
			difficulty_multiplier = 1.60

	var severity_multiplier := float(active_battle.get("wound_multiplier", 1.0))
	severity_multiplier *= difficulty_multiplier
	severity_multiplier *= 0.8 if victory else 1.25

	var should_wound := not victory or difficulty_multiplier >= 1.25
	if not should_wound:
		return result

	var severity_label := _severity_label(severity_multiplier)
	result["severity"] = severity_label

	if role == &"driver" and int(active_battle.get("local_drivers", 0)) > 0:
		result["Driver"] = 1
		hospital.send_to_hospital(&"Driver", 1, severity_multiplier, severity_label)
	elif role == &"spy" and int(active_battle.get("local_spies", 0)) > 0:
		result["Spy"] = 1
		hospital.send_to_hospital(&"Spy", 1, severity_multiplier, severity_label)

	return result


func _severity_label(multiplier: float) -> String:
	if multiplier < 0.85:
		return "Minor"
	if multiplier < 1.25:
		return "Standard"
	if multiplier < 1.70:
		return "Serious"
	return "Critical"


func _role_is_present(role: StringName, raid_math: Dictionary) -> bool:
	match role:
		&"Driver":
			return int(raid_math.get("driver_count", 0)) > 0
		&"Spy":
			return int(raid_math.get("spy_count", 0)) > 0
		&"Enforcer", &"frontline":
			return float(raid_math.get("frontline_power", 0.0)) > 0.0
		_:
			return false


func _calculate_grade(damage: float, target_hp: float) -> String:
	if target_hp <= 0.0:
		return "S"
	var ratio := damage / target_hp
	if ratio >= 1.35:
		return "S"
	if ratio >= 1.15:
		return "A"
	if ratio >= 1.0:
		return "B"
	if ratio >= 0.85:
		return "C"
	return "D"


func _rebuild_synergy(participants: Array) -> void:
	synergy.clear()
	for participant in participants:
		var role := StringName(participant.get("role", "frontline"))
		if bool(participant.get("is_local", false)):
			if role == &"driver" and int(participant.get("unit_count", 0)) <= 0:
				continue
			if role == &"spy" and int(participant.get("unit_count", 0)) <= 0:
				continue

		synergy.join_raid(
			String(participant.get("player_id", "")),
			int(participant.get("level", 1)),
			float(participant.get("base_power", 0.0)),
			role,
			String(participant.get("name", "Member"))
		)


func _calculate_reward_splits(reward_pool: int, contributions: Dictionary, participants: Array) -> Dictionary:
	var splits := {}
	if reward_pool <= 0 or participants.is_empty():
		return splits

	var participant_ids: Array[String] = []
	var total_contribution := 0.0

	for participant in participants:
		var player_id := String(participant.get("player_id", ""))
		if player_id == "" or not synergy.participants.has(player_id):
			continue
		participant_ids.append(player_id)
		total_contribution += maxf(0.0, float(contributions.get(player_id, 0.0)))

	if participant_ids.is_empty():
		return splits

	var equal_pool := float(reward_pool) * equal_reward_pool_share
	var performance_pool := float(reward_pool) - equal_pool
	var equal_each := equal_pool / float(participant_ids.size())
	var distributed := 0

	for i in range(participant_ids.size()):
		var player_id := participant_ids[i]
		var performance_share := 0.0
		if total_contribution > 0.0:
			performance_share = performance_pool * (
				float(contributions.get(player_id, 0.0)) / total_contribution
			)

		var share := roundi(equal_each + performance_share)
		if i == participant_ids.size() - 1:
			share = maxi(0, reward_pool - distributed)

		splits[player_id] = share
		distributed += share

	return splits


func _local_player_participated() -> bool:
	for participant in active_battle.get("participants", []):
		if String(participant.get("player_id", "")) == "local_player":
			return synergy.participants.has("local_player")
	return false


func _get_local_role() -> StringName:
	for participant in active_battle.get("participants", []):
		if String(participant.get("player_id", "")) == "local_player":
			return StringName(participant.get("role", ""))
	return &""


func get_save_data() -> Dictionary:
	return {
		"active": active_battle.duplicate(true),
		"last_result": last_result.duplicate(true)
	}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	active_battle.clear()
	last_result = data.get("last_result", {}).duplicate(true)
	_last_displayed_second = -1
	_offline_resolution_overrun = 0.0

	var saved_active = data.get("active", {})
	if not saved_active is Dictionary or saved_active.is_empty():
		changed.emit()
		return

	active_battle = saved_active.duplicate(true)
	var saved_remaining := float(active_battle.get("seconds_remaining", 0.0))
	_offline_resolution_overrun = maxf(0.0, offline_seconds - saved_remaining)
	active_battle["seconds_remaining"] = maxf(0.0, saved_remaining - maxf(0.0, offline_seconds))

	_rebuild_synergy(active_battle.get("participants", []))

	if float(active_battle["seconds_remaining"]) <= 0.0:
		_resolve_active_battle()
	else:
		changed.emit()
