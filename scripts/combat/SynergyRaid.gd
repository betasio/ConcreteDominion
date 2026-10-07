class_name SynergyRaid
extends Node

signal roster_changed
signal raid_calculated(result: Dictionary)

@export_range(0.0, 1.0, 0.01) var driver_bonus_each: float = 0.10
@export_range(0.0, 1.0, 0.01) var spy_bonus_each: float = 0.12
@export_range(0.0, 2.0, 0.05) var maximum_support_bonus: float = 1.00

var participants: Dictionary = {}

func clear() -> void:
	participants.clear()
	roster_changed.emit()

func join_raid(player_id: String, player_level: int, base_power: float, role: StringName = &"frontline") -> void:
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
	var strongest_frontline := 0.0
	var driver_count := 0
	var spy_count := 0

	for participant in participants.values():
		var power := float(participant["base_power"])
		var role := StringName(participant["role"])
		if role == &"frontline":
			strongest_frontline = maxf(strongest_frontline, power)
		elif role == &"driver":
			driver_count += 1
		elif role == &"spy":
			spy_count += 1

	var speed_bonus := float(driver_count) * driver_bonus_each
	var defense_break_bonus := float(spy_count) * spy_bonus_each
	var support_bonus := minf(speed_bonus + defense_break_bonus, maximum_support_bonus)

	var result := {
		"damage": strongest_frontline * (1.0 + support_bonus),
		"frontline_power": strongest_frontline,
		"driver_count": driver_count,
		"spy_count": spy_count,
		"speed_bonus": speed_bonus,
		"defense_break_bonus": defense_break_bonus,
		"support_bonus": support_bonus,
		"participant_count": participants.size()
	}
	raid_calculated.emit(result)
	return result
