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
	game._begin_shift(false)
	await process_frame

	await _test_terminal_camera(game)
	await _test_interaction_focus(game)
	await _test_hall_collision(game)
	await _test_realtime_delivery(game)

	game.audio_manager.shutdown()
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

	game.player.global_position = Vector3(-10.77, 0.05, -4.72)
	game.player.rotation.y = 0.0
	game.player.look_pitch = -0.15
	game.player.camera_pivot.rotation.x = -0.15
	await physics_frame
	game.player._update_focus()
	_expect(game.player.focused_target == game.world.faucet_interactable, "utility sink raycasts the faucet")
	_expect(game.player.focused_prompt.begins_with("E"), "faucet advertises the E interaction")


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


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  PASS: %s" % message)
	else:
		failures.append(message)


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
