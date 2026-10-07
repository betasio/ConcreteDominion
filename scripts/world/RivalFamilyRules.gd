class_name RivalFamilyRules
extends Node

var text_catalog: LocalizedText

var profiles: Dictionary = {
	"dock_rats": {
		"name_key": "FACTION_DOCK_RATS",
		"trait_key": "TRAIT_SCRAPPY",
		"pressure_multiplier": 0.85,
		"encounter_power_multiplier": 0.92,
		"cash_multiplier": 0.95,
		"preferred_encounter": "roadblock",
		"boss_name": "Rook Calder",
		"boss_title": "King of the Cut",
		"boss_quote": "Every block has a price. Yours just went up.",
		"perk_summary": "Scrappy crews recover pressure slowly but field cheaper, lighter patrols."
	},
	"iron_serpents": {
		"name_key": "FACTION_IRON_SERPENTS",
		"trait_key": "TRAIT_ARMORED",
		"pressure_multiplier": 1.05,
		"encounter_power_multiplier": 1.12,
		"cash_multiplier": 1.08,
		"preferred_encounter": "convoy_ambush",
		"boss_name": "Viktor Sable",
		"boss_title": "The Road King",
		"boss_quote": "You can take a corner. I own what moves through it.",
		"perk_summary": "Armored convoys hit harder, but successful feuds pay above-market cash."
	},
	"meridian_boys": {
		"name_key": "FACTION_MERIDIAN_BOYS",
		"trait_key": "TRAIT_WATCHFUL",
		"pressure_multiplier": 0.95,
		"encounter_power_multiplier": 1.05,
		"cash_multiplier": 1.00,
		"preferred_encounter": "surveillance",
		"boss_name": "Silas Vale",
		"boss_title": "The Auditor",
		"boss_quote": "You were interesting three moves ago. Now you are predictable.",
		"perk_summary": "Watchful surveillance favors Spy counters and creates intelligence-heavy encounters."
	},
	"northside_crew": {
		"name_key": "FACTION_NORTHSIDE_CREW",
		"trait_key": "TRAIT_AGGRESSIVE",
		"pressure_multiplier": 1.18,
		"encounter_power_multiplier": 1.08,
		"cash_multiplier": 1.05,
		"preferred_encounter": "roadblock",
		"boss_name": "Darius Knox",
		"boss_title": "Northside General",
		"boss_quote": "If you want this side of town, come take it while I am looking.",
		"perk_summary": "Aggressive turf pressure rises quickly and rewards strong Enforcer responses."
	},
	"velvet_circle": {
		"name_key": "FACTION_VELVET_CIRCLE",
		"trait_key": "TRAIT_CONNECTED",
		"pressure_multiplier": 1.00,
		"encounter_power_multiplier": 1.15,
		"cash_multiplier": 1.18,
		"preferred_encounter": "surveillance",
		"boss_name": "Celeste Marrow",
		"boss_title": "The Host",
		"boss_quote": "Power is not who enters the room. It is who decides when the room closes.",
		"perk_summary": "Connected crews field elite surveillance and pay premium cash when challenged."
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



func get_boss_name(target_id: String) -> String:
	return String(get_profile(target_id).get("boss_name", "Unknown Boss"))


func get_boss_title(target_id: String) -> String:
	return String(get_profile(target_id).get("boss_title", "Rival Boss"))


func get_boss_quote(target_id: String) -> String:
	return String(get_profile(target_id).get("boss_quote", ""))


func get_perk_summary(target_id: String) -> String:
	return String(get_profile(target_id).get("perk_summary", ""))


func get_reward_bonus_percent(target_id: String) -> int:
	return roundi(maxf(0.0, get_cash_multiplier(target_id) - 1.0) * 100.0)


func get_power_modifier_percent(target_id: String) -> int:
	return roundi((get_encounter_power_multiplier(target_id) - 1.0) * 100.0)
