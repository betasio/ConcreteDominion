class_name ResourceProductionManager
extends Node

signal changed

const CAP_SECONDS := 6.0 * 60.0 * 60.0

var scrap_yard: BuildLot
var data_hub: BuildLot
var loot: LootInventory

var parts_bank: float = 0.0
var intel_bank: float = 0.0
var elapsed: float = 0.0


func setup(scrap: BuildLot, data: BuildLot, inventory: LootInventory) -> void:
	scrap_yard = scrap
	data_hub = data
	loot = inventory
	for lot in [scrap_yard, data_hub]:
		if lot != null:
			lot.changed.connect(_emit_changed)
	changed.emit()


func _process(delta: float) -> void:
	if loot == null:
		return
	if get_parts_per_hour() <= 0 and get_intel_per_hour() <= 0:
		return

	var old_parts := floori(parts_bank)
	var old_intel := floori(intel_bank)
	elapsed = minf(CAP_SECONDS, elapsed + delta)
	parts_bank = minf(_parts_cap(), parts_bank + float(get_parts_per_hour()) * delta / 3600.0)
	intel_bank = minf(_intel_cap(), intel_bank + float(get_intel_per_hour()) * delta / 3600.0)

	if floori(parts_bank) != old_parts or floori(intel_bank) != old_intel:
		changed.emit()


func get_parts_per_hour() -> int:
	return 2 * scrap_yard.level if scrap_yard != null and scrap_yard.is_built else 0


func get_intel_per_hour() -> int:
	return data_hub.level if data_hub != null and data_hub.is_built else 0


func collect() -> Dictionary:
	var parts := floori(parts_bank)
	var intel := floori(intel_bank)
	if parts <= 0 and intel <= 0:
		return {}

	if parts > 0:
		loot.add_item("Parts", parts)
	if intel > 0:
		loot.add_item("Intel", intel)

	parts_bank = 0.0
	intel_bank = 0.0
	elapsed = 0.0
	changed.emit()
	return {"Parts": parts, "Intel": intel}


func get_summary() -> String:
	return "Parts +%d/hr • Intel +%d/hr • Bank P:%d I:%d" % [
		get_parts_per_hour(),
		get_intel_per_hour(),
		floori(parts_bank),
		floori(intel_bank)
	]


func get_save_data() -> Dictionary:
	return {
		"parts_bank": parts_bank,
		"intel_bank": intel_bank,
		"elapsed": elapsed
	}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	parts_bank = maxf(0.0, float(data.get("parts_bank", 0.0)))
	intel_bank = maxf(0.0, float(data.get("intel_bank", 0.0)))
	elapsed = minf(CAP_SECONDS, float(data.get("elapsed", 0.0)) + maxf(0.0, offline_seconds))

	var offline := minf(CAP_SECONDS, maxf(0.0, offline_seconds))
	parts_bank = minf(_parts_cap(), parts_bank + float(get_parts_per_hour()) * offline / 3600.0)
	intel_bank = minf(_intel_cap(), intel_bank + float(get_intel_per_hour()) * offline / 3600.0)
	changed.emit()


func _parts_cap() -> float:
	return float(get_parts_per_hour()) * CAP_SECONDS / 3600.0


func _intel_cap() -> float:
	return float(get_intel_per_hour()) * CAP_SECONDS / 3600.0


func _emit_changed() -> void:
	changed.emit()
