extends Node
## Versioned JSON persistence for campaign progress, checkpoints and settings.

const SAVE_VERSION := 5
const CAMPAIGN_STAGE_COUNT := 20
const LAST_CAMPAIGN_STAGE := CAMPAIGN_STAGE_COUNT - 1
const DEFAULT_SAVE_PATH := "user://forest_gear_save.json"
const KEYBOARD_ACTIONS := [
	&"move_left", &"move_right", &"move_down", &"jump", &"run", &"attack", &"stomp", &"pause", &"reload_level",
]

var save_path: String = DEFAULT_SAVE_PATH
var high_score: int = 0
var unlocked_levels: Array[String] = ["forest"]
var keyboard_bindings: Dictionary = {}
var campaign_stage: int = 0
var run_score: int = 0
var run_collectibles: int = 0
var carried_power_level: int = 0
var carried_reserve_bloom_count: int = 0
var checkpoint_level_id: String = ""
var checkpoint_position: Vector2 = Vector2.ZERO
var completed_stages: Array[String] = []


func _ready() -> void:
	load_game()


func load_game() -> void:
	_reset_progress_defaults()
	if not FileAccess.file_exists(save_path):
		_capture_current_bindings()
		save_game()
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	high_score = maxi(0, int(data.get("high_score", 0)))
	unlocked_levels.clear()
	for item: Variant in data.get("unlocked_levels", ["forest"]):
		unlocked_levels.append(str(item))
	if unlocked_levels.is_empty():
		unlocked_levels.append("forest")
	keyboard_bindings = data.get("keyboard_bindings", {})
	campaign_stage = clampi(int(data.get("campaign_stage", 0)), 0, LAST_CAMPAIGN_STAGE)
	run_score = maxi(0, int(data.get("run_score", 0)))
	run_collectibles = maxi(0, int(data.get("run_collectibles", 0)))
	carried_power_level = clampi(int(data.get("carried_power_level", 0)), 0, 2)
	# Version 4 used a single boolean reserve slot. Preserve it when migrating,
	# then use a clamped two-slot count from version 5 onward.
	if data.has("carried_reserve_bloom_count"):
		carried_reserve_bloom_count = clampi(int(data.get("carried_reserve_bloom_count", 0)), 0, 2)
	else:
		carried_reserve_bloom_count = 1 if bool(data.get("carried_reserve_bloom", false)) else 0
	checkpoint_level_id = str(data.get("checkpoint_level_id", ""))
	var saved_position: Variant = data.get("checkpoint_position", {})
	if saved_position is Dictionary:
		checkpoint_position = Vector2(
			float(saved_position.get("x", 0.0)),
			float(saved_position.get("y", 0.0))
		)
	completed_stages.clear()
	for item: Variant in data.get("completed_stages", []):
		completed_stages.append(str(item))
	_apply_saved_bindings()


func save_game() -> void:
	_capture_current_bindings()
	var data := {
		"version": SAVE_VERSION,
		"high_score": high_score,
		"unlocked_levels": unlocked_levels,
		"keyboard_bindings": keyboard_bindings,
		"campaign_stage": campaign_stage,
		"run_score": run_score,
		"run_collectibles": run_collectibles,
		"carried_power_level": carried_power_level,
		"carried_reserve_bloom_count": carried_reserve_bloom_count,
		"checkpoint_level_id": checkpoint_level_id,
		"checkpoint_position": {
			"x": checkpoint_position.x,
			"y": checkpoint_position.y,
		},
		"completed_stages": completed_stages,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	GameEvents.save_completed.emit(save_path)


func save_run_progress(
	stage: int,
	score: int,
	collectible_count: int,
	power_level: int,
	reserve_bloom_count: int = 0
) -> void:
	campaign_stage = clampi(stage, 0, LAST_CAMPAIGN_STAGE)
	run_score = maxi(0, score)
	run_collectibles = maxi(0, collectible_count)
	carried_power_level = clampi(power_level, 0, 2)
	carried_reserve_bloom_count = clampi(reserve_bloom_count, 0, 2)
	save_game()


func save_checkpoint(
	level_id: String,
	world_position: Vector2,
	stage: int,
	score: int,
	collectible_count: int,
	power_level: int,
	reserve_bloom_count: int = 0
) -> void:
	checkpoint_level_id = level_id
	checkpoint_position = world_position
	campaign_stage = clampi(stage, 0, LAST_CAMPAIGN_STAGE)
	run_score = maxi(0, score)
	run_collectibles = maxi(0, collectible_count)
	carried_power_level = clampi(power_level, 0, 2)
	carried_reserve_bloom_count = clampi(reserve_bloom_count, 0, 2)
	save_game()


func get_checkpoint(level_id: String, fallback: Vector2) -> Vector2:
	if checkpoint_level_id == level_id and checkpoint_position != Vector2.ZERO:
		return checkpoint_position
	return fallback


func complete_stage(
	level_id: String,
	next_stage: int,
	score: int,
	collectible_count: int,
	power_level: int,
	reserve_bloom_count: int = 0
) -> void:
	if not completed_stages.has(level_id):
		completed_stages.append(level_id)
	campaign_stage = clampi(next_stage, 0, LAST_CAMPAIGN_STAGE)
	run_score = maxi(0, score)
	run_collectibles = maxi(0, collectible_count)
	carried_power_level = clampi(power_level, 0, 2)
	carried_reserve_bloom_count = clampi(reserve_bloom_count, 0, 2)
	checkpoint_level_id = ""
	checkpoint_position = Vector2.ZERO
	save_game()


func clear_checkpoint(should_save: bool = true) -> void:
	checkpoint_level_id = ""
	checkpoint_position = Vector2.ZERO
	if should_save:
		save_game()


func reset_campaign_progress() -> void:
	campaign_stage = 0
	run_score = 0
	run_collectibles = 0
	carried_power_level = 0
	carried_reserve_bloom_count = 0
	checkpoint_level_id = ""
	checkpoint_position = Vector2.ZERO
	completed_stages.clear()
	save_game()


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


func _reset_progress_defaults() -> void:
	high_score = 0
	unlocked_levels = ["forest"]
	keyboard_bindings = {}
	campaign_stage = 0
	run_score = 0
	run_collectibles = 0
	carried_power_level = 0
	carried_reserve_bloom_count = 0
	checkpoint_level_id = ""
	checkpoint_position = Vector2.ZERO
	completed_stages = []


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
