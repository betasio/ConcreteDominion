class_name OnlineFactionUI
extends CanvasLayer

var client: OnlineFactionClient
var online_player: Dictionary = {}
var online_faction: Dictionary = {}
var invites: Array = []
var online_war: Dictionary = {}
var online_pvp: Dictionary = {}
var season_rankings: Dictionary = {}
var season_history: Dictionary = {}
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
	$Root/Panel/Margin/Scroll/VBox/RefreshSeasons.pressed.connect(client.get_season_rankings)
	$Root/Panel/Margin/Scroll/VBox/RefreshPrestige.pressed.connect(client.get_season_history)
	$Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPMuscle.pressed.connect(func(): client.attack_pvp("muscle"))
	$Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPConvoy.pressed.connect(func(): client.attack_pvp("convoy"))
	$Root/Panel/Margin/Scroll/VBox/PvPPlans/PvPIntel.pressed.connect(func(): client.attack_pvp("intel"))
	$Root/Panel/Margin/Scroll/VBox/AttackPlans/Muscle.pressed.connect(func(): client.attack_war("muscle"))
	$Root/Panel/Margin/Scroll/VBox/AttackPlans/Convoy.pressed.connect(func(): client.attack_war("convoy"))
	$Root/Panel/Margin/Scroll/VBox/AttackPlans/Intel.pressed.connect(func(): client.attack_war("intel"))
	_refresh()


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


func _disconnect() -> void:
	client.clear_session()
	online_player.clear()
	online_faction.clear()
	invites.clear()
	online_war.clear()
	online_pvp.clear()
	season_rankings.clear()
	season_history.clear()
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
		"season_rankings":
			season_rankings = data.duplicate(true)
		"season_history":
			season_history = data.duplicate(true)
		"pvp_queue", "pvp_cancel", "pvp_attack":
			client.get_pvp()
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
			ranking_lines.append("#%d [%s] %s • %d points • %d wins" % [
				int(entry.get("rank", 0)),
				String(entry.get("tag", "")),
				String(entry.get("name", "")),
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
