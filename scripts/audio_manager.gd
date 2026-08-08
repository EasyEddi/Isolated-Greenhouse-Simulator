class_name GreenhouseAudioManager
extends Node

var game_state: GreenhouseGameState
var player: GreenhousePlayer
var drone: GreenhouseDroneController
var ambient_player: AudioStreamPlayer
var water_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var one_shot_player: AudioStreamPlayer
var drone_player: AudioStreamPlayer3D
var footstep_streams: Array[AudioStream] = []
var footstep_index := 0
var step_cooldown := 0.0


func configure(state: GreenhouseGameState, controlled_player: GreenhousePlayer, delivery_drone: GreenhouseDroneController) -> GreenhouseAudioManager:
	game_state = state
	player = controlled_player
	drone = delivery_drone
	ambient_player = _make_player("res://assets/audio/ambient_hall.wav", -28.0, true)
	water_player = _make_player("res://assets/audio/water_pour.wav", -17.0, true)
	footstep_player = _make_player("", -19.0, false)
	one_shot_player = _make_player("", -13.0, false)
	for index in range(1, 5):
		footstep_streams.append(load("res://assets/audio/footstep_%d.wav" % index))
	drone_player = AudioStreamPlayer3D.new()
	drone_player.name = "DroneMotorAudio"
	drone_player.stream = _looping_stream("res://assets/audio/drone_motor.wav")
	drone_player.volume_db = -12.0
	drone_player.max_distance = 24.0
	drone_player.unit_size = 5.0
	drone.add_child(drone_player)
	game_state.message_requested.connect(_on_message)
	game_state.delivery_requested.connect(func(_order): play_one_shot("ui_confirm", -14.0))
	drone.delivery_landed.connect(func(_order): play_one_shot("delivery", -10.0))
	drone.delivery_collected.connect(func(_order): play_one_shot("ui_confirm", -12.0))
	ambient_player.play()
	return self


func bind_plants(plants: Array[GreenhousePlantActor]) -> void:
	for plant in plants:
		plant.harvested.connect(func(_harvested_plant): play_one_shot("harvest", -11.0))


func shutdown() -> void:
	for audio_player in [ambient_player, water_player, footstep_player, one_shot_player, drone_player]:
		if audio_player:
			audio_player.stop()
			audio_player.stream = null
	footstep_streams.clear()


func _exit_tree() -> void:
	shutdown()


func _process(delta: float) -> void:
	if not player or not drone:
		return
	if player.watering_active:
		if not water_player.playing:
			water_player.play()
	else:
		water_player.stop()
	var drone_active := drone.flight_state != GreenhouseDroneController.FlightState.IDLE
	if drone_active and not drone_player.playing:
		drone_player.play()
	elif not drone_active:
		drone_player.stop()
	step_cooldown -= delta
	var planar_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if player.gameplay_enabled and player.is_on_floor() and planar_speed > 0.65:
		if step_cooldown <= 0.0:
			footstep_player.stream = footstep_streams[footstep_index % footstep_streams.size()]
			footstep_index += 1
			footstep_player.pitch_scale = 0.95 + float(footstep_index % 4) * 0.025
			footstep_player.play()
			step_cooldown = 0.34 if planar_speed > player.walk_speed + 0.5 else 0.46
	else:
		step_cooldown = minf(step_cooldown, 0.10)


func play_one_shot(sound_name: String, volume_db: float = -13.0) -> void:
	var stream = load("res://assets/audio/%s.wav" % sound_name)
	if stream is AudioStream:
		one_shot_player.stream = stream
		one_shot_player.volume_db = volume_db
		one_shot_player.play()


func _on_message(_text: String, tone: String) -> void:
	if tone == "warning":
		play_one_shot("ui_warning", -14.0)


func _make_player(path: String, volume_db: float, loop: bool) -> AudioStreamPlayer:
	var result := AudioStreamPlayer.new()
	result.volume_db = volume_db
	if not path.is_empty():
		result.stream = _looping_stream(path) if loop else load(path)
	add_child(result)
	return result


func _looping_stream(path: String) -> AudioStream:
	var stream = load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
