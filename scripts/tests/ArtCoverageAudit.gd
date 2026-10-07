extends Node

var failures: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame

	_check_project_icon()

	var main_scene := load("res://scenes/core/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene could not be loaded for presentation audit.")
		_finish()
		return

	var game := main_scene.instantiate()
	add_child(game)
	await get_tree().process_frame

	var presentation := game.get_node_or_null("PresentationCatalog") as PresentationCatalog
	var city := game.get_node_or_null("CityMap")
	if presentation == null:
		_fail("PresentationCatalog is missing from Main.")
		_finish()
		return
	if city == null:
		_fail("CityMap is missing from Main.")
		_finish()
		return

	_check_city_art(presentation, city)
	_check_character_art(presentation)
	_check_ui_and_street_art(presentation)
	_finish()


func _check_project_icon() -> void:
	var icon_path := String(ProjectSettings.get_setting("application/config/icon", ""))
	if icon_path.is_empty():
		_fail("application/config/icon is not configured.")
	elif not ResourceLoader.exists(icon_path):
		_fail("Configured project icon is missing: %s" % icon_path)


func _check_city_art(presentation: PresentationCatalog, city: Node) -> void:
	if not presentation.is_city_atlas_ready():
		_fail("City atlas failed to decode: %s" % presentation.get_atlas_error())
		return

	if presentation.get_city_atlas_size() != Vector2i(320, 160):
		_fail("City atlas size changed unexpectedly: %s" % presentation.get_city_atlas_size())

	for key in [
		"safehouse",
		"hospital",
		"barracks",
		"Garage",
		"Intel Office",
		"Scrapyard",
		"Data Hub",
		"raid_target"
	]:
		if presentation.get_texture(key) == null:
			_fail("Missing required city art texture: %s" % key)

	for building in [city.safehouse, city.hospital, city.barracks]:
		if building == null or building.art_texture == null:
			_fail("A core building did not receive approved art at runtime.")

	for lot in [city.lot_a, city.lot_b, city.lot_c, city.lot_d]:
		if lot == null or lot.art_texture == null:
			_fail("A buildable facility did not receive approved art at runtime.")

	for target in city.get_raid_targets():
		if target == null or target.art_texture == null:
			_fail("A raid target did not receive approved art at runtime.")


func _check_character_art(presentation: PresentationCatalog) -> void:
	if not presentation.is_character_atlas_ready():
		_fail("Character/unit portrait atlas failed to load.")
		return

	if presentation.get_character_atlas_size() != Vector2i(128, 64):
		_fail("Character/unit portrait atlas size changed unexpectedly: %s" % presentation.get_character_atlas_size())

	for key in ["vex", "mia", "noah", "kira", "enforcer", "driver", "spy"]:
		if presentation.get_character_portrait(key) == null:
			_fail("Missing required character/unit portrait: %s" % key)


func _check_ui_and_street_art(presentation: PresentationCatalog) -> void:
	if not presentation.is_decor_atlas_ready():
		_fail("UI/street atlas failed to load.")
		return

	if presentation.get_decor_atlas_size() != Vector2i(256, 160):
		_fail("UI/street atlas size changed unexpectedly: %s" % presentation.get_decor_atlas_size())

	for key in [
		"ui_panel",
		"ui_bar",
		"ui_button_dark",
		"ui_button_gold",
		"road_intersection",
		"road_straight"
	]:
		if presentation.get_decor_texture(key) == null:
			_fail("Missing required UI/street art texture: %s" % key)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[ART AUDIT] %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("[ART AUDIT] PASS — required runtime art is present and wired.")
		get_tree().quit(0)
	else:
		print("[ART AUDIT] FAIL — %d issue(s)." % failures.size())
		get_tree().quit(1)
