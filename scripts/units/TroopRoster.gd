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
