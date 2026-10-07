class_name CombatStrategyUI
extends CanvasLayer

var loadout: CombatLoadout
var loot: LootInventory
var city_map: Node

@onready var shortcut: Button = $Root/Shortcut
@onready var panel: PanelContainer = $Root/Panel
@onready var summary: Label = $Root/Panel/Margin/VBox/Summary
@onready var preset_button: Button = $Root/Panel/Margin/VBox/Preset
@onready var equipment_button: Button = $Root/Panel/Margin/VBox/Equipment
@onready var upgrade_button: Button = $Root/Panel/Margin/VBox/Upgrade
@onready var consumable_button: Button = $Root/Panel/Margin/VBox/Consumable
@onready var counter_label: Label = $Root/Panel/Margin/VBox/Counter


func setup(combat_loadout: CombatLoadout, loot_inventory: LootInventory, world: Node) -> void:
	loadout = combat_loadout
	loot = loot_inventory
	city_map = world

	loadout.changed.connect(_refresh)
	loot.changed.connect(_refresh)

	shortcut.pressed.connect(_toggle_panel)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle_panel)
	preset_button.pressed.connect(func(): loadout.cycle_preset())
	equipment_button.pressed.connect(func(): loadout.cycle_equipment_role())
	upgrade_button.pressed.connect(_upgrade_perk)
	consumable_button.pressed.connect(func(): loadout.cycle_consumable())

	_refresh()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	_refresh()


func _upgrade_perk() -> void:
	loadout.upgrade_equipped_perk()
	_refresh()


func _refresh() -> void:
	if loadout == null:
		return

	shortcut.text = "TACTICS • %s" % loadout.get_preset_name()

	summary.text = "PRE-RAID PLAN\nDamage x%.2f   Reward x%.2f   Injury risk x%.2f" % [
		loadout.get_damage_multiplier(),
		loadout.get_reward_multiplier(),
		loadout.get_wound_multiplier()
	]

	preset_button.text = "Risk Plan: %s  (Change)" % loadout.get_preset_name()

	var role := loadout.equipped_role
	equipment_button.text = "Equipment: %s — %s Lv.%d" % [
		loadout.get_equipment_name(),
		String(role),
		loadout.get_perk_level(role)
	]

	upgrade_button.text = "Upgrade %s — %s" % [
		loadout.get_equipment_name(),
		_format_cost(loadout.get_perk_upgrade_cost(role))
	]
	upgrade_button.disabled = not loot.can_afford(loadout.get_perk_upgrade_cost(role))

	consumable_button.text = "Consumable: %s  (Change)" % loadout.get_consumable_name()

	if loadout.selected_consumable == &"intel_boost":
		consumable_button.tooltip_text = "Costs Intel x1 at raid launch. +10% final damage."
	elif loadout.selected_consumable == &"armor_plates":
		consumable_button.tooltip_text = "Costs Parts x1 at raid launch. -35% injury severity."
	else:
		consumable_button.tooltip_text = "No consumable cost."

	var target = city_map.selected_target
	if target is RaidTarget:
		counter_label.text = "SELECTED TARGET COUNTER\n%s is weak to %s support (+%d%% damage when present)." % [
			target.get_display_name(),
			String(target.get_weakness_role()),
			roundi(target.get_weakness_bonus() * 100.0)
		]
	else:
		counter_label.text = "SELECTED TARGET COUNTER\nSelect a raid target in WORLD view to see its recommended counter-role."


func _format_cost(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for item_name in cost.keys():
		parts.append("%s x%d" % [String(item_name), int(cost[item_name])])
	return ", ".join(parts)
