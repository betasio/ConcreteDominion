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
	var did_change := false

	for item_name in loot.keys():
		var amount := int(loot[item_name])
		if amount <= 0:
			continue
		items[String(item_name)] = get_count(String(item_name)) + amount
		did_change = true

	if did_change:
		changed.emit()


func can_afford(loot: Dictionary) -> bool:
	for item_name in loot.keys():
		var required := maxi(0, int(loot[item_name]))
		if get_count(String(item_name)) < required:
			return false
	return true


func spend_loot(loot: Dictionary) -> bool:
	if not can_afford(loot):
		return false

	for item_name in loot.keys():
		var required := maxi(0, int(loot[item_name]))
		items[String(item_name)] = maxi(0, get_count(String(item_name)) - required)

	changed.emit()
	return true


func get_count(item_name: String) -> int:
	return int(items.get(item_name, 0))


func get_save_data() -> Dictionary:
	return items.duplicate(true)


func load_save_data(data: Dictionary) -> void:
	for item_name in items.keys():
		items[item_name] = maxi(0, int(data.get(item_name, items[item_name])))
	changed.emit()
