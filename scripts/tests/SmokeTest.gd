extends Node

var failures: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame

	_check_resource("res://scenes/core/Boot.tscn")
	_check_resource("res://scenes/core/Main.tscn")
	_check_resource("res://scenes/ui/PauseMenu.tscn")
	_check_resource("res://scenes/ui/SettingsDiagnosticsUI.tscn")
	_check_resource("res://scenes/ui/CombatStrategyUI.tscn")

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
		"UIFocusManager"
	]:
		if game.get_node_or_null(path) == null:
			_fail("Missing Main node: %s" % path)

	var save := game.get_node_or_null("SaveManager") as SaveManager
	if save == null or SaveManager.SAVE_VERSION < 12:
		_fail("Save schema is not production-ready.")

	var balance := game.get_node_or_null("GameBalance") as GameBalance
	if balance == null or balance.get_recruitment_definition(&"Driver").is_empty():
		_fail("GameBalance recruitment table missing Driver.")

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
