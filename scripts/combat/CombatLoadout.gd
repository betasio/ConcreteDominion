class_name CombatLoadout
extends Node

signal changed

var loot: LootInventory
var progression: PlayerProgression

var selected_preset: StringName = &"balanced"
var equipped_role: StringName = &"Driver"
var selected_consumable: StringName = &"none"

var perk_levels: Dictionary = {
	&"Driver": 1,
	&"Spy": 1,
	&"Enforcer": 1
}


func setup(loot_inventory: LootInventory, player_progression: PlayerProgression) -> void:
	loot = loot_inventory
	progression = player_progression


func get_presets() -> Array[StringName]:
	return [&"balanced", &"blitz", &"cautious"]


func cycle_preset() -> void:
	var presets := get_presets()
	var index := presets.find(selected_preset)
	selected_preset = presets[(index + 1) % presets.size()]
	changed.emit()


func get_preset_name() -> String:
	match selected_preset:
		&"blitz":
			return "Blitz"
		&"cautious":
			return "Cautious"
		_:
			return "Balanced"


func get_damage_multiplier() -> float:
	match selected_preset:
		&"blitz":
			return 1.12
		&"cautious":
			return 0.94
		_:
			return 1.0


func get_wound_multiplier() -> float:
	match selected_preset:
		&"blitz":
			return 1.35
		&"cautious":
			return 0.65
		_:
			return 1.0


func get_reward_multiplier() -> float:
	match selected_preset:
		&"blitz":
			return 1.10
		&"cautious":
			return 0.95
		_:
			return 1.0


func cycle_equipment_role() -> void:
	var roles: Array[StringName] = [&"Driver", &"Spy", &"Enforcer"]
	var index := roles.find(equipped_role)
	equipped_role = roles[(index + 1) % roles.size()]
	changed.emit()


func get_equipment_name() -> String:
	match equipped_role:
		&"Driver":
			return "Turbo Kit"
		&"Spy":
			return "Signal Jammer"
		&"Enforcer":
			return "Ballistic Rig"
		_:
			return "Standard Kit"


func get_perk_level(role: StringName) -> int:
	return int(perk_levels.get(role, 1))


func get_perk_bonus(role: StringName) -> float:
	return 0.03 * float(get_perk_level(role))


func get_perk_upgrade_cost(role: StringName) -> Dictionary:
	var level := get_perk_level(role)
	match role:
		&"Driver":
			return {"Parts": 1 + level, "Intel": 1}
		&"Spy":
			return {"Intel": 1 + level}
		&"Enforcer":
			return {"Parts": 2 + level}
		_:
			return {}


func upgrade_equipped_perk() -> bool:
	if loot == null:
		return false

	var cost := get_perk_upgrade_cost(equipped_role)
	if not loot.spend_loot(cost):
		return false

	perk_levels[equipped_role] = get_perk_level(equipped_role) + 1
	changed.emit()
	return true


func cycle_consumable() -> void:
	var choices: Array[StringName] = [&"none", &"intel_boost", &"armor_plates"]
	var index := choices.find(selected_consumable)
	selected_consumable = choices[(index + 1) % choices.size()]
	changed.emit()


func get_consumable_name() -> String:
	match selected_consumable:
		&"intel_boost":
			return "Intel Burst"
		&"armor_plates":
			return "Armor Plates"
		_:
			return "None"


func can_use_selected_consumable() -> bool:
	if selected_consumable == &"none":
		return true
	if loot == null:
		return false

	match selected_consumable:
		&"intel_boost":
			return loot.can_afford({"Intel": 1})
		&"armor_plates":
			return loot.can_afford({"Parts": 1})
		_:
			return false


func consume_selected_consumable() -> bool:
	if selected_consumable == &"none":
		return true
	if loot == null:
		return false

	var paid := false
	match selected_consumable:
		&"intel_boost":
			paid = loot.spend_loot({"Intel": 1})
		&"armor_plates":
			paid = loot.spend_loot({"Parts": 1})

	return paid


func get_consumable_damage_multiplier() -> float:
	return 1.10 if selected_consumable == &"intel_boost" else 1.0


func get_consumable_wound_multiplier() -> float:
	return 0.65 if selected_consumable == &"armor_plates" else 1.0


func get_role_equipment_multiplier(role: StringName) -> float:
	if role != equipped_role:
		return 1.0
	return 1.0 + get_perk_bonus(role)


func get_save_data() -> Dictionary:
	return {
		"selected_preset": String(selected_preset),
		"equipped_role": String(equipped_role),
		"selected_consumable": String(selected_consumable),
		"perk_levels": {
			"Driver": get_perk_level(&"Driver"),
			"Spy": get_perk_level(&"Spy"),
			"Enforcer": get_perk_level(&"Enforcer")
		}
	}


func load_save_data(data: Dictionary) -> void:
	selected_preset = StringName(data.get("selected_preset", "balanced"))
	equipped_role = StringName(data.get("equipped_role", "Driver"))
	selected_consumable = StringName(data.get("selected_consumable", "none"))

	var saved = data.get("perk_levels", {})
	if saved is Dictionary:
		for role in [&"Driver", &"Spy", &"Enforcer"]:
			perk_levels[role] = maxi(1, int(saved.get(String(role), get_perk_level(role))))

	changed.emit()
