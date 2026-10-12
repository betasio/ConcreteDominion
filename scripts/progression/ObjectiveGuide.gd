extends RefCounted
## Navigation only: never claims rewards, spends resources or starts combat.
const RAIDS := {
	"win_downtown":"downtown_bank", "win_harbor":"harbor_bank",
	"win_midtown":"midtown_exchange", "win_northside":"northside_hq",
	"win_casino":"casino_vault", "win_financial":"financial_tower",
	"win_industrial":"industrial_depot"
}
const LOTS := {"build_garage":"lot_garage", "build_intel":"lot_intel", "build_data_hub":"lot_datahub"}

static func action(mission_id: String) -> Dictionary:
	if mission_id == "recruit_crew":
		return {"kind":"training", "label":"GO TO CREW TRAINING"}
	if LOTS.has(mission_id):
		return {"kind":"lot", "target":LOTS[mission_id], "label":"GO TO BUILDING SITE"}
	if RAIDS.has(mission_id):
		return {"kind":"raid", "target":RAIDS[mission_id], "label":"REVIEW RAID TARGET"}
	if mission_id.begins_with("discover_") or mission_id.is_empty():
		return {"kind":"panel", "target":"WorldControlUI", "label":"OPEN CITY OPERATIONS"}
	if mission_id.begins_with("reach_level_"):
		return {"kind":"panel", "target":"RetentionUI", "label":"VIEW CONTRACTS & XP REWARDS"}
	if mission_id in ["join_faction", "capture_faction_objective"]:
		return {"kind":"panel", "target":"FactionUI", "label":"OPEN FACTION OPERATIONS"}
	return {"kind":"panel", "target":"ProgressionUI", "label":"REVIEW CHAPTER"}
