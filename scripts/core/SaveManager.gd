class_name SaveManager
extends Node

signal save_completed
signal load_completed(found_save: bool)

const SAVE_PATH := "user://concrete_dominion_save.json"
const SAVE_VERSION := 12

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
var roster: TroopRoster
var hospital: HospitalQueue
var construction: ConstructionQueue
var recruitment: RecruitmentQueue
var raid_battle: RaidBattle
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
	troop_roster: TroopRoster,
	hospital_queue: HospitalQueue,
	construction_queue: ConstructionQueue,
	recruitment_queue: RecruitmentQueue,
	battle: RaidBattle,
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
	roster = troop_roster
	hospital = hospital_queue
	construction = construction_queue
	recruitment = recruitment_queue
	raid_battle = battle
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
	roster.changed.connect(mark_dirty)
	hospital.queue_changed.connect(mark_dirty)
	construction.queue_changed.connect(mark_dirty)
	recruitment.queue_changed.connect(mark_dirty)
	raid_battle.changed.connect(mark_dirty)
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
		"roster": roster.get_save_data(),
		"hospital": hospital.get_save_data(),
		"construction": construction.get_save_data(),
		"recruitment": recruitment.get_save_data(),
		"raid_battle": raid_battle.get_save_data(),
		"world": city_map.get_save_data()
	}

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
	if not FileAccess.file_exists(SAVE_PATH):
		load_completed.emit(false)
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		load_completed.emit(false)
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		push_warning("Save file is invalid; starting with defaults.")
		load_completed.emit(false)
		return false

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
	roster.load_save_data(data.get("roster", {}))
	city_map.load_save_data(data.get("world", {}), elapsed)
	hospital.load_save_data(data.get("hospital", {}), elapsed)
	construction.load_save_data(data.get("construction", {}), elapsed, city_map)
	recruitment.load_save_data(data.get("recruitment", {}), elapsed)
	raid_battle.load_save_data(data.get("raid_battle", {}), elapsed)
	_is_loading = false
	_dirty = false
	_autosave_timer = 0.0
	load_completed.emit(true)
	return true


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

	data["schema_meta"] = {
		"migrated_from": version,
		"schema": SAVE_VERSION
	}
	data["version"] = SAVE_VERSION
	return data


func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH)) == OK


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
