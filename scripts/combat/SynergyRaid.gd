class_name SynergyRaid
extends Node

signal roster_changed
signal raid_calculated(result: Dictionary)

@export var support_level_threshold: int = 20
@export_range(0.0, 1.0, 0.01) var support_buff_per_player: float = 0.08
@export_range(0.0, 2.0, 0.05) var maximum_support_bonus: float = 0.80

var participants: Dictionary = {}


func join_raid(
	player_id: String,
	player_level: int,
	base_power: float,
	role: StringName = &"frontline"
) -> void:
	participants[player_id] = {
		"level": maxi(1, player_level),
		"base_power": maxf(0.0, base_power),
		"role": role
	}
	roster_changed.emit()


func leave_raid(player_id: String) -> void:
	if participants.erase(player_id):
		roster_changed.emit()


func calculate_raid_damage() -> Dictionary:
	if participants.is_empty():
		var empty_result := {
			"damage": 0.0,
			"frontline_power": 0.0,
			"support_count": 0,
			"support_bonus": 0.0
		}
		raid_calculated.emit(empty_result)
		return empty_result

	var strongest_power := 0.0
	var support_count := 0

	for participant in participants.values():
		var level := int(participant["level"])
		var power := float(participant["base_power"])
		var role := StringName(participant["role"])

		if power > strongest_power:
			strongest_power = power

		if level <= support_level_threshold and role != &"frontline":
			support_count += 1

	var support_bonus := minf(
		float(support_count) * support_buff_per_player,
		maximum_support_bonus
	)

	var result := {
		"damage": strongest_power * (1.0 + support_bonus),
		"frontline_power": strongest_power,
		"support_count": support_count,
		"support_bonus": support_bonus
	}

	raid_calculated.emit(result)
	return result
