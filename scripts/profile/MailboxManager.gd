class_name MailboxManager
extends Node

signal changed

var economy: PlayerEconomy
var loot: LootInventory
var progression: PlayerProgression

var messages: Array[Dictionary] = []
var _next_id := 1


func setup(
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	player_progression: PlayerProgression
) -> void:
	economy = player_economy
	loot = loot_inventory
	progression = player_progression
	progression.leveled_up.connect(_on_level_up)

	if messages.is_empty():
		_add_welcome_mail()

	changed.emit()


func _add_welcome_mail() -> void:
	add_mail(
		"Welcome to Concrete Dominion",
		"Your operation is live. Use this starter package to recruit crew and begin taking territory.",
		{"cash": 3000, "gold": 5, "loot": {"Parts": 2}}
	)


func add_mail(subject: String, body: String, reward: Dictionary = {}) -> void:
	messages.push_front({
		"id": _next_id,
		"subject": subject,
		"body": body,
		"reward": reward.duplicate(true),
		"claimed": false
	})
	_next_id += 1
	changed.emit()


func claim_mail(mail_id: int) -> bool:
	for message in messages:
		if int(message["id"]) != mail_id:
			continue
		if bool(message["claimed"]):
			return false

		message["claimed"] = true
		_apply_reward(message.get("reward", {}))
		changed.emit()
		return true

	return false


func claim_all() -> int:
	var claimed := 0
	for message in messages:
		if bool(message["claimed"]):
			continue
		message["claimed"] = true
		_apply_reward(message.get("reward", {}))
		claimed += 1

	if claimed > 0:
		changed.emit()
	return claimed


func get_unclaimed_count() -> int:
	var count := 0
	for message in messages:
		if not bool(message["claimed"]):
			count += 1
	return count


func _on_level_up(new_level: int) -> void:
	match new_level:
		2:
			add_mail("Harbor District Open", "Your name is spreading. Harbor Bank and the Garage are now available.", {"cash": 2500, "loot": {"Parts": 1}})
		4:
			add_mail("Northside Opportunity", "Northside crews are taking you seriously. The Turf HQ is now within reach.", {"gold": 5, "loot": {"Intel": 1}})
		5:
			add_mail("Casino Vault Identified", "Alliance scouts found a high-value Casino Vault operation.", {"cash": 4000, "loot": {"Parts": 2}})
		6:
			add_mail("Financial District Intel", "A new high-value target has appeared in the Financial District.", {"loot": {"Intel": 2, "Contraband": 1}})


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
	return {"messages": messages.duplicate(true), "next_id": _next_id}


func load_save_data(data: Dictionary) -> void:
	if data.has("messages"):
		messages.clear()
		for message in data.get("messages", []):
			if message is Dictionary:
				messages.append(message.duplicate(true))
		_next_id = maxi(1, int(data.get("next_id", 1)))
	elif messages.is_empty():
		_add_welcome_mail()

	changed.emit()
