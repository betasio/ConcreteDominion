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


func setup(loot: LootInventory) -> void:
	loot_inventory = loot


func get_xp_for_next_level() -> int:
	return 100 + (account_level - 1) * 75


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
	return 0.15 + float(get_specialist_level(&"Driver") - 1) * 0.03


func get_spy_bonus() -> float:
	return 0.18 + float(get_specialist_level(&"Spy") - 1) * 0.04


func get_enforcer_power_each() -> float:
	return 100.0 + float(get_specialist_level(&"Enforcer") - 1) * 15.0


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
