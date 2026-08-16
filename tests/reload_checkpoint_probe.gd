extends SceneTree

const PROBE_PATH := "/private/tmp/forest_gear_reload_probe.json"
const CAMPAIGN_SCENE_PATH := "res://levels/campaign_level.tscn"
const SAVED_CHECKPOINT := Vector2(112, 168)

var failures: Array[String] = []
var checks: int = 0
var reload_events: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(PROBE_PATH):
		DirAccess.remove_absolute(PROBE_PATH)
	var save = root.get_node("SaveManager")
	var manager = root.get_node("GameManager")
	var events = root.get_node("GameEvents")
	var transition = root.get_node("SceneTransition")
	root.get_node("SettingsManager").set_difficulty("normal")
	root.get_node("SettingsManager").session_start_configured = true
	save.save_path = PROBE_PATH
	save.reset_campaign_progress()
	manager.persistence_enabled = true
	manager.set_campaign_stage(6)
	manager.score = 3450
	manager.collectibles = 27
	manager.carried_power_level = 2
	manager.carried_reserve_bloom_count = 2
	manager.current_level_id = "stage_07"
	# Keep the probe checkpoint in the quiet opening runway. Dense level-layout
	# tests should not accidentally collect a coin or touch a hazard on spawn.
	save.save_checkpoint("stage_07", SAVED_CHECKPOINT, 6, 3450, 27, 2, 2)
	events.level_reloaded.connect(func(_level_id: String) -> void: reload_events += 1)

	var first_level = (load(CAMPAIGN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(first_level)
	current_scene = first_level
	await process_frame
	await physics_frame
	_check(first_level.level_id == "stage_07", "saved campaign stage selects stage 7")
	_check(absf(first_level.player.global_position.x - SAVED_CHECKPOINT.x) < 2.0, "saved checkpoint is used on level start")
	_check(first_level.player.get_power_level() == 2, "saved BOLT power restores on level start")
	_check(first_level.player.reserve_bloom_count == 2, "two saved reserve blooms restore on level start")
	_check(manager.score == 3450 and manager.collectibles == 27, "saved score and coins remain active")
	for _frame: int in 20:
		await physics_frame
	var settled_checkpoint: Vector2 = first_level.player.global_position

	manager.reload_current_level()
	for _frame: int in 180:
		await process_frame
		if not transition.busy and current_scene != first_level:
			break
	var reloaded = current_scene
	for _frame: int in 20:
		await physics_frame
	_check(reloaded != null and reloaded != first_level, "shader transition reloads the scene")
	_check(reload_events == 1, "reload completion is published on the event bus")
	_check(reloaded.level_id == "stage_07", "reload keeps the saved stage")
	_check(reloaded.player.global_position.distance_to(settled_checkpoint) < 2.0, "reload restores checkpoint position")
	_check(reloaded.player.get_power_level() == 2, "reload restores saved power")
	_check(reloaded.player.reserve_bloom_count == 2, "reload restores both reserved energy blooms")
	_check(manager.score == 3450 and manager.collectibles == 27, "reload restores run totals")

	manager.persistence_enabled = false
	manager.run_active = false
	if FileAccess.file_exists(PROBE_PATH):
		DirAccess.remove_absolute(PROBE_PATH)
	if failures.is_empty():
		print("RELOAD/CHECKPOINT PROBE: %d checks passed" % checks)
		quit(0)
		return
	for failure: String in failures:
		push_error("RELOAD/CHECKPOINT PROBE: " + failure)
	quit(1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
