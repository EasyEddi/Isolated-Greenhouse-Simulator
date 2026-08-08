class_name GreenhouseInteractable
extends StaticBody3D


var interaction_id: String = ""
var display_name: String = "Interact"
var action_key: String = "E"
var callback: Callable
var prompt_callback: Callable
var interaction_enabled: bool = true


func configure(id: String, label: String, on_interact: Callable, key: String = "E", prompt_provider: Callable = Callable()) -> GreenhouseInteractable:
	interaction_id = id
	display_name = label
	callback = on_interact
	action_key = key
	prompt_callback = prompt_provider
	return self


func get_interaction_prompt(selected_item: String = "") -> String:
	if not interaction_enabled:
		return ""
	if prompt_callback.is_valid():
		return str(prompt_callback.call(selected_item))
	return "%s  %s" % [action_key, display_name]


func uses_terminal_key() -> bool:
	return action_key == "F"


func interact(player, selected_item: String = "") -> bool:
	if not interaction_enabled or not callback.is_valid():
		return false
	var result = callback.call(player, selected_item)
	return true if result == null else bool(result)
