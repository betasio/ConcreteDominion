class_name LocalizedText
extends Node

var fallback: Dictionary = {
	"FACTION_DOCK_RATS": "Dock Rats",
	"FACTION_IRON_SERPENTS": "Iron Serpents",
	"FACTION_MERIDIAN_BOYS": "Meridian Boys",
	"FACTION_NORTHSIDE_CREW": "Northside Crew",
	"FACTION_VELVET_CIRCLE": "Velvet Circle",
	"FACTION_GENERIC": "Rival Crew",
	"TRAIT_SCRAPPY": "Scrappy",
	"TRAIT_ARMORED": "Armored",
	"TRAIT_WATCHFUL": "Watchful",
	"TRAIT_AGGRESSIVE": "Aggressive",
	"TRAIT_CONNECTED": "Connected",
	"ENCOUNTER_ROADBLOCK": "Roadblock",
	"ENCOUNTER_SURVEILLANCE": "Surveillance Sweep",
	"ENCOUNTER_CONVOY": "Convoy Ambush",
	"ENCOUNTER_TURF_PUSH": "Turf Push",
	"ACH_FIRST_TURF": "First Territory",
	"ACH_ALL_DISTRICTS": "Citywide",
	"ACH_ALLIANCE_4": "Trusted Crew",
	"ACH_ACCOUNT_7": "Made Boss",
	"ACH_MAX_SAFEHOUSE": "Command Center",
	"ACH_RESOURCE_NETWORK": "Supply Network",
	"ACH_SPECIALISTS_3": "Specialist Crew",
	"ACH_DOMINION": "Concrete Dominion",
	"ACH_DESC_FIRST_TURF": "Capture your first district.",
	"ACH_DESC_ALL_DISTRICTS": "Own every district in the city.",
	"ACH_DESC_ALLIANCE_4": "Reach Alliance Level 4.",
	"ACH_DESC_ACCOUNT_7": "Reach Account Level 7.",
	"ACH_DESC_MAX_SAFEHOUSE": "Upgrade the Safehouse to Level 5.",
	"ACH_DESC_RESOURCE_NETWORK": "Build both the Scrapyard and Data Hub.",
	"ACH_DESC_SPECIALISTS_3": "Reach Level 3 with Enforcer, Driver, and Spy specialists.",
	"ACH_DESC_DOMINION": "Complete the citywide endgame requirements.",
	"UI_STORE": "Store",
	"UI_STORE_TITLE": "PROTOTYPE STORE",
	"UI_STORE_NOTICE": "Preview only. No real payments are connected. Offers focus on progression speed and resources, not exclusive combat units.",
	"UI_STORE_DISABLED": "Purchases Disabled — Prototype Catalog",
	"UI_STORE_TOOLTIP": "No billing SDK, store receipt validation, or real-money transaction is connected.",
	"UI_INCLUDES": "Includes:",
	"UI_CLOSE": "Close",
	"UI_TERRITORY": "Territory",
	"UI_TERRITORY_TITLE": "TERRITORY COMMAND",
	"UI_TURF_INCOME": "TURF INCOME",
	"UI_DISTRICTS": "DISTRICTS",
	"UI_NEXT_DISCOVERY": "NEXT DISCOVERY",
	"UI_COMMAND_SCAN": "Safehouse Command Scan",
	"UI_RESOURCE_FACILITIES": "RESOURCE FACILITIES",
	"UI_RIVAL_ENCOUNTER": "RIVAL ENCOUNTER",
	"UI_NO_THREAT": "No active threat.",
	"UI_ALLIANCE_TASKS": "ALLIANCE TASKS",
	"UI_COLLECT_RESOURCES": "Collect Parts / Intel",
	"UI_REVEAL_INTEL": "Reveal with Intel",
	"UI_CLEAR_PATROL": "Clear Patrol",
	"UI_PROGRESSION": "Progression",
	"UI_ACCOUNT_LEVEL": "ACCOUNT LEVEL",
	"UI_XP": "XP",
	"UI_UNLOCKS_TITLE": "DISTRICT / CITY UNLOCKS",
	"UI_MISSIONS": "MISSIONS",
	"UI_NO_COST": "No cost"
}


func text(key: String, replacements: Dictionary = {}) -> String:
	var translated := tr(key)
	var value := translated
	if translated == key:
		value = String(fallback.get(key, key))

	for token in replacements.keys():
		value = value.replace("{%s}" % String(token), String(replacements[token]))
	return value


func has_key(key: String) -> bool:
	return fallback.has(key)
