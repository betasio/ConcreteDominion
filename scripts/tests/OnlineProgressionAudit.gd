extends Node
## Driven by tools/online_progression_probe.py against a real private HTTP server.
var failures: PackedStringArray = []

func _ready() -> void:
	call_deferred("_audit")

func _audit() -> void:
	if OS.get_environment("CD_AUDIT_TOKEN").is_empty():
		push_error("Run tools/online_progression_probe.py to provision the test server.")
		get_tree().quit(1)
		return
	var game = load("res://scenes/core/Main.tscn").instantiate()
	add_child(game)
	game.save_manager.set_process(false)
	var hub := game.get_node("OnlineFactionUI") as OnlineFactionUI
	hub.set_process(false)
	_check(not hub.client.configure_server("http://example.com", ""), "Client accepted cleartext remote credentials")
	_check(not hub.client.configure_server("https://example.com?key=secret", ""), "Client accepted credentials in a server URL")
	_check(hub.client._http.max_redirects == 0, "Authenticated requests may follow redirects")
	_check(hub.client.configure_server(OS.get_environment("CD_AUDIT_URL"), OS.get_environment("CD_AUDIT_KEY")), "Server connection configuration failed")
	if not OS.get_environment("CD_AUDIT_CA").is_empty():
		var certificate := X509Certificate.new()
		_check(certificate.load(OS.get_environment("CD_AUDIT_CA")) == OK, "Test CA could not load")
		hub.client._http.set_tls_options(TLSOptions.client(certificate))
	hub.client.set_session(OS.get_environment("CD_AUDIT_TOKEN"))
	var cash_before: int = game.economy.cash
	var loot_before: Dictionary = game.loot_inventory.get_save_data()
	hub.client.get_me()
	await _idle(hub.client)
	_check(not hub.online_faction.is_empty(), "HTTP account/faction connection failed")
	game.get_node("FactionUI/Root/Panel/Margin/Scroll/VBox/OnlineFactionHub").pressed.emit()
	_check(hub.panel.visible and hub.hub_section == "Wars" and not game.get_node("FactionUI").panel.visible, "Faction shortcut did not open online wars")
	hub.progression_refresh_button.pressed.emit()
	await _idle(hub.client)
	_check(int(hub.online_progression.get("command_xp", 0)) == 110, "Live server command XP did not reach client")
	_check(not hub.hall_upgrade_button.disabled, "Earned upgrade was not enabled")
	_check(hub.hall_upgrade_button.text.contains("6000"), "Upgrade did not show exact price")
	# Capture the actual earned state before spending from the shared chest.
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(720,1280)
		await get_tree().process_frame
		hub.get_node("Root/Panel/Margin/Scroll").ensure_control_visible(hub.hall_upgrade_button)
		for i in range(8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
		get_viewport().get_texture().get_image().save_png("res://build/previews/online_war_progression.png")
	hub.hall_upgrade_button.pressed.emit()
	await _idle(hub.client)
	_check(int(hub.online_progression.get("hall_level",0)) == 2, "HTTP upgrade did not advance hall")
	_check(int(hub.online_rallies.get("capacity",0)) == 5, "Rally capacity did not refresh after upgrade")
	_check(int(hub.online_progression.get("treasury",{}).get("cash",-1)) == 0, "Upgrade did not deduct exact cost")
	hub.client.upgrade_online_hall(1) # Retry the old operation, not the next upgrade.
	await _idle(hub.client)
	_check(int(hub.online_progression.get("hall_level",0)) == 2 and not hub.upgrade_uncertain, "Retry was not reconciled to authoritative level")
	_check(game.economy.cash == cash_before and game.loot_inventory.get_save_data() == loot_before, "Online progression modified offline balances")
	if DisplayServer.get_name() != "headless":
		hub._select_hub_section("Account")
		for i in range(8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/previews/online_server_connection.png")
	hub.client.get_progression()
	hub._disconnect()
	_check(not hub.client.is_busy(), "Disconnect did not cancel in-flight account request")
	await get_tree().create_timer(0.2).timeout
	_check(hub.online_progression.is_empty() and hub.hall_upgrade_button.disabled, "Disconnect left another account's chest enabled")
	if failures.is_empty():
		print("[ONLINE PROGRESSION AUDIT] PASS — real HTTP account, earned resources, upgrade, retry, capacity and offline isolation")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _idle(client: OnlineFactionClient) -> void:
	var deadline := Time.get_ticks_msec()+10000
	while client.is_busy() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
	_check(not client.is_busy(), "HTTP request chain timed out")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
