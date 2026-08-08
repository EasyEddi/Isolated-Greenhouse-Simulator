class_name GreenhouseSettings
extends Node

signal changed

const DEFAULT_PATH := "user://isolated_greenhouse_settings.cfg"

var config_path := DEFAULT_PATH
var look_sensitivity := 0.0021
var master_volume := 0.82
var fullscreen := false


func load_and_apply() -> void:
	var config := ConfigFile.new()
	if config.load(config_path) == OK:
		look_sensitivity = clampf(float(config.get_value("controls", "look_sensitivity", look_sensitivity)), 0.0008, 0.0045)
		master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
		fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	apply()


func set_look_sensitivity(value: float) -> void:
	look_sensitivity = clampf(value, 0.0008, 0.0045)
	_save()
	changed.emit()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()
	changed.emit()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_display()
	_save()
	changed.emit()


func apply() -> void:
	_apply_audio()
	_apply_display()
	changed.emit()


func _apply_audio() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		return
	AudioServer.set_bus_mute(master_bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.001)))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "look_sensitivity", look_sensitivity)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(config_path)

