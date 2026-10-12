extends CanvasLayer
var game: Node
var districts: Node
var panel: PanelContainer
var title: Label
var info: Label
var choices: OptionButton
var action: Button
var selected: BuildLot
var status: Label
var row_buttons: VBoxContainer

func setup(root_game: Node) -> void:
	game = root_game
	districts = game.city_map.get_node("EstateDistricts")
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.name = "DistrictPanel"
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.name = "VBox"
	margin.add_child(body)
	title = Label.new()
	title.name = "Title"
	body.add_child(title)
	_button(body,"Close",func(): panel.hide())
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	choices = OptionButton.new()
	for kind in districts.KINDS:
		choices.add_item(districts.KINDS[kind])
		choices.set_item_metadata(choices.item_count-1,kind)
	choices.item_selected.connect(func(_index): _refresh())
	body.add_child(choices)
	action = _button(body,"",_build)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	row_buttons = VBoxContainer.new()
	body.add_child(row_buttons)
	for plot in districts.plots:
		_button(row_buttons,String(plot.building_name),func(): open_plot(plot))
	_button(body,"Collect production",func(): game.resource_production.collect(); _refresh())
	_button(body,"All districts",open_panel)
	_button(body,"View outer district",func():
		panel.hide()
		game.city_map.set_view_mode(&"base")
		game.city_map.camera.position = Vector2(118,960))
	districts.plot_selected.connect(open_plot)
	districts.changed.connect(_refresh)
	game.construction_queue.queue_changed.connect(_refresh)
	game.economy.changed.connect(_refresh)
	panel.hide()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open_panel() -> void:
	selected = null
	panel.show()
	_refresh()

func open_plot(plot: BuildLot) -> void:
	selected = plot
	panel.show()
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(panel) or not panel.visible:
		return
	row_buttons.visible = selected == null
	title.text = "Estate districts" if selected == null else selected.building_name
	choices.visible = selected != null and not selected.is_built and selected.can_develop() and not selected.is_constructing
	action.visible = selected != null
	status.text = ""
	if selected == null:
		info.text = "Inside the gate: HQ, Garage, Intel Office, Data Hub and Rally Hall. Outside: repeatable production, hospitals and barracks.\nHospital beds: %d / %d occupied • Training batch: %d\nCash bank: %d • No Diamond production." % [game.hospital_queue.get_occupied_beds(),game.core_building_effects.get_hospital_capacity(),game.core_building_effects.get_training_capacity(),floori(districts.cash_bank)]
		for i in range(districts.plots.size()):
			var plot = districts.plots[i]
			row_buttons.get_child(i).text = "%s · %s" % [("Garden row" if plot.required_chapter == 2 else "South row")+" • Plot %d" % (((i-2)%3)+1) if plot.facility_kind == "empty" else plot.building_name,"Complete Chapter %d" % plot.required_chapter if not plot.can_develop() else ("Lv.%d" % plot.level if plot.is_built else "Choose facility")]
		return
	if not selected.can_develop():
		info.text = "Complete Chapter %d to clear the fog and develop this plot." % selected.required_chapter
		action.text = "District locked"
		action.disabled = true
		return
	var kind: String = selected.facility_kind if selected.is_built or selected.is_constructing else choices.get_selected_metadata()
	info.text = districts.effect_summary(kind,selected.level if selected.is_built else 1)
	if selected.is_built and selected.can_upgrade():
		info.text += "\nNext level: "+districts.effect_summary(kind,selected.level+1)
	if kind == "hospital":
		info.text += "\nOverflow casualties are lost when all beds are occupied. Existing patients always remain safe during upgrades."
	if kind == "rally":
		info.text += "\nOnline faction rallies are available in Faction → Online → Wars. Online command progression is server controlled."
	var cost: int = selected.get_upgrade_cash_cost() if selected.is_built else selected.build_cash_cost
	action.text = ("Upgrade" if selected.is_built else "Build")+" · $%d" % cost
	action.disabled = game.construction_queue.is_busy() or game.economy.cash < cost or (selected.is_built and not selected.can_upgrade())
	if selected.is_constructing:
		status.text = "Construction in progress."
	elif selected.is_built and not selected.can_upgrade():
		status.text = "Maximum level reached."
	elif game.construction_queue.is_busy():
		status.text = "Finish the current construction first."

func _build() -> void:
	if selected == null:
		return
	if selected.is_built:
		game.construction_queue.start_facility_upgrade(selected)
	elif districts.configure(selected,choices.get_selected_metadata()):
		game.construction_queue.start_lot_build(selected)
	_refresh()
