class_name OnlineFactionUI
extends CanvasLayer

var client: OnlineFactionClient
var online_player: Dictionary = {}
var online_faction: Dictionary = {}
var invites: Array = []
var status_message := "Disconnected"

@onready var panel: PanelContainer = $Root/Panel
@onready var status_label: Label = $Root/Panel/Margin/Scroll/VBox/Status
@onready var token_edit: LineEdit = $Root/Panel/Margin/Scroll/VBox/SessionToken


func _ready() -> void:
	client = OnlineFactionClient.new()
	add_child(client)
	client.request_completed.connect(_on_completed)
	client.connection_failed.connect(_on_failed)
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/Scroll/VBox/Close.pressed.connect(_toggle)
	$Root/Panel/Margin/Scroll/VBox/Register.pressed.connect(func():
		client.register_player($Root/Panel/Margin/Scroll/VBox/DisplayName.text))
	$Root/Panel/Margin/Scroll/VBox/UseSession.pressed.connect(_connect_session)
	$Root/Panel/Margin/Scroll/VBox/ClearSession.pressed.connect(_disconnect)
	$Root/Panel/Margin/Scroll/VBox/CreateFaction.pressed.connect(func():
		client.create_faction($Root/Panel/Margin/Scroll/VBox/FactionName.text, $Root/Panel/Margin/Scroll/VBox/FactionTag.text))
	$Root/Panel/Margin/Scroll/VBox/Invite.pressed.connect(func():
		client.invite_player($Root/Panel/Margin/Scroll/VBox/TargetPlayer.text))
	$Root/Panel/Margin/Scroll/VBox/Invitations.pressed.connect(client.get_invitations)
	$Root/Panel/Margin/Scroll/VBox/Accept.pressed.connect(_accept_first)
	$Root/Panel/Margin/Scroll/VBox/Refresh.pressed.connect(client.get_faction)
	_refresh()


func _toggle() -> void:
	panel.visible = not panel.visible
	_refresh()


func _connect_session() -> void:
	client.set_session(token_edit.text)
	token_edit.clear()
	client.get_me()
	_refresh()


func _disconnect() -> void:
	client.clear_session()
	online_player.clear()
	online_faction.clear()
	invites.clear()
	status_message = "Disconnected"
	_refresh()


func _accept_first() -> void:
	if invites.is_empty():
		status_message = "Refresh invitations first"
		_refresh()
		return
	client.accept_invitation(String(invites[0].get("id", "")))


func _on_completed(action: String, code: int, data: Dictionary) -> void:
	if code < 200 or code >= 300:
		status_message = "%s (%d): %s" % [action, code, String(data.get("error", "Request rejected"))]
		_refresh()
		return
	status_message = "%s succeeded" % action
	match action:
		"register":
			var session := String(data.get("session_token", ""))
			client.set_session(session)
			# Show the token exactly once for developer backup; never persist it.
			token_edit.text = session
			online_player = {"player_id":String(data.get("player_id", ""))}
			status_message = "Player created. Copy the development token from the hidden field before leaving."
		"me":
			online_player = data.duplicate(true)
			if String(data.get("faction_id", "")).is_empty():
				online_faction.clear()
			else:
				client.get_faction()
		"create_faction", "accept_invitation":
			invites.clear()
			client.get_faction()
		"faction":
			online_faction = data.duplicate(true)
		"invitations":
			var response_invites = data.get("invitations", [])
			invites = response_invites.duplicate(true) if response_invites is Array else []
	_refresh()


func _on_failed(action: String, reason: String) -> void:
	status_message = "%s: %s" % [action, reason]
	_refresh()


func _refresh() -> void:
	if client == null:
		return
	var account := String(online_player.get("display_name", online_player.get("player_id", "No account")))
	var lines := PackedStringArray([
		"Server: %s" % client.base_url,
		"Account: %s" % account,
		"Session: %s" % ("connected in memory" if not client.session_token.is_empty() else "not connected"),
		status_message
	])
	var f = online_faction.get("faction", {})
	if f is Dictionary and not f.is_empty():
		lines.append("ONLINE FACTION: [%s] %s" % [String(f.get("tag", "")),String(f.get("name", ""))])
		for member in online_faction.get("members", []):
			if member is Dictionary:
				lines.append("• %s — %s" % [String(member.get("display_name", "")),String(member.get("role", ""))])
	if not invites.is_empty():
		lines.append("INVITATIONS")
		for invitation in invites:
			if invitation is Dictionary:
				lines.append("%s • %s" % [String(invitation.get("faction_name", "")),String(invitation.get("id", ""))])
	status_label.text = "\n".join(lines)
