class_name PlayerEconomy
extends Node

signal changed

@export var cash: int = 25000
@export var gold: int = 75


func can_afford_cash(amount: int) -> bool:
	return cash >= maxi(0, amount)


func spend_cash(amount: int) -> bool:
	amount = maxi(0, amount)
	if cash < amount:
		return false
	cash -= amount
	changed.emit()
	return true


func spend_gold(amount: int) -> bool:
	amount = maxi(0, amount)
	if gold < amount:
		return false
	gold -= amount
	changed.emit()
	return true


func add_cash(amount: int) -> void:
	cash += maxi(0, amount)
	changed.emit()


func add_gold(amount: int) -> void:
	gold += maxi(0, amount)
	changed.emit()


func get_save_data() -> Dictionary:
	return {
		"cash": cash,
		"gold": gold
	}


func load_save_data(data: Dictionary) -> void:
	cash = maxi(0, int(data.get("cash", cash)))
	gold = maxi(0, int(data.get("gold", gold)))
	changed.emit()
