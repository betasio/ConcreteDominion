class_name TroopRoster
extends Node

signal changed

var troops: Dictionary = {
	&"Enforcer": 10,
	&"Driver": 2,
	&"Spy": 2
}


func get_count(troop_type: StringName) -> int:
	return int(troops.get(troop_type, 0))


func add_troops(troop_type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	troops[troop_type] = get_count(troop_type) + amount
	changed.emit()


func remove_troops(troop_type: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	if get_count(troop_type) < amount:
		return false
	troops[troop_type] = get_count(troop_type) - amount
	changed.emit()
	return true


func get_frontline_power() -> float:
	return float(get_count(&"Enforcer")) * 100.0


func get_save_data() -> Dictionary:
	return {
		"Enforcer": get_count(&"Enforcer"),
		"Driver": get_count(&"Driver"),
		"Spy": get_count(&"Spy")
	}


func load_save_data(data: Dictionary) -> void:
	troops[&"Enforcer"] = int(data.get("Enforcer", get_count(&"Enforcer")))
	troops[&"Driver"] = int(data.get("Driver", get_count(&"Driver")))
	troops[&"Spy"] = int(data.get("Spy", get_count(&"Spy")))
	changed.emit()
