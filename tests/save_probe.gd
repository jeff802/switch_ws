extends SceneTree

const SAVE_SCRIPT_PATH := "res://autoload/save_manager.gd"
const PROBE_PATH := "/private/tmp/forest_gear_save_probe.json"
const LEGACY_PATH := "/private/tmp/forest_gear_legacy_save_probe.json"

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var save_script = load(SAVE_SCRIPT_PATH)
	var writer = save_script.new()
	writer.save_path = PROBE_PATH
	root.add_child(writer)
	writer.high_score = 7654
	writer.completed_stages.assign(["world_1_1", "world_1_2"])
	writer.save_checkpoint("world_2_3", Vector2(512, 144), 6, 3450, 27, 2)
	_check(FileAccess.file_exists(PROBE_PATH), "versioned save file is written")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROBE_PATH))
	_check(raw is Dictionary and int(raw.get("version", 0)) == 2, "save file carries schema version 2")
	writer.queue_free()
	await process_frame

	var reader = save_script.new()
	reader.save_path = PROBE_PATH
	root.add_child(reader)
	_check(reader.high_score == 7654, "high score reloads")
	_check(reader.campaign_stage == 6, "campaign stage reloads")
	_check(reader.run_score == 3450 and reader.run_collectibles == 27, "run score and coins reload")
	_check(reader.carried_power_level == 2, "power state reloads")
	_check(reader.get_checkpoint("world_2_3", Vector2.ZERO) == Vector2(512, 144), "checkpoint reloads")
	_check(reader.completed_stages.size() == 2, "completed stage list reloads")
	reader.queue_free()
	await process_frame

	var legacy_file := FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({
		"high_score": 99,
		"unlocked_levels": ["forest", "cave"],
		"keyboard_bindings": {},
	}))
	legacy_file.close()
	var legacy_reader = save_script.new()
	legacy_reader.save_path = LEGACY_PATH
	root.add_child(legacy_reader)
	_check(legacy_reader.high_score == 99, "legacy high score migrates")
	_check(legacy_reader.campaign_stage == 0, "legacy save receives safe campaign defaults")
	_check(legacy_reader.is_level_unlocked("cave"), "legacy unlocks are preserved")
	legacy_reader.queue_free()
	await process_frame

	_cleanup()
	if failures.is_empty():
		print("SAVE PROBE: %d checks passed" % checks)
		quit(0)
		return
	for failure: String in failures:
		push_error("SAVE PROBE: " + failure)
	quit(1)


func _cleanup() -> void:
	for path: String in [PROBE_PATH, LEGACY_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
