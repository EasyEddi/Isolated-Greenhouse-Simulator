class_name GreenhouseHUD
extends CanvasLayer

signal inventory_open_changed(open: bool)
signal pause_open_changed(open: bool)
signal begin_requested(load_existing: bool)
signal save_requested
signal quit_requested

var game_state: GreenhouseGameState
var player: GreenhousePlayer
var root: Control
var gameplay_root: Control
var currency_panel: PanelContainer
var currency_label: Label
var objective_label: Label
var prompt_label: Label
var hotbar_buttons: Array[Button] = []
var hotbar_icons: Array[GreenhouseIcon] = []
var hotbar_counts: Array[Label] = []
var message_panel: PanelContainer
var message_label: Label
var message_tween: Tween
var plant_panel: PanelContainer
var plant_name: Label
var plant_detail: Label
var plant_bars: Dictionary = {}
var inspected_plant: GreenhousePlantActor
var inventory_overlay: Control
var inventory_grid: GridContainer
var journal_grid: GridContainer
var inventory_content: Control
var journal_content: Control
var pause_overlay: Control
var start_overlay: Control
var continue_button: Button
var inventory_open := false
var pause_open := false
var start_open := true

var palette := {
	"ink": Color("#172524"),
	"panel": Color(0.10, 0.16, 0.15, 0.94),
	"panel_light": Color(0.18, 0.27, 0.25, 0.96),
	"line": Color("#819a92"),
	"text": Color("#edf1df"),
	"muted": Color("#aabbb2"),
	"green": Color("#67c587"),
	"gold": Color("#d0bd65"),
	"blue": Color("#79cad8"),
	"warning": Color("#d58b67"),
}


func configure(state: GreenhouseGameState, controlled_player: GreenhousePlayer) -> GreenhouseHUD:
	game_state = state
	player = controlled_player
	_build_ui()
	game_state.state_changed.connect(_refresh_state)
	game_state.objective_changed.connect(_set_objective)
	game_state.message_requested.connect(show_message)
	player.focus_changed.connect(_on_focus_changed)
	_refresh_state()
	_set_objective(game_state.current_objective())
	return self


func _process(_delta: float) -> void:
	if is_instance_valid(inspected_plant) and plant_panel.visible:
		_refresh_plant_panel(inspected_plant)


func show_start_menu(has_save: bool) -> void:
	start_open = true
	start_overlay.visible = true
	gameplay_root.visible = false
	currency_panel.visible = false
	player.held_root.visible = false
	continue_button.visible = has_save
	player.set_gameplay_enabled(false)


func close_start_menu() -> void:
	start_open = false
	start_overlay.visible = false
	gameplay_root.visible = true
	currency_panel.visible = true
	player.held_root.visible = true
	player.set_gameplay_enabled(true)


func set_terminal_mode(active: bool) -> void:
	gameplay_root.visible = not active
	currency_panel.visible = true
	player.held_root.visible = not active


func toggle_inventory() -> void:
	if start_open or pause_open:
		return
	inventory_open = not inventory_open
	inventory_overlay.visible = inventory_open
	if inventory_open:
		_rebuild_inventory()
	player.set_gameplay_enabled(not inventory_open)
	inventory_open_changed.emit(inventory_open)


func toggle_pause() -> void:
	if start_open:
		return
	if inventory_open:
		inventory_open = false
		inventory_overlay.visible = false
		inventory_open_changed.emit(false)
	pause_open = not pause_open
	pause_overlay.visible = pause_open
	player.set_gameplay_enabled(not pause_open)
	pause_open_changed.emit(pause_open)


func close_overlays() -> void:
	inventory_open = false
	pause_open = false
	inventory_overlay.visible = false
	pause_overlay.visible = false
	if not start_open:
		player.set_gameplay_enabled(true)


func show_message(text: String, tone: String = "neutral") -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", {
		"good": palette.green.lightened(0.18),
		"warning": palette.warning.lightened(0.10),
	}.get(tone, palette.text))
	message_panel.visible = true
	message_panel.modulate.a = 1.0
	if message_tween and message_tween.is_running():
		message_tween.kill()
	message_tween = create_tween()
	message_tween.tween_interval(2.4)
	message_tween.tween_property(message_panel, "modulate:a", 0.0, 0.45)
	message_tween.tween_callback(func(): message_panel.visible = false)


func show_plant(plant: GreenhousePlantActor) -> void:
	inspected_plant = plant
	plant_panel.visible = true
	_refresh_plant_panel(plant)


func hide_plant() -> void:
	inspected_plant = null
	plant_panel.visible = false


func _build_ui() -> void:
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	gameplay_root = Control.new()
	gameplay_root.name = "GameplayHUD"
	gameplay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gameplay_root)
	_build_currency()
	_build_objective()
	_build_crosshair()
	_build_prompt()
	_build_hotbar()
	_build_message()
	_build_plant_panel()
	_build_inventory()
	_build_pause()
	_build_start_menu()


func _build_currency() -> void:
	var panel := PanelContainer.new()
	currency_panel = panel
	panel.name = "Currency"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-232, 22)
	panel.size = Vector2(202, 68)
	panel.add_theme_stylebox_override("panel", _style(palette.panel, palette.line, 1, 4, 12))
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	currency_label = Label.new()
	currency_label.text = "0"
	currency_label.add_theme_font_size_override("font_size", 31)
	currency_label.add_theme_color_override("font_color", palette.text)
	currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(currency_label)
	var leaf := GreenhouseIcon.new()
	leaf.icon_kind = "leaf"
	leaf.custom_minimum_size = Vector2(42, 42)
	row.add_child(leaf)


func _build_objective() -> void:
	var panel := PanelContainer.new()
	panel.name = "Objective"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(24, 24)
	panel.size = Vector2(460, 88)
	panel.add_theme_stylebox_override("panel", _style(palette.panel, palette.line.darkened(0.18), 1, 4, 14))
	gameplay_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var header := Label.new()
	header.text = "CURRENT TASK"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", palette.gold)
	column.add_child(header)
	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", palette.text)
	column.add_child(objective_label)


func _build_crosshair() -> void:
	var horizontal := ColorRect.new()
	horizontal.color = Color(0.94, 0.98, 0.90, 0.86)
	horizontal.set_anchors_preset(Control.PRESET_CENTER)
	horizontal.position = Vector2(-8, -1)
	horizontal.size = Vector2(16, 2)
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_root.add_child(horizontal)
	var vertical := ColorRect.new()
	vertical.color = horizontal.color
	vertical.set_anchors_preset(Control.PRESET_CENTER)
	vertical.position = Vector2(-1, -8)
	vertical.size = Vector2(2, 16)
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_root.add_child(vertical)


func _build_prompt() -> void:
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-300, -150)
	prompt_label.size = Vector2(600, 42)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", palette.text)
	prompt_label.add_theme_color_override("font_outline_color", palette.ink)
	prompt_label.add_theme_constant_override("outline_size", 6)
	gameplay_root.add_child(prompt_label)


func _build_hotbar() -> void:
	var panel := PanelContainer.new()
	panel.name = "Hotbar"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-245, -92)
	panel.size = Vector2(490, 78)
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.11, 0.10, 0.88), palette.line.darkened(0.25), 1, 3, 7))
	gameplay_root.add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	for index in range(5):
		var button := Button.new()
		button.custom_minimum_size = Vector2(82, 62)
		button.tooltip_text = "Hotbar %d" % (index + 1)
		button.pressed.connect(game_state.select_hotbar.bind(index))
		row.add_child(button)
		hotbar_buttons.append(button)
		var icon := GreenhouseIcon.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 20
		icon.offset_top = 8
		icon.offset_right = -20
		icon.offset_bottom = -8
		button.add_child(icon)
		hotbar_icons.append(icon)
		var number := Label.new()
		number.text = str(index + 1)
		number.position = Vector2(5, 3)
		number.add_theme_font_size_override("font_size", 12)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)
		var count := Label.new()
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.position = Vector2(-31, -24)
		count.size = Vector2(26, 20)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 14)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
		hotbar_counts.append(count)


func _build_message() -> void:
	message_panel = PanelContainer.new()
	message_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_panel.position = Vector2(-260, 30)
	message_panel.size = Vector2(520, 52)
	message_panel.add_theme_stylebox_override("panel", _style(palette.panel, palette.line, 1, 4, 10))
	message_panel.visible = false
	gameplay_root.add_child(message_panel)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 17)
	message_panel.add_child(message_label)


func _build_plant_panel() -> void:
	plant_panel = PanelContainer.new()
	plant_panel.name = "PlantReadout"
	plant_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	plant_panel.position = Vector2(-330, -175)
	plant_panel.size = Vector2(300, 350)
	plant_panel.add_theme_stylebox_override("panel", _style(palette.panel, palette.line, 1, 4, 15))
	plant_panel.visible = false
	gameplay_root.add_child(plant_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	plant_panel.add_child(column)
	plant_name = Label.new()
	plant_name.add_theme_font_size_override("font_size", 23)
	plant_name.add_theme_color_override("font_color", palette.text)
	plant_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(plant_name)
	plant_detail = Label.new()
	plant_detail.add_theme_font_size_override("font_size", 14)
	plant_detail.add_theme_color_override("font_color", palette.muted)
	plant_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(plant_detail)
	for spec in [["growth", "GROWTH", palette.green], ["health", "HEALTH", Color("#b4d978")], ["moisture", "MOISTURE", palette.blue], ["nutrition", "NUTRITION", palette.gold], ["offshoot", "OFFSHOOT", Color("#9ac7a3")]]:
		var label := Label.new()
		label.text = spec[1]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", palette.muted)
		column.add_child(label)
		var bar := ProgressBar.new()
		bar.name = str(spec[0]).capitalize()
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.custom_minimum_size.y = 10
		bar.add_theme_stylebox_override("background", _style(palette.ink, palette.ink, 0, 2, 0))
		bar.add_theme_stylebox_override("fill", _style(spec[2], spec[2], 0, 2, 0))
		column.add_child(bar)
		plant_bars[spec[0]] = bar


func _build_inventory() -> void:
	inventory_overlay = _modal_backdrop()
	inventory_overlay.visible = false
	root.add_child(inventory_overlay)
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-510, -320)
	frame.size = Vector2(1020, 640)
	frame.add_theme_stylebox_override("panel", _style(palette.panel, palette.line, 2, 5, 20))
	inventory_overlay.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	frame.add_child(outer)
	var top := HBoxContainer.new()
	outer.add_child(top)
	var inventory_button := _text_button("INVENTORY")
	inventory_button.pressed.connect(_show_inventory_tab)
	top.add_child(inventory_button)
	var journal_button := _text_button("PLANT JOURNAL")
	journal_button.pressed.connect(_show_journal_tab)
	top.add_child(journal_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close := _text_button("X")
	close.custom_minimum_size.x = 52
	close.pressed.connect(toggle_inventory)
	top.add_child(close)
	inventory_content = ScrollContainer.new()
	inventory_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(inventory_content)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 5
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 12)
	inventory_grid.add_theme_constant_override("v_separation", 12)
	inventory_content.add_child(inventory_grid)
	journal_content = ScrollContainer.new()
	journal_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal_content.visible = false
	outer.add_child(journal_content)
	journal_grid = GridContainer.new()
	journal_grid.columns = 3
	journal_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_grid.add_theme_constant_override("h_separation", 12)
	journal_grid.add_theme_constant_override("v_separation", 12)
	journal_content.add_child(journal_grid)


func _build_pause() -> void:
	pause_overlay = _modal_backdrop()
	pause_overlay.visible = false
	root.add_child(pause_overlay)
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-220, -250)
	frame.size = Vector2(440, 500)
	frame.add_theme_stylebox_override("panel", _style(palette.panel, palette.line, 2, 5, 24))
	pause_overlay.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	frame.add_child(column)
	var title := Label.new()
	title.text = "SHIFT PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", palette.text)
	column.add_child(title)
	var sensitivity_label := Label.new()
	sensitivity_label.text = "LOOK SENSITIVITY"
	sensitivity_label.add_theme_font_size_override("font_size", 13)
	sensitivity_label.add_theme_color_override("font_color", palette.muted)
	column.add_child(sensitivity_label)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0008
	sensitivity.max_value = 0.0045
	sensitivity.step = 0.0001
	sensitivity.value = player.mouse_sensitivity
	sensitivity.value_changed.connect(func(value): player.mouse_sensitivity = float(value))
	column.add_child(sensitivity)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var resume := _text_button("RESUME")
	resume.pressed.connect(toggle_pause)
	column.add_child(resume)
	var save := _text_button("SAVE GREENHOUSE")
	save.pressed.connect(func(): save_requested.emit())
	column.add_child(save)
	var quit := _text_button("SAVE AND QUIT")
	quit.pressed.connect(func(): quit_requested.emit())
	column.add_child(quit)


func _build_start_menu() -> void:
	start_overlay = ColorRect.new()
	start_overlay.color = Color(0.02, 0.045, 0.04, 0.72)
	start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(start_overlay)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	column.position = Vector2(90, -235)
	column.size = Vector2(560, 470)
	column.add_theme_constant_override("separation", 16)
	start_overlay.add_child(column)
	var title := Label.new()
	title.text = "ISOLATED\nGREENHOUSE"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", palette.text)
	column.add_child(title)
	var version := Label.new()
	version.text = "MVP ALPHA 0.1.0"
	version.add_theme_font_size_override("font_size", 15)
	version.add_theme_color_override("font_color", palette.gold)
	column.add_child(version)
	var description := Label.new()
	description.text = "A quiet shift among living things."
	description.add_theme_font_size_override("font_size", 20)
	description.add_theme_color_override("font_color", palette.muted)
	column.add_child(description)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)
	continue_button = _text_button("CONTINUE SHIFT")
	continue_button.pressed.connect(func(): begin_requested.emit(true))
	column.add_child(continue_button)
	var new_game := _text_button("BEGIN NEW SHIFT")
	new_game.pressed.connect(func(): begin_requested.emit(false))
	column.add_child(new_game)
	var quit := _text_button("EXIT")
	quit.pressed.connect(func(): quit_requested.emit())
	column.add_child(quit)


func _refresh_state() -> void:
	if not currency_label:
		return
	currency_label.text = str(game_state.currency)
	for index in range(hotbar_buttons.size()):
		var item_id := game_state.hotbar[index]
		var data := PlantCatalog.item(item_id)
		hotbar_icons[index].icon_kind = str(data.get("icon", "leaf"))
		var count := game_state.item_count(item_id)
		hotbar_counts[index].text = str(count) if count > 1 else ""
		var active := index == game_state.selected_hotbar_index
		hotbar_buttons[index].add_theme_stylebox_override("normal", _style(palette.panel_light if active else palette.ink, palette.gold if active else palette.line.darkened(0.25), 2 if active else 1, 3, 4))
		hotbar_buttons[index].tooltip_text = "%d: %s" % [index + 1, PlantCatalog.display_name(item_id)]
	if inventory_open:
		_rebuild_inventory()


func _set_objective(text: String) -> void:
	objective_label.text = text


func _on_focus_changed(target, prompt: String) -> void:
	prompt_label.text = prompt
	if target is GreenhousePlantActor:
		show_plant(target)
	elif inspected_plant and target != inspected_plant:
		hide_plant()


func _refresh_plant_panel(plant: GreenhousePlantActor) -> void:
	var data := plant.plant_readout()
	plant_name.text = str(data.get("name", "Plant"))
	if plant.species_id.is_empty():
		plant_detail.text = "%s%s" % [str(data.get("soil", "No soil")), " / mixed" if data.get("prepared", false) else ""]
		for bar in plant_bars.values():
			bar.value = 0
		return
	plant_detail.text = "%s\nSoil: %s / prefers %s\nFeed: %s" % [data.group, data.soil, data.preferred_soil, data.feed]
	for key in plant_bars:
		plant_bars[key].value = clampf(float(data.get(key, 0.0)), 0.0, 1.0) * 100.0


func _show_inventory_tab() -> void:
	inventory_content.visible = true
	journal_content.visible = false
	_rebuild_inventory()


func _show_journal_tab() -> void:
	inventory_content.visible = false
	journal_content.visible = true
	_rebuild_journal()


func _rebuild_inventory() -> void:
	_free_children(inventory_grid)
	var item_ids := game_state.inventory.keys()
	item_ids.sort()
	for item_id in item_ids:
		if game_state.item_count(str(item_id)) <= 0:
			continue
		var data := PlantCatalog.item(str(item_id))
		var button := Button.new()
		button.custom_minimum_size = Vector2(170, 145)
		button.tooltip_text = "Equip %s" % str(data.name)
		button.add_theme_stylebox_override("normal", _style(palette.panel_light, palette.line.darkened(0.15), 1, 4, 8))
		button.add_theme_stylebox_override("hover", _style(palette.panel_light.lightened(0.08), palette.green, 2, 4, 8))
		button.pressed.connect(_equip_inventory_item.bind(str(item_id)))
		inventory_grid.add_child(button)
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 10
		column.offset_top = 8
		column.offset_right = -10
		column.offset_bottom = -8
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(column)
		var icon := GreenhouseIcon.new()
		icon.icon_kind = str(data.icon)
		icon.custom_minimum_size = Vector2(52, 52)
		column.add_child(icon)
		var label := Label.new()
		label.text = str(data.name)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 15)
		column.add_child(label)
		var count := Label.new()
		count.text = "x%d" % game_state.item_count(str(item_id))
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_color_override("font_color", palette.gold)
		column.add_child(count)


func _rebuild_journal() -> void:
	_free_children(journal_grid)
	for species_id in PlantCatalog.species_ids():
		var data := PlantCatalog.species(species_id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(285, 170)
		card.add_theme_stylebox_override("panel", _style(palette.panel_light, palette.line.darkened(0.2), 1, 4, 12))
		journal_grid.add_child(card)
		var column := VBoxContainer.new()
		card.add_child(column)
		var name_label := Label.new()
		name_label.text = str(data.name)
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_color_override("font_color", data.accent)
		column.add_child(name_label)
		var details := Label.new()
		details.text = "%s\nSoil: %s\nFeed: %s\nWater: %s" % [data.group, PlantCatalog.SOIL_NAMES[data.soil], PlantCatalog.FEED_NAMES[data.feed], _water_label(float(data.water_use))]
		details.add_theme_font_size_override("font_size", 14)
		details.add_theme_color_override("font_color", palette.muted)
		column.add_child(details)


func _equip_inventory_item(item_id: String) -> void:
	game_state.equip_item(item_id)
	toggle_inventory()


func _water_label(rate: float) -> String:
	if rate >= 0.0058:
		return "high"
	if rate >= 0.0035:
		return "medium"
	return "low"


func _modal_backdrop() -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.02, 0.018, 0.76)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	return backdrop


func _text_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", palette.text)
	button.add_theme_stylebox_override("normal", _style(palette.panel_light, palette.line.darkened(0.1), 1, 4, 8))
	button.add_theme_stylebox_override("hover", _style(palette.panel_light.lightened(0.08), palette.green, 2, 4, 8))
	button.add_theme_stylebox_override("pressed", _style(palette.ink, palette.gold, 2, 4, 8))
	return button


func _style(background: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(border_width)
	result.set_corner_radius_all(radius)
	result.content_margin_left = margin
	result.content_margin_right = margin
	result.content_margin_top = margin
	result.content_margin_bottom = margin
	return result


func _free_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
