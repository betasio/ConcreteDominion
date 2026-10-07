class_name RaidTargetData
extends Resource

@export var target_id: String = "target"
@export var display_name: String = "Raid Target"
@export var district_name: String = "Downtown"
@export var difficulty: String = "Medium"
@export var max_hp: float = 9000.0
@export_range(1.0, 2.0, 0.01) var hp_multiplier: float = 1.0
@export var modifier_name: String = "Standard Security"
@export_multiline var modifier_description: String = "No special defenses."
@export var reward_cash: int = 5000
@export var reward_xp: int = 75
@export var required_account_level: int = 1
@export var cooldown_seconds: float = 30.0
@export var accent_color: Color = Color(0.72, 0.52, 0.18)
@export var guaranteed_loot: Dictionary = {}
