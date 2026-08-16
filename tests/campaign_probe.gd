extends SceneTree

const CAMPAIGN_SCENE_PATH := "res://levels/campaign_level.tscn"
const FLAGPOLE_SCRIPT := "res://world/flagpole.gd"
const EXIT_SCRIPT := "res://world/level_exit.gd"
const BOSS_SCRIPT := "res://enemies/boss.gd"
const STAGE_COUNT := 20
const STAGE_WIDTHS: Array[int] = [
	128, 138, 144, 140, 146, 160, 142, 150, 158, 128,
	152, 158, 146, 162, 166, 150, 164, 154, 170, 142,
]
const BOSS_STAGES := {2: 0, 5: 1, 9: 2, 12: 3, 15: 4, 17: 5, 19: 6}
const BOSS_BOLT_STYLES := {2: 0, 5: 1, 9: 2, 12: 3, 15: 4, 17: 5, 19: 6}

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	manager.persistence_enabled = false
	root.get_node("SettingsManager").set_difficulty("normal")
	var campaign_scene := load(CAMPAIGN_SCENE_PATH) as PackedScene
	var previous_boss_health := 0
	var boss_names: Dictionary = {}
	for stage_index: int in STAGE_COUNT:
		manager.set_campaign_stage(stage_index)
		manager.set_carried_power_level(0 if stage_index == 0 else 2)
		manager.set_carried_reserve_bloom_count(0)
		var level = campaign_scene.instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		await physics_frame

		var label := "第 %02d 关" % (stage_index + 1)
		_check(level.level_id == "stage_%02d" % (stage_index + 1), label + "编号")
		_check(level.level_width_tiles == STAGE_WIDTHS[stage_index], label + "宽度")
		_check(level.player != null and level.player.is_inside_tree(), label + "玩家")
		_check(level.player.camera.limit_right == level.level_width_tiles * level.TILE_SIZE, label + "镜头边界")
		_check(level.hud.world_label.text == "第 %02d 关 / 20" % (stage_index + 1), label + "中文关卡显示")

		if BOSS_STAGES.has(stage_index):
			_check(_count_script(level.entity_root, BOSS_SCRIPT) == 1, label + "具有独立首领")
			_check(level.entity_root.get_node_or_null("CampaignArenaGate") != null, label + "首领门")
			_check(int(level.boss.boss_variant) == int(BOSS_STAGES[stage_index]), label + "首领类型按进度变化")
			_check(not boss_names.has(level.boss.display_name), label + "首领名称与美术身份不重复")
			boss_names[level.boss.display_name] = true
			_check(level.boss.max_health > previous_boss_health, label + "首领生命值逐级提高")
			previous_boss_health = level.boss.max_health
			_check(level.boss.get_skill_names().size() >= 3, label + "首领具有独立技能组")
			_check(not level.boss.activated and not level.hud.boss_panel.visible, label + "玩家接近前首领保持休眠")
			level.boss.set_physics_process(false)
			level.boss._activate()
			_check(level.hud.boss_panel.visible and level.hud.boss_name.text == level.boss.display_name, label + "接战时显示对应中文首领名")
			var bolts_before := get_nodes_in_group("boss_projectiles").size()
			if stage_index == 2:
				level.boss._spawn_summoned_hazard(0)
				_check(_new_bolts_use_style(bolts_before, 0), label + "岩窟首领生成落石锁定技能")
			elif stage_index == 5:
				level.boss._fire_volley()
				_check(get_nodes_in_group("boss_projectiles").size() == bolts_before + 3, label + "荆棘首领发射三向种子")
				_check(_new_bolts_use_style(bolts_before, 1), label + "荆棘弹幕使用独立种子美术")
			else:
				level.boss._fire_volley()
				_check(get_nodes_in_group("boss_projectiles").size() > bolts_before, label + "首领可以发射独立弹幕")
				_check(_new_bolts_use_style(bolts_before, int(BOSS_BOLT_STYLES[stage_index])), label + "首领弹幕颜色与身份一致")
			var calm_watch: float = level.boss._watch_time()
			level.boss.health = level.boss.max_health / 2
			_check(level.boss._watch_time() < calm_watch, label + "半血后攻击节奏加快")
			if stage_index == STAGE_COUNT - 1:
				_check(_count_script(level.entity_root, EXIT_SCRIPT) == 1, label + "最终出口")
				_check(_count_script(level.entity_root, FLAGPOLE_SCRIPT) == 0, label + "无旗杆")
			else:
				_check(_count_script(level.entity_root, FLAGPOLE_SCRIPT) == 1, label + "击败首领后使用旗杆结算")
				_check(_count_script(level.entity_root, EXIT_SCRIPT) == 0, label + "中段首领不误用最终出口")
		else:
			_check(_count_script(level.entity_root, FLAGPOLE_SCRIPT) == 1, label + "旗杆")
			_check(_count_script(level.entity_root, BOSS_SCRIPT) == 0, label + "普通关不重复放置首领")
			_check(_count_script(level.entity_root, EXIT_SCRIPT) == 0, label + "普通关无最终出口")

		if stage_index == 1:
			_check(level.player.get_power_level() == 2, "能量弹能力可跨关保存")
			var palette := level.player.sprite.material as ShaderMaterial
			_check(palette != null, "玩家调色材质")
			_check(is_equal_approx(float(palette.get_shader_parameter("bolt_mix")), 1.0), "能量形态调色启用")

		level.queue_free()
		await process_frame
		current_scene = null

	_check(boss_names.size() == 7, "二十关包含七名不同首领")
	await _check_final_progression(manager, campaign_scene)
	manager.set_campaign_stage(0)
	manager.set_carried_power_level(0)
	manager.set_carried_reserve_bloom_count(0)
	manager.run_active = false
	manager.persistence_enabled = true
	if failures.is_empty():
		print("CAMPAIGN PROBE: %d checks passed across 20 stages" % checks)
		quit(0)
		return
	for failure: String in failures:
		push_error("CAMPAIGN PROBE: " + failure)
	quit(1)


func _check_final_progression(manager: Node, campaign_scene: PackedScene) -> void:
	manager.set_campaign_stage(STAGE_COUNT - 1)
	manager.set_carried_power_level(2)
	manager.set_carried_reserve_bloom_count(0)
	var level = campaign_scene.instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var gate = level.entity_root.get_node("CampaignArenaGate")
	var final_boss = level.boss
	final_boss.set_physics_process(false)
	final_boss.take_damage(999, false)
	await create_timer(0.5).timeout
	_check(not is_instance_valid(gate), "最终首领被击败后开启通道")
	_check(level.hud.boss_panel.visible == false, "首领生命条关闭")
	level.final_exit._on_body_entered(level.player)
	await process_frame
	_check(manager.campaign_stage == STAGE_COUNT - 1, "最终关进度保持在第二十关")
	var completion_menu = level.hud.get_node("PauseMenu")
	_check(completion_menu.visible and level.get_tree().paused, "最终出口自动打开可操作的通关结算菜单")
	_check(not level.player.controls_locked, "关闭结算菜单后仍可继续浏览最终关")
	_check(completion_menu.title_label.text == "全部 20 关通关！", "结算菜单明确显示全部通关")
	_check(completion_menu.restart_button.text == "从第 01 关重新开始", "结算菜单提供重新开始入口")
	_check(completion_menu.stage_option.item_count == STAGE_COUNT, "结算菜单可直接选择任意关卡")
	_check(level.hud.get_node("VictoryLabel").visible, "显示通关横幅")
	_check(level.hud.get_node("VictoryLabel").text.contains("全部 20 关"), "通关横幅已汉化")
	completion_menu.close_menu()
	_check(not level.get_tree().paused, "继续浏览按钮能够解除暂停")
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


func _new_bolts_use_style(previous_count: int, expected_style: int) -> bool:
	var bolts := get_nodes_in_group("boss_projectiles")
	if bolts.size() <= previous_count:
		return false
	for index: int in range(previous_count, bolts.size()):
		if int(bolts[index].style) != expected_style:
			return false
	return true


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
