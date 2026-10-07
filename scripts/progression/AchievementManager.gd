class_name AchievementManager
extends Node

signal changed
signal achievement_unlocked(achievement_id: String)
signal dominion_completed

var progression: PlayerProgression
var alliance: AllianceManager
var city_map: Node
var world_control: WorldControlManager
var economy: PlayerEconomy

var unlocked: Dictionary = {}
var dominion_reward_claimed := false

var definitions: Dictionary = {
	"first_turf": {"title_key":"ACH_FIRST_TURF","desc_key":"ACH_DESC_FIRST_TURF","gold":5},
	"all_districts": {"title_key":"ACH_ALL_DISTRICTS","desc_key":"ACH_DESC_ALL_DISTRICTS","gold":20},
	"alliance_4": {"title_key":"ACH_ALLIANCE_4","desc_key":"ACH_DESC_ALLIANCE_4","gold":10},
	"account_7": {"title_key":"ACH_ACCOUNT_7","desc_key":"ACH_DESC_ACCOUNT_7","gold":10},
	"max_safehouse": {"title_key":"ACH_MAX_SAFEHOUSE","desc_key":"ACH_DESC_MAX_SAFEHOUSE","gold":10},
	"resource_network": {"title_key":"ACH_RESOURCE_NETWORK","desc_key":"ACH_DESC_RESOURCE_NETWORK","gold":8},
	"specialists_3": {"title_key":"ACH_SPECIALISTS_3","desc_key":"ACH_DESC_SPECIALISTS_3","gold":12},
	"dominion": {"title_key":"ACH_DOMINION","desc_key":"ACH_DESC_DOMINION","gold":100}
}


func setup(
	player_progression: PlayerProgression,
	alliance_manager: AllianceManager,
	world: Node,
	control: WorldControlManager,
	player_economy: PlayerEconomy
) -> void:
	progression = player_progression
	alliance = alliance_manager
	city_map = world
	world_control = control
	economy = player_economy

	progression.changed.connect(_evaluate)
	alliance.changed.connect(_evaluate)
	world_control.changed.connect(_evaluate)
	for building in city_map.get_persistent_buildings():
		building.changed.connect(_evaluate)

	_evaluate()


func _evaluate() -> void:
	if progression == null or alliance == null or city_map == null or world_control == null:
		return

	var owned_count := 0
	for target_id in world_control.owned.keys():
		if bool(world_control.owned[target_id]):
			owned_count += 1

	if owned_count >= 1:
		_unlock("first_turf")
	if owned_count >= 7:
		_unlock("all_districts")
	if alliance.alliance_level >= 4:
		_unlock("alliance_4")
	if progression.account_level >= 7:
		_unlock("account_7")
	if city_map.safehouse.level >= 5:
		_unlock("max_safehouse")
	if city_map.lot_c.is_built and city_map.lot_d.is_built:
		_unlock("resource_network")
	if (
		progression.get_specialist_level(&"Enforcer") >= 3
		and progression.get_specialist_level(&"Driver") >= 3
		and progression.get_specialist_level(&"Spy") >= 3
	):
		_unlock("specialists_3")

	if _meets_dominion_requirements():
		_unlock("dominion")
		if not dominion_reward_claimed:
			dominion_reward_claimed = true
			if economy != null:
				economy.add_gold(100)
			dominion_completed.emit()

	changed.emit()


func _meets_dominion_requirements() -> bool:
	var owned_count := 0
	for target_id in world_control.owned.keys():
		if bool(world_control.owned[target_id]):
			owned_count += 1

	return (
		owned_count >= 7
		and progression.account_level >= 7
		and alliance.alliance_level >= 4
		and city_map.safehouse.level >= 5
		and city_map.hospital.level >= 5
		and city_map.barracks.level >= 5
		and city_map.lot_a.level >= 3
		and city_map.lot_b.level >= 3
		and city_map.lot_c.is_built
		and city_map.lot_d.is_built
	)


func _unlock(achievement_id: String) -> void:
	if bool(unlocked.get(achievement_id, false)):
		return
	unlocked[achievement_id] = true
	var reward := int((definitions.get(achievement_id, {}) as Dictionary).get("gold", 0))
	if reward > 0 and economy != null and achievement_id != "dominion":
		economy.add_gold(reward)
	achievement_unlocked.emit(achievement_id)


func is_unlocked(achievement_id: String) -> bool:
	return bool(unlocked.get(achievement_id, false))


func get_progress_lines(text_catalog: LocalizedText) -> PackedStringArray:
	var lines := PackedStringArray()
	for achievement_id in definitions.keys():
		var def: Dictionary = definitions[achievement_id]
		var title := text_catalog.text(String(def["title_key"])) if text_catalog != null else String(def["title_key"])
		var description := text_catalog.text(String(def["desc_key"])) if text_catalog != null else String(def["desc_key"])
		var state := "UNLOCKED" if is_unlocked(String(achievement_id)) else "LOCKED"
		lines.append("%s — %s\n%s" % [title, state, description])
	return lines


func get_dominion_summary() -> String:
	if _meets_dominion_requirements():
		return "DOMINION COMPLETE — citywide control secured."
	return "ENDGAME: own all districts, reach Account Lv.7 + Alliance Lv.4, max core buildings, and establish all specialist/resource facilities."


func get_save_data() -> Dictionary:
	return {
		"unlocked": unlocked.duplicate(true),
		"dominion_reward_claimed": dominion_reward_claimed
	}


func load_save_data(data: Dictionary) -> void:
	var saved = data.get("unlocked", {})
	if saved is Dictionary:
		unlocked = saved.duplicate(true)
	dominion_reward_claimed = bool(data.get("dominion_reward_claimed", false))
	changed.emit()
