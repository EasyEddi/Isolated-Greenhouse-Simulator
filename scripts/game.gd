extends Node

const VERSION := "0.1.0"
const TERMINAL_POSITION := Vector3(-7.72, 0.05, 7.05)
const TERMINAL_YAW := PI
const TERMINAL_PITCH := -0.49

var game_state: GreenhouseGameState
var settings: GreenhouseSettings
var world: GreenhouseWorldBuilder
var player: GreenhousePlayer
var drone: GreenhouseDroneController
var hud: GreenhouseHUD
var terminal_ui: GreenhouseTerminalUI
var audio_manager: GreenhouseAudioManager
var autosave_timer: Timer

var terminal_active := false
var terminal_transitioning := false
var return_position := Vector3.ZERO
var return_yaw := 0.0
var return_pitch := 0.0


func _ready() -> void:
	_configure_input_map()
	_build_game()
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if args.has("--smoke-test"):
		await _run_smoke_test()
		return
	if args.has("--capture"):
		await _run_capture_mode(args)
		return
	if args.has("--benchmark"):
		await _run_benchmark()
		return
	hud.show_start_menu(GreenhouseGameState.has_save_file())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and game_state and world:
		game_state.save_game(world.plant_snapshots(), world.storage_snapshots())


func _build_game() -> void:
	settings = GreenhouseSettings.new()
	settings.name = "Settings"
	add_child(settings)
	settings.load_and_apply()

	game_state = GreenhouseGameState.new()
	game_state.name = "GameState"
	add_child(game_state)

	world = GreenhouseWorldBuilder.new()
	add_child(world)
	world.build(game_state)

	player = GreenhousePlayer.new()
	player.name = "Player"
	add_child(player)
	player.configure(game_state)
	player.mouse_sensitivity = settings.look_sensitivity
	player.position = world.player_spawn_position
	player.rotation.y = world.player_spawn_yaw

	drone = GreenhouseDroneController.new()
	world.delivery_root.add_child(drone)
	drone.configure(
		game_state,
		world.delivery_root,
		world.drone_entry_position,
		world.drone_hover_position,
		world.delivery_pad_position
	)

	terminal_ui = GreenhouseTerminalUI.new()
	terminal_ui.name = "TerminalUI"
	add_child(terminal_ui)
	terminal_ui.configure(game_state)

	hud = GreenhouseHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.configure(game_state, player, settings)
	audio_manager = GreenhouseAudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)
	audio_manager.configure(game_state, player, drone)
	audio_manager.bind_plants(world.plant_actors)

	world.terminal_open_requested.connect(_open_terminal)
	world.plant_inspection_requested.connect(hud.show_plant)
	terminal_ui.close_requested.connect(_close_terminal)
	player.inventory_requested.connect(_on_inventory_requested)
	player.pause_requested.connect(_on_pause_requested)
	hud.begin_requested.connect(_begin_shift)
	hud.save_requested.connect(_save_game)
	hud.quit_requested.connect(_quit_game)

	autosave_timer = Timer.new()
	autosave_timer.name = "AutosaveTimer"
	autosave_timer.wait_time = 45.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(_autosave)
	add_child(autosave_timer)


func _begin_shift(load_existing: bool) -> void:
	if load_existing:
		var payload := game_state.load_game()
		if payload.is_empty():
			game_state.new_game()
			world.reset_plants()
		else:
			world.restore_plant_snapshots(Array(payload.get("plants", [])))
			var stored_items := Array(payload.get("storage", []))
			if stored_items.is_empty():
				world.reset_storage()
			else:
				world.restore_storage_snapshots(stored_items)
			for pending_order in game_state.pending_orders:
				drone.queue_order(Dictionary(pending_order))
	else:
		game_state.new_game()
		world.reset_plants()
		world.reset_storage()
	hud.close_start_menu()
	hud.show_message("Shift started. Take your time.", "neutral")


func _open_terminal() -> void:
	if terminal_active or terminal_transitioning or hud.start_open:
		return
	terminal_transitioning = true
	terminal_active = true
	hud.close_overlays()
	hud.hide_plant()
	return_position = player.global_position
	return_yaw = player.rotation.y
	return_pitch = player.look_pitch
	player.set_gameplay_enabled(false, false)
	hud.set_terminal_mode(true)
	world.terminal_interactable.interaction_enabled = false
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "global_position", TERMINAL_POSITION, 0.72)
	tween.tween_property(player, "rotation:y", TERMINAL_YAW, 0.72)
	tween.tween_property(player, "look_pitch", TERMINAL_PITCH, 0.72)
	tween.tween_property(player.camera_pivot, "rotation:x", TERMINAL_PITCH, 0.72)
	await tween.finished
	player.camera.position.y = 0.0
	terminal_transitioning = false
	terminal_ui.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_terminal() -> void:
	if not terminal_active or terminal_transitioning:
		return
	terminal_transitioning = true
	terminal_ui.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "global_position", return_position, 0.62)
	tween.tween_property(player, "rotation:y", return_yaw, 0.62)
	tween.tween_property(player, "look_pitch", return_pitch, 0.62)
	tween.tween_property(player.camera_pivot, "rotation:x", return_pitch, 0.62)
	await tween.finished
	terminal_active = false
	terminal_transitioning = false
	world.terminal_interactable.interaction_enabled = true
	hud.set_terminal_mode(false)
	player.set_gameplay_enabled(true)


func _on_inventory_requested() -> void:
	if terminal_active:
		return
	hud.toggle_inventory()


func _on_pause_requested() -> void:
	if terminal_active:
		_close_terminal()
		return
	if hud.inventory_open:
		hud.toggle_inventory()
		return
	hud.toggle_pause()


func _save_game() -> void:
	game_state.save_game(world.plant_snapshots(), world.storage_snapshots())
	hud.close_overlays()


func _autosave() -> void:
	if hud.start_open or terminal_transitioning:
		return
	game_state.save_game(world.plant_snapshots(), world.storage_snapshots())


func _quit_game() -> void:
	if not hud.start_open:
		game_state.save_game(world.plant_snapshots(), world.storage_snapshots())
	get_tree().quit()


func _configure_input_map() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("interact", KEY_E)
	_bind_key("terminal", KEY_F)
	_bind_key("inventory", KEY_TAB)
	_bind_key("pause", KEY_ESCAPE)
	for index in range(5):
		_bind_key("hotbar_%d" % (index + 1), KEY_1 + index)
	_bind_mouse_button("hotbar_next", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_mouse_button("hotbar_previous", MOUSE_BUTTON_WHEEL_UP)


func _bind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	InputMap.action_add_event(action, event)


func _bind_mouse_button(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	for existing in InputMap.action_get_events(action):
		if existing is InputEventMouseButton and existing.button_index == button:
			return
	InputMap.action_add_event(action, event)


func _run_smoke_test() -> void:
	hud.close_start_menu()
	await get_tree().process_frame
	var failures: Array[String] = []
	_expect(PlantCatalog.species_ids().size() >= 12, "catalog contains twelve species", failures)
	_expect(world.plant_actors.size() >= 16, "world contains sixteen plant stations", failures)
	_expect(world.terminal_interactable != null, "shop terminal exists", failures)
	_expect(world.delivery_root != null, "delivery department exists", failures)
	_expect(world.storage_slots.size() == 12, "storage department has twelve usable shelf slots", failures)
	if not world.storage_slots.is_empty():
		var shelf_slot: GreenhouseStorageSlot = world.storage_slots[0]
		var shelf_item := shelf_slot.stored_item_id
		var shelf_count_before := game_state.item_count(shelf_item)
		_expect(shelf_slot.interact(player, ""), "stored supply can be taken from shelf", failures)
		_expect(game_state.item_count(shelf_item) == shelf_count_before + 1, "taking shelf stock returns exactly one item", failures)
		_expect(shelf_slot.interact(player, shelf_item), "inventory supply can be stored again", failures)
		_expect(game_state.item_count(shelf_item) == shelf_count_before, "storing shelf stock removes exactly one item", failures)

	game_state.currency = 200
	game_state.cart.clear()
	game_state.add_to_cart("starter:mint")
	game_state.add_to_cart("soil:moist")
	game_state.add_to_cart("feed:herb")
	_expect(game_state.checkout_cart(), "shop checkout succeeds", failures)
	drone.force_complete_active_delivery()
	_expect(is_instance_valid(drone.delivery_crate), "drone creates a physical crate", failures)
	if is_instance_valid(drone.delivery_crate):
		drone._on_crate_interacted(player, "")
	_expect(game_state.item_count("starter:mint") == 1, "delivery reaches inventory", failures)

	var empty_slot: GreenhousePlantActor
	for candidate in world.plant_actors:
		if candidate.species_id.is_empty():
			empty_slot = candidate
			break
	_expect(empty_slot != null, "an empty pot is available", failures)
	if empty_slot:
		empty_slot.mutation_chance = 0.0
		_expect(empty_slot.interact(player, "soil:moist"), "soil can be added", failures)
		_expect(empty_slot.interact(player, "trowel"), "soil can be prepared", failures)
		_expect(empty_slot.interact(player, "starter:mint"), "starter can be planted", failures)
		game_state.watering_can_liters = 4.0
		_expect(empty_slot.hold_interact(player, "watering_can", 1.0), "plant can be watered", failures)
		_expect(empty_slot.interact(player, "feed:herb"), "plant can be fed", failures)
		empty_slot.growth = 1.0
		empty_slot.health = 0.95
		empty_slot.moisture = 0.70
		empty_slot.nutrition = 0.75
		empty_slot.offshoot_progress = 0.999
		empty_slot._process(1.0)
		_expect(empty_slot.offshoot_ready, "mature plant produces an offshoot", failures)
		_expect(empty_slot.interact(player, "secateurs"), "offshoot can be harvested", failures)
		_expect(game_state.sell_offshoot("offshoot:mint"), "offshoot can be sold", failures)

	_expect(game_state.save_game(world.plant_snapshots(), world.storage_snapshots()), "save game can be written", failures)
	audio_manager.shutdown()
	audio_manager.queue_free()
	if hud.message_tween and hud.message_tween.is_running():
		hud.message_tween.kill()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	if failures.is_empty():
		print("ISOLATED_GREENHOUSE_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SMOKE TEST: %s" % failure)
		print("ISOLATED_GREENHOUSE_SMOKE_TEST: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if condition:
		print("  PASS: %s" % label)
	else:
		failures.append(label)


func _run_capture_mode(args: Array) -> void:
	var capture_view := "overview"
	var view_index := args.find("--capture-view")
	if view_index >= 0 and view_index + 1 < args.size():
		capture_view = str(args[view_index + 1])
	var view: Array = {
		"overview": [Vector3(-5.8, 0.05, 3.9), -2.35, -0.10],
		"greenhouse": [Vector3(1.6, 0.05, -1.0), -0.88, -0.08],
		"living": [Vector3(-11.2, 0.05, 2.7), 2.08, -0.08],
		"office": [Vector3(-5.4, 0.05, 4.9), 2.55, -0.06],
		"delivery": [Vector3(5.6, 0.05, 4.7), -2.02, -0.07],
		"delivery_drone": [Vector3(5.6, 0.05, 4.7), -2.02, 0.31],
		"nursery_left": [Vector3(2.4, 0.05, 2.78), PI, -0.26],
		"nursery_right": [Vector3(6.9, 0.05, 2.78), PI, -0.26],
		"nursery_back": [Vector3(2.4, 0.05, 3.12), 0.0, -0.26],
		"mutation": [Vector3(8.25, 0.05, 2.88), PI, -0.31],
		"stress": [Vector3(2.85, 0.05, 2.88), PI, -0.29],
		"soil_pot": [Vector3(1.05, 0.05, 3.12), 0.0, -0.29],
		"offshoot": [Vector3(2.85, 0.05, 2.88), PI, -0.29],
		"storage": [Vector3(-3.0, 0.05, 5.25), PI, -0.08],
		"greenhouse_inside": [Vector3(7.0, 0.05, -4.92), 0.0, -0.22],
		"water_station": [Vector3(-9.0, 0.05, -5.8), 0.68, -0.16],
		"watering": [Vector3(2.85, 0.05, 2.78), PI, -0.26],
		"delivery_crate": [Vector3(5.1, 0.05, 4.1), -2.02, 0.04],
		"inventory": [Vector3(-5.8, 0.05, 3.9), -2.35, -0.10],
		"journal": [Vector3(-5.8, 0.05, 3.9), -2.35, -0.10],
		"pause": [Vector3(-5.8, 0.05, 3.9), -2.35, -0.10],
		"held_watering_can": [Vector3(-9.1, 0.05, -5.5), 0.72, -0.08],
		"held_trowel": [Vector3(-9.1, 0.05, -5.5), 0.72, -0.08],
		"held_secateurs": [Vector3(-9.1, 0.05, -5.5), 0.72, -0.08],
		"held_soil": [Vector3(-9.1, 0.05, -5.5), 0.72, -0.08],
		"held_feed": [Vector3(-9.1, 0.05, -5.5), 0.72, -0.08],
		"held_starter": [Vector3(-9.1, 0.05, -5.5), 0.72, -0.08],
		"terminal": [TERMINAL_POSITION, TERMINAL_YAW, TERMINAL_PITCH],
		"terminal_camera": [TERMINAL_POSITION, TERMINAL_YAW, TERMINAL_PITCH],
	}.get(capture_view, [Vector3(-5.8, 0.05, 3.9), -2.35, -0.10])
	if capture_view == "menu":
		hud.show_start_menu(FileAccess.file_exists(GreenhouseGameState.SAVE_PATH))
	else:
		hud.close_start_menu()
	player.global_position = view[0]
	player.rotation.y = view[1]
	player.look_pitch = view[2]
	player.camera_pivot.rotation.x = player.look_pitch
	player.set_gameplay_enabled(false, false)
	if capture_view == "terminal":
		hud.set_terminal_mode(true)
		terminal_ui.open()
		var category_index := args.find("--terminal-category")
		if category_index >= 0 and category_index + 1 < args.size():
			var category := str(args[category_index + 1])
			if category == "sell":
				game_state.add_item("offshoot:monstera_deliciosa", 2)
				game_state.add_item("offshoot:mint", 1)
				terminal_ui._set_mode("sell")
			else:
				terminal_ui._set_category(category)
	elif capture_view.begins_with("held_"):
		var held_item: String = {
			"held_watering_can": "watering_can",
			"held_trowel": "trowel",
			"held_secateurs": "secateurs",
			"held_soil": "soil:aroid",
			"held_feed": "feed:foliage",
			"held_starter": "starter:monstera_deliciosa",
		}.get(capture_view, "watering_can")
		if game_state.item_count(held_item) <= 0:
			game_state.add_item(held_item)
		game_state.hotbar[0] = held_item
		game_state.select_hotbar(0)
	elif capture_view == "terminal_camera":
		hud.set_terminal_mode(true)
	elif capture_view == "mutation":
		player.held_root.visible = false
		if world.plant_actors.size() > 7:
			hud.show_plant(world.plant_actors[7])
	elif capture_view == "stress":
		player.held_root.visible = false
		var stressed_plant: GreenhousePlantActor = world.plant_actors[2]
		stressed_plant.health = 0.12
		stressed_plant.moisture = 0.02
		stressed_plant._update_visuals(true)
		hud.show_plant(stressed_plant)
	elif capture_view == "soil_pot":
		player.held_root.visible = false
		for plant in world.plant_actors:
			if plant.species_id.is_empty():
				game_state.add_item("soil:loam")
				plant.interact(player, "soil:loam")
				hud.show_plant(plant)
				break
	elif capture_view == "offshoot":
		player.held_root.visible = false
		var offshoot_plant: GreenhousePlantActor = world.plant_actors[2]
		offshoot_plant.offshoot_progress = 1.0
		offshoot_plant.offshoot_ready = true
		offshoot_plant._update_visuals(true)
		hud.show_plant(offshoot_plant)
	elif capture_view.begins_with("nursery_") or capture_view in ["greenhouse_inside", "water_station", "storage"]:
		player.held_root.visible = false
	elif capture_view == "delivery_drone":
		player.held_root.visible = false
		drone.visible = true
		drone.position = world.drone_hover_position
		if drone.loaded_visual:
			drone.loaded_visual.visible = true
		if drone.empty_visual:
			drone.empty_visual.visible = false
	elif capture_view == "watering":
		player.set_gameplay_enabled(true, false)
		Input.action_press("interact")
	elif capture_view == "delivery_crate":
		var order := {"id": "qa-delivery", "items": {"starter:mint": 1}, "total": 16}
		drone.queue_order(order)
		drone.force_complete_active_delivery()
		drone.visible = true
		drone.position = world.drone_hover_position + Vector3(0, 0.65, 0)
		if drone.loaded_visual:
			drone.loaded_visual.visible = false
		if drone.empty_visual:
			drone.empty_visual.visible = true
	elif capture_view == "inventory":
		hud.toggle_inventory()
	elif capture_view == "journal":
		hud.toggle_inventory()
		hud._show_journal_tab()
	elif capture_view == "pause":
		hud.toggle_pause()
	await get_tree().create_timer(1.2).timeout
	var output_path := "user://isolated-greenhouse-capture.png"
	var index := args.find("--capture")
	if index >= 0 and index + 1 < args.size():
		output_path = str(args[index + 1])
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	Input.action_release("interact")
	print("ISOLATED_GREENHOUSE_CAPTURE: %s (%s)" % [output_path, error_string(error)])
	audio_manager.shutdown()
	audio_manager.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if error == OK else 1)


func _run_benchmark() -> void:
	hud.close_start_menu()
	player.global_position = Vector3(-5.8, 0.05, 3.9)
	player.rotation.y = -2.35
	player.look_pitch = -0.10
	player.camera_pivot.rotation.x = player.look_pitch
	player.held_root.visible = false
	player.set_gameplay_enabled(false, false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(1.0).timeout
	var frame_times: Array[float] = []
	var start_usec := Time.get_ticks_usec()
	var previous_usec := start_usec
	var peak_draw_calls := 0.0
	while Time.get_ticks_usec() - start_usec < 5_000_000:
		await get_tree().process_frame
		var now_usec := Time.get_ticks_usec()
		frame_times.append((now_usec - previous_usec) / 1000.0)
		previous_usec = now_usec
		player.rotation.y += 0.0018
		peak_draw_calls = maxf(peak_draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frame_times.sort()
	var total_ms := 0.0
	for frame_ms in frame_times:
		total_ms += frame_ms
	var average_ms := total_ms / maxf(frame_times.size(), 1)
	var p95_index := clampi(int(frame_times.size() * 0.95), 0, frame_times.size() - 1)
	var p95_ms: float = frame_times[p95_index]
	print("ISOLATED_GREENHOUSE_BENCHMARK: frames=%d avg_ms=%.3f p95_ms=%.3f avg_fps=%.1f peak_draw_calls=%d" % [frame_times.size(), average_ms, p95_ms, 1000.0 / maxf(average_ms, 0.001), int(peak_draw_calls)])
	audio_manager.shutdown()
	audio_manager.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0)
