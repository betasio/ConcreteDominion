class_name AllianceSocial
extends Node

signal changed

@export var invite_duration: float = 15.0
@export var max_feed_entries: int = 12

var alliance: AllianceManager
var feed: Array[String] = []
var active_invite: Dictionary = {}
var _joined_mia := false
var _joined_noah := false
var _joined_kira := false


func setup(alliance_manager: AllianceManager) -> void:
	alliance = alliance_manager

	if feed.is_empty():
		_add_feed("Alliance channel connected.")
		_add_feed("Vex: Banks are active in the district.")
		_add_feed("Mia: I can cover Driver support.")

	changed.emit()


func _process(delta: float) -> void:
	if active_invite.is_empty():
		return

	var previous := float(active_invite["seconds_remaining"])
	active_invite["seconds_remaining"] = maxf(0.0, previous - delta)
	var current := float(active_invite["seconds_remaining"])

	if not _joined_mia and current <= 12.0:
		_join_simulated_member("driver_ally_01", "Mia joined the raid invite.")
		_joined_mia = true

	if not _joined_noah and current <= 9.0:
		_join_simulated_member("spy_ally_01", "Noah joined the raid invite.")
		_joined_noah = true

	if not _joined_kira and current <= 6.0:
		var kira := alliance.get_member("driver_ally_02")
		if not kira.is_empty() and bool(kira["online"]):
			_join_simulated_member("driver_ally_02", "Kira joined the raid invite.")
		_joined_kira = true

	if current <= 0.0:
		_add_feed("Raid invite expired.")
		active_invite.clear()

	changed.emit()


func create_raid_invite(target_id: String, target_name: String) -> bool:
	if target_id == "":
		return false

	active_invite = {
		"target_id": target_id,
		"target_name": target_name,
		"seconds_remaining": invite_duration,
		"joined_members": []
	}

	_joined_mia = false
	_joined_noah = false
	_joined_kira = false

	_add_feed("You invited the alliance to raid %s." % target_name)
	changed.emit()
	return true


func join_local_invite(role: StringName) -> bool:
	if active_invite.is_empty() or alliance == null:
		return false

	if not alliance.assign_local_player(role):
		return false

	var joined: Array = active_invite.get("joined_members", [])
	if not joined.has("local_player"):
		joined.append("local_player")
	active_invite["joined_members"] = joined

	_add_feed("You joined the invite as %s." % String(role).capitalize())
	changed.emit()
	return true


func post_message(message: String) -> void:
	var clean := message.strip_edges()
	if clean == "":
		return

	_add_feed("You: %s" % clean)
	changed.emit()


func get_feed_text() -> String:
	if feed.is_empty():
		return "No alliance activity yet."
	return "\n".join(feed)


func get_invite_target_id() -> String:
	return String(active_invite.get("target_id", ""))


func get_invite_target_name() -> String:
	return String(active_invite.get("target_name", ""))


func get_invite_seconds_remaining() -> float:
	return float(active_invite.get("seconds_remaining", 0.0))


func get_invite_joined_names() -> PackedStringArray:
	var names := PackedStringArray()

	for member_id in active_invite.get("joined_members", []):
		var member := alliance.get_member(String(member_id))
		if not member.is_empty():
			names.append(String(member["name"]))

	return names


func get_save_data() -> Dictionary:
	return {
		"feed": feed.duplicate(),
		"active_invite": active_invite.duplicate(true),
		"joined_mia": _joined_mia,
		"joined_noah": _joined_noah,
		"joined_kira": _joined_kira
	}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	feed.clear()

	for entry in data.get("feed", []):
		feed.append(String(entry))

	active_invite = data.get("active_invite", {}).duplicate(true)
	_joined_mia = bool(data.get("joined_mia", false))
	_joined_noah = bool(data.get("joined_noah", false))
	_joined_kira = bool(data.get("joined_kira", false))

	if not active_invite.is_empty():
		active_invite["seconds_remaining"] = maxf(
			0.0,
			float(active_invite.get("seconds_remaining", 0.0)) - maxf(0.0, offline_seconds)
		)

		if float(active_invite["seconds_remaining"]) <= 0.0:
			active_invite.clear()

	if feed.is_empty():
		_add_feed("Alliance channel connected.")

	changed.emit()


func _join_simulated_member(member_id: String, feed_message: String) -> void:
	if alliance == null:
		return

	var member := alliance.get_member(member_id)
	if member.is_empty() or not bool(member["online"]):
		return

	var joined: Array = active_invite.get("joined_members", [])
	if not joined.has(member_id):
		joined.append(member_id)
		active_invite["joined_members"] = joined
		_add_feed(feed_message)


func _add_feed(message: String) -> void:
	feed.append(message)

	while feed.size() > max_feed_entries:
		feed.pop_front()
