extends Node

const SAVE_PATH := "user://forest_gear_save.json"
const KEYBOARD_ACTIONS := [&"move_left", &"move_right", &"jump", &"run", &"attack", &"stomp", &"pause"]

var high_score: int = 0
var unlocked_levels: Array[String] = ["forest"]
var keyboard_bindings: Dictionary = {}


func _ready() -> void:
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_capture_current_bindings()
		save_game()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	high_score = int(parsed.get("high_score", 0))
	unlocked_levels.clear()
	for item: Variant in parsed.get("unlocked_levels", ["forest"]):
		unlocked_levels.append(str(item))
	if unlocked_levels.is_empty():
		unlocked_levels.append("forest")
	keyboard_bindings = parsed.get("keyboard_bindings", {})
	_apply_saved_bindings()


func save_game() -> void:
	_capture_current_bindings()
	var data := {
		"high_score": high_score,
		"unlocked_levels": unlocked_levels,
		"keyboard_bindings": keyboard_bindings,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))


func submit_score(value: int) -> void:
	if value > high_score:
		high_score = value
		save_game()


func unlock_level(level_id: String) -> void:
	if not unlocked_levels.has(level_id):
		unlocked_levels.append(level_id)
		save_game()


func is_level_unlocked(level_id: String) -> bool:
	return unlocked_levels.has(level_id)


func rebind_key(action: StringName, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key)
	save_game()


func _capture_current_bindings() -> void:
	keyboard_bindings.clear()
	for action: StringName in KEYBOARD_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				keyboard_bindings[String(action)] = event.physical_keycode
				break


func _apply_saved_bindings() -> void:
	for action_text: String in keyboard_bindings:
		var action := StringName(action_text)
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var key := InputEventKey.new()
		key.physical_keycode = int(keyboard_bindings[action_text])
		InputMap.action_add_event(action, key)
