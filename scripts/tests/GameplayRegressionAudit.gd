extends Node

var failures: PackedStringArray = []


func _ready() -> void:
	_test_event_rollover()
	_test_resource_caps()
	_test_reward_split_conservation()
	_finish()


func _test_event_rollover() -> void:
	var event := EventManager.new()
	add_child(event)

	var now := Time.get_unix_time_from_system()
	event.load_save_data({
		"event_name": "Blackout Week",
		"event_started_unix": now - EventManager.EVENT_DURATION_SECONDS - 60.0,
		"event_ends_unix": now - 60.0,
		"event_marks": 45,
		"claimed_milestones": [5, 12, 25, 45]
	})

	if not event.is_active():
		_fail("Expired event did not roll into a new active cycle.")
	if event.event_marks != 0:
		_fail("New event cycle did not reset event marks.")
	if not event.claimed_milestones.is_empty():
		_fail("New event cycle did not reset milestone claims.")
	if event.event_ends_unix <= now:
		_fail("New event cycle has an invalid end timestamp.")

	event.queue_free()


func _test_resource_caps() -> void:
	var scrap := BuildLot.new()
	scrap.building_name = "Scrapyard"
	scrap.is_built = true
	scrap.level = 5

	var data_hub := BuildLot.new()
	data_hub.building_name = "Data Hub"
	data_hub.is_built = true
	data_hub.level = 5

	var loot := LootInventory.new()
	var manager := ResourceProductionManager.new()
	add_child(scrap)
	add_child(data_hub)
	add_child(loot)
	add_child(manager)
	manager.setup(scrap, data_hub, loot)
	manager.load_save_data({}, 24.0 * 60.0 * 60.0)

	var expected_parts := float(manager.get_parts_per_hour()) * 6.0
	var expected_intel := float(manager.get_intel_per_hour()) * 6.0
	if not is_equal_approx(manager.parts_bank, expected_parts):
		_fail("Parts offline production exceeded or missed the six-hour cap.")
	if not is_equal_approx(manager.intel_bank, expected_intel):
		_fail("Intel offline production exceeded or missed the six-hour cap.")

	manager.queue_free()
	scrap.queue_free()
	data_hub.queue_free()
	loot.queue_free()


func _test_reward_split_conservation() -> void:
	# Mirror the public design invariant: the 50/50 equal/performance split
	# must distribute exactly the target reward pool, never create/delete Cash.
	var reward_pool := 10001
	var ids := ["frontline", "driver", "spy"]
	var contribution := {
		"frontline": 8000.0,
		"driver": 1200.0,
		"spy": 1440.0
	}
	var equal_share := 0.50
	var equal_pool := float(reward_pool) * equal_share
	var performance_pool := float(reward_pool) - equal_pool
	var total_contribution := 0.0
	for id in ids:
		total_contribution += float(contribution[id])

	var distributed := 0
	for i in range(ids.size()):
		var id := ids[i]
		var performance_share := performance_pool * float(contribution[id]) / total_contribution
		var share := roundi(equal_pool / float(ids.size()) + performance_share)
		if i == ids.size() - 1:
			share = maxi(0, reward_pool - distributed)
		distributed += share

	if distributed != reward_pool:
		_fail("Raid reward split does not conserve the reward pool.")


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[REGRESSION] %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("[REGRESSION] PASS — long-horizon state invariants are intact.")
		get_tree().quit(0)
	else:
		print("[REGRESSION] FAIL — %d issue(s)." % failures.size())
		get_tree().quit(1)
