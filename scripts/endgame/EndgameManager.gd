class_name EndgameManager
extends Node

signal changed
signal dominion_cache_claimed
signal dominion_mastery_claimed
signal season_reward_claimed(tier: String)

const WEEKLY_REQUIRED := 2
const FAMILY_OPERATION_GOAL := 3
const BOSS_REMATCH_GOAL := 1
const FACTION_WAR_GOAL := 1

const SEASON_WEEKS := 4
const FEATURED_WIN_POINTS := 25
const NORMAL_WIN_POINTS := 10

const SEASON_IDENTITIES := [
	{
		"name":"Steel Reign",
		"subtitle":"Supply lines, convoys, and hard control decide the city.",
		"prestige":"STEEL"
	},
	{
		"name":"Velvet Ledger",
		"subtitle":"Money, favors, and information move faster than bullets.",
		"prestige":"VELVET"
	},
	{
		"name":"Crown of Northside",
		"subtitle":"Borders harden and reputation becomes a weapon.",
		"prestige":"CROWN"
	},
	{
		"name":"Blackout Accord",
		"subtitle":"The city goes quiet while surveillance networks fail.",
		"prestige":"BLACKOUT"
	}
]

const SEASON_MODIFIERS := [
	{
		"id":"supply_shock",
		"title":"SUPPLY SHOCK",
		"family_id":"iron_serpents",
		"district_id":"industrial_depot",
		"description":"Iron Serpent logistics are exposed. Industrial operations pay bonus seasonal progress.",
		"bonus_cash":2500,
		"bonus_loot":{"Parts":1}
	},
	{
		"id":"velvet_liquidity",
		"title":"VELVET LIQUIDITY",
		"family_id":"velvet_circle",
		"district_id":"financial_tower",
		"description":"Velvet Circle money is moving fast. Financial operations are especially valuable this week.",
		"bonus_cash":3000,
		"bonus_loot":{"Intel":1}
	},
	{
		"id":"northside_pressure",
		"title":"NORTHSIDE PRESSURE",
		"family_id":"northside_crew",
		"district_id":"northside_hq",
		"description":"Northside is testing every border. Wins there generate extra Dominion influence.",
		"bonus_cash":2500,
		"bonus_loot":{"Parts":1,"Intel":1}
	},
	{
		"id":"meridian_blackout",
		"title":"MERIDIAN BLACKOUT",
		"family_id":"meridian_boys",
		"district_id":"midtown_exchange",
		"description":"Meridian surveillance is disrupted. Midtown operations are paying out intelligence caches.",
		"bonus_cash":2000,
		"bonus_loot":{"Intel":2}
	}
]

const TARGET_ROTATION := [
	"downtown_bank",
	"harbor_bank",
	"midtown_exchange",
	"northside_hq",
	"casino_vault",
	"financial_tower",
	"industrial_depot"
]

var missions: MissionTracker
var world_control: WorldControlManager
var faction: FactionManager
var economy: PlayerEconomy
var loot: LootInventory
var progression: PlayerProgression

var weekly_period := -1
var family_operation_wins := 0
var boss_rematch_wins := 0
var faction_war_wins := 0
var weekly_claimed := false
var mastery_claimed := false
var dominion_marks := 0
var cycles_completed := 0
var operation_cursor := 0
var boss_cursor := 0
var active_boss_target := ""

var season_period := -1
var season_points := 0
var claimed_season_tiers: Array[String] = []
var pending_season_tiers: Array[String] = []
var pending_season_prestige: Dictionary = {}
var featured_wins := 0
var scored_operation_wins := 0
var prestige_badges: Array[String] = []
var equipped_prestige_badge := ""
var last_season_result: Dictionary = {}


func setup(
	mission_tracker: MissionTracker,
	control: WorldControlManager,
	faction_manager: FactionManager,
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	player_progression: PlayerProgression
) -> void:
	missions = mission_tracker
	world_control = control
	faction = faction_manager
	economy = player_economy
	loot = loot_inventory
	progression = player_progression

	world_control.family_encounter_resolved.connect(_on_family_encounter_resolved)
	faction.war_completed.connect(_on_faction_war_completed)
	missions.mission_completed.connect(_on_mission_completed)
	_refresh_season()
	_refresh_week()
	changed.emit()


func _process(delta: float) -> void:
	_period_check_accumulator += delta
	if _period_check_accumulator < 30.0:
		return
	_period_check_accumulator = 0.0
	_refresh_week()


var _period_check_accumulator := 0.0


func is_unlocked() -> bool:
	return missions != null and bool(missions.missions.get("chapter_6_complete", {}).get("completed", false))


func _get_week_index() -> int:
	return floori(float(floori(Time.get_unix_time_from_system() / 86400.0)) / 7.0)


func _get_season_index() -> int:
	return floori(float(_get_week_index()) / float(SEASON_WEEKS))


func _refresh_season() -> void:
	var season := _get_season_index()
	if season_period == season:
		return

	if season_period >= 0:
		var completed_identity := _get_season_identity_for_period(season_period)
		last_season_result = {
			"season_name": String(completed_identity.get("name", "Dominion Season")),
			"season_points": season_points,
			"season_tier": get_season_tier(),
			"featured_wins": featured_wins,
			"claimed_tiers": claimed_season_tiers.duplicate()
		}
		for tier in _eligible_tiers_for_points(season_points):
			if not tier in claimed_season_tiers and not tier in pending_season_tiers:
				pending_season_tiers.append(tier)
				pending_season_prestige[tier] = "%s %s" % [
					String(completed_identity.get("prestige", "DOMINION")),
					tier
				]

	season_period = season
	season_points = 0
	claimed_season_tiers.clear()
	featured_wins = 0
	scored_operation_wins = 0
	changed.emit()


func _eligible_tiers_for_points(points: int) -> Array[String]:
	var tiers: Array[String] = []
	if points >= 250:
		tiers.append("SILVER")
	if points >= 450:
		tiers.append("GOLD")
	if points >= 700:
		tiers.append("PLATINUM")
	return tiers


func _refresh_week() -> void:
	_refresh_season()
	var week := _get_week_index()
	if weekly_period == week:
		return
	weekly_period = week
	family_operation_wins = 0
	boss_rematch_wins = 0
	faction_war_wins = 0
	weekly_claimed = false
	mastery_claimed = false
	active_boss_target = ""
	scored_operation_wins = 0
	changed.emit()


func _completed_tracks() -> int:
	var completed := 0
	if family_operation_wins >= FAMILY_OPERATION_GOAL:
		completed += 1
	if boss_rematch_wins >= BOSS_REMATCH_GOAL:
		completed += 1
	if faction_war_wins >= FACTION_WAR_GOAL:
		completed += 1
	return completed


func get_status() -> Dictionary:
	_refresh_week()
	return {
		"unlocked": is_unlocked(),
		"completed_tracks": _completed_tracks(),
		"required_tracks": WEEKLY_REQUIRED,
		"family_wins": family_operation_wins,
		"family_goal": FAMILY_OPERATION_GOAL,
		"boss_wins": boss_rematch_wins,
		"boss_goal": BOSS_REMATCH_GOAL,
		"war_wins": faction_war_wins,
		"war_goal": FACTION_WAR_GOAL,
		"claimable": is_unlocked() and _completed_tracks() >= WEEKLY_REQUIRED and not weekly_claimed,
		"mastery_claimable": is_unlocked() and _completed_tracks() >= 3 and not mastery_claimed,
		"claimed": weekly_claimed,
		"mastery_claimed": mastery_claimed,
		"dominion_marks": dominion_marks,
		"rank": get_dominion_rank(),
		"cycles_completed": cycles_completed,
		"season_points": season_points,
		"season_tier": get_season_tier(),
		"season_reward_claimable": is_season_reward_claimable(),
		"next_season_reward_tier": get_next_claimable_season_tier(),
		"claimed_season_tiers": claimed_season_tiers.duplicate(),
		"pending_season_tiers": pending_season_tiers.duplicate(),
		"pending_season_prestige": pending_season_prestige.duplicate(true),
		"featured_wins": featured_wins,
		"season_week": posmod(_get_week_index(), SEASON_WEEKS) + 1,
		"season_name": get_season_name(),
		"season_subtitle": get_season_subtitle(),
		"equipped_prestige_badge": equipped_prestige_badge
	}


func _get_season_identity_for_period(period: int) -> Dictionary:
	return SEASON_IDENTITIES[posmod(period, SEASON_IDENTITIES.size())].duplicate(true)


func get_season_identity() -> Dictionary:
	return _get_season_identity_for_period(_get_season_index())


func get_season_name() -> String:
	return String(get_season_identity().get("name", "Dominion Season"))


func get_season_subtitle() -> String:
	return String(get_season_identity().get("subtitle", ""))


func get_last_season_result_text() -> String:
	if last_season_result.is_empty():
		return "No completed Dominion season yet."
	return "%s • %s • %d influence • %d featured win(s)" % [
		String(last_season_result.get("season_name", "Season")),
		String(last_season_result.get("season_tier", "BRONZE")),
		int(last_season_result.get("season_points", 0)),
		int(last_season_result.get("featured_wins", 0))
	]


func get_prestige_badge_lines() -> PackedStringArray:
	if prestige_badges.is_empty():
		return PackedStringArray(["No seasonal prestige badges earned yet."])
	var lines := PackedStringArray()
	for badge in prestige_badges:
		lines.append("%s%s" % [badge, " • EQUIPPED" if badge == equipped_prestige_badge else ""])
	return lines


func equip_next_prestige_badge() -> bool:
	if prestige_badges.is_empty():
		return false
	var index := prestige_badges.find(equipped_prestige_badge)
	if index < 0:
		equipped_prestige_badge = prestige_badges[0]
	else:
		equipped_prestige_badge = prestige_badges[(index + 1) % prestige_badges.size()]
	changed.emit()
	return true


func get_equipped_prestige_badge() -> String:
	return equipped_prestige_badge


func get_current_modifier() -> Dictionary:
	return SEASON_MODIFIERS[posmod(_get_week_index(), SEASON_MODIFIERS.size())].duplicate(true)


func get_featured_family_name() -> String:
	var modifier := get_current_modifier()
	var district_id := String(modifier.get("district_id", ""))
	if world_control != null:
		return world_control.get_rival_faction(district_id)
	return String(modifier.get("family_id", "Rival Family")).replace("_", " ").capitalize()


func get_featured_summary() -> String:
	var modifier := get_current_modifier()
	return "%s • %s\n%s" % [
		String(modifier["title"]),
		get_featured_family_name(),
		String(modifier["description"])
	]


func get_season_tier() -> String:
	if season_points >= 700:
		return "PLATINUM"
	if season_points >= 450:
		return "GOLD"
	if season_points >= 250:
		return "SILVER"
	return "BRONZE"


func get_next_claimable_season_tier() -> String:
	if not pending_season_tiers.is_empty():
		return pending_season_tiers[0]
	if season_points >= 250 and not "SILVER" in claimed_season_tiers:
		return "SILVER"
	if season_points >= 450 and not "GOLD" in claimed_season_tiers:
		return "GOLD"
	if season_points >= 700 and not "PLATINUM" in claimed_season_tiers:
		return "PLATINUM"
	return ""


func is_season_reward_claimable() -> bool:
	# Seasonal tiers are incremental: claiming Silver never forfeits Gold or Platinum.
	return is_unlocked() and not get_next_claimable_season_tier().is_empty()


func get_season_reward_summary(tier: String = "") -> String:
	var reward_tier := tier if not tier.is_empty() else get_next_claimable_season_tier()
	match reward_tier:
		"PLATINUM":
			return "$30,000 + 25 Gold + Parts x5 + Intel x5 + Contraband x2"
		"GOLD":
			return "$22,000 + 18 Gold + Parts x4 + Intel x4 + Contraband x1"
		"SILVER":
			return "$15,000 + 12 Gold + Parts x3 + Intel x3"
		_:
			return "Next tier unlocks at 250 seasonal influence."


func get_dominion_rank() -> String:
	if dominion_marks >= 1500:
		return "SOVEREIGN"
	if dominion_marks >= 750:
		return "REGENT"
	if dominion_marks >= 300:
		return "KINGPIN"
	return "OPERATOR"


func get_season_leaderboard_lines() -> PackedStringArray:
	var player_name := faction.faction_name if faction != null and faction.has_faction() else "Your Family"
	var faction_bonus := faction.season_points if faction != null and faction.has_faction() else 0
	var player_score := season_points + int(faction_bonus / 4)
	var rows: Array[Dictionary] = [
		{"name":"Black Crown","score":maxi(320, player_score + 110)},
		{"name":"Night Union","score":maxi(260, player_score + 55)},
		{"name":player_name,"score":player_score},
		{"name":"Red Hands","score":maxi(90, player_score - 45)}
	]
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["score"]) > int(b["score"]))
	var lines := PackedStringArray()
	var rank := 1
	for row in rows:
		lines.append("#%d %s — %d influence" % [rank, String(row["name"]), int(row["score"])])
		rank += 1
	return lines


func get_contract_lines() -> PackedStringArray:
	return PackedStringArray([
		"Rival Family Operations — %d/%d wins" % [family_operation_wins, FAMILY_OPERATION_GOAL],
		"Boss Rematch — %d/%d win" % [boss_rematch_wins, BOSS_REMATCH_GOAL],
		"Faction War — %d/%d victory" % [faction_war_wins, FACTION_WAR_GOAL]
	])


func launch_rival_operation() -> bool:
	if not is_unlocked() or world_control == null or not world_control.active_patrol.is_empty():
		return false

	var featured_target := String(get_current_modifier().get("district_id", ""))
	if world_control.is_discovered(featured_target):
		var featured_type := world_control.family_rules.get_preferred_encounter(featured_target)
		if world_control.launch_family_operation(featured_target, featured_type):
			operation_cursor = (TARGET_ROTATION.find(featured_target) + 1) % TARGET_ROTATION.size()
			changed.emit()
			return true

	for offset in range(TARGET_ROTATION.size()):
		var index := (operation_cursor + offset) % TARGET_ROTATION.size()
		var target_id := String(TARGET_ROTATION[index])
		if not world_control.is_discovered(target_id):
			continue
		var encounter_type := world_control.family_rules.get_preferred_encounter(target_id)
		operation_cursor = (index + 1) % TARGET_ROTATION.size()
		if world_control.launch_family_operation(target_id, encounter_type):
			changed.emit()
			return true
	return false


func launch_boss_rematch() -> bool:
	if not is_unlocked() or world_control == null or not world_control.active_patrol.is_empty():
		return false

	var featured_target := String(get_current_modifier().get("district_id", ""))
	if world_control.is_discovered(featured_target) and world_control.launch_boss_rematch(featured_target):
		active_boss_target = featured_target
		boss_cursor = (TARGET_ROTATION.find(featured_target) + 1) % TARGET_ROTATION.size()
		changed.emit()
		return true

	for offset in range(TARGET_ROTATION.size()):
		var index := (boss_cursor + offset) % TARGET_ROTATION.size()
		var target_id := String(TARGET_ROTATION[index])
		if not world_control.is_discovered(target_id):
			continue
		if world_control.launch_boss_rematch(target_id):
			boss_cursor = (index + 1) % TARGET_ROTATION.size()
			active_boss_target = target_id
			changed.emit()
			return true
	return false


func claim_season_reward() -> bool:
	var tier := get_next_claimable_season_tier()
	if tier.is_empty():
		return false
	var badge_name := ""
	if tier in pending_season_tiers:
		pending_season_tiers.erase(tier)
		badge_name = String(pending_season_prestige.get(tier, "DOMINION %s" % tier))
		pending_season_prestige.erase(tier)
	else:
		claimed_season_tiers.append(tier)
		var identity := get_season_identity()
		badge_name = "%s %s" % [
			String(identity.get("prestige", "DOMINION")),
			tier
		]
	if not badge_name in prestige_badges:
		prestige_badges.append(badge_name)
		if equipped_prestige_badge.is_empty():
			equipped_prestige_badge = badge_name

	match tier:
		"PLATINUM":
			economy.add_cash(30000)
			economy.add_gold(25)
			loot.add_loot({"Parts":5,"Intel":5,"Contraband":2})
		"GOLD":
			economy.add_cash(22000)
			economy.add_gold(18)
			loot.add_loot({"Parts":4,"Intel":4,"Contraband":1})
		"SILVER":
			economy.add_cash(15000)
			economy.add_gold(12)
			loot.add_loot({"Parts":3,"Intel":3})
		_:
			economy.add_cash(8000)
			economy.add_gold(6)
			loot.add_loot({"Parts":2,"Intel":2})
	season_reward_claimed.emit(tier)
	changed.emit()
	return true


func claim_weekly_cache() -> bool:
	var status := get_status()
	if not bool(status["claimable"]):
		return false
	weekly_claimed = true
	dominion_marks += 100
	season_points += 100
	cycles_completed += 1
	economy.add_cash(15000)
	economy.add_gold(10)
	loot.add_loot({"Parts":3,"Intel":2})
	progression.add_xp(250)
	dominion_cache_claimed.emit()
	changed.emit()
	return true


func claim_mastery() -> bool:
	var status := get_status()
	if not bool(status["mastery_claimable"]):
		return false
	mastery_claimed = true
	dominion_marks += 50
	season_points += 50
	economy.add_cash(10000)
	economy.add_gold(10)
	loot.add_loot({"Contraband":1,"Intel":2})
	progression.add_xp(150)
	dominion_mastery_claimed.emit()
	changed.emit()
	return true


func _on_family_encounter_resolved(district_id: String, _encounter_type: String, victory: bool) -> void:
	if not is_unlocked() or not victory:
		if district_id == active_boss_target:
			active_boss_target = ""
		return
	family_operation_wins = mini(FAMILY_OPERATION_GOAL, family_operation_wins + 1)
	var modifier := get_current_modifier()
	var featured := district_id == String(modifier.get("district_id", ""))
	if scored_operation_wins < 5:
		scored_operation_wins += 1
		season_points += FEATURED_WIN_POINTS if featured else NORMAL_WIN_POINTS
		if featured:
			featured_wins += 1
			economy.add_cash(int(modifier.get("bonus_cash", 0)))
			var bonus_loot = modifier.get("bonus_loot", {})
			if bonus_loot is Dictionary:
				loot.add_loot(bonus_loot)
	if district_id == active_boss_target:
		boss_rematch_wins = mini(BOSS_REMATCH_GOAL, boss_rematch_wins + 1)
		active_boss_target = ""
	changed.emit()


func _on_faction_war_completed(won: bool, _season_points_awarded: int) -> void:
	if not is_unlocked() or not won:
		return
	faction_war_wins = mini(FACTION_WAR_GOAL, faction_war_wins + 1)
	season_points += 40
	changed.emit()


func _on_mission_completed(mission_id: String) -> void:
	if mission_id == "chapter_6_complete":
		_refresh_week()
		changed.emit()


func get_save_data() -> Dictionary:
	return {
		"weekly_period": weekly_period,
		"family_operation_wins": family_operation_wins,
		"boss_rematch_wins": boss_rematch_wins,
		"faction_war_wins": faction_war_wins,
		"weekly_claimed": weekly_claimed,
		"mastery_claimed": mastery_claimed,
		"dominion_marks": dominion_marks,
		"cycles_completed": cycles_completed,
		"operation_cursor": operation_cursor,
		"boss_cursor": boss_cursor,
		"active_boss_target": active_boss_target,
		"season_period": season_period,
		"season_points": season_points,
		"claimed_season_tiers": claimed_season_tiers.duplicate(),
		"featured_wins": featured_wins,
		"scored_operation_wins": scored_operation_wins,
		"prestige_badges": prestige_badges.duplicate(),
		"equipped_prestige_badge": equipped_prestige_badge,
		"last_season_result": last_season_result.duplicate(true)
	}


func load_save_data(data: Dictionary) -> void:
	weekly_period = int(data.get("weekly_period", weekly_period))
	family_operation_wins = clampi(int(data.get("family_operation_wins", 0)), 0, FAMILY_OPERATION_GOAL)
	boss_rematch_wins = clampi(int(data.get("boss_rematch_wins", 0)), 0, BOSS_REMATCH_GOAL)
	faction_war_wins = clampi(int(data.get("faction_war_wins", 0)), 0, FACTION_WAR_GOAL)
	weekly_claimed = bool(data.get("weekly_claimed", false))
	mastery_claimed = bool(data.get("mastery_claimed", false))
	dominion_marks = maxi(0, int(data.get("dominion_marks", 0)))
	cycles_completed = maxi(0, int(data.get("cycles_completed", 0)))
	operation_cursor = posmod(int(data.get("operation_cursor", 0)), TARGET_ROTATION.size())
	boss_cursor = posmod(int(data.get("boss_cursor", 0)), TARGET_ROTATION.size())
	active_boss_target = String(data.get("active_boss_target", ""))
	season_period = int(data.get("season_period", season_period))
	season_points = maxi(0, int(data.get("season_points", 0)))
	claimed_season_tiers.clear()
	var saved_tiers = data.get("claimed_season_tiers", [])
	if saved_tiers is Array:
		for raw_tier in saved_tiers:
			var tier := String(raw_tier)
			if tier in ["SILVER", "GOLD", "PLATINUM"] and not tier in claimed_season_tiers:
				claimed_season_tiers.append(tier)

	pending_season_tiers.clear()
	var saved_pending = data.get("pending_season_tiers", [])
	if saved_pending is Array:
		for raw_tier in saved_pending:
			var pending_tier := String(raw_tier)
			if pending_tier in ["SILVER", "GOLD", "PLATINUM"] and not pending_tier in pending_season_tiers:
				pending_season_tiers.append(pending_tier)

	pending_season_prestige.clear()
	var saved_pending_prestige = data.get("pending_season_prestige", {})
	if saved_pending_prestige is Dictionary:
		for raw_key in saved_pending_prestige.keys():
			var prestige_tier := String(raw_key)
			if prestige_tier in pending_season_tiers:
				pending_season_prestige[prestige_tier] = String(saved_pending_prestige[raw_key]).left(40)

	featured_wins = maxi(0, int(data.get("featured_wins", 0)))
	scored_operation_wins = clampi(int(data.get("scored_operation_wins", 0)), 0, 5)

	prestige_badges.clear()
	var saved_badges = data.get("prestige_badges", [])
	if saved_badges is Array:
		for raw_badge in saved_badges:
			var badge := String(raw_badge).strip_edges().left(40)
			if not badge.is_empty() and not badge in prestige_badges:
				prestige_badges.append(badge)
	equipped_prestige_badge = String(data.get("equipped_prestige_badge", ""))
	if not equipped_prestige_badge.is_empty() and not equipped_prestige_badge in prestige_badges:
		equipped_prestige_badge = prestige_badges[0] if not prestige_badges.is_empty() else ""

	var saved_result = data.get("last_season_result", {})
	last_season_result = saved_result.duplicate(true) if saved_result is Dictionary else {}

	_refresh_season()
	_refresh_week()
	changed.emit()
