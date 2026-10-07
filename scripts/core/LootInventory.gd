class_name LootInventory
extends Node

signal changed

var items: Dictionary = {
	"Parts": 0,
	"Intel": 0,
	"Contraband": 0
}


func add_item(item_name: String, amount: int) -> void:
	if amount <= 0:
		return
	items[item_name] = int(items.get(item_name, 0)) + amount
	changed.emit()


func add_loot(loot: Dictionary) -> void:
	for item_name in loot.keys():
		add_item(String(item_name), int(loot[item_name]))


func get_count(item_name: String) -> int:
	return int(items.get(item_name, 0))


func get_save_data() -> Dictionary:
	return items.duplicate(true)


func load_save_data(data: Dictionary) -> void:
	for item_name in items.keys():
		items[item_name] = int(data.get(item_name, items[item_name]))
	changed.emit()
