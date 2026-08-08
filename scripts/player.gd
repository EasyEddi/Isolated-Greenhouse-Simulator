class_name GreenhousePlayer
extends CharacterBody3D

signal focus_changed(target, prompt: String)
signal inventory_requested
signal pause_requested
signal terminal_requested

var game_state: GreenhouseGameState
var camera_pivot: Node3D
var camera: Camera3D
var held_root: Node3D
var gameplay_enabled: bool = true
var mouse_sensitivity: float = 0.0021
var walk_speed: float = 4.2
var sprint_speed: float = 6.2
var acceleration: float = 15.0
var look_pitch: float = 0.0
var focused_target = null
var focused_prompt: String = ""
var bob_time: float = 0.0
var _last_held_item: String = ""


func configure(state: GreenhouseGameState) -> GreenhousePlayer:
	game_state = state
	_build_player()
	game_state.state_changed.connect(_refresh_held_item)
	_refresh_held_item()
	return self


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and gameplay_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		look_pitch = clampf(look_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-82.0), deg_to_rad(82.0))
		camera_pivot.rotation.x = look_pitch
	if event.is_action_pressed("inventory") and gameplay_enabled:
		inventory_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
	if not gameplay_enabled:
		return
	for index in range(5):
		if event.is_action_pressed("hotbar_%d" % (index + 1)):
			game_state.select_hotbar(index)
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("hotbar_next"):
		game_state.select_hotbar(game_state.selected_hotbar_index + 1)
	if event.is_action_pressed("hotbar_previous"):
		game_state.select_hotbar(game_state.selected_hotbar_index - 1)
	if event.is_action_pressed("terminal") and is_instance_valid(focused_target) and focused_target.has_method("uses_terminal_key") and focused_target.uses_terminal_key():
		focused_target.interact(self, game_state.selected_item())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and is_instance_valid(focused_target) and focused_target.has_method("interact") and not (focused_target.has_method("uses_terminal_key") and focused_target.uses_terminal_key()):
		focused_target.interact(self, game_state.selected_item())
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not camera:
		return
	_update_focus()
	if gameplay_enabled:
		var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := (global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
		var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
		velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
		if not is_on_floor():
			velocity.y -= 18.0 * delta
		else:
			velocity.y = -0.2
		move_and_slide()
		var planar_speed := Vector2(velocity.x, velocity.z).length()
		if planar_speed > 0.2 and is_on_floor():
			bob_time += delta * planar_speed * 1.6
			camera.position.y = 0.025 * sin(bob_time * 2.0)
		else:
			camera.position.y = lerpf(camera.position.y, 0.0, delta * 8.0)
		if Input.is_action_pressed("interact") and is_instance_valid(focused_target) and focused_target.has_method("hold_interact"):
			focused_target.hold_interact(self, game_state.selected_item(), delta)
	else:
		velocity = Vector3.ZERO


func set_gameplay_enabled(enabled: bool, capture_mouse: bool = true) -> void:
	gameplay_enabled = enabled
	if enabled and capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_player() -> void:
	if camera_pivot:
		return
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position.y = 1.62
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	camera.fov = 74.0
	camera.near = 0.04
	camera_pivot.add_child(camera)
	held_root = Node3D.new()
	held_root.name = "HeldItem"
	held_root.position = Vector3(0.39, -0.36, -0.72)
	held_root.rotation_degrees = Vector3(-9.0, -12.0, 6.0)
	camera.add_child(held_root)


func _update_focus() -> void:
	if not gameplay_enabled:
		_set_focus(null, "")
		return
	var origin := camera.global_position
	var end := origin + -camera.global_transform.basis.z * 3.15
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var target = result.get("collider")
	if is_instance_valid(target) and target.has_method("get_interaction_prompt"):
		_set_focus(target, str(target.get_interaction_prompt(game_state.selected_item())))
	else:
		_set_focus(null, "")


func _set_focus(target, prompt: String) -> void:
	if target == focused_target and prompt == focused_prompt:
		return
	focused_target = target
	focused_prompt = prompt
	focus_changed.emit(target, prompt)


func _refresh_held_item() -> void:
	var item_id := game_state.selected_item()
	if item_id == _last_held_item:
		return
	_last_held_item = item_id
	for child in held_root.get_children():
		child.queue_free()
	if item_id.is_empty():
		return
	var model_name := ""
	var item_data := PlantCatalog.item(item_id)
	match str(item_data.get("kind", "")):
		"tool":
			model_name = {"watering_can": "watering_can", "trowel": "trowel", "secateurs": "secateurs"}.get(item_id, "")
		"soil":
			model_name = "soil_bag"
		"feed":
			model_name = "fertilizer_bag"
		"starter", "offshoot":
			model_name = "empty_pot"
	if model_name.is_empty():
		return
	var resource = load("res://assets/models/props/%s.glb" % model_name)
	if resource is PackedScene:
		var model = resource.instantiate()
		held_root.add_child(model)
		var first_person_scale: float = {
			"watering_can": 0.42,
			"trowel": 0.52,
			"secateurs": 0.55,
			"soil_bag": 0.48,
			"fertilizer_bag": 0.48,
			"empty_pot": 0.52,
		}.get(model_name, 0.50)
		model.scale = Vector3.ONE * first_person_scale
