class_name WorldControlManager
extends Node

signal changed
signal district_discovered(district_id: String)
signal district_captured(district_id: String)
signal patrol_spawned(district_id: String)
signal patrol_resolved(district_id: String, victory: bool)
signal family_encounter_resolved(district_id: String, encounter_type: String, victory: bool)
signal alliance_task_completed(task_id: String)
signal task_cycle_refreshed

const PRODUCTION_CAP_SECONDS := 8.0 * 60.0 * 60.0
const PATROL_INTERVAL_SECONDS := 90.0
const COMMAND_SCAN_COOLDOWN_SECONDS := 10.0 * 60.0
const TASK_CYCLE_SECONDS := 24.0 * 60.0 * 60.0
const PRESSURE_PER_SECOND := 0.0015

var economy: PlayerEconomy
var loot: LootInventory
var progression: PlayerProgression
var roster: TroopRoster
var hospital: HospitalQueue
var alliance: AllianceManager
var city_map: Node
var core_effects: CoreBuildingEffects
var family_rules: RivalFamilyRules
var faction: FactionManager

var discovered: Dictionary = {"downtown_bank": true}
var owned: Dictionary = {}
var pressure: Dictionary = {}
var contested: Dictionary = {}
var production_bank: float = 0.0
var production_elapsed: float = 0.0
var patrol_elapsed: float = 0.0
var command_scan_remaining: float = 0.0
var task_cycle_remaining: float = TASK_CYCLE_SECONDS
var active_patrol: Dictionary = {}
var _encounter_cursor := 0

var faction_rivalry: Dictionary = {
	"dock_rats": 0,
	"iron_serpents": 0,
	"meridian_boys": 0,
	"northside_crew": 0,
	"velvet_circle": 0
}

var factions: Dictionary = {
	"downtown_bank": "Dock Rats",
	"harbor_bank": "Iron Serpents",
	"midtown_exchange": "Meridian Boys",
	"northside_hq": "Northside Crew",
	"casino_vault": "Velvet Circle",
	"financial_tower": "Velvet Circle",
	"industrial_depot": "Iron Serpents"
}

var alliance_tasks: Dictionary = {
	"raid_wins": {
		"title": "Hit the Streets",
		"goal": 3,
		"progress": 0,
		"completed": false,
		"alliance_xp": 70,
		"cash": 4000
	},
	"collect_income": {
		"title": "Keep It Moving",
		"goal": 2,
		"progress": 0,
		"completed": false,
		"alliance_xp": 55,
		"cash": 3000
	},
	"clear_patrols": {
		"title": "Clean the Block",
		"goal": 2,
		"progress": 0,
		"completed": false,
		"alliance_xp": 85,
		"cash": 5000
	}
}

var districts: Dictionary = {
	"downtown_bank": {"name":"Downtown Core","level":1,"intel":0,"cash_per_hour":600,"patrol_power":700},
	"harbor_bank": {"name":"Harbor District","level":2,"intel":1,"cash_per_hour":850,"patrol_power":1050},
	"midtown_exchange": {"name":"Midtown","level":3,"intel":1,"cash_per_hour":1100,"patrol_power":1350},
	"northside_hq": {"name":"Northside","level":4,"intel":2,"cash_per_hour":1450,"patrol_power":1700},
	"casino_vault": {"name":"High Roller Strip","level":5,"intel":2,"cash_per_hour":1800,"patrol_power":2150},
	"financial_tower": {"name":"Financial District","level":6,"intel":3,"cash_per_hour":2300,"patrol_power":2600},
	"industrial_depot": {"name":"Industrial Belt","level":7,"intel":3,"cash_per_hour":2900,"patrol_power":3200}
}


func setup(
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	player_progression: PlayerProgression,
	troop_roster: TroopRoster,
	hospital_queue: HospitalQueue,
	alliance_manager: AllianceManager,
	world: Node,
	building_effects: CoreBuildingEffects,
	rules: RivalFamilyRules,
	faction_manager: FactionManager,
	raid_battle: RaidBattle
) -> void:
	economy = player_economy
	loot = loot_inventory
	progression = player_progression
	roster = troop_roster
	hospital = hospital_queue
	alliance = alliance_manager
	city_map = world
	core_effects = building_effects
	family_rules = rules
	faction = faction_manager

	raid_battle.battle_resolved.connect(_on_raid_resolved)
	progression.leveled_up.connect(_on_progression_changed)
	_apply_discovery_visibility()
	changed.emit()


func _process(delta: float) -> void:
	if economy == null:
		return

	var did_change := false

	if command_scan_remaining > 0.0:
		command_scan_remaining = maxf(0.0, command_scan_remaining - delta)

	task_cycle_remaining -= delta
	if task_cycle_remaining <= 0.0:
		_reset_task_cycle()
		did_change = true

	if not owned.is_empty():
		var before_bank := production_bank
		var cap_amount := float(get_base_income_per_hour()) * (PRODUCTION_CAP_SECONDS / 3600.0)
		production_bank = minf(
			cap_amount,
			production_bank + float(get_income_per_hour()) * (delta / 3600.0)
		)
		production_elapsed = minf(PRODUCTION_CAP_SECONDS, production_elapsed + delta)
		if floori(before_bank) != floori(production_bank):
			did_change = true

		for target_id in owned.keys():
			if not bool(owned[target_id]):
				continue
			var current := float(pressure.get(target_id, 0.0))
			if not bool(contested.get(target_id, false)):
				var pressure_multiplier := family_rules.get_pressure_multiplier(String(target_id)) if family_rules != null else 1.0
				current = minf(1.0, current + delta * PRESSURE_PER_SECOND * pressure_multiplier)
				pressure[target_id] = current
				if current >= 1.0:
					contested[target_id] = true
					if active_patrol.is_empty():
						_spawn_contested_event(String(target_id))
					did_change = true

		if active_patrol.is_empty():
			patrol_elapsed += delta
			if patrol_elapsed >= PATROL_INTERVAL_SECONDS:
				_spawn_patrol()
				patrol_elapsed = 0.0
				did_change = true

	if did_change:
		changed.emit()


func is_discovered(target_id: String) -> bool:
	return bool(discovered.get(target_id, false))


func is_owned(target_id: String) -> bool:
	return bool(owned.get(target_id, false))


func is_contested(target_id: String) -> bool:
	return bool(contested.get(target_id, false))


func get_pressure(target_id: String) -> float:
	return clampf(float(pressure.get(target_id, 0.0)), 0.0, 1.0)


func get_owner_label(target_id: String) -> String:
	if is_owned(target_id):
		return "YOUR TURF • CONTESTED" if is_contested(target_id) else "YOUR TURF"
	return String(factions.get(target_id, "Rival Crew")).to_upper()


func get_rival_faction(target_id: String) -> String:
	if family_rules != null:
		return family_rules.get_faction_name(target_id)
	return String(factions.get(target_id, "Rival Crew"))


func get_rival_family_id(target_id: String) -> String:
	return family_rules.get_faction_id(target_id) if family_rules != null else ""


func get_rival_trait(target_id: String) -> String:
	return family_rules.get_trait_name(target_id) if family_rules != null else ""


func get_rivalry_score(target_id: String) -> int:
	var family_id := family_rules.get_faction_id(target_id) if family_rules != null else ""
	return int(faction_rivalry.get(family_id, 0))


func get_rivalry_label(target_id: String) -> String:
	var score := get_rivalry_score(target_id)
	if score >= 5:
		return "VENDETTA"
	if score >= 3:
		return "HOSTILE"
	if score >= 1:
		return "NOTICED"
	return "COLD"


func get_rivalry_reward_multiplier(target_id: String) -> float:
	return 1.0 + minf(0.25, float(get_rivalry_score(target_id)) * 0.05)


func get_faction_dossier(target_id: String) -> Dictionary:
	if family_rules == null or not districts.has(target_id):
		return {}
	var data: Dictionary = districts[target_id]
	return {
		"target_id": target_id,
		"district": String(data["name"]),
		"faction": get_rival_faction(target_id),
		"trait": get_rival_trait(target_id),
		"boss": family_rules.get_boss_name(target_id),
		"boss_title": family_rules.get_boss_title(target_id),
		"boss_quote": family_rules.get_boss_quote(target_id),
		"perk": family_rules.get_perk_summary(target_id),
		"preferred_encounter": family_rules.get_preferred_encounter(target_id),
		"rivalry": get_rivalry_label(target_id),
		"rivalry_score": get_rivalry_score(target_id),
		"feud_bonus_percent": roundi((get_rivalry_reward_multiplier(target_id) - 1.0) * 100.0),
		"base_cash_bonus_percent": family_rules.get_reward_bonus_percent(target_id),
		"power_modifier_percent": family_rules.get_power_modifier_percent(target_id)
	}


func get_rivalry_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var seen_families := {}
	for target_id in _ordered_ids():
		if not is_discovered(target_id):
			continue
		var family_id := family_rules.get_faction_id(target_id) if family_rules != null else target_id
		if seen_families.has(family_id):
			continue
		seen_families[family_id] = true
		var dossier := get_faction_dossier(target_id)
		if dossier.is_empty():
			continue
		lines.append("%s — %s, %s — %s %d/10 — feud rewards +%d%%" % [
			String(dossier["faction"]),
			String(dossier["boss"]),
			String(dossier["boss_title"]),
			String(dossier["rivalry"]),
			int(dossier["rivalry_score"]),
			int(dossier["feud_bonus_percent"])
		])
	if lines.is_empty():
		lines.append("No rival dossiers revealed.")
	return lines


func get_capture_victory_summary(target_id: String) -> Dictionary:
	var dossier := get_faction_dossier(target_id)
	if dossier.is_empty():
		return {}
	var data: Dictionary = districts[target_id]
	dossier["income_per_hour"] = int(data["cash_per_hour"])
	dossier["victory_line"] = "%s has been taken from %s. Turf income unlocked: $%d/hr." % [
		String(data["name"]),
		String(dossier["faction"]),
		int(data["cash_per_hour"])
	]
	return dossier


func _increase_rivalry(target_id: String, amount: int = 1) -> void:
	if family_rules == null:
		return
	var family_id := family_rules.get_faction_id(target_id)
	faction_rivalry[family_id] = mini(10, int(faction_rivalry.get(family_id, 0)) + maxi(0, amount))


func can_discover(target_id: String) -> bool:
	if is_discovered(target_id) or not districts.has(target_id) or progression == null:
		return false
	var data: Dictionary = districts[target_id]
	return progression.account_level >= int(data["level"])


func discover_with_intel(target_id: String) -> bool:
	if not can_discover(target_id) or loot == null:
		return false
	var cost := int((districts[target_id] as Dictionary)["intel"])
	if cost > 0 and not loot.spend_loot({"Intel": cost}):
		return false
	_discover(target_id)
	return true


func command_scan() -> bool:
	if command_scan_remaining > 0.0:
		return false
	var next_id := _get_next_discoverable_target()
	if next_id == "":
		return false

	_discover(next_id)
	var safehouse_level := core_effects.safehouse.level if core_effects != null and core_effects.safehouse != null else 1
	command_scan_remaining = maxf(180.0, COMMAND_SCAN_COOLDOWN_SECONDS - float(safehouse_level - 1) * 60.0)
	changed.emit()
	return true


func collect_income() -> int:
	var amount := floori(production_bank)
	if amount <= 0 or economy == null:
		return 0
	economy.add_cash(amount)
	production_bank = 0.0
	production_elapsed = 0.0
	_add_task_progress("collect_income", 1)
	changed.emit()
	return amount


func get_income_per_hour() -> int:
	var total := 0
	for target_id in owned.keys():
		if bool(owned[target_id]) and districts.has(target_id):
			var rate := int((districts[target_id] as Dictionary)["cash_per_hour"])
			if is_contested(String(target_id)):
				rate = roundi(float(rate) * 0.65)
			total += rate
	if faction != null and faction.has_faction():
		total = roundi(
			float(total)
			* faction.get_territory_income_multiplier()
			* faction.get_territory_cash_multiplier()
		)
	return total


func get_base_income_per_hour() -> int:
	var total := 0
	for target_id in owned.keys():
		if bool(owned[target_id]) and districts.has(target_id):
			total += int((districts[target_id] as Dictionary)["cash_per_hour"])
	return total


func resolve_patrol() -> Dictionary:
	if active_patrol.is_empty() or roster == null:
		return {}

	var target_id := String(active_patrol["district_id"])
	var encounter_type := String(active_patrol.get("type", "roadblock"))
	var required_power := float(active_patrol["power"])
	var role := StringName(active_patrol.get("role", "Enforcer"))
	var count := roster.get_count(role)
	var unit_power := _get_unit_power(role)
	var player_power := float(count) * unit_power
	var victory := player_power >= required_power
	var cash_reward := int(active_patrol.get("cash_reward", 0)) if victory else 0

	if victory:
		_increase_rivalry(target_id)
		economy.add_cash(cash_reward)
		if loot != null:
			if encounter_type == "surveillance":
				loot.add_item("Intel", 1)
			elif encounter_type == "convoy_ambush":
				loot.add_item("Parts", 1)
		if encounter_type == "turf_push":
			contested[target_id] = false
			pressure[target_id] = 0.15
		else:
			pressure[target_id] = maxf(0.0, get_pressure(target_id) - 0.20)
		_add_task_progress("clear_patrols", 1)
	else:
		var wounded := mini(1, count)
		if wounded > 0 and hospital != null:
			hospital.send_to_hospital(role, wounded, 1.1 if encounter_type != "turf_push" else 1.3, "Standard")
		if encounter_type == "turf_push":
			pressure[target_id] = 0.80

	active_patrol.clear()
	patrol_elapsed = 0.0
	patrol_resolved.emit(target_id, victory)
	family_encounter_resolved.emit(target_id, encounter_type, victory)
	changed.emit()

	return {
		"victory": victory,
		"district_id": target_id,
		"encounter_type": encounter_type,
		"role": String(role),
		"player_power": player_power,
		"required_power": required_power,
		"cash_reward": cash_reward
	}


func get_district_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for target_id in _ordered_ids():
		var data: Dictionary = districts[target_id]
		var state := "FOG"
		if is_owned(target_id):
			state = "CONTESTED %d%%" % roundi(get_pressure(target_id) * 100.0) if is_contested(target_id) else "OWNED %d%%" % roundi(get_pressure(target_id) * 100.0)
		elif is_discovered(target_id):
			state = "RIVAL: %s • %s • %s" % [
				get_rival_faction(target_id),
				get_rival_trait(target_id),
				get_rivalry_label(target_id)
			]
		lines.append("%s — %s — $%d/hr" % [
			String(data["name"]),
			state,
			int(data["cash_per_hour"])
		])
	return lines


func get_task_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for task_id in alliance_tasks.keys():
		var task: Dictionary = alliance_tasks[task_id]
		var state := "DONE" if bool(task["completed"]) else "%d/%d" % [
			int(task["progress"]),
			int(task["goal"])
		]
		lines.append("%s — %s" % [String(task["title"]), state])
	return lines


func get_task_cycle_remaining() -> float:
	return maxf(0.0, task_cycle_remaining)


func has_discoverable_target() -> bool:
	return _get_next_discoverable_target() != ""


func get_next_discovery_summary() -> String:
	var target_id := _get_next_discoverable_target()
	if target_id == "":
		return "No eligible fogged district."
	var data: Dictionary = districts[target_id]
	return "%s — %s — Intel x%d" % [
		String(data["name"]),
		get_rival_faction(target_id),
		int(data["intel"])
	]


func discover_next_with_intel() -> bool:
	var target_id := _get_next_discoverable_target()
	return target_id != "" and discover_with_intel(target_id)


func can_launch_family_operation(target_id: String, encounter_type: String) -> bool:
	if not active_patrol.is_empty() or not is_discovered(target_id) or family_rules == null:
		return false
	return encounter_type in family_rules.get_encounter_cycle(target_id)


func launch_family_operation(target_id: String, encounter_type: String) -> bool:
	if not can_launch_family_operation(target_id, encounter_type):
		return false
	_create_encounter(target_id, encounter_type, 1.0)
	changed.emit()
	return true


func _on_raid_resolved(result: Dictionary) -> void:
	if not bool(result.get("victory", false)):
		return
	var target_id := String(result.get("target_id", ""))
	if not districts.has(target_id):
		return

	_add_task_progress("raid_wins", 1)
	_increase_rivalry(target_id)
	if not is_owned(target_id):
		owned[target_id] = true
		pressure[target_id] = 0.0
		contested[target_id] = false
		if not is_discovered(target_id):
			discovered[target_id] = true
		district_captured.emit(target_id)
	_apply_discovery_visibility()
	changed.emit()


func _spawn_patrol() -> void:
	var owned_ids: Array[String] = []
	for target_id in _ordered_ids():
		if is_owned(target_id) and not is_contested(target_id):
			owned_ids.append(target_id)
	if owned_ids.is_empty():
		return

	var target_id := owned_ids[_encounter_cursor % owned_ids.size()]
	var cycle := family_rules.get_encounter_cycle(target_id) if family_rules != null else ["roadblock", "surveillance", "convoy_ambush"]
	var encounter_type := String(cycle[_encounter_cursor % cycle.size()])
	_encounter_cursor += 1
	_create_encounter(target_id, encounter_type, 1.0)


func _spawn_contested_event(target_id: String) -> void:
	_create_encounter(target_id, "turf_push", 1.25)


func _create_encounter(target_id: String, encounter_type: String, power_multiplier: float) -> void:
	if not districts.has(target_id):
		return
	var data: Dictionary = districts[target_id]
	var faction_power := family_rules.get_encounter_power_multiplier(target_id) if family_rules != null else 1.0
	var faction_cash := family_rules.get_cash_multiplier(target_id) if family_rules != null else 1.0
	var role := &"Enforcer"
	match encounter_type:
		"surveillance":
			role = &"Spy"
		"convoy_ambush":
			role = &"Driver"
		_:
			role = &"Enforcer"

	active_patrol = {
		"district_id": target_id,
		"district_name": String(data["name"]),
		"faction": get_rival_faction(target_id),
		"type": encounter_type,
		"role": role,
		"power": roundi(float(data["patrol_power"]) * power_multiplier * faction_power),
		"cash_reward": roundi(
			float(data["cash_per_hour"])
			* (1.0 if encounter_type == "turf_push" else 0.75)
			* faction_cash
			* get_rivalry_reward_multiplier(target_id)
		),
		"trait": get_rival_trait(target_id)
	}
	patrol_spawned.emit(target_id)


func _get_unit_power(role: StringName) -> float:
	match role:
		&"Enforcer":
			return progression.get_enforcer_power_each() if progression != null else 100.0
		&"Driver":
			return 240.0 + float(progression.get_specialist_level(&"Driver") - 1) * 35.0 if progression != null else 240.0
		&"Spy":
			return 260.0 + float(progression.get_specialist_level(&"Spy") - 1) * 40.0 if progression != null else 260.0
		_:
			return 100.0


func _discover(target_id: String) -> void:
	discovered[target_id] = true
	_apply_discovery_visibility()
	district_discovered.emit(target_id)
	changed.emit()


func _get_next_discoverable_target() -> String:
	for target_id in _ordered_ids():
		if can_discover(target_id):
			return target_id
	return ""


func _ordered_ids() -> Array[String]:
	return [
		"downtown_bank",
		"harbor_bank",
		"midtown_exchange",
		"northside_hq",
		"casino_vault",
		"financial_tower",
		"industrial_depot"
	]


func refresh_visibility() -> void:
	_apply_discovery_visibility()


func _apply_discovery_visibility() -> void:
	if city_map == null:
		return
	for target in city_map.get_raid_targets():
		target.visible = is_discovered(target.get_target_id()) and city_map.get_view_mode() == &"world"


func _on_progression_changed(_new_level: int) -> void:
	changed.emit()


func _add_task_progress(task_id: String, amount: int) -> void:
	if not alliance_tasks.has(task_id):
		return
	var task: Dictionary = alliance_tasks[task_id]
	if bool(task["completed"]):
		return
	task["progress"] = mini(int(task["goal"]), int(task["progress"]) + maxi(0, amount))
	if int(task["progress"]) >= int(task["goal"]):
		task["completed"] = true
		if alliance != null:
			alliance.award_alliance_xp(int(task["alliance_xp"]))
		if economy != null:
			economy.add_cash(int(task["cash"]))
		alliance_task_completed.emit(task_id)


func _reset_task_cycle() -> void:
	for task_id in alliance_tasks.keys():
		alliance_tasks[task_id]["progress"] = 0
		alliance_tasks[task_id]["completed"] = false
	task_cycle_remaining = TASK_CYCLE_SECONDS
	task_cycle_refreshed.emit()


func get_save_data() -> Dictionary:
	return {
		"discovered": discovered.duplicate(true),
		"owned": owned.duplicate(true),
		"pressure": pressure.duplicate(true),
		"contested": contested.duplicate(true),
		"production_elapsed": production_elapsed,
		"production_bank": production_bank,
		"patrol_elapsed": patrol_elapsed,
		"command_scan_remaining": command_scan_remaining,
		"task_cycle_remaining": task_cycle_remaining,
		"active_patrol": active_patrol.duplicate(true),
		"encounter_cursor": _encounter_cursor,
		"faction_rivalry": faction_rivalry.duplicate(true),
		"alliance_tasks": _get_task_save()
	}


func _get_task_save() -> Dictionary:
	var saved := {}
	for task_id in alliance_tasks.keys():
		var task: Dictionary = alliance_tasks[task_id]
		saved[task_id] = {
			"progress": int(task["progress"]),
			"completed": bool(task["completed"])
		}
	return saved


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	var saved_discovered = data.get("discovered", {})
	if saved_discovered is Dictionary and not saved_discovered.is_empty():
		discovered = saved_discovered.duplicate(true)
	discovered["downtown_bank"] = true

	var saved_owned = data.get("owned", {})
	if saved_owned is Dictionary:
		owned = saved_owned.duplicate(true)

	var saved_pressure = data.get("pressure", {})
	if saved_pressure is Dictionary:
		pressure = saved_pressure.duplicate(true)
	var saved_contested = data.get("contested", {})
	if saved_contested is Dictionary:
		contested = saved_contested.duplicate(true)

	production_elapsed = minf(
		PRODUCTION_CAP_SECONDS,
		float(data.get("production_elapsed", 0.0)) + maxf(0.0, offline_seconds)
	)
	production_bank = maxf(0.0, float(data.get("production_bank", 0.0)))
	var offline_income := float(get_income_per_hour()) * (minf(PRODUCTION_CAP_SECONDS, maxf(0.0, offline_seconds)) / 3600.0)
	var cap_amount := float(get_base_income_per_hour()) * (PRODUCTION_CAP_SECONDS / 3600.0)
	production_bank = minf(cap_amount, production_bank + offline_income)
	patrol_elapsed = fmod(float(data.get("patrol_elapsed", 0.0)) + maxf(0.0, offline_seconds), PATROL_INTERVAL_SECONDS)
	command_scan_remaining = maxf(0.0, float(data.get("command_scan_remaining", 0.0)) - maxf(0.0, offline_seconds))

	var offline := maxf(0.0, offline_seconds)
	for target_id in owned.keys():
		if not bool(owned[target_id]) or bool(contested.get(target_id, false)):
			continue
		var pressure_multiplier := family_rules.get_pressure_multiplier(String(target_id)) if family_rules != null else 1.0
		var offline_pressure := minf(
			0.99,
			float(pressure.get(target_id, 0.0))
			+ minf(offline, 4.0 * 60.0 * 60.0) * PRESSURE_PER_SECOND * pressure_multiplier
		)
		pressure[target_id] = offline_pressure

	var saved_rivalry = data.get("faction_rivalry", {})
	if saved_rivalry is Dictionary:
		for family_id in faction_rivalry.keys():
			faction_rivalry[family_id] = clampi(int(saved_rivalry.get(family_id, faction_rivalry[family_id])), 0, 10)

	var saved_tasks = data.get("alliance_tasks", {})
	if saved_tasks is Dictionary:
		for task_id in alliance_tasks.keys():
			if saved_tasks.has(task_id) and saved_tasks[task_id] is Dictionary:
				alliance_tasks[task_id]["progress"] = int(saved_tasks[task_id].get("progress", alliance_tasks[task_id]["progress"]))
				alliance_tasks[task_id]["completed"] = bool(saved_tasks[task_id].get("completed", alliance_tasks[task_id]["completed"]))

	task_cycle_remaining = float(data.get("task_cycle_remaining", TASK_CYCLE_SECONDS)) - offline
	if task_cycle_remaining <= 0.0:
		_reset_task_cycle()

	var saved_patrol = data.get("active_patrol", {})
	active_patrol = saved_patrol.duplicate(true) if saved_patrol is Dictionary else {}
	_encounter_cursor = maxi(0, int(data.get("encounter_cursor", 0)))

	if active_patrol.is_empty():
		for target_id in _ordered_ids():
			if is_owned(target_id) and is_contested(target_id):
				_spawn_contested_event(target_id)
				break

	_apply_discovery_visibility()
	changed.emit()
