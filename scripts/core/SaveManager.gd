class_name SaveManager
extends Node

signal save_completed
signal load_completed(found_save: bool)

const SAVE_PATH := "user://concrete_dominion_save.json"
const BACKUP_PATH := "user://concrete_dominion_save.backup.json"
const SAVE_VERSION := 23

var economy: PlayerEconomy
var loot_inventory: LootInventory
var progression: PlayerProgression
var missions: MissionTracker
var retention: RetentionManager
var event_manager: EventManager
var combat_loadout: CombatLoadout
var player_profile: PlayerProfile
var mailbox: MailboxManager
var alliance: AllianceManager
var alliance_social: AllianceSocial
var faction: FactionManager
var roster: TroopRoster
var hospital: HospitalQueue
var construction: ConstructionQueue
var recruitment: RecruitmentQueue
var raid_battle: RaidBattle
var world_control: WorldControlManager
var resource_production: ResourceProductionManager
var achievements: AchievementManager
var tutorial: TutorialManager
var city_map: Node

var _autosave_timer := 0.0
var last_loaded_version: int = SAVE_VERSION
var _dirty := false
var _is_loading := false

@export var autosave_delay: float = 1.0


func setup(
	player_economy: PlayerEconomy,
	loot: LootInventory,
	player_progression: PlayerProgression,
	mission_tracker: MissionTracker,
	retention_manager: RetentionManager,
	event: EventManager,
	loadout: CombatLoadout,
	profile: PlayerProfile,
	mailbox_manager: MailboxManager,
	alliance_manager: AllianceManager,
	social: AllianceSocial,
	faction_manager: FactionManager,
	troop_roster: TroopRoster,
	hospital_queue: HospitalQueue,
	construction_queue: ConstructionQueue,
	recruitment_queue: RecruitmentQueue,
	battle: RaidBattle,
	control: WorldControlManager,
	resources: ResourceProductionManager,
	achievement_manager: AchievementManager,
	tutorial_manager: TutorialManager,
	world: Node
) -> void:
	economy = player_economy
	loot_inventory = loot
	progression = player_progression
	missions = mission_tracker
	retention = retention_manager
	event_manager = event
	combat_loadout = loadout
	player_profile = profile
	mailbox = mailbox_manager
	alliance = alliance_manager
	alliance_social = social
	faction = faction_manager
	roster = troop_roster
	hospital = hospital_queue
	construction = construction_queue
	recruitment = recruitment_queue
	raid_battle = battle
	world_control = control
	resource_production = resources
	achievements = achievement_manager
	tutorial = tutorial_manager
	city_map = world

	economy.changed.connect(mark_dirty)
	loot_inventory.changed.connect(mark_dirty)
	progression.changed.connect(mark_dirty)
	missions.changed.connect(mark_dirty)
	retention.changed.connect(mark_dirty)
	event_manager.changed.connect(mark_dirty)
	combat_loadout.changed.connect(mark_dirty)
	player_profile.changed.connect(mark_dirty)
	mailbox.changed.connect(mark_dirty)
	alliance.changed.connect(mark_dirty)
	alliance_social.changed.connect(mark_dirty)
	faction.changed.connect(mark_dirty)
	roster.changed.connect(mark_dirty)
	hospital.queue_changed.connect(mark_dirty)
	construction.queue_changed.connect(mark_dirty)
	recruitment.queue_changed.connect(mark_dirty)
	raid_battle.changed.connect(mark_dirty)
	world_control.changed.connect(mark_dirty)
	resource_production.changed.connect(mark_dirty)
	achievements.changed.connect(mark_dirty)
	tutorial.changed.connect(mark_dirty)
	city_map.view_mode_changed.connect(func(_mode): mark_dirty())

	for building in city_map.get_persistent_buildings():
		building.changed.connect(mark_dirty)
	for target in city_map.get_raid_targets():
		target.changed.connect(mark_dirty)


func _process(delta: float) -> void:
	if not _dirty or _is_loading:
		return
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		save_game()


func mark_dirty() -> void:
	if _is_loading:
		return
	_dirty = true
	_autosave_timer = autosave_delay


func save_game() -> bool:
	if economy == null:
		return false

	var data := {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"economy": economy.get_save_data(),
		"loot": loot_inventory.get_save_data(),
		"progression": progression.get_save_data(),
		"missions": missions.get_save_data(),
		"retention": retention.get_save_data(),
		"event": event_manager.get_save_data(),
		"combat_loadout": combat_loadout.get_save_data(),
		"profile": player_profile.get_save_data(),
		"mailbox": mailbox.get_save_data(),
		"alliance": alliance.get_save_data(),
		"alliance_social": alliance_social.get_save_data(),
		"faction": faction.get_save_data(),
		"roster": roster.get_save_data(),
		"hospital": hospital.get_save_data(),
		"construction": construction.get_save_data(),
		"recruitment": recruitment.get_save_data(),
		"raid_battle": raid_battle.get_save_data(),
		"world_control": world_control.get_save_data(),
		"resource_production": resource_production.get_save_data(),
		"achievements": achievements.get_save_data(),
		"tutorial": tutorial.get_save_data(),
		"world": city_map.get_save_data()
	}

	_backup_current_save()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing: %s" % SAVE_PATH)
		return false

	file.store_string(JSON.stringify(data, "	"))
	file.close()
	_dirty = false
	_autosave_timer = 0.0
	save_completed.emit()
	return true


func load_game() -> bool:
	var parsed := _read_save_dictionary(SAVE_PATH)
	var used_backup := false

	if parsed.is_empty():
		parsed = _read_save_dictionary(BACKUP_PATH)
		used_backup = not parsed.is_empty()

	if parsed.is_empty():
		load_completed.emit(false)
		return false

	if used_backup:
		push_warning("Primary save was unavailable or invalid. Loaded backup save.")

	var data: Dictionary = _migrate_save(parsed)
	last_loaded_version = int(data.get("version", SAVE_VERSION))
	var saved_at := float(data.get("saved_at_unix", Time.get_unix_time_from_system()))
	var elapsed := maxf(0.0, Time.get_unix_time_from_system() - saved_at)

	_is_loading = true
	economy.load_save_data(data.get("economy", {}))
	loot_inventory.load_save_data(data.get("loot", {}))
	progression.load_save_data(data.get("progression", {}))
	missions.load_save_data(data.get("missions", {}))
	retention.load_save_data(data.get("retention", {}))
	event_manager.load_save_data(data.get("event", {}))
	combat_loadout.load_save_data(data.get("combat_loadout", {}))
	player_profile.load_save_data(data.get("profile", {}))
	mailbox.load_save_data(data.get("mailbox", {}))
	alliance.load_save_data(data.get("alliance", {}))
	alliance_social.load_save_data(data.get("alliance_social", {}), elapsed)
	faction.load_save_data(data.get("faction", {}), elapsed)
	roster.load_save_data(data.get("roster", {}))
	city_map.load_save_data(data.get("world", {}), elapsed)
	world_control.load_save_data(data.get("world_control", {}), elapsed)
	resource_production.load_save_data(data.get("resource_production", {}), elapsed)
	achievements.load_save_data(data.get("achievements", {}))
	tutorial.load_save_data(data.get("tutorial", {}))
	hospital.load_save_data(data.get("hospital", {}), elapsed)
	construction.load_save_data(data.get("construction", {}), elapsed, city_map)
	recruitment.load_save_data(data.get("recruitment", {}), elapsed)
	raid_battle.load_save_data(data.get("raid_battle", {}), elapsed)
	_is_loading = false
	_dirty = false
	_autosave_timer = 0.0
	load_completed.emit(true)
	return true


func _read_save_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Dictionary:
		return parsed
	return {}


func _backup_current_save() -> void:
	var existing := _read_save_dictionary(SAVE_PATH)
	if existing.is_empty():
		return

	var file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(existing, "\t"))
		file.close()


func _migrate_save(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var version := maxi(1, int(data.get("version", 1)))

	if version < 7:
		if not data.has("progression"):
			data["progression"] = {}
		if not data.has("missions"):
			data["missions"] = {}

	if version < 8 and not data.has("retention"):
		data["retention"] = {}

	if version < 9:
		if not data.has("profile"):
			data["profile"] = {}
		if not data.has("mailbox"):
			data["mailbox"] = {}

	if version < 10 and not data.has("event"):
		data["event"] = {}

	if version < 11 and not data.has("combat_loadout"):
		data["combat_loadout"] = {}

	if version < 13:
		var world = data.get("world", {})
		if world is Dictionary:
			if bool(world.get("garage_built", false)) and not world.has("garage_level"):
				world["garage_level"] = 1
			if bool(world.get("intel_built", false)) and not world.has("intel_level"):
				world["intel_level"] = 1
			data["world"] = world

	if version < 15 and not data.has("world_control"):
		var saved_level := 1
		var progression_data = data.get("progression", {})
		if progression_data is Dictionary:
			saved_level = maxi(1, int(progression_data.get("account_level", 1)))
		var migrated_discovered := {"downtown_bank": true}
		var unlocks := {
			"harbor_bank": 2,
			"midtown_exchange": 3,
			"northside_hq": 4,
			"casino_vault": 5,
			"financial_tower": 6,
			"industrial_depot": 7
		}
		for target_id in unlocks.keys():
			if saved_level >= int(unlocks[target_id]):
				migrated_discovered[target_id] = true
		data["world_control"] = {
			"discovered": migrated_discovered,
			"owned": {}
		}

	if version < 16 and not data.has("resource_production"):
		data["resource_production"] = {}

	if version < 17 and not data.has("achievements"):
		data["achievements"] = {}

	if version < 18 and not data.has("tutorial"):
		data["tutorial"] = {}

	if version < 19:
		var retention_data = data.get("retention", {})
		if not (retention_data is Dictionary):
			retention_data = {}
		if not retention_data.has("daily_mastery_claimed"):
			retention_data["daily_mastery_claimed"] = false
		if not retention_data.has("weekly_mastery_claimed"):
			retention_data["weekly_mastery_claimed"] = false
		if not retention_data.has("pending_comeback_reward"):
			retention_data["pending_comeback_reward"] = {}
		if not retention_data.has("comeback_gap_days"):
			retention_data["comeback_gap_days"] = 0
		if not retention_data.has("lifetime_construction_completed"):
			retention_data["lifetime_construction_completed"] = 0
		data["retention"] = retention_data

	if version < 20:
		var mission_data = data.get("missions", {})
		if not (mission_data is Dictionary):
			mission_data = {}
		if not mission_data.has("_chapter_meta"):
			mission_data["_chapter_meta"] = {
				"milestones_claimed": {"2": false, "4": false}
			}
		data["missions"] = mission_data

	if version < 21:
		var mission_data_v21 = data.get("missions", {})
		if not (mission_data_v21 is Dictionary):
			mission_data_v21 = {}
		var chapter_meta = mission_data_v21.get("_chapter_meta", {})
		if not (chapter_meta is Dictionary):
			chapter_meta = {}
		if not chapter_meta.has("chapter_2_choice"):
			chapter_meta["chapter_2_choice"] = ""
		mission_data_v21["_chapter_meta"] = chapter_meta
		data["missions"] = mission_data_v21

		var world_control_data = data.get("world_control", {})
		if not (world_control_data is Dictionary):
			world_control_data = {}
		if not world_control_data.has("faction_rivalry"):
			world_control_data["faction_rivalry"] = {
				"dock_rats": 0,
				"iron_serpents": 0,
				"meridian_boys": 0,
				"northside_crew": 0,
				"velvet_circle": 0
			}
		data["world_control"] = world_control_data

	if version < 22:
		if not data.has("faction"):
			data["faction"] = {}

	if version < 23:
		var faction_data = data.get("faction", {})
		if not (faction_data is Dictionary):
			faction_data = {}
		if not faction_data.has("daily_period"):
			faction_data["daily_period"] = -1
		if not faction_data.has("daily_claimed"):
			faction_data["daily_claimed"] = false
		if not faction_data.has("daily_mastery_claimed"):
			faction_data["daily_mastery_claimed"] = false
		if not faction_data.has("daily_tasks"):
			faction_data["daily_tasks"] = {}
		if not faction_data.has("gift_charges"):
			faction_data["gift_charges"] = 0
		if not faction_data.has("active_rally"):
			faction_data["active_rally"] = {}
		if not faction_data.has("active_war"):
			faction_data["active_war"] = {}
		data["faction"] = faction_data

	data["schema_meta"] = {
		"migrated_from": version,
		"schema": SAVE_VERSION
	}
	data["version"] = SAVE_VERSION
	return data


func delete_save() -> bool:
	var ok := true
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and ok
	return ok


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
