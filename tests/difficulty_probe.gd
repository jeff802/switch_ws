extends SceneTree

const CAMPAIGN_SCENE_PATH := "res://levels/campaign_level.tscn"
const BLOCK_SCRIPT := "res://world/block.gd"
const COIN_SCRIPT := "res://world/collectible.gd"
const SPAWNER_SCRIPT := "res://enemies/enemy_spawner.gd"
const MUSHROOM_CONTENT := 2
const DUCK_KIND := 3

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	var settings := root.get_node("SettingsManager")
	manager.persistence_enabled = false
	settings.session_start_configured = true
	var campaign_scene := load(CAMPAIGN_SCENE_PATH) as PackedScene
	var samples: Dictionary = {}

	for difficulty_id: String in ["easy", "normal", "hard"]:
		settings.set_difficulty(difficulty_id)
		manager.set_campaign_stage(18)
		manager.set_carried_power_level(0)
		manager.set_carried_reserve_bloom_count(0)
		var level = campaign_scene.instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		var blocks := _children_with_script(level.entity_root, BLOCK_SCRIPT)
		var coins := _children_with_script(level.entity_root, COIN_SCRIPT)
		var spawners := _children_with_script(level.entity_root, SPAWNER_SCRIPT)
		var duck_health := 0
		for spawner: Node in spawners:
			if int(spawner.enemy_kind) == DUCK_KIND and spawner.current_enemy != null:
				duck_health = int(spawner.current_enemy.health)
				break
		samples[difficulty_id] = {
			"power_blocks": _power_block_count(blocks),
			"coins": coins.size(),
			"spawners": spawners.size(),
			"duck_health": duck_health,
		}
		level.queue_free()
		await process_frame
		current_scene = null

	_check(int(samples.easy.power_blocks) > int(samples.normal.power_blocks), "简单难度每关增加明显补给")
	_check(int(samples.easy.spawners) < int(samples.normal.spawners), "简单难度减少部分敌人编组")
	_check(int(samples.hard.spawners) > int(samples.normal.spawners), "困难难度增加敌人编组")
	_check(int(samples.hard.coins) < int(samples.normal.coins), "困难难度减少沿途金币补给")
	_check(int(samples.hard.duck_health) > int(samples.normal.duck_health), "困难难度提高普通怪物生命")

	var boss_health: Dictionary = {}
	var boss_tiers: Dictionary = {}
	var volley_counts: Dictionary = {}
	for difficulty_id: String in ["easy", "normal", "hard"]:
		settings.set_difficulty(difficulty_id)
		manager.set_campaign_stage(19)
		var level = campaign_scene.instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		level.boss.set_physics_process(false)
		boss_health[difficulty_id] = level.boss.max_health
		boss_tiers[difficulty_id] = level.boss.difficulty_skill_tier
		var bolts_before := get_nodes_in_group("boss_projectiles").size()
		level.boss._fire_volley()
		volley_counts[difficulty_id] = get_nodes_in_group("boss_projectiles").size() - bolts_before
		level.queue_free()
		await process_frame
		for bolt: Node in get_nodes_in_group("boss_projectiles"):
			bolt.queue_free()
		await process_frame
		current_scene = null

	_check(int(boss_health.easy) < int(boss_health.normal), "简单难度降低首领生命")
	_check(int(boss_health.hard) > int(boss_health.normal), "困难难度提高首领生命")
	_check(int(boss_tiers.easy) == 0 and int(boss_tiers.normal) == 1 and int(boss_tiers.hard) == 2, "三档难度使用独立首领技能层级")
	_check(int(volley_counts.hard) > int(volley_counts.normal), "困难最终首领追加弹幕数量")

	settings.set_difficulty("normal")
	manager.set_campaign_stage(0)
	manager.run_active = false
	manager.persistence_enabled = true
	if failures.is_empty():
		print("DIFFICULTY PROBE: %d checks passed" % checks)
		quit(0)
		return
	for failure: String in failures:
		push_error("DIFFICULTY PROBE: " + failure)
	quit(1)


func _children_with_script(parent: Node, script_path: String) -> Array[Node]:
	var matches: Array[Node] = []
	for child: Node in parent.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == script_path:
			matches.append(child)
	return matches


func _power_block_count(blocks: Array[Node]) -> int:
	var count := 0
	for block: Node in blocks:
		if int(block.content) == MUSHROOM_CONTENT:
			count += 1
	return count


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
