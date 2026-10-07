class_name EventManager
extends Node

signal changed
signal milestone_claimed(points_required: int)

const EVENT_DURATION_SECONDS := 7.0 * 24.0 * 60.0 * 60.0

var economy: PlayerEconomy
var loot: LootInventory
var progression: PlayerProgression

var event_name: String = "Blackout Week"
var event_started_unix: float = 0.0
var event_ends_unix: float = 0.0
var event_marks: int = 0
var claimed_milestones: Array[int] = []


func setup(
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	player_progression: PlayerProgression,
	raid_battle: RaidBattle
) -> void:
	economy = player_economy
	loot = loot_inventory
	progression = player_progression
	raid_battle.battle_resolved.connect(_on_battle_resolved)

	_ensure_current_event()

	changed.emit()


func _process(_delta: float) -> void:
	_ensure_current_event()


func _ensure_current_event() -> void:
	var now := Time.get_unix_time_from_system()
	if event_started_unix <= 0.0 or event_ends_unix <= 0.0 or now >= event_ends_unix:
		_start_event()


func _start_event() -> void:
	event_started_unix = Time.get_unix_time_from_system()
	event_ends_unix = event_started_unix + EVENT_DURATION_SECONDS
	event_marks = 0
	claimed_milestones.clear()


func get_seconds_remaining() -> float:
	return maxf(0.0, event_ends_unix - Time.get_unix_time_from_system())


func is_active() -> bool:
	return get_seconds_remaining() > 0.0


func get_milestones() -> Array[Dictionary]:
	return [
		{"marks": 5, "reward": {"cash": 2500, "xp": 30}},
		{"marks": 12, "reward": {"gold": 5, "loot": {"Parts": 2}}},
		{"marks": 25, "reward": {"cash": 7500, "xp": 100, "loot": {"Intel": 2}}},
		{"marks": 45, "reward": {"gold": 15, "xp": 180, "loot": {"Contraband": 1}}}
	]


func can_claim_milestone(points_required: int) -> bool:
	return (
		is_active()
		and event_marks >= points_required
		and not claimed_milestones.has(points_required)
	)


func claim_milestone(points_required: int) -> bool:
	for milestone in get_milestones():
		if int(milestone["marks"]) != points_required:
			continue
		if not can_claim_milestone(points_required):
			return false

		claimed_milestones.append(points_required)
		_apply_reward(milestone["reward"])
		milestone_claimed.emit(points_required)
		changed.emit()
		return true

	return false


func _on_battle_resolved(result: Dictionary) -> void:
	if not is_active() or not bool(result.get("victory", false)):
		return

	var target_id := String(result.get("target_id", ""))
	var marks := 1

	match target_id:
		"downtown_bank":
			marks = 2
		"harbor_bank":
			marks = 4
		"midtown_exchange":
			marks = 5
		"northside_hq":
			marks = 6
		"casino_vault":
			marks = 9
		"financial_tower":
			marks = 12
		"industrial_depot":
			marks = 15

	event_marks += marks
	changed.emit()


func _apply_reward(reward: Dictionary) -> void:
	if economy != null:
		economy.add_cash(int(reward.get("cash", 0)))
		economy.add_gold(int(reward.get("gold", 0)))

	if progression != null:
		progression.add_xp(int(reward.get("xp", 0)))

	if loot != null:
		var reward_loot = reward.get("loot", {})
		if reward_loot is Dictionary:
			loot.add_loot(reward_loot)


func get_save_data() -> Dictionary:
	return {
		"event_name": event_name,
		"event_started_unix": event_started_unix,
		"event_ends_unix": event_ends_unix,
		"event_marks": event_marks,
		"claimed_milestones": claimed_milestones.duplicate()
	}


func load_save_data(data: Dictionary) -> void:
	event_name = String(data.get("event_name", event_name))
	event_started_unix = float(data.get("event_started_unix", 0.0))
	event_ends_unix = float(data.get("event_ends_unix", 0.0))
	event_marks = maxi(0, int(data.get("event_marks", 0)))

	claimed_milestones.clear()
	for value in data.get("claimed_milestones", []):
		claimed_milestones.append(int(value))

	_ensure_current_event()
	changed.emit()
