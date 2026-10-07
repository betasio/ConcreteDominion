class_name TutorialManager
extends Node

signal changed
signal tutorial_completed

const STEP_WELCOME := 0
const STEP_RECRUIT := 1
const STEP_UPGRADE := 2
const STEP_WORLD := 3
const STEP_ALLIANCE := 4
const STEP_RAID := 5
const STEP_DONE := 6

var current_step := STEP_WELCOME
var skipped := false

var city_map: Node
var alliance: AllianceManager


func setup(
	recruitment: RecruitmentQueue,
	construction: ConstructionQueue,
	world: Node,
	alliance_manager: AllianceManager,
	raid_battle: RaidBattle
) -> void:
	city_map = world
	alliance = alliance_manager

	recruitment.recruitment_completed.connect(_on_recruitment_completed)
	construction.construction_completed.connect(_on_construction_completed)
	city_map.view_mode_changed.connect(_on_view_mode_changed)
	alliance.changed.connect(_on_alliance_changed)
	raid_battle.battle_resolved.connect(_on_battle_resolved)

	_evaluate_loaded_state()


func advance_welcome() -> void:
	if is_active() and current_step == STEP_WELCOME:
		_set_step(STEP_RECRUIT)


func skip_tutorial() -> void:
	if not is_active():
		return
	skipped = true
	_set_step(STEP_DONE)


func is_active() -> bool:
	return current_step < STEP_DONE and not skipped


func get_title_key() -> String:
	match current_step:
		STEP_WELCOME:
			return "TUTORIAL_WELCOME_TITLE"
		STEP_RECRUIT:
			return "TUTORIAL_RECRUIT_TITLE"
		STEP_UPGRADE:
			return "TUTORIAL_UPGRADE_TITLE"
		STEP_WORLD:
			return "TUTORIAL_WORLD_TITLE"
		STEP_ALLIANCE:
			return "TUTORIAL_ALLIANCE_TITLE"
		STEP_RAID:
			return "TUTORIAL_RAID_TITLE"
		_:
			return "TUTORIAL_DONE_TITLE"


func get_body_key() -> String:
	match current_step:
		STEP_WELCOME:
			return "TUTORIAL_WELCOME_BODY"
		STEP_RECRUIT:
			return "TUTORIAL_RECRUIT_BODY"
		STEP_UPGRADE:
			return "TUTORIAL_UPGRADE_BODY"
		STEP_WORLD:
			return "TUTORIAL_WORLD_BODY"
		STEP_ALLIANCE:
			return "TUTORIAL_ALLIANCE_BODY"
		STEP_RAID:
			return "TUTORIAL_RAID_BODY"
		_:
			return "TUTORIAL_DONE_BODY"


func get_progress_text() -> String:
	if current_step >= STEP_DONE:
		return "6 / 6"
	return "%d / 6" % (current_step + 1)


func get_save_data() -> Dictionary:
	return {
		"current_step": current_step,
		"skipped": skipped
	}


func load_save_data(data: Dictionary) -> void:
	current_step = clampi(int(data.get("current_step", STEP_WELCOME)), STEP_WELCOME, STEP_DONE)
	skipped = bool(data.get("skipped", false))
	_evaluate_loaded_state()
	changed.emit()


func _evaluate_loaded_state() -> void:
	if not is_active():
		return
	if current_step == STEP_UPGRADE and city_map.safehouse.level >= 2:
		_set_step(STEP_WORLD)
	if current_step == STEP_WORLD and city_map.get_view_mode() == &"world":
		_set_step(STEP_ALLIANCE)
	if current_step == STEP_ALLIANCE and alliance.is_member_assigned("local_player"):
		_set_step(STEP_RAID)


func _on_recruitment_completed(_troop_type: StringName, _amount: int) -> void:
	if current_step == STEP_RECRUIT:
		_set_step(STEP_UPGRADE)


func _on_construction_completed(target: Node) -> void:
	if current_step == STEP_UPGRADE and target == city_map.safehouse:
		_set_step(STEP_WORLD)


func _on_view_mode_changed(mode: StringName) -> void:
	if current_step == STEP_WORLD and mode == &"world":
		_set_step(STEP_ALLIANCE)


func _on_alliance_changed() -> void:
	if current_step == STEP_ALLIANCE and alliance.is_member_assigned("local_player"):
		_set_step(STEP_RAID)


func _on_battle_resolved(result: Dictionary) -> void:
	if current_step != STEP_RAID:
		return
	if bool(result.get("victory", false)):
		_set_step(STEP_DONE)


func _set_step(value: int) -> void:
	var previous := current_step
	current_step = clampi(value, STEP_WELCOME, STEP_DONE)
	changed.emit()
	if previous < STEP_DONE and current_step >= STEP_DONE:
		tutorial_completed.emit()
