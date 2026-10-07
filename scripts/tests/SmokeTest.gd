extends Node

var failures: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame

	_check_resource("res://scenes/core/Boot.tscn")
	_check_resource("res://scenes/core/Main.tscn")
	_check_resource("res://scenes/ui/PauseMenu.tscn")
	_check_resource("res://scenes/ui/SettingsDiagnosticsUI.tscn")
	_check_resource("res://scenes/ui/CombatStrategyUI.tscn")
	_check_resource("res://scenes/ui/WorldControlUI.tscn")

	var main_scene := load("res://scenes/core/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene could not be loaded.")
		_finish()
		return

	var game := main_scene.instantiate()
	add_child(game)
	await get_tree().process_frame

	for path in [
		"GameBalance",
		"SettingsManager",
		"SaveManager",
		"CityMap",
		"HUD",
		"PauseMenu",
		"AudioManager",
		"UIFocusManager",
		"FacilityEffects",
		"CoreBuildingEffects",
		"StoreManager",
		"StoreUI",
		"WorldControlManager",
		"WorldControlUI",
		"ResourceProductionManager"
	]:
		if game.get_node_or_null(path) == null:
			_fail("Missing Main node: %s" % path)

	var save := game.get_node_or_null("SaveManager") as SaveManager
	if save == null or SaveManager.SAVE_VERSION < 16:
		_fail("Save schema is not production-ready.")

	var balance := game.get_node_or_null("GameBalance") as GameBalance
	if balance == null or balance.get_recruitment_definition(&"Driver").is_empty():
		_fail("GameBalance recruitment table missing Driver.")
	if balance == null or balance.get_facility_value("garage_driver_support_per_level", 0.0) <= 0.0:
		_fail("GameBalance facility tuning is missing.")
	if balance == null or balance.get_core_building_value("clinic_healing_reduction_per_level", 0.0) <= 0.0:
		_fail("GameBalance core-building tuning is missing.")

	var recruitment := game.get_node_or_null("RecruitmentQueue") as RecruitmentQueue
	if recruitment == null or recruitment.get_queue_capacity() < 1:
		_fail("Recruitment queue capacity is invalid.")

	var alliance := game.get_node_or_null("AllianceManager") as AllianceManager
	if alliance == null or alliance.get_xp_for_next_level() <= 0:
		_fail("Alliance progression is invalid.")

	var world_control := game.get_node_or_null("WorldControlManager") as WorldControlManager
	if world_control == null or not world_control.is_discovered("downtown_bank"):
		_fail("World-control discovery defaults are invalid.")

	var resources := game.get_node_or_null("ResourceProductionManager") as ResourceProductionManager
	if resources == null:
		_fail("Resource production manager is missing.")

	var city := game.get_node_or_null("CityMap")
	if city == null or city.get_node_or_null("TurfOverlay") == null:
		_fail("Turf ownership overlay is missing.")
	elif city.lot_c == null or city.lot_d == null:
		_fail("Resource-production build lots are missing.")

	_finish()


func _check_resource(path: String) -> void:
	if not ResourceLoader.exists(path):
		_fail("Missing resource: %s" % path)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[SMOKE] %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("[SMOKE] PASS — core scenes and systems loaded.")
		get_tree().quit(0)
	else:
		print("[SMOKE] FAIL — %d issue(s)." % failures.size())
		get_tree().quit(1)
