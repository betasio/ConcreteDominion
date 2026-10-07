class_name PlayerProfile
extends Node

signal changed

var display_name: String = "Boss"
var avatar_index: int = 0

var progression: PlayerProgression
var roster: TroopRoster
var city_map: Node
var retention: RetentionManager


func setup(
	player_progression: PlayerProgression,
	troop_roster: TroopRoster,
	world: Node,
	retention_manager: RetentionManager
) -> void:
	progression = player_progression
	roster = troop_roster
	city_map = world
	retention = retention_manager

	progression.changed.connect(_emit_changed)
	roster.changed.connect(_emit_changed)
	retention.changed.connect(_emit_changed)

	for building in city_map.get_persistent_buildings():
		building.changed.connect(_emit_changed)

	changed.emit()


func set_display_name(value: String) -> void:
	var clean := value.strip_edges()

	if clean == "":
		clean = "Boss"

	display_name = clean.left(20)
	changed.emit()


func cycle_avatar() -> void:
	avatar_index = (avatar_index + 1) % 4
	changed.emit()


func get_avatar_name() -> String:
	var names := ["The Boss", "Street Fox", "Night Wolf", "Golden King"]
	return names[avatar_index]


func get_power_rating() -> int:
	if progression == null or roster == null or city_map == null:
		return 0

	var troop_power := int(
		float(roster.get_count(&"Enforcer")) * progression.get_enforcer_power_each()
		+ float(roster.get_count(&"Driver")) * 140.0 * float(progression.get_specialist_level(&"Driver"))
		+ float(roster.get_count(&"Spy")) * 150.0 * float(progression.get_specialist_level(&"Spy"))
	)

	var building_power := 0
	for building in city_map.get_persistent_buildings():
		if building is Building:
			building_power += building.level * 450
		elif building is BuildLot and building.is_built:
			building_power += 700

	return troop_power + building_power + progression.account_level * 1000


func get_badges() -> PackedStringArray:
	var badges := PackedStringArray()

	if progression != null:
		if progression.account_level >= 2:
			badges.append("Rising Boss")
		if progression.account_level >= 4:
			badges.append("District Player")
		if progression.account_level >= 6:
			badges.append("City Kingpin")

	if retention != null:
		if bool(retention.achievements.get("first_raid", false)):
			badges.append("First Blood")
		if bool(retention.achievements.get("specialist", false)):
			badges.append("Specialist")
		if bool(retention.achievements.get("crew_builder", false)):
			badges.append("Crew Builder")

	if badges.is_empty():
		badges.append("New Operator")

	return badges


func get_save_data() -> Dictionary:
	return {
		"display_name": display_name,
		"avatar_index": avatar_index
	}


func load_save_data(data: Dictionary) -> void:
	display_name = String(data.get("display_name", display_name)).left(20)
	avatar_index = posmod(int(data.get("avatar_index", avatar_index)), 4)
	changed.emit()


func _emit_changed() -> void:
	changed.emit()
