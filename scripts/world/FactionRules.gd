class_name FactionRules
extends Node

var text_catalog: LocalizedText

var profiles: Dictionary = {
	"dock_rats": {
		"name_key": "FACTION_DOCK_RATS",
		"trait_key": "TRAIT_SCRAPPY",
		"pressure_multiplier": 0.85,
		"encounter_power_multiplier": 0.92,
		"cash_multiplier": 0.95,
		"preferred_encounter": "roadblock"
	},
	"iron_serpents": {
		"name_key": "FACTION_IRON_SERPENTS",
		"trait_key": "TRAIT_ARMORED",
		"pressure_multiplier": 1.05,
		"encounter_power_multiplier": 1.12,
		"cash_multiplier": 1.08,
		"preferred_encounter": "convoy_ambush"
	},
	"meridian_boys": {
		"name_key": "FACTION_MERIDIAN_BOYS",
		"trait_key": "TRAIT_WATCHFUL",
		"pressure_multiplier": 0.95,
		"encounter_power_multiplier": 1.05,
		"cash_multiplier": 1.00,
		"preferred_encounter": "surveillance"
	},
	"northside_crew": {
		"name_key": "FACTION_NORTHSIDE_CREW",
		"trait_key": "TRAIT_AGGRESSIVE",
		"pressure_multiplier": 1.18,
		"encounter_power_multiplier": 1.08,
		"cash_multiplier": 1.05,
		"preferred_encounter": "roadblock"
	},
	"velvet_circle": {
		"name_key": "FACTION_VELVET_CIRCLE",
		"trait_key": "TRAIT_CONNECTED",
		"pressure_multiplier": 1.00,
		"encounter_power_multiplier": 1.15,
		"cash_multiplier": 1.18,
		"preferred_encounter": "surveillance"
	}
}

var district_factions: Dictionary = {
	"downtown_bank": "dock_rats",
	"harbor_bank": "iron_serpents",
	"midtown_exchange": "meridian_boys",
	"northside_hq": "northside_crew",
	"casino_vault": "velvet_circle",
	"financial_tower": "velvet_circle",
	"industrial_depot": "iron_serpents"
}

var district_encounters: Dictionary = {
	"downtown_bank": ["roadblock", "convoy_ambush"],
	"harbor_bank": ["convoy_ambush", "roadblock"],
	"midtown_exchange": ["surveillance", "roadblock"],
	"northside_hq": ["roadblock", "turf_push"],
	"casino_vault": ["surveillance", "convoy_ambush"],
	"financial_tower": ["surveillance", "roadblock"],
	"industrial_depot": ["convoy_ambush", "roadblock"]
}


func setup(localized_text: LocalizedText) -> void:
	text_catalog = localized_text


func get_faction_id(target_id: String) -> String:
	return String(district_factions.get(target_id, "dock_rats"))


func get_profile(target_id: String) -> Dictionary:
	var faction_id := get_faction_id(target_id)
	return (profiles.get(faction_id, profiles["dock_rats"]) as Dictionary).duplicate(true)


func get_faction_name(target_id: String) -> String:
	var profile := get_profile(target_id)
	var key := String(profile.get("name_key", "FACTION_GENERIC"))
	return text_catalog.text(key) if text_catalog != null else key


func get_trait_name(target_id: String) -> String:
	var profile := get_profile(target_id)
	var key := String(profile.get("trait_key", ""))
	return text_catalog.text(key) if text_catalog != null else key


func get_pressure_multiplier(target_id: String) -> float:
	return float(get_profile(target_id).get("pressure_multiplier", 1.0))


func get_encounter_power_multiplier(target_id: String) -> float:
	return float(get_profile(target_id).get("encounter_power_multiplier", 1.0))


func get_cash_multiplier(target_id: String) -> float:
	return float(get_profile(target_id).get("cash_multiplier", 1.0))


func get_encounter_cycle(target_id: String) -> Array:
	return (district_encounters.get(target_id, ["roadblock", "surveillance", "convoy_ambush"]) as Array).duplicate()


func get_preferred_encounter(target_id: String) -> String:
	return String(get_profile(target_id).get("preferred_encounter", "roadblock"))
