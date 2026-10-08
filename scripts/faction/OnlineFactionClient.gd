class_name OnlineFactionClient
extends Node

signal request_completed(action: String, status: int, data: Dictionary)
signal connection_failed(action: String, reason: String)

# Development-only endpoint. Production must use HTTPS and verified identity.
@export var base_url := "http://127.0.0.1:8765"
var session_token := ""
var _busy := false
var _http: HTTPRequest
var _pending_action := ""


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func set_session(token: String) -> void:
	# Keep bearer tokens in memory only; never write to the unencrypted game save.
	session_token = token.strip_edges()


func clear_session() -> void:
	session_token = ""


func is_busy() -> bool:
	return _busy


func register_player(display_name: String) -> bool:
	return _request("register", HTTPClient.METHOD_POST, "/v1/players", {"display_name": display_name}, false)


func get_me() -> bool:
	return _request("me", HTTPClient.METHOD_GET, "/v1/me", {}, true)


func create_faction(name: String, tag: String) -> bool:
	return _request("create_faction", HTTPClient.METHOD_POST, "/v1/factions", {"name":name,"tag":tag}, true)


func get_faction() -> bool:
	return _request("faction", HTTPClient.METHOD_GET, "/v1/faction", {}, true)


func invite_player(player_id: String) -> bool:
	return _request("invite", HTTPClient.METHOD_POST, "/v1/invitations", {"player_id":player_id}, true)


func get_invitations() -> bool:
	return _request("invitations", HTTPClient.METHOD_GET, "/v1/invitations", {}, true)


func accept_invitation(invitation_id: String) -> bool:
	if not invitation_id.is_valid_hex_number() or invitation_id.length() != 24:
		connection_failed.emit("accept_invitation", "Invalid invitation ID")
		return false
	return _request("accept_invitation", HTTPClient.METHOD_POST,
		"/v1/invitations/%s/accept" % invitation_id, {}, true)


func get_war() -> bool:
	return _request("war", HTTPClient.METHOD_GET, "/v1/war", {}, true)


func start_war() -> bool:
	return _request("start_war", HTTPClient.METHOD_POST, "/v1/war/start", {}, true)


func attack_war(strategy: String) -> bool:
	return _request("war_attack", HTTPClient.METHOD_POST, "/v1/war/attack", {"strategy":strategy}, true)


func _request(action: String, method: int, path: String, body: Dictionary, authenticated: bool) -> bool:
	if _busy:
		connection_failed.emit(action, "Another API request is running")
		return false
	if authenticated and session_token.is_empty():
		connection_failed.emit(action, "No session. Register or sign in first.")
		return false
	if not base_url.begins_with("http://127.0.0.1:") and not base_url.begins_with("https://"):
		connection_failed.emit(action, "Online API must use HTTPS outside localhost")
		return false

	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated:
		headers.append("Authorization: Bearer %s" % session_token)
	var payload := JSON.stringify(body) if method == HTTPClient.METHOD_POST else ""
	_pending_action = action
	_busy = true
	var err := _http.request(base_url.trim_suffix("/") + path, headers, method, payload)
	if err != OK:
		_busy = false
		connection_failed.emit(action, "Network request could not start (%d)" % err)
		return false
	return true


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var action := _pending_action
	_pending_action = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		connection_failed.emit(action, "Network error %d" % result)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		connection_failed.emit(action, "Server returned invalid JSON")
		return
	# A registration session token is intentionally returned only to the caller.
	# The caller must decide how to securely persist it; this node does not save it.
	request_completed.emit(action, response_code, parsed)
