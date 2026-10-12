extends Node2D
signal changed
signal plot_selected(plot: BuildLot)
const LOT := preload("res://scripts/buildings/ExpansionLot.gd")
const LAYOUT := preload("res://scripts/world/IllustratedEstateLayout.gd")
const KINDS := {"cash":"Cash Business","supplies":"Supply Depot","intel":"Intel Exchange","hospital":"Hospital","barracks":"Barracks"}
var plots: Array[BuildLot] = []
var gate: BuildLot
var rally_hall: BuildLot
var game: Node
var cash_bank := 0.0
var tick := 0.0

func _ready() -> void:
	rally_hall = _new_plot("RallyHall",Vector2(387,265),0,"rally",true)
	gate = _new_plot("EstateGate",Vector2(580,588),0,"gate",true)
	gate.configure_illustrated_pad(Vector2(85,28))
	for row in range(2):
		for col in range(3):
			_new_plot("District%d%d" % [row,col],Vector2(([313,580,850] if row == 0 else [300,580,854])[col],[850,1010][row]),2 if row == 0 else 4,"empty",false)
	get_parent().view_mode_changed.connect(func(mode): visible = mode == &"base" and ProjectSettings.get_setting("concrete_dominion/preview_illustrated_terrain",true))

func setup(root: Node) -> void:
	game = root
	game.mission_tracker.changed.connect(_refresh_locks)

func _new_plot(id: String, pixel: Vector2, chapter: int, kind: String, built: bool) -> BuildLot:
	var lot := Area2D.new()
	lot.set_script(LOT)
	lot.name = id
	lot.districts = self
	lot.required_chapter = chapter
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	lot.add_child(collision)
	add_child(lot)
	lot.position = LAYOUT.artwork_to_world(pixel)
	lot.configure_illustrated_pad(Vector2(94,43))
	lot.selected.connect(func(selected): plot_selected.emit(selected))
	lot.changed.connect(func(): changed.emit())
	plots.append(lot)
	configure(lot,kind)
	if built:
		lot.restore_progress(true,1)
	return lot

func configure(lot: BuildLot, kind: String, restoring: bool = false) -> bool:
	if not restoring and (lot.is_built or lot.is_constructing or (kind != "empty" and not lot.can_develop())):
		return false
	if not KINDS.has(kind) and not kind in ["empty","gate","rally"]:
		return false
	lot.facility_kind = kind
	lot.building_name = KINDS.get(kind,{"gate":"Estate Gate","rally":"Rally Hall","empty":"Development"}.get(kind,"Development"))
	lot.build_cash_cost = 7000
	lot.build_duration = 60
	lot.base_upgrade_cash_cost = 5000
	lot.base_upgrade_duration = 90
	lot.description = effect_summary(kind,1)
	var art: String = {"cash":"garage","supplies":"scrapyard","intel":"data_hub"}.get(kind,kind)
	lot.art_texture = preload("res://scripts/buildings/EstateFacadeArt.gd").texture(art)
	lot.queue_redraw()
	return true

func chapter_completed(chapter: int) -> bool:
	return game != null and bool(game.mission_tracker.missions.get("chapter_%d_complete" % chapter,{}).get("completed",false))

func _refresh_locks() -> void:
	for lot in plots:
		lot.queue_redraw()
	changed.emit()

func built_count(kind: String) -> int:
	var count := 0
	for lot in plots:
		if lot.is_built and lot.facility_kind == kind:
			count += 1
	return count

func total_levels(kind: String) -> int:
	var count := 0
	for lot in plots:
		if lot.is_built and lot.facility_kind == kind:
			count += lot.level
	return count

func effect_summary(kind: String, level: int) -> String:
	match kind:
		"cash": return "Cash +%d/hr • six-hour storage" % (1200*level)
		"supplies": return "Supplies +%d/hr • six-hour storage" % (2*level)
		"intel": return "Intel +%d/hr • six-hour storage" % level
		"hospital": return "+%d casualty beds • +1 treatment lane" % (25*level)
		"barracks": return "+%d training batch • +1 queue slot • training -%d%%" % [10*level,3*level]
		"gate": return "Local war defence +%d%% • guards reduce local raid injuries" % (level*4)
		"rally": return "Faction rally capacity %d members • command strength +%d%%" % [3+level,level*3]
	return "Choose a resource facility, Hospital or Barracks. No Diamond production."

func _process(delta: float) -> void:
	if game == null:
		return
	var rate := total_levels("cash")*1200
	cash_bank = minf(float(rate*6),cash_bank+float(rate)*delta/3600.0)
	tick += delta
	if tick >= 5.0:
		tick = 0
		if rate > 0:
			changed.emit()

func collect_cash() -> int:
	var amount := floori(cash_bank)
	cash_bank -= amount
	if amount > 0:
		game.economy.add_cash(amount)
	changed.emit()
	return amount

func get_save_data() -> Dictionary:
	var states := {}
	for lot in plots:
		states[String(lot.name)] = {"kind":lot.facility_kind,"built":lot.is_built,"level":lot.level}
	return {"plots":states,"cash_bank":cash_bank}

func load_save_data(data: Dictionary, offline: float) -> void:
	var states: Dictionary = data.get("plots",{})
	for lot in plots:
		if not states.has(String(lot.name)):
			continue
		var state: Dictionary = states[String(lot.name)]
		# A saved in-progress build may have a chosen type but no completed level.
		lot.is_built = false
		configure(lot,String(state.get("kind","empty")),true)
		lot.restore_progress(bool(state.get("built",false)),int(state.get("level",1)))
	cash_bank = clampf(float(data.get("cash_bank",0))+float(total_levels("cash")*1200)*minf(21600,maxf(0,offline))/3600.0,0,float(total_levels("cash")*7200))
	changed.emit()
