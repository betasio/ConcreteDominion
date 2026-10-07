class_name HospitalQueue
extends Node

signal queue_changed
signal treatment_completed(entry: Dictionary)

@export var seconds_per_troop: float = 45.0
@export var gold_per_chunk: int = 1
var speedup_chunk_seconds: int = 300

var wounded_queue: Array[Dictionary] = []
var economy: PlayerEconomy
var balance: GameBalance
var core_effects: CoreBuildingEffects
var roster: TroopRoster
var _last_displayed_second := -1


func setup(player_economy: PlayerEconomy, troop_roster: TroopRoster = null, game_balance: GameBalance = null, building_effects: CoreBuildingEffects = null) -> void:
	economy = player_economy
	roster = troop_roster
	balance = game_balance
	core_effects = building_effects
	if balance != null:
		gold_per_chunk = balance.get_speedup_rate("hospital_gold_per_chunk", gold_per_chunk)
		speedup_chunk_seconds = balance.get_speedup_chunk_seconds()


func _process(delta: float) -> void:
	if wounded_queue.is_empty():
		return

	var slots := core_effects.get_clinic_slots() if core_effects != null else 1
	for i in range(mini(slots, wounded_queue.size()) - 1, -1, -1):
		wounded_queue[i]["seconds_remaining"] = maxf(0.0, float(wounded_queue[i]["seconds_remaining"]) - delta)
		if float(wounded_queue[i]["seconds_remaining"]) <= 0.0:
			_finish_entry(i)

	queue_changed.emit()


func add_wounded(troop_type: StringName, amount: int) -> void:
	send_to_hospital(troop_type, amount)


func send_to_hospital(
	troop_type: StringName,
	amount: int,
	severity_multiplier: float = 1.0,
	severity_label: String = "Standard"
) -> bool:
	if amount <= 0:
		return false

	if roster != null and not roster.remove_troops(troop_type, amount):
		return false

	var severity := maxf(0.25, severity_multiplier)
	wounded_queue.append({
		"troop_type": troop_type,
		"amount": amount,
		"severity": severity_label,
		"severity_multiplier": severity,
		"seconds_remaining": maxf(1.0, amount * seconds_per_troop * severity * (core_effects.get_clinic_time_multiplier() if core_effects != null else 1.0))
	})
	queue_changed.emit()
	return true


func get_instant_heal_cost() -> int:
	var total_seconds := 0.0
	for entry in wounded_queue:
		total_seconds += float(entry["seconds_remaining"])
	return ceili(total_seconds / float(speedup_chunk_seconds)) * gold_per_chunk


func instant_heal() -> bool:
	if wounded_queue.is_empty():
		return true

	var cost := get_instant_heal_cost()
	if economy == null or not economy.spend_gold(cost):
		return false

	while not wounded_queue.is_empty():
		_finish_front_entry()

	_last_displayed_second = -1
	queue_changed.emit()
	return true


func _finish_front_entry() -> void:
	_finish_entry(0)


func _finish_entry(index: int) -> void:
	if wounded_queue.is_empty() or index < 0 or index >= wounded_queue.size():
		return

	var completed := wounded_queue[index]
	wounded_queue.remove_at(index)
	completed["seconds_remaining"] = 0.0

	if roster != null:
		roster.add_troops(
			StringName(completed["troop_type"]),
			int(completed["amount"])
		)

	_last_displayed_second = -1
	treatment_completed.emit(completed)
	queue_changed.emit()


func get_save_data() -> Dictionary:
	var saved_queue: Array = []
	for entry in wounded_queue:
		saved_queue.append({
			"troop_type": String(entry["troop_type"]),
			"amount": int(entry["amount"]),
			"severity": String(entry.get("severity", "Standard")),
			"severity_multiplier": float(entry.get("severity_multiplier", 1.0)),
			"seconds_remaining": float(entry["seconds_remaining"])
		})
	return {"queue": saved_queue}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	wounded_queue.clear()

	for raw_entry in data.get("queue", []):
		if raw_entry is Dictionary:
			wounded_queue.append({
				"troop_type": StringName(raw_entry.get("troop_type", "Enforcer")),
				"amount": int(raw_entry.get("amount", 0)),
				"severity": String(raw_entry.get("severity", "Standard")),
				"severity_multiplier": float(raw_entry.get("severity_multiplier", 1.0)),
				"seconds_remaining": float(raw_entry.get("seconds_remaining", 0.0))
			})

	var remaining_offline := maxf(0.0, offline_seconds)
	var slots := core_effects.get_clinic_slots() if core_effects != null else 1

	while remaining_offline > 0.0 and not wounded_queue.is_empty():
		var active_count := mini(slots, wounded_queue.size())
		var step := INF
		for i in range(active_count):
			step = minf(step, float(wounded_queue[i]["seconds_remaining"]))
		if step <= 0.0:
			step = 0.001
		if step > remaining_offline:
			for i in range(active_count):
				wounded_queue[i]["seconds_remaining"] = maxf(0.0, float(wounded_queue[i]["seconds_remaining"]) - remaining_offline)
			remaining_offline = 0.0
		else:
			for i in range(active_count):
				wounded_queue[i]["seconds_remaining"] = maxf(0.0, float(wounded_queue[i]["seconds_remaining"]) - step)
			remaining_offline -= step
			for i in range(active_count - 1, -1, -1):
				if float(wounded_queue[i]["seconds_remaining"]) <= 0.0:
					_finish_entry(i)

	_last_displayed_second = -1
	queue_changed.emit()
