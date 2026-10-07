class_name RetentionManager
extends Node

signal changed
signal login_reward_claimed(reward: Dictionary)
signal achievement_unlocked(achievement_id: String)

var economy: PlayerEconomy
var loot: LootInventory
var progression: PlayerProgression

var last_login_claim_day: int = -1
var login_streak: int = 0
var last_seen_day: int = -1

var daily_period: int = -1
var weekly_period: int = -1

var daily_progress: Dictionary = {
	"recruit": 0,
	"raid_win": 0
}

var weekly_progress: Dictionary = {
	"recruit": 0,
	"raid_win": 0
}

var daily_claimed := false
var weekly_claimed := false

var achievements: Dictionary = {
	"first_raid": false,
	"crew_builder": false,
	"specialist": false,
	"level_three": false
}

var lifetime_recruited := 0
var lifetime_raid_wins := 0


func setup(
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	player_progression: PlayerProgression,
	recruitment: RecruitmentQueue,
	raid_battle: RaidBattle
) -> void:
	economy = player_economy
	loot = loot_inventory
	progression = player_progression

	recruitment.recruitment_completed.connect(_on_recruitment_completed)
	raid_battle.battle_resolved.connect(_on_battle_resolved)
	progression.specialist_upgraded.connect(_on_specialist_upgraded)
	progression.leveled_up.connect(_on_level_up)

	_refresh_periods()
	_check_achievements()
	changed.emit()


func _process(_delta: float) -> void:
	_refresh_periods()


func _get_day_index() -> int:
	return floori(Time.get_unix_time_from_system() / 86400.0)


func _get_week_index() -> int:
	return floori(float(_get_day_index()) / 7.0)


func _refresh_periods() -> void:
	var day := _get_day_index()
	var week := _get_week_index()
	var did_change := false

	if daily_period != day:
		daily_period = day
		daily_progress["recruit"] = 0
		daily_progress["raid_win"] = 0
		daily_claimed = false
		did_change = true

	if weekly_period != week:
		weekly_period = week
		weekly_progress["recruit"] = 0
		weekly_progress["raid_win"] = 0
		weekly_claimed = false
		did_change = true

	if last_seen_day != day:
		last_seen_day = day
		did_change = true

	if did_change:
		changed.emit()


func can_claim_login_reward() -> bool:
	return last_login_claim_day != _get_day_index()


func claim_login_reward() -> Dictionary:
	_refresh_periods()

	if not can_claim_login_reward():
		return {}

	var today := _get_day_index()

	if last_login_claim_day == today - 1:
		login_streak += 1
	else:
		login_streak = 1

	last_login_claim_day = today

	var cycle_day := ((login_streak - 1) % 7) + 1
	var reward := _get_login_reward(cycle_day)
	_apply_reward(reward)
	login_reward_claimed.emit(reward)
	changed.emit()
	return reward


func _get_login_reward(cycle_day: int) -> Dictionary:
	match cycle_day:
		1:
			return {"cash": 1500}
		2:
			return {"loot": {"Parts": 2}}
		3:
			return {"gold": 5}
		4:
			return {"loot": {"Intel": 2}}
		5:
			return {"cash": 3000, "xp": 40}
		6:
			return {"loot": {"Parts": 3, "Intel": 1}}
		7:
			return {"gold": 15, "loot": {"Contraband": 1}, "xp": 100}
		_:
			return {"cash": 1000}


func get_daily_status() -> Dictionary:
	return {
		"recruit": int(daily_progress["recruit"]),
		"recruit_goal": 3,
		"raid_win": int(daily_progress["raid_win"]),
		"raid_goal": 1,
		"complete": _daily_complete(),
		"claimed": daily_claimed
	}


func get_weekly_status() -> Dictionary:
	return {
		"recruit": int(weekly_progress["recruit"]),
		"recruit_goal": 15,
		"raid_win": int(weekly_progress["raid_win"]),
		"raid_goal": 5,
		"complete": _weekly_complete(),
		"claimed": weekly_claimed
	}


func _daily_complete() -> bool:
	return int(daily_progress["recruit"]) >= 3 and int(daily_progress["raid_win"]) >= 1


func _weekly_complete() -> bool:
	return int(weekly_progress["recruit"]) >= 15 and int(weekly_progress["raid_win"]) >= 5


func claim_daily_objective_reward() -> bool:
	if daily_claimed or not _daily_complete():
		return false

	daily_claimed = true
	_apply_reward({
		"cash": 2500,
		"gold": 3,
		"xp": 50,
		"loot": {"Parts": 1}
	})
	changed.emit()
	return true


func claim_weekly_objective_reward() -> bool:
	if weekly_claimed or not _weekly_complete():
		return false

	weekly_claimed = true
	_apply_reward({
		"cash": 10000,
		"gold": 15,
		"xp": 200,
		"loot": {"Parts": 3, "Intel": 2, "Contraband": 1}
	})
	changed.emit()
	return true


func can_craft_street_cache() -> bool:
	return loot != null and loot.can_afford({"Parts": 3, "Intel": 1})


func craft_street_cache() -> bool:
	if loot == null or not loot.spend_loot({"Parts": 3, "Intel": 1}):
		return false

	_apply_reward({"cash": 3500, "gold": 4, "xp": 60})
	changed.emit()
	return true


func can_craft_syndicate_crate() -> bool:
	return loot != null and loot.can_afford({
		"Parts": 5,
		"Intel": 3,
		"Contraband": 1
	})


func craft_syndicate_crate() -> bool:
	if loot == null or not loot.spend_loot({
		"Parts": 5,
		"Intel": 3,
		"Contraband": 1
	}):
		return false

	_apply_reward({"cash": 9000, "gold": 12, "xp": 150})
	changed.emit()
	return true


func _on_recruitment_completed(_troop_type: StringName, amount: int) -> void:
	_refresh_periods()
	daily_progress["recruit"] = mini(3, int(daily_progress["recruit"]) + amount)
	weekly_progress["recruit"] = mini(15, int(weekly_progress["recruit"]) + amount)
	lifetime_recruited += amount
	_check_achievements()
	changed.emit()


func _on_battle_resolved(result: Dictionary) -> void:
	if not bool(result.get("victory", false)):
		return

	_refresh_periods()
	daily_progress["raid_win"] = mini(1, int(daily_progress["raid_win"]) + 1)
	weekly_progress["raid_win"] = mini(5, int(weekly_progress["raid_win"]) + 1)
	lifetime_raid_wins += 1
	_check_achievements()
	changed.emit()


func _on_specialist_upgraded(_role: StringName, _new_level: int) -> void:
	_unlock_achievement("specialist")
	changed.emit()


func _on_level_up(_new_level: int) -> void:
	_check_achievements()
	changed.emit()


func _check_achievements() -> void:
	if lifetime_raid_wins >= 1:
		_unlock_achievement("first_raid")
	if lifetime_recruited >= 20:
		_unlock_achievement("crew_builder")
	if progression != null and progression.account_level >= 3:
		_unlock_achievement("level_three")


func _unlock_achievement(achievement_id: String) -> void:
	if bool(achievements.get(achievement_id, false)):
		return

	achievements[achievement_id] = true

	match achievement_id:
		"first_raid":
			_apply_reward({"gold": 3, "xp": 25})
		"crew_builder":
			_apply_reward({"cash": 3000, "xp": 50})
		"specialist":
			_apply_reward({"gold": 5, "xp": 40})
		"level_three":
			_apply_reward({"loot": {"Intel": 2}, "xp": 75})

	achievement_unlocked.emit(achievement_id)


func get_achievement_lines() -> PackedStringArray:
	var definitions := {
		"first_raid": "First Blood — win a raid",
		"crew_builder": "Crew Builder — recruit 20 troops",
		"specialist": "Specialist — upgrade a specialist",
		"level_three": "Known Name — reach Account Lv.3"
	}

	var lines := PackedStringArray()
	for achievement_id in definitions.keys():
		var mark := "✓" if bool(achievements.get(achievement_id, false)) else "○"
		lines.append("%s %s" % [mark, definitions[achievement_id]])
	return lines


func get_tutorial_hint() -> String:
	if progression == null:
		return "Open Progression to review your next objective."

	if lifetime_recruited < 5:
		return "Tutorial: Recruit 5 troops from the Crew Barracks."

	if lifetime_raid_wins < 1:
		return "Tutorial: Switch to WORLD and win Downtown Bank with alliance support."

	if progression.account_level < 2:
		return "Tutorial: Complete missions and raids to reach Account Lv.2."

	if progression.get_specialist_level(&"Driver") <= 1:
		return "Tutorial: Earn Parts/Intel, then upgrade Driver support in Progression."

	return "Tutorial complete: build your alliance, improve specialists, and push higher-tier targets."


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
		"last_login_claim_day": last_login_claim_day,
		"login_streak": login_streak,
		"last_seen_day": last_seen_day,
		"daily_period": daily_period,
		"weekly_period": weekly_period,
		"daily_progress": daily_progress.duplicate(true),
		"weekly_progress": weekly_progress.duplicate(true),
		"daily_claimed": daily_claimed,
		"weekly_claimed": weekly_claimed,
		"achievements": achievements.duplicate(true),
		"lifetime_recruited": lifetime_recruited,
		"lifetime_raid_wins": lifetime_raid_wins
	}


func load_save_data(data: Dictionary) -> void:
	last_login_claim_day = int(data.get("last_login_claim_day", last_login_claim_day))
	login_streak = maxi(0, int(data.get("login_streak", login_streak)))
	last_seen_day = int(data.get("last_seen_day", last_seen_day))
	daily_period = int(data.get("daily_period", daily_period))
	weekly_period = int(data.get("weekly_period", weekly_period))
	daily_claimed = bool(data.get("daily_claimed", daily_claimed))
	weekly_claimed = bool(data.get("weekly_claimed", weekly_claimed))
	lifetime_recruited = maxi(0, int(data.get("lifetime_recruited", lifetime_recruited)))
	lifetime_raid_wins = maxi(0, int(data.get("lifetime_raid_wins", lifetime_raid_wins)))

	var saved_daily = data.get("daily_progress", {})
	if saved_daily is Dictionary:
		daily_progress["recruit"] = int(saved_daily.get("recruit", 0))
		daily_progress["raid_win"] = int(saved_daily.get("raid_win", 0))

	var saved_weekly = data.get("weekly_progress", {})
	if saved_weekly is Dictionary:
		weekly_progress["recruit"] = int(saved_weekly.get("recruit", 0))
		weekly_progress["raid_win"] = int(saved_weekly.get("raid_win", 0))

	var saved_achievements = data.get("achievements", {})
	if saved_achievements is Dictionary:
		for achievement_id in achievements.keys():
			achievements[achievement_id] = bool(
				saved_achievements.get(achievement_id, achievements[achievement_id])
			)

	_refresh_periods()
	changed.emit()
