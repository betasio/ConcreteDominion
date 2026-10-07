class_name SaveManager
extends Node

signal save_completed
signal load_completed(found_save: bool)

const SAVE_PATH := "user://concrete_dominion_save.json"
const SAVE_VERSION := 1

var economy: PlayerEconomy
var roster: TroopRoster
var hospital: HospitalQueue
var construction: ConstructionQueue
var recruitment: RecruitmentQueue
var city_map: Node

var _autosave_timer := 0.0
var _dirty := false
var _is_loading := false

@export var autosave_delay: float = 1.0


func setup(
	player_economy: PlayerEconomy,
	troop_roster: TroopRoster,
	hospital_queue: HospitalQueue,
	construction_queue: ConstructionQueue,
	recruitment_queue: RecruitmentQueue,
	world: Node
) -> void:
	economy = player_economy
	roster = troop_roster
	hospital = hospital_queue
	construction = construction_queue
	recruitment = recruitment_queue
	city_map = world

	economy.changed.connect(mark_dirty)
	roster.changed.connect(mark_dirty)
	hospital.queue_changed.connect(mark_dirty)
	construction.queue_changed.connect(mark_dirty)
	recruitment.queue_changed.connect(mark_dirty)

	for building in city_map.get_persistent_buildings():
		building.changed.connect(mark_dirty)


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
		"roster": roster.get_save_data(),
		"hospital": hospital.get_save_data(),
		"construction": construction.get_save_data(),
		"recruitment": recruitment.get_save_data(),
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

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Save file is invalid; starting with defaults.")
		load_completed.emit(false)
		return false

	var data: Dictionary = parsed
	var saved_at := float(data.get("saved_at_unix", Time.get_unix_time_from_system()))
	var elapsed := maxf(0.0, Time.get_unix_time_from_system() - saved_at)

	_is_loading = true

	economy.load_save_data(data.get("economy", {}))
	roster.load_save_data(data.get("roster", {}))
	city_map.load_save_data(data.get("world", {}))
	hospital.load_save_data(data.get("hospital", {}), elapsed)
	construction.load_save_data(data.get("construction", {}), elapsed, city_map)
	recruitment.load_save_data(data.get("recruitment", {}), elapsed)

	_is_loading = false
	_dirty = false
	_autosave_timer = 0.0

	load_completed.emit(true)
	return true


func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true

	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	return error == OK


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
