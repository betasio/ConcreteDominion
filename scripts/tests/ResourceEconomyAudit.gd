extends Node
var failures: PackedStringArray = []

func _ready() -> void:
	var economy := PlayerEconomy.new()
	var loot := LootInventory.new()
	var retention := RetentionManager.new()
	add_child(economy)
	add_child(loot)
	add_child(retention)
	retention.set_process(false)
	retention.economy = economy
	retention.loot = loot
	# Old saves and inventory keys retain their values under the new identity.
	economy.load_save_data({"cash":12345,"gold":337})
	_check(economy.gold == 337 and economy.get_save_data().gold == 337,"Legacy premium balance changed")
	loot.add_item("Parts",8)
	loot.add_item("Intel",4)
	loot.add_item("Contraband",1)
	_check(preload("res://scripts/core/ResourceIdentity.gd").display_name("Parts") == "Supplies","Supplies display mapping failed")
	_check(preload("res://scripts/core/ResourceIdentity.gd").display_name("Gold") == "Diamonds","Diamonds display mapping failed")
	var premium_before := economy.gold
	_check(retention.craft_street_cache() and retention.craft_syndicate_crate(),"Ordinary-resource crafting failed")
	_check(economy.gold == premium_before,"Repeatable crafting created premium currency")
	_check(economy.cash == 12345+5000+12500,"Crafting cash compensation is incorrect")
	# A genuine day-three free reward, once per day.
	retention.login_streak = 2
	retention.last_login_claim_day = retention._get_day_index()-1
	retention.claim_login_reward()
	_check(economy.gold == premium_before+5,"Free login Diamonds were lost")
	retention.claim_login_reward()
	_check(economy.gold == premium_before+5,"Login reward was claimable twice")
	retention.daily_progress = {"recruit":3,"raid_win":1,"construction":1}
	_check(retention.claim_daily_objective_reward(),"Free daily reward failed")
	_check(retention.claim_daily_mastery_reward(),"Free daily mastery failed")
	_check(economy.gold == premium_before+10,"Daily free Diamond budget changed")
	_check(not retention.claim_daily_objective_reward() and not retention.claim_daily_mastery_reward(),"Daily rewards were claimable twice")
	retention.weekly_progress = {"recruit":15,"raid_win":5,"construction":3}
	_check(retention.claim_weekly_objective_reward() and retention.claim_weekly_mastery_reward(),"Weekly free rewards failed")
	_check(economy.gold == premium_before+30,"Weekly free Diamond budget changed")
	_check(not retention.claim_weekly_objective_reward() and not retention.claim_weekly_mastery_reward(),"Weekly rewards were claimable twice")
	var store := StoreManager.new()
	_check(not store.purchases_enabled(),"Unconnected billing became available")
	store.free()
	if failures.is_empty():
		print("[RESOURCE ECONOMY AUDIT] PASS — legacy balances, free rewards, claim limits and crafting")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
