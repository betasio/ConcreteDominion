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
	_audit_contract_choices(economy,loot)
	var store := StoreManager.new()
	_check(not store.purchases_enabled(),"Unconnected billing became available")
	store.free()
	if failures.is_empty():
		print("[RESOURCE ECONOMY AUDIT] PASS — legacy balances, production contracts, reward choices, save replay, period boundaries and free Diamond budget")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _audit_contract_choices(economy: PlayerEconomy, loot: LootInventory) -> void:
	var contracts := RetentionManager.new()
	var production := ResourceProductionManager.new()
	add_child(contracts)
	add_child(production)
	contracts.set_process(false)
	production.set_process(false)
	contracts.economy = economy
	contracts.loot = loot
	production.loot = loot
	production.collected.connect(contracts._on_production_collected)
	contracts.load_save_data({"daily_period":contracts._get_day_index(),"weekly_period":contracts._get_week_index(),
		"daily_progress":{"recruit":3,"raid_win":0,"construction":0},
		"weekly_progress":{"recruit":15,"raid_win":0,"construction":0}})
	_check(contracts.get_daily_status().production == 0,"Old saves gained invented production progress")
	_check(not contracts.claim_daily_objective_reward(),"Incomplete contracts paid a reward")
	production.parts_bank = 1.75
	production.intel_bank = 0.25
	production.collect()
	_check(contracts.get_daily_status().production == 1 and is_equal_approx(production.parts_bank,0.75),"Collection did not preserve fractions or count actual goods")
	_check(production.collect().is_empty() and contracts.get_daily_status().production == 1,"Empty collection farmed contract progress")
	production.intel_bank += 1.0
	production.collect()
	_check(contracts.get_daily_status().complete,"Recruitment and production should unlock the daily reward without combat")
	var cash_before := economy.cash
	var diamonds_before := economy.gold
	var intel_before := loot.get_count("Intel")
	_check(not contracts.claim_daily_objective_reward("unknown"),"Invalid reward choice was accepted")
	_check(contracts.claim_daily_objective_reward("intel"),"Intel choice could not be claimed")
	_check(economy.cash == cash_before+1000 and economy.gold == diamonds_before+3 and loot.get_count("Intel") == intel_before+2,"Chosen package payout did not match preview")
	_check(contracts.get_weekly_status().production == 2,"Reward inventory counted as produced goods")
	_check(not contracts.claim_daily_objective_reward("supplies"),"Switching packages allowed a second claim")
	contracts._on_construction_completed(null)
	_check(contracts.claim_daily_mastery_reward() and economy.gold == diamonds_before+5,"Peaceful three-contract bonus changed the Diamond budget")
	production.parts_bank = 100
	production.collect()
	_check(contracts.get_weekly_status().production == 10,"Weekly production was not capped")
	_check(contracts.claim_weekly_objective_reward(),"Production was not available as a weekly alternative")
	var restored := RetentionManager.new()
	add_child(restored)
	restored.set_process(false)
	restored.economy = economy
	restored.loot = loot
	restored.load_save_data(contracts.get_save_data())
	_check(restored.daily_reward_choice == "intel" and not restored.claim_daily_objective_reward("cash"),"Save restore lost reward choice or allowed replay")
	# Claim boundaries must refresh immediately, not wait for the 30-second poll.
	restored.daily_period -= 1
	restored.daily_claimed = false
	cash_before = economy.cash
	_check(not restored.claim_daily_objective_reward() and restored.get_daily_status().completed_contracts == 0,"Yesterday's unclaimed progress paid today's reward")
	restored.weekly_period -= 1
	restored.weekly_claimed = false
	_check(not restored.claim_weekly_objective_reward() and economy.cash == cash_before,"Expired weekly progress paid a reward")
