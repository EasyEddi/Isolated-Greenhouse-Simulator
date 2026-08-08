extends SceneTree

var failures: Array[String] = []
var checks := 0
var save_existed := false
var save_backup := PackedByteArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_backup_save()
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(game.get_tree().paused, "start menu pauses the simulation")
	var start_session_seconds: float = game.game_state.session_seconds
	await create_timer(0.15, true).timeout
	_expect(is_equal_approx(game.game_state.session_seconds, start_session_seconds), "world time does not advance behind the start menu")
	game._begin_shift(false)
	await process_frame

	await _test_terminal_camera(game)
	await _test_interaction_focus(game)
	await _test_hall_collision(game)
	await _test_pause_freezes_simulation(game)
	await _test_realtime_delivery(game)
	await _test_queued_deliveries(game)
	await _test_full_save_restore(game)

	game.audio_manager.shutdown()
	await create_timer(0.20, true).timeout
	game.queue_free()
	await process_frame
	await process_frame
	_restore_save()
	if failures.is_empty():
		print("ISOLATED_GREENHOUSE_INTEGRATION: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("INTEGRATION FAILURE: %s" % failure)
		print("ISOLATED_GREENHOUSE_INTEGRATION: FAIL (%d of %d checks)" % [failures.size(), checks])
		quit(1)


func _test_terminal_camera(game) -> void:
	var starts := [
		Vector3(-9.25, 0.05, 7.05),
		Vector3(-7.72, 0.05, 6.70),
		Vector3(-6.20, 0.05, 7.05),
	]
	for start in starts:
		game.player.global_position = start
		game.player.rotation.y = -0.35
		game.player.look_pitch = 0.12
		game.player.camera_pivot.rotation.x = 0.12
		await game._open_terminal()
		_expect(game.player.global_position.distance_to(game.TERMINAL_POSITION) < 0.002, "terminal camera reaches fixed position from x=%.2f" % start.x)
		_expect(absf(angle_difference(game.player.rotation.y, game.TERMINAL_YAW)) < 0.002, "terminal camera reaches fixed yaw from x=%.2f" % start.x)
		_expect(absf(game.player.look_pitch - game.TERMINAL_PITCH) < 0.002, "terminal camera reaches fixed pitch from x=%.2f" % start.x)
		_expect(not game.player.gameplay_enabled, "movement locks while terminal is open")
		await game._close_terminal()
		_expect(game.player.global_position.distance_to(start) < 0.002, "terminal exit restores exact position x=%.2f" % start.x)
		_expect(game.player.gameplay_enabled, "movement unlocks after terminal exit")


func _test_interaction_focus(game) -> void:
	game.player.global_position = game.TERMINAL_POSITION
	game.player.rotation.y = game.TERMINAL_YAW
	game.player.look_pitch = game.TERMINAL_PITCH
	game.player.camera_pivot.rotation.x = game.TERMINAL_PITCH
	await physics_frame
	game.player._update_focus()
	_expect(game.player.focused_target == game.world.terminal_interactable, "fixed desk view raycasts the terminal")
	_expect(game.player.focused_prompt.begins_with("F"), "terminal advertises the F interaction")
	_send_action(game.player, "terminal")
	var open_deadline := Time.get_ticks_msec() + 2200
	while (not game.terminal_active or game.terminal_transitioning) and Time.get_ticks_msec() < open_deadline:
		await process_frame
	_expect(game.terminal_active and game.terminal_ui.visible, "F opens the terminal through the real input path")
	_send_action(game.player, "interact")
	await process_frame
	_expect(game.terminal_active, "E is ignored while the terminal owns input")
	_send_action(game.player, "pause")
	var close_deadline := Time.get_ticks_msec() + 2200
	while (game.terminal_active or game.terminal_transitioning) and Time.get_ticks_msec() < close_deadline:
		await process_frame
	_expect(not game.terminal_active and game.player.gameplay_enabled, "Escape exits the terminal and restores movement")

	game.player.global_position = Vector3(-10.77, 0.05, -4.72)
	game.player.rotation.y = 0.0
	game.player.look_pitch = -0.15
	game.player.camera_pivot.rotation.x = -0.15
	await physics_frame
	game.player._update_focus()
	_expect(game.player.focused_target == game.world.faucet_interactable, "utility sink raycasts the faucet")
	_expect(game.player.focused_prompt.begins_with("E"), "faucet advertises the E interaction")

	game.player.global_position = Vector3(-5.45, 0.05, 6.72)
	game.player.rotation.y = PI
	game.player.look_pitch = -0.38
	game.player.camera_pivot.rotation.x = -0.38
	await physics_frame
	game.player._update_focus()
	_expect(game.player.focused_target == game.world.storage_slots[6], "storage raycast reaches the front shelf slot")
	_expect(game.player.focused_prompt.begins_with("E  Take"), "occupied shelf slot advertises retrieval in first person")


func _test_hall_collision(game) -> void:
	game.player.global_position = Vector3(10.70, 0.05, 0.0)
	game.player.rotation.y = -PI * 0.5
	game.player.look_pitch = 0.0
	game.player.camera_pivot.rotation.x = 0.0
	game.player.set_gameplay_enabled(true, false)
	Input.action_press("move_forward")
	for _frame in range(90):
		await physics_frame
	Input.action_release("move_forward")
	_expect(game.player.global_position.x < 11.48, "outer hall wall blocks first-person movement")
	_expect(game.player.is_on_floor(), "player remains grounded after collision test")


func _test_pause_freezes_simulation(game) -> void:
	var observed_plant: GreenhousePlantActor = game.world.plant_actors[0]
	var growth_before := observed_plant.growth
	var session_before: float = float(game.game_state.session_seconds)
	var position_before: Vector3 = Vector3(game.player.global_position)
	_send_action(game.player, "pause")
	await process_frame
	_expect(game.get_tree().paused and game.hud.pause_open, "pause menu pauses the scene tree")
	await create_timer(0.25, true).timeout
	_expect(is_equal_approx(observed_plant.growth, growth_before), "plant growth freezes while paused")
	_expect(is_equal_approx(game.game_state.session_seconds, session_before), "session time freezes while paused")
	_expect(game.player.global_position.distance_to(position_before) < 0.001, "player remains fixed while paused")
	_send_action(game.player, "pause")
	await process_frame
	_expect(not game.get_tree().paused and not game.hud.pause_open, "resume unpauses the simulation")


func _test_realtime_delivery(game) -> void:
	game.game_state.cart.clear()
	game.game_state.currency = 85
	_expect(game.game_state.add_to_cart("starter:mint"), "integration order accepts a starter")
	_expect(game.game_state.checkout_cart(), "integration order checks out")
	var seen_states: Dictionary = {}
	var deadline := Time.get_ticks_msec() + 9000
	while not is_instance_valid(game.drone.delivery_crate) and Time.get_ticks_msec() < deadline:
		seen_states[game.drone.flight_state] = true
		await process_frame
	seen_states[game.drone.flight_state] = true
	_expect(is_instance_valid(game.drone.delivery_crate), "drone lands a physical crate in real time")
	_expect(seen_states.has(game.drone.FlightState.APPROACH), "drone flies an approach segment")
	_expect(seen_states.has(game.drone.FlightState.LOWER), "drone lowers over the delivery pad")
	_expect(seen_states.has(game.drone.FlightState.RISE), "drone rises after releasing the package")
	var depart_deadline := Time.get_ticks_msec() + 6000
	while game.drone.flight_state != game.drone.FlightState.IDLE and Time.get_ticks_msec() < depart_deadline:
		seen_states[game.drone.flight_state] = true
		await process_frame
	_expect(seen_states.has(game.drone.FlightState.DEPART), "drone departs after delivery")
	_expect(game.drone.flight_state == game.drone.FlightState.IDLE and not game.drone.visible, "drone returns to its idle state")
	var mint_before: int = int(game.game_state.item_count("starter:mint"))
	_expect(game.drone.delivery_crate.interact(game.player, ""), "landed crate can be collected")
	await process_frame
	_expect(game.game_state.item_count("starter:mint") == mint_before + 1, "crate collection grants its exact contents")


func _test_queued_deliveries(game) -> void:
	game.game_state.currency = 200
	game.game_state.cart.clear()
	_expect(game.game_state.add_to_cart("starter:lily"), "first queued order accepts stock")
	_expect(game.game_state.checkout_cart(), "first queued order checks out")
	var first_id := str(game.game_state.pending_orders[0].id)
	_expect(game.game_state.add_to_cart("soil:loam"), "second queued order accepts stock")
	_expect(game.game_state.checkout_cart(), "second queued order checks out")
	var second_id := str(game.game_state.pending_orders[1].id)
	_expect(game.drone.order_queue.size() == 1, "second delivery waits behind the active drone run")
	game.drone.force_complete_active_delivery()
	_expect(str(game.drone.crate_order.id) == first_id, "first queued order lands first")
	_expect(game.drone.delivery_crate.interact(game.player, ""), "first queued crate can be collected")
	await process_frame
	await process_frame
	_expect(str(game.drone.active_order.id) == second_id, "drone automatically starts the next queued order")
	game.drone.force_complete_active_delivery()
	_expect(str(game.drone.crate_order.id) == second_id, "second queued order lands second")
	_expect(game.drone.delivery_crate.interact(game.player, ""), "second queued crate can be collected")
	await process_frame
	_expect(game.game_state.pending_orders.is_empty(), "collecting both crates clears the delivery queue")


func _test_full_save_restore(game) -> void:
	var saved_slot: GreenhouseStorageSlot = game.world.storage_slots[6]
	var saved_item := saved_slot.stored_item_id
	var inventory_before: int = int(game.game_state.item_count(saved_item))
	_expect(saved_slot.interact(game.player, ""), "save test retrieves a stored supply")
	game.world.plant_actors[0].growth = 0.4242
	game.game_state.currency = 137
	_expect(game.game_state.save_game(game.world.plant_snapshots(), game.world.storage_snapshots()), "full game save writes plant and shelf state")

	var scene := load("res://scenes/main.tscn") as PackedScene
	var restored_game = scene.instantiate()
	root.add_child(restored_game)
	await process_frame
	await process_frame
	restored_game._begin_shift(true)
	await process_frame
	_expect(restored_game.game_state.currency == 137, "full load restores leaf balance")
	_expect(is_equal_approx(restored_game.world.plant_actors[0].growth, 0.4242), "full load restores continuous plant growth")
	_expect(restored_game.world.storage_slots[6].stored_item_id.is_empty(), "full load preserves an emptied shelf slot")
	_expect(restored_game.game_state.item_count(saved_item) == inventory_before + 1, "full load preserves the retrieved shelf item")
	restored_game.audio_manager.shutdown()
	await create_timer(0.20, true).timeout
	restored_game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  PASS: %s" % message)
	else:
		failures.append(message)


func _send_action(target: Node, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	target._unhandled_input(event)


func _backup_save() -> void:
	save_existed = FileAccess.file_exists(GreenhouseGameState.SAVE_PATH)
	if save_existed:
		save_backup = FileAccess.get_file_as_bytes(GreenhouseGameState.SAVE_PATH)


func _restore_save() -> void:
	if save_existed:
		var file := FileAccess.open(GreenhouseGameState.SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_buffer(save_backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GreenhouseGameState.SAVE_PATH))
