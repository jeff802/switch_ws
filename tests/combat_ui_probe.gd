extends SceneTree

const CAMPAIGN_SCENE_PATH := "res://levels/campaign_level.tscn"
const ENERGY_BLOOM_SCENE_PATH := "res://world/energy_bloom.tscn"
const CACTUS_SCENE_PATH := "res://world/clockwork_cactus.tscn"
const BLOCK_SCRIPT_PATH := "res://world/block.gd"
const BLOCK_SCENE_PATH := "res://world/block.tscn"
const SPAWNER_SCRIPT := "res://enemies/enemy_spawner.gd"
const BOUNCECAP_KIND := 1
const DUCK_KIND := 3
const TURTLE_KIND := 4

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	manager.persistence_enabled = false
	root.get_node("SettingsManager").set_difficulty("normal")
	manager.set_campaign_stage(1)
	manager.set_carried_power_level(0)
	manager.set_carried_reserve_bloom_count(0)
	var level = (load(CAMPAIGN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	await physics_frame

	var mushroom_spawner = _find_spawner(level.entity_root, BOUNCECAP_KIND)
	var duck_spawner = _find_spawner(level.entity_root, DUCK_KIND)
	var turtle_spawner = _find_spawner(level.entity_root, TURTLE_KIND)
	_check_player_form_geometry(level.player)
	_check(mushroom_spawner != null, "关卡含弹跳蘑菇")
	_check(duck_spawner != null, "关卡含发条鸭")
	_check(turtle_spawner != null, "关卡含铜甲龟")
	if mushroom_spawner != null:
		_check_automatic_stomp(level.player, mushroom_spawner.current_enemy)
	if turtle_spawner != null:
		_check_turtle_cycle(level.player, turtle_spawner.current_enemy)
	if duck_spawner != null:
		_check_side_contact(level.player, duck_spawner.current_enemy)

	_check_virtual_controls(level.hud)
	_check_touch_visibility_modes(level.hud)
	_check_level_selector(level.hud)
	await _check_hidden_and_multi_hit_blocks(level)
	await _check_stone_breaking(level)
	await _check_reserve_bloom(level)
	_check_projectile_cactus(level)
	_check_projectile_visibility(level.player)
	_check(level.hud.score_label.text.begins_with("分数"), "HUD 分数已汉化")
	_check(level.hud.collectible_label.text.begins_with("金币"), "HUD 金币已汉化")
	_check(level.hud.timer_label.text.begins_with("时间"), "HUD 时间已汉化")
	var settings := root.get_node("SettingsManager")
	_check(
		str(settings.get_character("gear")["desc"]).contains("均衡")
				and str(settings.get_character("blaze")["desc"]).contains("奔跑")
				and str(settings.get_character("frost")["desc"]).contains("跳得"),
		"角色说明已汉化"
	)

	var selected_level = await _check_level_selection_transition(level)
	if selected_level != null:
		selected_level.queue_free()
	elif is_instance_valid(level):
		level.queue_free()
	await process_frame
	current_scene = null
	manager.set_campaign_stage(0)
	manager.run_active = false
	manager.persistence_enabled = true
	if failures.is_empty():
		print("COMBAT/UI PROBE: %d checks passed" % checks)
		quit(0)
		return
	for failure: String in failures:
		push_error("COMBAT/UI PROBE: " + failure)
	quit(1)


func _check_automatic_stomp(player: Node, enemy: Node) -> void:
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	var health_before := int(player.health)
	player.global_position = enemy.global_position + Vector2(0, -22)
	player.position_before_move = player.global_position + Vector2(0, -8)
	player.vertical_speed_before_move = 145.0
	player.velocity = Vector2(0, 145)
	player.is_stomping = false
	player.handle_enemy_contact(enemy, Vector2.UP)
	_check(enemy.active == false, "普通跳跃落下可直接踩死蘑菇")
	_check(int(player.health) == health_before, "成功踩踏不会受伤")
	_check(player.velocity.y < 0.0, "踩踏后自动反弹")


func _check_side_contact(player: Node, enemy: Node) -> void:
	enemy.set_physics_process(false)
	player.invulnerability_timer = 0.0
	player.stomp_grace_timer = 0.0
	player.global_position = enemy.global_position + Vector2(-12, 0)
	player.position_before_move = player.global_position
	player.vertical_speed_before_move = 0.0
	player.velocity = Vector2.ZERO
	var health_before := int(player.health)
	player.handle_enemy_contact(enemy, Vector2.LEFT)
	_check(int(player.health) == health_before - 1, "侧面接触仍会造成伤害")
	player.set_physics_process(true)


func _check_turtle_cycle(player: Node, turtle: Node) -> void:
	player.set_physics_process(false)
	turtle.set_physics_process(false)
	var health_before := int(player.health)
	player.stomp_grace_timer = 0.0
	player.global_position = turtle.global_position + Vector2(0, -22)
	player.position_before_move = player.global_position + Vector2(0, -8)
	player.vertical_speed_before_move = 145.0
	player.velocity = Vector2(0, 145)
	player.is_stomping = false
	player.handle_enemy_contact(turtle, Vector2.UP)
	_check(turtle.active and turtle.is_waiting_shell(), "铜甲龟第一次被踩后缩壳")
	_check(int(player.health) == health_before, "踩龟缩壳时玩家不受伤")

	player.stomp_grace_timer = 0.0
	player.global_position = turtle.global_position + Vector2(-14, 0)
	player.position_before_move = player.global_position
	player.vertical_speed_before_move = 0.0
	player.velocity = Vector2.ZERO
	player.handle_enemy_contact(turtle, Vector2.LEFT)
	_check(turtle.is_sliding_shell(), "第二次接触会踢出滑行龟壳")
	_check(absf(turtle.velocity.x) >= 220.0, "滑行龟壳具有明显撞击速度")
	_check(int(player.health) == health_before, "踢龟壳时玩家不受伤")

	turtle.take_damage(1, true)
	_check(turtle.is_waiting_shell(), "从上方踩中滑壳可令其停下")
	player.global_position = turtle.global_position + Vector2(-160, -80)
	turtle.shell_timer = 0.01
	turtle._update_shellback(0.02)
	_check(not turtle.is_waiting_shell() and not turtle.is_sliding_shell(), "龟壳超时后重新伸头走动")


func _check_virtual_controls(hud: Node) -> void:
	var left = hud.get_node("MobileControls/Left")
	var right = hud.get_node("MobileControls/Right")
	var jump = hud.get_node("MobileControls/Jump")
	_check(float(left.radius) >= 34.0 and float(right.radius) >= 34.0, "左右触控键已放大")
	_check(float(jump.radius) >= 36.0, "跳跃触控键已放大")
	_check(str(left.caption).is_empty() and str(right.caption).is_empty(), "左右箭头使用图形绘制")
	_check((left.shape as CircleShape2D).radius >= 39.0, "左右键点击热区同步放大")


func _check_touch_visibility_modes(hud: Node) -> void:
	var settings := root.get_node("SettingsManager")
	var original_mode: String = settings.touch_controls_mode
	hud.force_virtual_controls = false
	settings.touch_controls_mode = "hide"
	hud._refresh_virtual_controls_visibility()
	_check(not hud.mobile_controls.visible and hud.controls_hint.visible, "电脑隐藏模式不显示触控按钮")
	settings.touch_controls_mode = "show"
	hud._refresh_virtual_controls_visibility()
	_check(hud.mobile_controls.visible and not hud.controls_hint.visible, "设置可强制显示触控按钮")
	settings.touch_controls_mode = "auto"
	hud._refresh_virtual_controls_visibility()
	if not OS.has_feature("mobile"):
		_check(not hud.mobile_controls.visible, "自动模式在电脑端隐藏触控按钮")
	settings.touch_controls_mode = original_mode
	hud._refresh_virtual_controls_visibility()


func _check_level_selector(hud: Node) -> void:
	var pause_menu = hud.get_node("PauseMenu")
	_check(hud.menu_button != null and hud.menu_button.text == "选关 / 设置", "电脑端可直接看到设置与选关入口")
	_check(pause_menu.stage_option.item_count == 20, "选关菜单列出全部二十关")
	pause_menu.stage_option.select(19)
	_check(pause_menu.stage_option.get_selected_id() == 19, "选关菜单可以定位最终关")
	_check(pause_menu.select_level_button.text == "进入关卡", "选关入口已汉化")
	_check(pause_menu.difficulty_button.text.begins_with("难度："), "设置界面可切换难度")
	var start_setup = hud.get_node("StartSetup")
	_check(start_setup.character_option.item_count == 3, "开局界面提供三个角色")
	_check(start_setup.difficulty_option.item_count == 3, "开局界面提供简单、普通、困难")


func _check_hidden_and_multi_hit_blocks(level: Node) -> void:
	var player = level.player
	player.set_physics_process(false)
	var power_block = (load(BLOCK_SCENE_PATH) as PackedScene).instantiate()
	power_block.block_type = 0
	power_block.content = 2
	power_block.global_position = Vector2(-80, 90)
	level.entity_root.add_child(power_block)
	var visible_power_block = _find_block_with_content(level, 2, 1)
	var multi_coin_block = _find_block_with_content(level, 3, 1)
	_check(power_block != null and int(power_block.block_type) == 0, "蘑菇与能量花隐藏在普通土砖外观中")
	_check(visible_power_block != null, "同一关多数强化奖励仍使用明显强化砖外观")
	_check(multi_coin_block != null and int(multi_coin_block.block_type) == 1, "多数多金币砖使用明显的连续金币砖外观")
	if power_block != null:
		player.restore_power_level(0)
		var powerups_before := get_nodes_in_group("powerups").size()
		power_block.bump_by_player(player)
		await create_timer(0.2).timeout
		_check(power_block.used, "隐藏强化砖顶一次后进入用尽状态")
		_check(get_nodes_in_group("powerups").size() == powerups_before + 1, "隐藏强化砖正常出现蘑菇")
		power_block.bump_by_player(player)
		await create_timer(0.2).timeout
		_check(get_nodes_in_group("powerups").size() == powerups_before + 1, "隐藏强化砖不能重复刷出道具")
	if multi_coin_block != null:
		var coins_before: int = root.get_node("GameManager").collectibles
		for _hit: int in multi_coin_block.multi_coin_hits:
			multi_coin_block.bump_by_player(player)
			await create_timer(0.18).timeout
		_check(root.get_node("GameManager").collectibles == coins_before + multi_coin_block.multi_coin_hits, "多金币砖可按限定次数连续顶出金币")
		_check(multi_coin_block.used, "多金币砖次数耗尽后变成空砖")
		multi_coin_block.bump_by_player(player)
		await create_timer(0.18).timeout
		_check(root.get_node("GameManager").collectibles == coins_before + multi_coin_block.multi_coin_hits, "多金币砖耗尽后不再重复出币")
	player.restore_power_level(0)
	player.set_physics_process(true)


func _check_player_form_geometry(player: Node) -> void:
	player.set_physics_process(false)
	player._set_state(0)
	player.restore_power_level(0)
	var small_shape := player.collision_shape.shape as CapsuleShape2D
	var small_bottom: float = player.collision_shape.position.y + small_shape.height * 0.5
	_check(small_shape.radius * 2.0 < 16.0, "小角色碰撞宽度小于单块砖的 16 像素")
	_check(is_equal_approx(small_shape.height, 25.0), "小角色高度与有效像素轮廓匹配")
	player.grow()
	player._update_sprite_visual()
	var big_shape := player.collision_shape.shape as CapsuleShape2D
	var big_bottom: float = player.collision_shape.position.y + big_shape.height * 0.5
	_check(big_shape.radius * 2.0 <= 20.0 and big_shape.height <= 35.0, "大角色碰撞盒不再过宽过高")
	_check(is_equal_approx(small_bottom, big_bottom), "大小形态切换保持脚底基线不变")
	_check(player.growth_animation_timer > 0.0, "角色长大时启动独立变身动画")
	_check(player.sprite.scale.x < player.BIG_SCALE, "长大动画从小体形平滑展开")
	player.growth_animation_timer = 0.0
	player._update_sprite_visual()
	_check(player.sprite.position.y < -1.0, "大角色画面向上展开而不是陷入地面")
	_check(is_equal_approx(player.sprite.scale.x, player.BIG_SCALE), "长大动画最终准确落在大体形比例")
	player.restore_power_level(0)
	player.set_physics_process(true)


func _check_stone_breaking(level: Node) -> void:
	var stone_cell := Vector2i(40, 7)
	var physics_stone_cell := Vector2i(41, 7)
	var unbreakable_cell := Vector2i(96, 9)
	var player = level.player
	var stone_bottom: Vector2 = level.tile_map.to_global(level.tile_map.map_to_local(stone_cell)) + Vector2(0, 7)
	_check(level.breakable_stone_cells.has(stone_cell), "石砖平台注册为可碎石块")
	_check(is_instance_valid(level.breakable_stone_cells[stone_cell]), "可碎石砖具有醒目的裂纹外观标记")
	_check(not level.breakable_stone_cells.has(unbreakable_cell), "完整石砖独立注册为不可碎承重块")
	player.restore_power_level(1)
	_check(not level.break_stone_at_world_point(stone_bottom, player), "普通强化状态不能顶碎石块")
	_check(level.tile_map.get_cell_source_id(0, stone_cell) >= 0, "能力不足时石块保持完整")
	player.restore_power_level(2)
	var score_before: int = root.get_node("GameManager").score
	_check(level.break_stone_at_world_point(stone_bottom, player), "强化状态吃能量花后可顶碎石块")
	_check(level.tile_map.get_cell_source_id(0, stone_cell) < 0, "碎石能力会移除命中的石块")
	_check(root.get_node("GameManager").score == score_before + 75, "顶碎石块获得分数")
	_check(level.hud.power_title.text == "状态：能量·碎石", "HUD 显示碎石能力状态")
	var unbreakable_bottom: Vector2 = level.tile_map.to_global(level.tile_map.map_to_local(unbreakable_cell)) + Vector2(0, 7)
	_check(not level.break_stone_at_world_point(unbreakable_bottom, player), "碎石形态也不能顶开无裂纹承重石砖")
	_check(level.tile_map.get_cell_source_id(0, unbreakable_cell) >= 0, "不可碎石砖碰撞与外观保持完整")

	# 再通过真实 CharacterBody2D 顶撞流程验证碰撞点能正确映射到 TileMap 格子。
	var physics_stone_center: Vector2 = level.tile_map.to_global(level.tile_map.map_to_local(physics_stone_cell))
	player._set_state(0)
	player.controls_locked = false
	player.global_position = physics_stone_center + Vector2(0, 32)
	player.velocity = Vector2(0, -260)
	player.coyote_timer = 0.0
	player.set_physics_process(true)
	for _frame: int in 8:
		await physics_frame
	_check(level.tile_map.get_cell_source_id(0, physics_stone_cell) < 0, "真实向上跳跃可顶碎石块")
	player.restore_power_level(0)


func _check_reserve_bloom(level: Node) -> void:
	var player = level.player
	player.set_physics_process(false)
	player.restore_power_level(2)
	player.restore_reserve_bloom(0)
	root.get_node("GameManager").set_carried_reserve_bloom_count(0)
	var score_before: int = root.get_node("GameManager").score

	var reserve_bloom = (load(ENERGY_BLOOM_SCENE_PATH) as PackedScene).instantiate()
	level.add_child(reserve_bloom)
	reserve_bloom._on_body_entered(player)
	_check(player.reserve_bloom_count == 1, "满能量状态再吃能力花会存入第一格备用栏")
	_check(root.get_node("GameManager").carried_reserve_bloom_count == 1, "第一朵备用能力花同步到关卡进度")
	_check(level.hud.reserve_bloom_button.text == "备用花：1 / 2", "HUD 清楚显示第一格备用能力花")
	_check(root.get_node("GameManager").score == score_before + 1000, "存入备用栏的能力花保留基础拾取分数")

	var second_bloom = (load(ENERGY_BLOOM_SCENE_PATH) as PackedScene).instantiate()
	level.add_child(second_bloom)
	second_bloom._on_body_entered(player)
	_check(player.reserve_bloom_count == 2, "第二朵能力花存入第二格备用栏")
	_check(level.hud.reserve_bloom_button.text == "备用花：2 / 2", "HUD 显示双格备用栏已满")
	_check(root.get_node("GameManager").score == score_before + 2000, "两朵存储能力花分别保留基础拾取分数")

	var overflow_bloom = (load(ENERGY_BLOOM_SCENE_PATH) as PackedScene).instantiate()
	level.add_child(overflow_bloom)
	overflow_bloom._on_body_entered(player)
	_check(player.reserve_bloom_count == 2, "双格备用栏满时不会覆盖已有能力花")
	_check(root.get_node("GameManager").score == score_before + 3500, "双格备用栏满后额外能力花转换为 1500 分")

	player.invulnerability_timer = 0.0
	player.take_damage(1, player.global_position + Vector2(-12, 0))
	_check(player.get_power_level() == 1 and player.reserve_bloom_count == 2, "受击后先正常失去能量能力")
	await create_timer(0.5).timeout
	_check(player.get_power_level() == 2 and player.reserve_bloom_count == 1, "受伤后自动消耗一朵并保留另一朵")
	_check(level.hud.reserve_bloom_button.text == "备用花：1 / 2", "HUD 在第一次自动使用后显示剩余一朵")
	player.invulnerability_timer = 0.0
	player.take_damage(1, player.global_position + Vector2(-12, 0))
	await create_timer(0.5).timeout
	_check(player.get_power_level() == 2, "第二朵备用花也可再次自动恢复能量状态")
	_check(player.reserve_bloom_count == 0 and root.get_node("GameManager").carried_reserve_bloom_count == 0, "两次自动使用后清空双格备用栏")
	_check(level.hud.reserve_bloom_button.text == "备用花：0 / 2", "HUD 在两次自动使用后恢复为空")
	player.restore_power_level(0)
	player._set_state(0)
	player.set_physics_process(true)


func _check_level_selection_transition(level: Node) -> Node:
	var pause_menu = level.hud.get_node("PauseMenu")
	level.hud._on_menu_pressed()
	_check(pause_menu.visible and level.get_tree().paused, "点击可见入口后设置选关菜单正常显示")
	pause_menu.stage_option.select(4)
	pause_menu._on_select_level_pressed()
	for _frame: int in 100:
		await process_frame
		if current_scene != level and current_scene != null:
			break
	var selected_level: Node = current_scene
	_check(selected_level != null and selected_level != level, "选关按钮实际切换关卡场景")
	if selected_level != null and selected_level != level:
		_check(int(selected_level.stage_index) == 4, "选关后进入指定的第 05 关")
		_check(int(selected_level.player.get_power_level()) == 0, "选关挑战从无携带能力状态开始")
		_check(root.get_node("GameManager").score == 0, "选关挑战清空旧关分数")
		return selected_level
	return null


func _check_projectile_visibility(player: Node) -> void:
	var pool := root.get_node("ObjectPool")
	var projectile = pool.acquire_projectile(Vector2(220, 120), 1.0, player)
	projectile.set_physics_process(false)
	_check(projectile.visible and projectile.active, "能量弹成功显示")
	_check(projectile.z_index >= 14 and not projectile.z_as_relative, "能量弹位于前景层")
	_check(projectile.modulate == Color.WHITE and projectile.self_modulate == Color.WHITE, "能量弹颜色不被调制变暗")
	pool.release_projectile(projectile)


func _check_projectile_cactus(level: Node) -> void:
	var cactus = (load(CACTUS_SCENE_PATH) as PackedScene).instantiate()
	cactus.mobile = true
	cactus.global_position = Vector2(340, 110)
	level.entity_root.add_child(cactus)
	var projectile = root.get_node("ObjectPool").acquire_projectile(cactus.global_position, 1.0, level.player)
	projectile.set_physics_process(false)
	_check((int(cactus.collision_mask) & 8) != 0, "伸缩仙人掌会检测能量弹碰撞层")
	var cactus_shape := cactus.collision_shape.shape as RectangleShape2D
	_check(cactus_shape.size == Vector2(14, 34), "仙人掌伤害框尺寸与可见尖刺轮廓一致")
	_check(is_equal_approx(cactus.collision_shape.position.y, cactus.plant_y - 13.0), "仙人掌伤害框随伸缩动画精确对齐")
	cactus._on_body_entered(projectile)
	_check(cactus.defeated, "能量弹可以消灭伸缩仙人掌")
	_check(not projectile.active, "命中仙人掌后能量弹正确回收到对象池")
	_check(is_instance_valid(cactus.get_node("Pipe")), "消灭仙人掌后保留可站立管道")


func _find_block_with_content(level: Node, target_content: int, target_type: int = -1) -> Node:
	for child: Node in level.entity_root.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == BLOCK_SCRIPT_PATH \
				and int(child.content) == target_content \
				and (target_type < 0 or int(child.block_type) == target_type):
			return child
	return null


func _find_spawner(parent: Node, kind: int) -> Node:
	for child: Node in parent.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == SPAWNER_SCRIPT and int(child.enemy_kind) == kind:
			return child
	return null


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
