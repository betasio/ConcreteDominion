extends Node
var failures := 0
func _ready() -> void:
	call_deferred("_audit")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("[DISTRICTS] "+message)
func _audit() -> void:
	var game = load("res://scenes/core/Main.tscn").instantiate()
	add_child(game)
	game.save_manager.set_process(false)
	game.economy.cash = 1000000
	game.construction_queue.set_process(false)
	var districts = game.city_map.get_node("EstateDistricts")
	districts.set_process(false)
	var plot: BuildLot = districts.plots[2]
	check(not plot.can_develop(),"Chapter 2 plot starts locked")
	var cash: int = game.economy.cash
	check(not game.construction_queue.start_lot_build(plot),"Locked construction rejected")
	check(game.economy.cash == cash,"Locked construction charged cash")
	game.mission_tracker.missions["chapter_2_complete"]["completed"] = true
	game.mission_tracker.changed.emit()
	check(plot.can_develop(),"Chapter completion clears fog")
	check(not districts.configure(plot,"diamonds"),"Premium production prohibited")
	check(districts.configure(plot,"hospital"),"Select hospital")
	check(game.construction_queue.start_lot_build(plot),"Start hospital")
	var saved: Dictionary = game.city_map.get_save_data()
	var pending: Dictionary = game.construction_queue.get_save_data()
	game.city_map.load_save_data(saved)
	game.construction_queue.load_save_data(pending,1000,game.city_map)
	check(plot.is_built and plot.facility_kind == "hospital","Offline construction preserves selected facility")
	check(game.core_building_effects.get_hospital_capacity() == 50,"Hospital beds add together")
	check(game.construction_queue.start_facility_upgrade(plot),"Upgrade repeatable hospital")
	game.construction_queue._process(10000)
	check(game.core_building_effects.get_hospital_capacity() == 75,"Hospital upgrades add beds")
	game.troop_roster.add_troops(&"Enforcer",100)
	game.hospital_queue.send_to_hospital(&"Enforcer",80)
	check(game.hospital_queue.get_occupied_beds() == 75 and game.hospital_queue.overflow_losses == 5,"Capacity admits beds and records overflow")
	var barracks: BuildLot = districts.plots[3]
	districts.configure(barracks,"barracks")
	barracks.restore_progress(true,2)
	check(game.core_building_effects.get_training_capacity() == 30,"Barracks training capacity stacks")
	check(game.recruitment_queue.get_queue_capacity() == 2,"Barracks adds queue lane")
	check(not game.recruitment_queue.recruit(&"Enforcer",31),"Batch above capacity rejected")
	check(game.recruitment_queue.recruit(&"Enforcer",30),"Full capacity batch accepted")
	var business: BuildLot = districts.plots[4]
	districts.configure(business,"cash")
	business.restore_progress(true,2)
	districts._process(3600)
	check(is_equal_approx(districts.cash_bank,2400),"Hourly Cash accrues")
	saved = game.city_map.get_save_data()
	game.city_map.load_save_data(saved,86400)
	check(is_equal_approx(districts.cash_bank,14400),"Offline Cash capped at six hours")
	cash = game.economy.cash
	game.resource_production.collect()
	check(game.economy.cash == cash+14400 and districts.cash_bank == 0,"Cash-only collection works")
	check(not districts.plots[5].can_develop(),"Chapter 4 district remains locked")
	game.mission_tracker.missions["chapter_4_complete"]["completed"] = true
	for i in [5,6]:
		districts.configure(districts.plots[i],"supplies")
		districts.plots[i].restore_progress(true,2)
	check(game.resource_production.get_parts_per_hour() == 8,"Multiple supply buildings add production")
	var gate_defence: float = game.core_building_effects.get_gate_defence()
	districts.gate.restore_progress(true,2)
	check(game.core_building_effects.get_gate_defence() > gate_defence,"Gate upgrade improves defence")
	var power: float = game.faction_manager.get_rally_power_multiplier()
	districts.rally_hall.restore_progress(true,2)
	check(game.faction_manager.get_rally_power_multiplier() > power,"Rally Hall upgrade improves command")
	game.get_node("DistrictUI").open_plot(plot)
	await get_tree().process_frame
	check(game.city_map.camera.controls_blocked,"District dialog blocks map input")
	game.get_node("DistrictUI").panel.hide()
	var online = game.online_faction_ui
	online.online_rallies = {"hall_level":1,"capacity":4,"rallies":[{
		"id":"audit-fixture","incoming":true,"status":"preparing","faction_name":"QA faction",
		"strategy":"convoy","seconds_remaining":60,"capacity":4,
		"members":[{"player_id":"qa-member","display_name":"QA member","outcome":""}]}]}
	online._refresh_rallies()
	await get_tree().process_frame
	check(online.alert_button.visible,"Incoming rally raises defender alert")
	check("Build the Data Hub" in online.rally_list.get_child(1).text,"Basic warning available without radar")
	game.city_map.lot_d.restore_progress(true,2)
	online._refresh_rallies()
	await get_tree().process_frame
	check("convoy" in online.rally_list.get_child(1).text and "QA member" in online.rally_list.get_child(1).text,"Radar upgrade reveals strategy and members")
	online.online_rallies = {"rallies":[]}
	online._refresh_rallies()
	check(not online.alert_button.visible,"Departed rally clears warning")
	# Production notifications must leave enough time for the save debounce.
	game.save_manager._dirty = false
	for i in range(14):
		districts._process(0.5)
		game.save_manager._process(0.5)
	check(not game.save_manager._dirty,"Production does not starve autosave")
	if failures == 0:
		print("[DISTRICTS] PASS — chapter locks, build/upgrade, offline saves, income, beds, training, gate and command")
	get_tree().quit(1 if failures else 0)
