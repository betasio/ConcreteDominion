class_name EndgameManager
extends Node

signal changed
signal dominion_cache_claimed
signal dominion_mastery_claimed

const WEEKLY_REQUIRED := 2
const FAMILY_OPERATION_GOAL := 3
const BOSS_REMATCH_GOAL := 1
const FACTION_WAR_GOAL := 1

const TARGET_ROTATION := [
	"downtown_bank",
	"harbor_bank",
	"midtown_exchange",
	"northside_hq",
	"casino_vault",
	"financial_tower",
	"industrial_depot"
]

var missions: MissionTracker
var world_control: WorldControlManager
var faction: FactionManager
var economy: PlayerEconomy
var loot: LootInventory
var progression: PlayerProgression

var weekly_period := -1
var family_operation_wins := 0
var boss_rematch_wins := 0
var faction_war_wins := 0
var weekly_claimed := false
var mastery_claimed := false
var dominion_marks := 0
var cycles_completed := 0
var operation_cursor := 0
var boss_cursor := 0
var active_boss_target := ""


func setup(
	mission_tracker: MissionTracker,
	control: WorldControlManager,
	faction_manager: FactionManager,
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	player_progression: PlayerProgression
) -> void:
	missions = mission_tracker
	world_control = control
	faction = faction_manager
	economy = player_economy
	loot = loot_inventory
	progression = player_progression

	world_control.family_encounter_resolved.connect(_on_family_encounter_resolved)
	faction.war_completed.connect(_on_faction_war_completed)
	missions.mission_completed.connect(_on_mission_completed)
	_refresh_week()
	changed.emit()


func _process(delta: float) -> void:
	_period_check_accumulator += delta
	if _period_check_accumulator < 30.0:
		return
	_period_check_accumulator = 0.0
	_refresh_week()


var _period_check_accumulator := 0.0


func is_unlocked() -> bool:
	return missions != null and bool(missions.missions.get("chapter_6_complete", {}).get("completed", false))


func _get_week_index() -> int:
	return floori(float(floori(Time.get_unix_time_from_system() / 86400.0)) / 7.0)


func _refresh_week() -> void:
	var week := _get_week_index()
	if weekly_period == week:
		return
	weekly_period = week
	family_operation_wins = 0
	boss_rematch_wins = 0
	faction_war_wins = 0
	weekly_claimed = false
	mastery_claimed = false
	active_boss_target = ""
	changed.emit()


func _completed_tracks() -> int:
	var completed := 0
	if family_operation_wins >= FAMILY_OPERATION_GOAL:
		completed += 1
	if boss_rematch_wins >= BOSS_REMATCH_GOAL:
		completed += 1
	if faction_war_wins >= FACTION_WAR_GOAL:
		completed += 1
	return completed


func get_status() -> Dictionary:
	_refresh_week()
	return {
		"unlocked": is_unlocked(),
		"completed_tracks": _completed_tracks(),
		"required_tracks": WEEKLY_REQUIRED,
		"family_wins": family_operation_wins,
		"family_goal": FAMILY_OPERATION_GOAL,
		"boss_wins": boss_rematch_wins,
		"boss_goal": BOSS_REMATCH_GOAL,
		"war_wins": faction_war_wins,
		"war_goal": FACTION_WAR_GOAL,
		"claimable": is_unlocked() and _completed_tracks() >= WEEKLY_REQUIRED and not weekly_claimed,
		"mastery_claimable": is_unlocked() and _completed_tracks() >= 3 and not mastery_claimed,
		"claimed": weekly_claimed,
		"mastery_claimed": mastery_claimed,
		"dominion_marks": dominion_marks,
		"rank": get_dominion_rank(),
		"cycles_completed": cycles_completed
	}


func get_dominion_rank() -> String:
	if dominion_marks >= 1500:
		return "SOVEREIGN"
	if dominion_marks >= 750:
		return "REGENT"
	if dominion_marks >= 300:
		return "KINGPIN"
	return "OPERATOR"


func get_contract_lines() -> PackedStringArray:
	return PackedStringArray([
		"Rival Family Operations — %d/%d wins" % [family_operation_wins, FAMILY_OPERATION_GOAL],
		"Boss Rematch — %d/%d win" % [boss_rematch_wins, BOSS_REMATCH_GOAL],
		"Faction War — %d/%d victory" % [faction_war_wins, FACTION_WAR_GOAL]
	])


func launch_rival_operation() -> bool:
	if not is_unlocked() or world_control == null or not world_control.active_patrol.is_empty():
		return false
	for offset in range(TARGET_ROTATION.size()):
		var index := (operation_cursor + offset) % TARGET_ROTATION.size()
		var target_id := String(TARGET_ROTATION[index])
		if not world_control.is_discovered(target_id):
			continue
		var encounter_type := world_control.family_rules.get_preferred_encounter(target_id)
		operation_cursor = (index + 1) % TARGET_ROTATION.size()
		if world_control.launch_family_operation(target_id, encounter_type):
			changed.emit()
			return true
	return false


func launch_boss_rematch() -> bool:
	if not is_unlocked() or world_control == null or not world_control.active_patrol.is_empty():
		return false
	for offset in range(TARGET_ROTATION.size()):
		var index := (boss_cursor + offset) % TARGET_ROTATION.size()
		var target_id := String(TARGET_ROTATION[index])
		if not world_control.is_discovered(target_id):
			continue
		if world_control.launch_boss_rematch(target_id):
			boss_cursor = (index + 1) % TARGET_ROTATION.size()
			active_boss_target = target_id
			changed.emit()
			return true
	return false


func claim_weekly_cache() -> bool:
	var status := get_status()
	if not bool(status["claimable"]):
		return false
	weekly_claimed = true
	dominion_marks += 100
	cycles_completed += 1
	economy.add_cash(15000)
	economy.add_gold(10)
	loot.add_loot({"Parts":3,"Intel":2})
	progression.add_xp(250)
	dominion_cache_claimed.emit()
	changed.emit()
	return true


func claim_mastery() -> bool:
	var status := get_status()
	if not bool(status["mastery_claimable"]):
		return false
	mastery_claimed = true
	dominion_marks += 50
	economy.add_cash(10000)
	economy.add_gold(10)
	loot.add_loot({"Contraband":1,"Intel":2})
	progression.add_xp(150)
	dominion_mastery_claimed.emit()
	changed.emit()
	return true


func _on_family_encounter_resolved(district_id: String, _encounter_type: String, victory: bool) -> void:
	if not is_unlocked() or not victory:
		if district_id == active_boss_target:
			active_boss_target = ""
		return
	family_operation_wins = mini(FAMILY_OPERATION_GOAL, family_operation_wins + 1)
	if district_id == active_boss_target:
		boss_rematch_wins = mini(BOSS_REMATCH_GOAL, boss_rematch_wins + 1)
		active_boss_target = ""
	changed.emit()


func _on_faction_war_completed(won: bool, _season_points_awarded: int) -> void:
	if not is_unlocked() or not won:
		return
	faction_war_wins = mini(FACTION_WAR_GOAL, faction_war_wins + 1)
	changed.emit()


func _on_mission_completed(mission_id: String) -> void:
	if mission_id == "chapter_6_complete":
		_refresh_week()
		changed.emit()


func get_save_data() -> Dictionary:
	return {
		"weekly_period": weekly_period,
		"family_operation_wins": family_operation_wins,
		"boss_rematch_wins": boss_rematch_wins,
		"faction_war_wins": faction_war_wins,
		"weekly_claimed": weekly_claimed,
		"mastery_claimed": mastery_claimed,
		"dominion_marks": dominion_marks,
		"cycles_completed": cycles_completed,
		"operation_cursor": operation_cursor,
		"boss_cursor": boss_cursor,
		"active_boss_target": active_boss_target
	}


func load_save_data(data: Dictionary) -> void:
	weekly_period = int(data.get("weekly_period", weekly_period))
	family_operation_wins = clampi(int(data.get("family_operation_wins", 0)), 0, FAMILY_OPERATION_GOAL)
	boss_rematch_wins = clampi(int(data.get("boss_rematch_wins", 0)), 0, BOSS_REMATCH_GOAL)
	faction_war_wins = clampi(int(data.get("faction_war_wins", 0)), 0, FACTION_WAR_GOAL)
	weekly_claimed = bool(data.get("weekly_claimed", false))
	mastery_claimed = bool(data.get("mastery_claimed", false))
	dominion_marks = maxi(0, int(data.get("dominion_marks", 0)))
	cycles_completed = maxi(0, int(data.get("cycles_completed", 0)))
	operation_cursor = posmod(int(data.get("operation_cursor", 0)), TARGET_ROTATION.size())
	boss_cursor = posmod(int(data.get("boss_cursor", 0)), TARGET_ROTATION.size())
	active_boss_target = String(data.get("active_boss_target", ""))
	_refresh_week()
	changed.emit()
