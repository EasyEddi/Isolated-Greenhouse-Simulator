extends Node

const VERSION := "0.1.0"
const TERMINAL_POSITION := Vector3(-8.1, 0.05, 6.38)
const TERMINAL_YAW := PI
const TERMINAL_PITCH := -0.16

var game_state: GreenhouseGameState
var world: GreenhouseWorldBuilder
var player: GreenhousePlayer
var drone: GreenhouseDroneController
var hud: GreenhouseHUD
var terminal_ui: GreenhouseTerminalUI
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
	hud.show_start_menu(FileAccess.file_exists(GreenhouseGameState.SAVE_PATH))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and game_state and world:
		game_state.save_game(world.plant_snapshots())


func _build_game() -> void:
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
	hud.configure(game_state, player)

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
			for pending_order in game_state.pending_orders:
				drone.queue_order(Dictionary(pending_order))
	else:
		game_state.new_game()
		world.reset_plants()
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
	player.set_gameplay_enabled(true)


func _on_inventory_requested() -> void:
	if terminal_active:
		return
	hud.toggle_inventory()


func _on_pause_requested() -> void:
	if terminal_active:
		_close_terminal()
		return
	hud.toggle_pause()


func _save_game() -> void:
	game_state.save_game(world.plant_snapshots())
	hud.close_overlays()


func _autosave() -> void:
	if hud.start_open or terminal_transitioning:
		return
	game_state.save_game(world.plant_snapshots())


func _quit_game() -> void:
	if not hud.start_open:
		game_state.save_game(world.plant_snapshots())
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

	_expect(game_state.save_game(world.plant_snapshots()), "save game can be written", failures)
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
	hud.close_start_menu()
	player.global_position = Vector3(-5.8, 0.05, 3.9)
	player.rotation.y = -2.35
	player.look_pitch = -0.10
	player.camera_pivot.rotation.x = player.look_pitch
	player.set_gameplay_enabled(false, false)
	await get_tree().create_timer(1.2).timeout
	var output_path := "user://isolated-greenhouse-capture.png"
	var index := args.find("--capture")
	if index >= 0 and index + 1 < args.size():
		output_path = str(args[index + 1])
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	print("ISOLATED_GREENHOUSE_CAPTURE: %s (%s)" % [output_path, error_string(error)])
	get_tree().quit(0 if error == OK else 1)
