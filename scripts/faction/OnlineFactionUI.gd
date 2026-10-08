class_name OnlineFactionUI
extends CanvasLayer

var client: OnlineFactionClient
var online_player: Dictionary = {}
var online_faction: Dictionary = {}
var invites: Array = []
var online_war: Dictionary = {}
var online_pvp: Dictionary = {}
var pvp_history: Dictionary = {}
var trophy_case: Dictionary = {}
var rival_challenges: Array = []
var season_rankings: Dictionary = {}
var season_history: Dictionary = {}
var viewed_identity: Dictionary = {}
var status_message := "Disconnected"
var hub_section := "Identity"
const HUB_GROUPS := {
	"Account": ["Warning", "DisplayName", "Register", "SessionToken", "UseSession",
		"ClearSession", "RecoveryPlayer", "RecoveryKey", "RecoverAccount",
		"FactionName", "FactionTag", "CreateFaction", "TargetPlayer", "Invite",
		"Invitations", "Accept", "Refresh"],
	"Wars": ["WarTitle", "StartWar", "RefreshWar", "AttackPlans", "WarStatus",
		"PvPMatchup", "PvPHeader", "QueuePvP", "CancelPvP", "RefreshPvP",
		"PvPPlans", "PvPStatus"],
	"Rivals": ["ChallengeTitle", "RivalFactionId", "SendChallenge",
		"RefreshChallenges", "AcceptChallenge", "DeclineChallenge",
		"CancelChallenge", "ChallengeStatus", "RefreshTrophies",
		"TrophyStatus", "RivalryTitle", "RefreshRivalries", "RivalryStatus"],
	"Rankings": ["SeasonTitle", "RefreshSeasons", "SeasonStandings"],
	"Prestige": ["PrestigeTitle", "RefreshPrestige", "PrestigeHistory"],
	"Identity": ["FactionCard", "IdentityTitle", "Emblem", "Banner",
		"ApplyIdentity", "FeaturedBadge", "ApplyBadge", "ProfileLookup",
		"ViewFactionProfile", "ViewMyProfile", "IdentityStatus"]
}


@onready var panel: PanelContainer = $Root/Panel
@onready var status_label: Label = $Root/Panel/Margin/Scroll/VBox/Status
@onready var token_edit: LineEdit = $Root/Panel/Margin/Scroll/VBox/SessionToken


func _ready() -> void:
	client = OnlineFactionClient.new()
	add_child(client)
	client.request_completed.connect(_on_completed)
	client.connection_failed.connect(_on_failed)
	for section in HUB_GROUPS.keys():
		var tab := $Root/Panel/Margin/Scroll/VBox.get_node(_hub_tab_path(section)) as Button
		tab.pressed.connect(_select_hub_section.bind(section))
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_ALL
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/Scroll/VBox/Close.pressed.connect(_toggle)
	$Root/Panel/Margin/Scroll/VBox/Register.pressed.connect(func():
		client.register_player($Root/Panel/Margin/Scroll/VBox/DisplayName.text))
	$Root/Panel/Margin/Scroll/VBox/UseSession.pressed.connect(_connect_session)
	$Root/Panel/Margin/Scroll/VBox/RecoverAccount.pressed.connect(_recover_account)
	$Root/Panel/Margin/Scroll/VBox/ClearSession.pressed.connect(_disconnect)
	$Root/Panel/Margin/Scroll/VBox/CreateFaction.pressed.connect(func():
		client.create_faction($Root/Panel/Margin/Scroll/VBox/FactionName.text, $Root/Panel/Margin/Scroll/VBox/FactionTag.text))
	$Root/Panel/Margin/Scroll/VBox/Invite.pressed.connect(func():
		client.invite_player($Root/Panel/Margin/Scroll/VBox/TargetPlayer.text))
	$Root/Panel/Margin/Scroll/VBox/Invitations.pressed.connect(client.get_invitations)
	$Root/Panel/Margin/Scroll/VBox/Accept.pressed.connect(_accept_first)
	$Root/Panel/Margin/Scroll/VBox/Refresh.pressed.connect(client.get_faction)
	$Root/Panel/Margin/Scroll/VBox/StartWar.pressed.connect(client.start_war)
	$Root/Panel/Margin/Scroll/VBox/RefreshWar.pressed.connect(client.get_war)
	$Root/Panel/Margin/Scroll/VBox/QueuePvP.pressed.connect(client.queue_pvp)
	$Root/Panel/Margin/Scroll/VBox/CancelPvP.pressed.connect(client.cancel_pvp_queue)
	$Root/Panel/Margin/Scroll/VBox/RefreshPvP.pressed.connect(client.get_pvp)
	$Root/Panel/Margin/Scroll/VBox/RefreshRivalries.pressed.connect(client.get_pvp_history)
	$Root/Panel/Margin/Scroll/VBox/RefreshTrophies.pressed.connect(client.get_rivalry_trophies)
	$Root/Panel/Margin/Scroll/VBox/SendChallenge.pressed.connect(func():
		client.send_rival_challenge($Root/Panel/Margin/Scroll/VBox/RivalFactionId.text.strip_edges()))
	$Root/Panel/Margin/Scroll/VBox/RefreshChallenges.pressed.connect(client.get_challenges)
	$Root/Panel/Margin/Scroll/VBox/AcceptChallenge.pressed.connect(func(): _respond_first_challenge("accept", "received"))
	$Root/Panel/Margin/Scroll/VBox/DeclineChallenge.pressed.connect(func(): _respond_first_challenge("decline", "received"))
	$Root/Panel/Margin/Scroll/VBox/CancelChallenge.pressed.connect(func(): _respond_first_challenge("cancel", "sent"))
	$Root/Panel/Margin/Scroll/VBox/RefreshSeasons.pressed.connect(client.get_season_rankings)
	$Root/Panel/Margin/Scroll/VBox/RefreshPrestige.pressed.connect(client.get_season_history)
	$Root/Panel/Margin/Scroll/VBox/ApplyIdentity.pressed.connect(_save_identity)
	$Root/Panel/Margin/Scroll/VBox/Emblem.item_selected.connect(func(_index: int): _refresh())
	$Root/Panel/Margin/Scroll/VBox/Banner.item_selected.connect(func(_index: int): _refresh())
	$Root/Panel/Margin/Scroll/VBox/ApplyBadge.pressed.connect(_save_badge)
	$Root/Panel/Margin/Scroll/VBox/ViewFactionProfile.pressed.connect(func():
		client.get_faction_profile($Root/Panel/Margin/Scroll/VBox/ProfileLookup.text.strip_edges()))
	$Root/Panel/Margin/Scroll/VBox/ViewMyProfile.pressed.connect(func():
		client.get_player_profile(String(online_player.get("player_id", ""))))

	$Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPMuscle.pressed.connect(func(): client.attack_pvp("muscle"))
	$Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPConvoy.pressed.connect(func(): client.attack_pvp("convoy"))
	$Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPIntel.pressed.connect(func(): client.attack_pvp("intel"))
	$Root/Panel/Margin/Scroll/VBox/AttackPlans/Muscle.pressed.connect(func(): client.attack_war("muscle"))
	$Root/Panel/Margin/Scroll/VBox/AttackPlans/Convoy.pressed.connect(func(): client.attack_war("convoy"))
	$Root/Panel/Margin/Scroll/VBox/AttackPlans/Intel.pressed.connect(func(): client.attack_war("intel"))
	get_viewport().size_changed.connect(_resize_hub)
	_resize_hub()
	_select_hub_section("Identity")
	_refresh()


func _resize_hub() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(680.0, maxf(280.0, viewport_size.x - 24.0))
	var height := minf(760.0, maxf(270.0, viewport_size.y - 24.0))
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	var art_width := maxf(220.0, width - 74.0)
	for path in ["FactionCard", "PvPMatchup/OurCard", "PvPMatchup/OpponentCard"]:
		var card := $Root/Panel/Margin/Scroll/VBox.get_node(path) as Control
		card.custom_minimum_size.x = art_width


func _style_hub_tabs() -> void:
	var nav := $Root/Panel/Margin/Scroll/VBox
	for section in HUB_GROUPS.keys():
		var tab := nav.get_node(_hub_tab_path(section)) as Button
		var selected: bool = String(section) == hub_section
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#655037") if selected else Color("#18212e")
		style.border_color = Color("#dab981") if selected else Color("#405064")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		tab.add_theme_stylebox_override("normal", style)
		tab.add_theme_stylebox_override("pressed", style)
		tab.add_theme_stylebox_override("hover", style)
		tab.add_theme_color_override("font_color", Color("#fff3dc") if selected else Color("#b8c5d2"))
		tab.add_theme_color_override("font_pressed_color", Color("#fff3dc"))
		tab.add_theme_color_override("font_hover_color", Color("#fff3dc"))


func _hub_tab_path(section: String) -> String:
	var row := "HubNav1" if section in ["Identity", "Wars", "Rivals"] else "HubNav2"
	return "%s/Hub%s" % [row, section]


func _select_hub_section(section: String) -> void:
	if not HUB_GROUPS.has(section):
		return
	hub_section = section
	var content := $Root/Panel/Margin/Scroll/VBox
	for key in HUB_GROUPS.keys():
		for control_name in HUB_GROUPS[key]:
			content.get_node(control_name).visible = key == section
		var tab := content.get_node(_hub_tab_path(key)) as Button
		tab.button_pressed = key == section
	content.get_node("HubHeading").text = section.to_upper()
	_style_hub_tabs()
	$Root/Panel/Margin/Scroll.scroll_vertical = 0


func _toggle() -> void:
	panel.visible = not panel.visible
	_refresh()


func _connect_session() -> void:
	client.set_session(token_edit.text)
	token_edit.clear()
	client.get_me()
	_refresh()


func _recover_account() -> void:
	client.recover_account(
		$Root/Panel/Margin/Scroll/VBox/RecoveryPlayer.text,
		$Root/Panel/Margin/Scroll/VBox/RecoveryKey.text
	)


func _save_identity() -> void:
	var emblem_options := ["crown", "serpent", "shield", "wolf"]
	var banner_options := ["obsidian", "crimson", "gold", "steel"]
	client.set_faction_identity(
		emblem_options[$Root/Panel/Margin/Scroll/VBox/Emblem.selected],
		banner_options[$Root/Panel/Margin/Scroll/VBox/Banner.selected]
	)


func _save_badge() -> void:
	var badges := ["", "CHAMPION", "RUNNER_UP", "PODIUM", "VETERAN"]
	client.feature_prestige_badge(badges[$Root/Panel/Margin/Scroll/VBox/FeaturedBadge.selected])


func _disconnect() -> void:
	client.clear_session()
	online_player.clear()
	online_faction.clear()
	invites.clear()
	online_war.clear()
	online_pvp.clear()
	pvp_history.clear()
	trophy_case.clear()
	rival_challenges.clear()
	season_rankings.clear()
	season_history.clear()
	viewed_identity.clear()
	status_message = "Disconnected"
	_refresh()


func _respond_first_challenge(action: String, direction: String) -> void:
	for record in rival_challenges:
		if record is Dictionary and String(record.get("status", "")) == "pending" and String(record.get("direction", "")) == direction:
			client.respond_to_challenge(String(record.get("id", "")), action)
			return
	status_message = "No pending %s challenge found" % direction
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
			$Root/Panel/Margin/Scroll/VBox/RecoveryPlayer.text = String(data.get("player_id", ""))
			$Root/Panel/Margin/Scroll/VBox/RecoveryKey.text = String(data.get("recovery_key", ""))
			status_message = "Player created. Securely copy both your hidden session token and one-time recovery key."
		"recover":
			var session := String(data.get("session_token", ""))
			client.set_session(session)
			token_edit.text = session
			$Root/Panel/Margin/Scroll/VBox/RecoveryKey.text = String(data.get("recovery_key", ""))
			online_player = {"player_id":String(data.get("player_id", ""))}
			online_faction.clear()
			online_war.clear()
			online_pvp.clear()
			status_message = "Account recovered. Previous credentials revoked. Securely copy BOTH new hidden keys."
		"me":
			online_player = data.duplicate(true)
			if String(data.get("faction_id", "")).is_empty():
				online_faction.clear()
			else:
				client.get_faction()
		"create_faction", "accept_invitation":
			invites.clear()
			client.get_faction()
		"start_war", "war_attack":
			client.get_war()
		"war":
			online_war = data.duplicate(true)
		"pvp":
			online_pvp = data.duplicate(true)
		"pvp_history":
			pvp_history = data.duplicate(true)
		"rivalry_trophies":
			trophy_case = data.duplicate(true)
		"challenges":
			var incoming = data.get("challenges", [])
			rival_challenges = incoming.duplicate(true) if incoming is Array else []
		"send_challenge", "respond_challenge":
			client.get_challenges()
		"season_rankings":
			season_rankings = data.duplicate(true)
		"season_history":
			season_history = data.duplicate(true)
		"faction_profile", "player_profile":
			viewed_identity = data.duplicate(true)
		"set_faction_identity":
			status_message = "Faction emblem and banner saved on server."
			var existing_faction = online_faction.get("faction", {})
			if existing_faction is Dictionary and not existing_faction.is_empty():
				client.get_faction_profile(String(existing_faction.get("id", "")))
		"feature_prestige_badge":
			status_message = "Earned prestige badge updated."
		"pvp_queue", "pvp_cancel", "pvp_attack":
			client.get_pvp()
		"faction":
			online_faction = data.duplicate(true)
			var faction_details = data.get("faction", {})
			if faction_details is Dictionary and not faction_details.is_empty():
				client.get_faction_profile(String(faction_details.get("id", "")))
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
	var connected := not client.session_token.is_empty()
	var faction_label := "NO FACTION"
	if f is Dictionary and not f.is_empty():
		faction_label = "[%s] %s" % [String(f.get("tag", "")), String(f.get("name", ""))]
	var matches_label := "QUEUED" if bool(online_pvp.get("queued", false)) else "STANDBY"
	var latest_match = online_pvp.get("match", {})
	if latest_match is Dictionary and not latest_match.is_empty():
		matches_label = String(latest_match.get("status", "STANDBY")).to_upper()
	$Root/Panel/Margin/Scroll/VBox/HubSummary.text = "ONLINE • %s  |  %s  |  PVP %s" % [
		"CONNECTED" if connected else "DISCONNECTED", faction_label, matches_label
	]
	status_label.text = "\n".join(lines)
	var war_data = online_war.get("war", {})
	var war_lines := PackedStringArray()
	if war_data is Dictionary and not war_data.is_empty():
		war_lines.append("%s vs %s • %s" % [String(war_data.get("id", "")).left(6), String(war_data.get("opponent_name", "")), String(war_data.get("status", ""))])
		war_lines.append("Score %d–%d • Round %d/6 • Defense: %s" % [int(war_data.get("our_score", 0)), int(war_data.get("their_score", 0)), int(war_data.get("rounds", 0)), String(online_war.get("defense", "—"))])
		for member in online_war.get("contributions", []):
			if member is Dictionary:
				war_lines.append("%s: %d points (%d attacks)" % [String(member.get("display_name", "")), int(member.get("contribution", 0)), int(member.get("attacks", 0))])
	else:
		war_lines.append("No server war loaded. Refresh after joining a Faction.")
	$Root/Panel/Margin/Scroll/VBox/WarStatus.text = "\n".join(war_lines)
	var active := war_data is Dictionary and String(war_data.get("status", "")) == "active"
	for button in [$Root/Panel/Margin/Scroll/VBox/AttackPlans/Muscle, $Root/Panel/Margin/Scroll/VBox/AttackPlans/Convoy, $Root/Panel/Margin/Scroll/VBox/AttackPlans/Intel]:
		button.disabled = not active or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/StartWar.disabled = client.session_token.is_empty() or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/RefreshWar.disabled = client.session_token.is_empty() or client.is_busy()
	var pvp_data = online_pvp.get("match", {})
	var pvp_lines := PackedStringArray()
	if pvp_data is Dictionary and not pvp_data.is_empty():
		pvp_lines.append("VS [%s] %s • %s" % [
			String(pvp_data.get("opponent_tag", "")),
			String(pvp_data.get("opponent_name", "")),
			String(pvp_data.get("status", ""))
		])
		pvp_lines.append("Score %d–%d • Rounds %d/6 vs %d/6" % [
			int(pvp_data.get("our_score", 0)),
			int(pvp_data.get("enemy_score", 0)),
			int(pvp_data.get("our_rounds", 0)),
			int(pvp_data.get("enemy_rounds", 0))
		])
		pvp_lines.append("Enemy stance: %s • Result: %s" % [
			String(pvp_data.get("defense", "—")),
			String(pvp_data.get("result", "Pending"))
		])
		for ledger_entry in online_pvp.get("ledger", []):
			if ledger_entry is Dictionary:
				pvp_lines.append("Server ledger: %s • %d points" % [
					String(ledger_entry.get("faction_id", "")).left(8),
					int(ledger_entry.get("points", 0))
				])
	elif bool(online_pvp.get("queued", false)):
		pvp_lines.append("Searching for another queued Faction. Refresh to check.")
	else:
		pvp_lines.append("No PvP match yet. Both Faction leaders must queue.")
	var our_card := $Root/Panel/Margin/Scroll/VBox/PvPMatchup/OurCard as FactionIdentityCard
	var rival_card := $Root/Panel/Margin/Scroll/VBox/PvPMatchup/OpponentCard as FactionIdentityCard
	var own_identity = online_pvp.get("our_identity", {})
	var rival_identity = online_pvp.get("opponent_identity", {})
	our_card.set_identity(own_identity if own_identity is Dictionary else {})
	rival_card.set_identity(rival_identity if rival_identity is Dictionary else {})
	var own_prestige = online_pvp.get("our_rivalry_prestige", {})
	var rival_prestige = online_pvp.get("opponent_rivalry_prestige", {})
	our_card.set_rivalry_prestige(own_prestige if own_prestige is Dictionary else {})
	rival_card.set_rivalry_prestige(rival_prestige if rival_prestige is Dictionary else {})
	$Root/Panel/Margin/Scroll/VBox/PvPMatchup.visible = hub_section == "Wars" and pvp_data is Dictionary and not pvp_data.is_empty()
	$Root/Panel/Margin/Scroll/VBox/PvPStatus.text = "\n".join(pvp_lines)
	var pvp_active := pvp_data is Dictionary and String(pvp_data.get("status", "")) == "active" and int(pvp_data.get("our_rounds", 0)) < 6
	for button in [
		$Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPMuscle,
		$Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPConvoy,
		$Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPIntel
	]:
		button.disabled = not pvp_active or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/QueuePvP.disabled = client.session_token.is_empty() or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/CancelPvP.disabled = not bool(online_pvp.get("queued", false)) or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/RefreshPvP.disabled = client.session_token.is_empty() or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/RefreshRivalries.disabled = client.session_token.is_empty() or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/RefreshTrophies.disabled = client.session_token.is_empty() or client.is_busy()
	var trophy_lines := PackedStringArray(["SERVER-VERIFIED COSMETIC PRESTIGE"])
	trophy_lines.append("Current win streak: %d • Best: %d" % [
		int(trophy_case.get("current_win_streak", 0)),
		int(trophy_case.get("best_win_streak", 0))
	])
	trophy_lines.append("Rival Conqueror trophies: %d" % int(trophy_case.get("total_rematch_trophies", 0)))
	var trophy_records = trophy_case.get("rematch_trophies", [])
	if trophy_records is Array:
		for entry in trophy_records:
			if entry is Dictionary:
				trophy_lines.append("RIVAL CONQUEROR • [%s] %s • Match %s" % [
					String(entry.get("opponent_tag", "")),
					String(entry.get("opponent_name", "")),
					String(entry.get("match_id", "")).left(8)
				])
				if trophy_lines.size() >= 11:
					break
	$Root/Panel/Margin/Scroll/VBox/TrophyStatus.text = "\n".join(trophy_lines)

	$Root/Panel/Margin/Scroll/VBox/RefreshChallenges.disabled = client.session_token.is_empty() or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/SendChallenge.disabled = client.session_token.is_empty() or client.is_busy()
	var first_incoming := false
	var first_outgoing := false
	var challenge_lines := PackedStringArray(["DIRECT CHALLENGES • PENDING REQUESTS"])
	for challenge in rival_challenges:
		if not (challenge is Dictionary):
			continue
		var direction := String(challenge.get("direction", ""))
		var state := String(challenge.get("status", ""))
		if state == "pending" and direction == "received":
			first_incoming = true
		if state == "pending" and direction == "sent":
			first_outgoing = true
		challenge_lines.append("[%s] %s • %s • %s" % [
			String(challenge.get("opponent_tag", "")),
			String(challenge.get("opponent_name", "")),
			direction, state
		])
		if challenge_lines.size() >= 11:
			break
	if rival_challenges.is_empty():
		challenge_lines.append("No challenges yet. Select a previous rival from the War Room.")
	$Root/Panel/Margin/Scroll/VBox/ChallengeStatus.text = "\n".join(challenge_lines)
	$Root/Panel/Margin/Scroll/VBox/AcceptChallenge.disabled = not first_incoming or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/DeclineChallenge.disabled = not first_incoming or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/CancelChallenge.disabled = not first_outgoing or client.is_busy()
	var rivalry_lines := PackedStringArray(["RIVAL FACTIONS • RECENT COMPLETED MATCHES"])
	var rivals = pvp_history.get("rivals", [])
	if rivals is Array and not rivals.is_empty():
		for rival in rivals:
			if rival is Dictionary:
				rivalry_lines.append("[%s] %s (%s) • %s / %s • %dW %dL %dD %dT" % [
					String(rival.get("tag", "")),
					String(rival.get("name", "")),
					String(rival.get("opponent_id", "")),
					String(rival.get("emblem", "")).to_upper(),
					String(rival.get("banner", "")).to_upper(),
					int(rival.get("wins", 0)), int(rival.get("losses", 0)),
					int(rival.get("draws", 0)), int(rival.get("timeouts", 0))
				])
				if rivalry_lines.size() >= 7:
					break
	var historic_matches = pvp_history.get("matches", [])
	if historic_matches is Array and not historic_matches.is_empty():
		rivalry_lines.append("BATTLE ARCHIVE • LATEST RESULTS")
		for previous_match in historic_matches:
			if previous_match is Dictionary:
				rivalry_lines.append("%s vs [%s] • %d–%d • %s" % [
					String(previous_match.get("match_id", "")).left(7),
					String(previous_match.get("opponent_tag", "")),
					int(previous_match.get("our_score", 0)),
					int(previous_match.get("enemy_score", 0)),
					String(previous_match.get("result", ""))
				])
				if rivalry_lines.size() >= 16:
					break
	else:
		rivalry_lines.append("No settled matchups found. Finish a Faction PvP war to build your rivalry history.")
	$Root/Panel/Margin/Scroll/VBox/RivalryStatus.text = "\n".join(rivalry_lines)

	$Root/Panel/Margin/Scroll/VBox/RefreshSeasons.disabled = client.session_token.is_empty() or client.is_busy()
	var season_info = season_rankings.get("season", {})
	var ranking_lines := PackedStringArray()
	if season_info is Dictionary and not season_info.is_empty():
		ranking_lines.append("Season %d • UTC cycle (%d–%d)" % [
			int(season_info.get("id", 0)),
			int(season_info.get("starts_at", 0)),
			int(season_info.get("ends_at", 0))
		])
		ranking_lines.append("Your rank: %s • Preview points only" % str(season_rankings.get("your_rank", "Unranked")))
		for entry in season_rankings.get("leaderboard", []):
			if not (entry is Dictionary):
				continue
			ranking_lines.append("#%d [%s] %s • %s / %s • %d points • %d wins" % [
				int(entry.get("rank", 0)),
				String(entry.get("tag", "")),
				String(entry.get("name", "")),
				String(entry.get("emblem", "shield")).to_upper(),
				String(entry.get("banner", "obsidian")).to_upper(),
				int(entry.get("points", 0)),
				int(entry.get("wins", 0))
			])
			if ranking_lines.size() >= 12:
				break
	else:
		ranking_lines.append("Connect and refresh to view server rankings.")
	$Root/Panel/Margin/Scroll/VBox/SeasonStandings.text = "\n".join(ranking_lines)

	$Root/Panel/Margin/Scroll/VBox/RefreshPrestige.disabled = client.session_token.is_empty() or client.is_busy()
	var prestige_lines := PackedStringArray()
	prestige_lines.append("COSMETIC ONLY • Server-verified completed seasons")
	var awards = season_history.get("your_awards", [])
	if awards is Array and not awards.is_empty():
		prestige_lines.append("YOUR FACTION BADGES")
		for award in awards:
			if not (award is Dictionary):
				continue
			prestige_lines.append("Season %d • #%d • %s (%d points)" % [
				int(award.get("season_id", 0)),
				int(award.get("rank", 0)),
				String(award.get("badge", "VETERAN")),
				int(award.get("points", 0))
			])
	else:
		prestige_lines.append("No completed-season badge yet.")
	var champions = season_history.get("champions", [])
	if champions is Array and not champions.is_empty():
		prestige_lines.append("HALL OF FAME")
		for champion in champions:
			if not (champion is Dictionary):
				continue
			prestige_lines.append("Season %d • [%s] %s" % [
				int(champion.get("season_id", 0)),
				String(champion.get("faction_tag", "")),
				String(champion.get("faction_name", ""))
			])
			if prestige_lines.size() >= 16:
				break
	$Root/Panel/Margin/Scroll/VBox/PrestigeHistory.text = "\n".join(prestige_lines)

	$Root/Panel/Margin/Scroll/VBox/ApplyIdentity.disabled = client.session_token.is_empty() or client.is_busy()
	$Root/Panel/Margin/Scroll/VBox/ApplyBadge.disabled = client.session_token.is_empty() or client.is_busy()
	var identity_lines := PackedStringArray(["COSMETIC PUBLIC PROFILE"])
	var public_faction = viewed_identity.get("faction", {})
	if public_faction is Dictionary and not public_faction.is_empty():
		identity_lines.append("[%s] %s • Emblem: %s • Banner: %s" % [
			String(public_faction.get("tag", "")),
			String(public_faction.get("name", "")),
			String(public_faction.get("emblem", "")),
			String(public_faction.get("banner", ""))
		])
		var prestige_data = viewed_identity.get("rivalry_prestige", {})
		if prestige_data is Dictionary:
			identity_lines.append("Rival Conqueror: %d • Win streak: %d • Best: %d" % [
				int(prestige_data.get("total_rematch_trophies", 0)),
				int(prestige_data.get("current_win_streak", 0)),
				int(prestige_data.get("best_win_streak", 0))
			])
		for award in viewed_identity.get("achievements", []):
			if award is Dictionary:
				identity_lines.append("Season %d • %s • Rank #%d" % [
					int(award.get("season_id", 0)),
					String(award.get("badge", "")),
					int(award.get("rank", 0))
				])
	var public_player = viewed_identity.get("player", {})
	if public_player is Dictionary and not public_player.is_empty():
		identity_lines.append("%s • Featured: %s" % [
			String(public_player.get("display_name", "")),
			String(public_player.get("featured_badge", "None"))
		])
	$Root/Panel/Margin/Scroll/VBox/IdentityStatus.text = "\n".join(identity_lines)
	_update_identity_card()


func _update_identity_card() -> void:
	var card := $Root/Panel/Margin/Scroll/VBox/FactionCard as FactionIdentityCard
	var public_faction = viewed_identity.get("faction", {})
	var displayed := {}
	var awards := 0
	var badge := ""
	if public_faction is Dictionary and not public_faction.is_empty():
		displayed = public_faction.duplicate()
		var achievements = viewed_identity.get("achievements", [])
		if achievements is Array:
			awards = achievements.size()
			if not achievements.is_empty() and achievements[0] is Dictionary:
				badge = String(achievements[0].get("badge", ""))
	else:
		var own = online_faction.get("faction", {})
		if own is Dictionary and not own.is_empty():
			displayed = own.duplicate()
		# Before server data arrives, preview the selected styles without saving.
		displayed["emblem"] = ["crown", "serpent", "shield", "wolf"][
			maxi(0, $Root/Panel/Margin/Scroll/VBox/Emblem.selected)]
		displayed["banner"] = ["obsidian", "crimson", "gold", "steel"][
			maxi(0, $Root/Panel/Margin/Scroll/VBox/Banner.selected)]
	card.set_identity(displayed, badge, awards)
	var rivalry_data = viewed_identity.get("rivalry_prestige", {})
	card.set_rivalry_prestige(rivalry_data if rivalry_data is Dictionary else {})
