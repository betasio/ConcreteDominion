class_name SynergyRaid
extends Node

signal roster_changed
signal raid_calculated(result: Dictionary)

@export_range(0.0, 2.0, 0.05) var maximum_support_bonus: float = 1.25

var participants: Dictionary = {}
var progression: PlayerProgression


func setup(player_progression: PlayerProgression) -> void:
	progression = player_progression


func clear() -> void:
	participants.clear()
	roster_changed.emit()


func join_raid(
	player_id: String,
	player_level: int,
	base_power: float,
	role: StringName = &"frontline",
	display_name: String = ""
) -> void:
	participants[player_id] = {
		"level": maxi(1, player_level),
		"base_power": maxf(0.0, base_power),
		"role": role,
		"name": display_name if display_name != "" else player_id
	}
	roster_changed.emit()


func leave_raid(player_id: String) -> void:
	if participants.erase(player_id):
		roster_changed.emit()


func get_driver_bonus_each() -> float:
	return progression.get_driver_bonus() if progression != null else 0.15


func get_spy_bonus_each() -> float:
	return progression.get_spy_bonus() if progression != null else 0.18


func calculate_raid_damage() -> Dictionary:
	var strongest_frontline := 0.0
	var driver_count := 0
	var spy_count := 0
	var frontline_id := ""

	for player_id in participants.keys():
		var participant: Dictionary = participants[player_id]
		var power := float(participant["base_power"])
		var role := StringName(participant["role"])

		if role == &"frontline" and power > strongest_frontline:
			strongest_frontline = power
			frontline_id = String(player_id)
		elif role == &"driver":
			driver_count += 1
		elif role == &"spy":
			spy_count += 1

	var driver_bonus := get_driver_bonus_each()
	var spy_bonus := get_spy_bonus_each()
	var speed_bonus := float(driver_count) * driver_bonus
	var defense_break_bonus := float(spy_count) * spy_bonus
	var support_bonus := minf(speed_bonus + defense_break_bonus, maximum_support_bonus)
	var total_damage := strongest_frontline * (1.0 + support_bonus)

	var contributions: Dictionary = {}
	for player_id in participants.keys():
		var participant: Dictionary = participants[player_id]
		var role := StringName(participant["role"])
		var score := 0.0

		if String(player_id) == frontline_id:
			score = strongest_frontline
		elif role == &"driver":
			score = strongest_frontline * driver_bonus
		elif role == &"spy":
			score = strongest_frontline * spy_bonus

		contributions[String(player_id)] = score

	var result := {
		"damage": total_damage,
		"frontline_power": strongest_frontline,
		"frontline_id": frontline_id,
		"driver_count": driver_count,
		"spy_count": spy_count,
		"driver_bonus_each": driver_bonus,
		"spy_bonus_each": spy_bonus,
		"speed_bonus": speed_bonus,
		"defense_break_bonus": defense_break_bonus,
		"support_bonus": support_bonus,
		"participant_count": participants.size(),
		"contributions": contributions
	}

	raid_calculated.emit(result)
	return result
