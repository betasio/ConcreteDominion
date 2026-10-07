class_name PlayerProgression
extends Node

signal changed
signal leveled_up(new_level: int)
signal specialist_upgraded(role: StringName, new_level: int)

var account_level: int = 1
var current_xp: int = 0

var specialist_levels: Dictionary = {
	&"Enforcer": 1,
	&"Driver": 1,
	&"Spy": 1
}

var loot_inventory: LootInventory
var balance: GameBalance


func setup(loot: LootInventory, game_balance: GameBalance = null) -> void:
	loot_inventory = loot
	balance = game_balance


func get_xp_for_next_level() -> int:
	var base := 100.0 if balance == null else balance.get_progression_value("base_xp_to_level", 100.0)
	var step := 75.0 if balance == null else balance.get_progression_value("xp_step_per_level", 75.0)
	return roundi(base + float(account_level - 1) * step)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	current_xp += amount

	while current_xp >= get_xp_for_next_level():
		current_xp -= get_xp_for_next_level()
		account_level += 1
		leveled_up.emit(account_level)

	changed.emit()


func get_specialist_level(role: StringName) -> int:
	return int(specialist_levels.get(role, 1))


func get_driver_bonus() -> float:
	var base := 0.15 if balance == null else balance.get_progression_value("driver_base_bonus", 0.15)
	var step := 0.03 if balance == null else balance.get_progression_value("driver_bonus_per_level", 0.03)
	return base + float(get_specialist_level(&"Driver") - 1) * step


func get_spy_bonus() -> float:
	var base := 0.18 if balance == null else balance.get_progression_value("spy_base_bonus", 0.18)
	var step := 0.04 if balance == null else balance.get_progression_value("spy_bonus_per_level", 0.04)
	return base + float(get_specialist_level(&"Spy") - 1) * step


func get_enforcer_power_each() -> float:
	var base := 100.0 if balance == null else balance.get_progression_value("enforcer_base_power", 100.0)
	var step := 15.0 if balance == null else balance.get_progression_value("enforcer_power_per_level", 15.0)
	return base + float(get_specialist_level(&"Enforcer") - 1) * step


func get_upgrade_cost(role: StringName) -> Dictionary:
	var level := get_specialist_level(role)

	match role:
		&"Enforcer":
			return {"Parts": 2 + level}
		&"Driver":
			return {"Parts": 2 + level, "Intel": maxi(0, level - 1)}
		&"Spy":
			return {"Intel": 2 + level, "Contraband": maxi(0, level - 2)}
		_:
			return {}


func can_upgrade_specialist(role: StringName) -> bool:
	if loot_inventory == null:
		return false

	for item_name in get_upgrade_cost(role).keys():
		if loot_inventory.get_count(String(item_name)) < int(get_upgrade_cost(role)[item_name]):
			return false

	return true


func upgrade_specialist(role: StringName) -> bool:
	if not can_upgrade_specialist(role):
		return false

	var cost := get_upgrade_cost(role)
	if not loot_inventory.spend_loot(cost):
		return false

	var new_level := get_specialist_level(role) + 1
	specialist_levels[role] = new_level
	specialist_upgraded.emit(role, new_level)
	changed.emit()
	return true


func is_building_unlocked(building_name: String) -> bool:
	match building_name:
		"Garage":
			return account_level >= 2
		"Intel Office":
			return account_level >= 3
		_:
			return true


func get_building_unlock_level(building_name: String) -> int:
	match building_name:
		"Garage":
			return 2
		"Intel Office":
			return 3
		_:
			return 1


func get_save_data() -> Dictionary:
	return {
		"account_level": account_level,
		"current_xp": current_xp,
		"specialist_levels": {
			"Enforcer": get_specialist_level(&"Enforcer"),
			"Driver": get_specialist_level(&"Driver"),
			"Spy": get_specialist_level(&"Spy")
		}
	}


func load_save_data(data: Dictionary) -> void:
	account_level = maxi(1, int(data.get("account_level", account_level)))
	current_xp = maxi(0, int(data.get("current_xp", current_xp)))

	var saved_levels = data.get("specialist_levels", {})
	if saved_levels is Dictionary:
		specialist_levels[&"Enforcer"] = maxi(1, int(saved_levels.get("Enforcer", get_specialist_level(&"Enforcer"))))
		specialist_levels[&"Driver"] = maxi(1, int(saved_levels.get("Driver", get_specialist_level(&"Driver"))))
		specialist_levels[&"Spy"] = maxi(1, int(saved_levels.get("Spy", get_specialist_level(&"Spy"))))

	changed.emit()
