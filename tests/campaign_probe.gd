extends SceneTree

const CAMPAIGN_SCENE_PATH := "res://levels/campaign_level.tscn"
const FLAGPOLE_SCRIPT := "res://world/flagpole.gd"
const EXIT_SCRIPT := "res://world/level_exit.gd"
const BOSS_SCRIPT := "res://enemies/boss.gd"

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	var campaign_scene = load(CAMPAIGN_SCENE_PATH) as PackedScene
	for stage_index: int in 32:
		manager.set_campaign_stage(stage_index)
		manager.set_carried_power_level(0 if stage_index == 0 else 2)
		var level = campaign_scene.instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		await physics_frame

		var world_number: int = stage_index / 4 + 1
		var stage_number: int = stage_index % 4 + 1
		var label := "%d-%d" % [world_number, stage_number]
		var expected_width: int = 120 + world_number * 5 if stage_number == 4 else 138 + world_number * 6 + stage_number * 4
		_check(level.level_id == "world_%d_%d" % [world_number, stage_number], label + " level id")
		_check(level.level_width_tiles == expected_width, label + " level width")
		_check(level.player != null and level.player.is_inside_tree(), label + " player")
		_check(level.player.camera.limit_right == level.level_width_tiles * level.TILE_SIZE, label + " camera limit")

		if stage_number == 4:
			_check(_count_script(level.entity_root, BOSS_SCRIPT) == 1, label + " boss")
			_check(level.entity_root.get_node_or_null("CampaignArenaGate") != null, label + " boss gate")
			_check(_count_script(level.entity_root, EXIT_SCRIPT) == 1, label + " final exit")
		else:
			_check(_count_script(level.entity_root, FLAGPOLE_SCRIPT) == 1, label + " flagpole")
			_check(_count_script(level.entity_root, BOSS_SCRIPT) == 0, label + " no boss")
			_check(_count_script(level.entity_root, EXIT_SCRIPT) == 0, label + " no early exit")

		if stage_index == 1:
			_check(level.player.get_power_level() == 2, "carried BOLT power")
			var palette := level.player.sprite.material as ShaderMaterial
			_check(palette != null, "player palette material")
			_check(is_equal_approx(float(palette.get_shader_parameter("bolt_mix")), 1.0), "BOLT palette enabled")

		level.queue_free()
		await process_frame
		current_scene = null

	await _check_boss_progression(manager)
	manager.set_campaign_stage(0)
	manager.set_carried_power_level(0)
	manager.run_active = false
	if failures.is_empty():
		print("CAMPAIGN PROBE: %d checks passed across 32 stages" % checks)
		quit(0)
		return
	for failure: String in failures:
		push_error("CAMPAIGN PROBE: " + failure)
	quit(1)


func _check_boss_progression(manager: Node) -> void:
	var campaign_scene = load(CAMPAIGN_SCENE_PATH) as PackedScene
	for stage_index: int in range(3, 32, 4):
		manager.set_campaign_stage(stage_index)
		manager.set_carried_power_level(2)
		var level = campaign_scene.instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		var world_number: int = stage_index / 4 + 1
		var label := "%d-4" % world_number
		var gate = level.entity_root.get_node("CampaignArenaGate")
		var boss = level.boss
		boss.set_physics_process(false)
		boss.take_damage(999, false)
		await create_timer(0.5).timeout
		_check(not is_instance_valid(gate), label + " boss opens gate")
		_check(level.hud.boss_panel.visible == false, label + " boss HUD closes")
		level.final_exit.next_scene = ""
		level.final_exit._on_body_entered(level.player)
		await process_frame
		_check(manager.campaign_stage == mini(stage_index + 1, 31), label + " campaign progression")
		if stage_index == 31:
			_check(level.player.controls_locked, "8-4 locks controls after final exit")
			_check(level.hud.get_node("VictoryLabel").visible, "8-4 completion banner")
			_check(level.hud.get_node("VictoryLabel").text.contains("32 STAGES"), "8-4 completion text")
		level.queue_free()
		await process_frame
		current_scene = null


func _count_script(parent: Node, script_path: String) -> int:
	var count := 0
	for child: Node in parent.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == script_path:
			count += 1
	return count


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
