extends SceneTree

const CAMPAIGN_SCENE_PATH := "res://levels/campaign_level.tscn"
const PIPE_SCRIPT_PATH := "res://world/pipe.gd"
const BONUS_DECOR_PATH := "res://world/bonus_dungeon_decor.gd"
const BLOCK_SCRIPT_PATH := "res://world/block.gd"
const ENTER_BONUS := 1
const EXIT_BONUS := 2

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	manager.persistence_enabled = false
	root.get_node("SettingsManager").set_difficulty("normal")
	manager.set_campaign_stage(0)
	manager.set_carried_power_level(0)
	manager.set_carried_reserve_bloom_count(0)
	var level = (load(CAMPAIGN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	await physics_frame

	var pipes := _children_with_script(level.entity_root, PIPE_SCRIPT_PATH)
	var blocks := _children_with_script(level.entity_root, BLOCK_SCRIPT_PATH)
	var entry_pipe = _find_pipe(pipes, ENTER_BONUS)
	var exit_pipe = _find_pipe(pipes, EXIT_BONUS)
	_check(level.bonus_dungeon_built, "第 01 关已构建奖励副本")
	_check(entry_pipe != null and exit_pipe != null, "奖励副本具有入口和返回管道")
	_check(_has_child_script(level.generated_backdrop, BONUS_DECOR_PATH), "副本具有独立动态灯光与微尘背景")
	_check(level.breakable_stone_cells.has(Vector2i(10, 35)), "副本包含可碎石平台")
	_check(level.tile_map.get_cell_source_id(0, Vector2i(0, 20)) >= 0, "副本边界完整封闭")
	_check(_bonus_power_block_count(blocks) >= 2, "副本内可依次取得大形态与能量花")

	_check_gamepad_map()
	var pause_menu = level.hud.get_node("PauseMenu")
	level.hud._on_menu_pressed()
	_check(pause_menu.visible and level.get_tree().paused, "右上角菜单入口会真正暂停并打开设置选关界面")
	_check(level.hud.menu_button.visible and level.hud.menu_button.text == "选关 / 设置", "电脑端具有常驻的设置选关入口")
	_check(pause_menu.get_viewport().gui_get_focus_owner() == pause_menu.resume_button, "手柄打开菜单后焦点落在继续游戏")
	_check(pause_menu.stage_option.focus_neighbor_right == NodePath("../SelectLevelButton"), "选关控件具有明确手柄左右焦点")
	pause_menu.close_menu()
	var player = level.player
	_check(is_zero_approx(float(player._shape_horizontal_input(0.1))), "轻微摇杆漂移会被死区过滤")
	var shaped_half: float = player._shape_horizontal_input(0.55)
	_check(shaped_half > 0.0 and shaped_half < 0.55, "中段摇杆输入使用细腻响应曲线")
	_check(is_equal_approx(float(player._shape_horizontal_input(1.0)), 1.0), "摇杆推到底保持满速")

	if entry_pipe != null and exit_pipe != null:
		player.global_position = entry_pipe.global_position + Vector2(0, -entry_pipe.pipe_height - 16)
		entry_pipe.nearby_player = player
		entry_pipe.down_was_pressed = false
		Input.action_press("move_down")
		await physics_frame
		Input.action_release("move_down")
		for _frame: int in 80:
			await process_frame
			if level.inside_bonus_dungeon and not level.pipe_travel_busy:
				break
		_check(level.inside_bonus_dungeon, "键盘或手柄下方向可进入奖励副本")
		_check(player.global_position.y > 500.0, "玩家传送到副本出生区")
		_check(player.camera.limit_top == 320 and player.camera.limit_bottom == 680, "副本镜头锁定独立房间")
		_check(not player.controls_locked and player.is_physics_processing(), "进管动画后恢复角色控制")
		player.restore_power_level(2)
		player.attack_cooldown.stop()
		var shots_before: int = root.get_node("ObjectPool").active_projectile_count(player)
		player._try_attack()
		player.sprite.frame = 2
		player._on_sprite_frame_changed()
		await process_frame
		_check(root.get_node("ObjectPool").active_projectile_count(player) > shots_before, "能量状态可在奖励副本正常发射子弹")
		root.get_node("ObjectPool").reset_all()
		player.restore_power_level(0)
		for _frame: int in 70:
			await physics_frame
		_check(player.state != 6 and player.global_position.y < 700.0, "副本纵向坐标不会触发主关坠落判定")
		await level.travel_through_pipe(exit_pipe, player, EXIT_BONUS)
		_check(not level.inside_bonus_dungeon, "返回管道可离开奖励副本")
		_check(player.global_position.y < 220.0, "玩家返回原入口上方")
		_check(player.camera.limit_right == level.level_width_tiles * level.TILE_SIZE, "返回后恢复主关镜头边界")

	var fixed_camera_position: Vector2 = player.camera.position
	player.velocity.x = player.run_speed
	player.facing = -1.0
	for _frame: int in 3:
		await process_frame
	_check(player.camera.position == fixed_camera_position, "镜头前瞻不会随角色移动速度或朝向来回摆动")
	_check(is_equal_approx(player.camera.position.x, level.camera_look_ahead), "主关恢复原先的固定前瞻距离")
	_check(player.camera.offset == Vector2.ZERO, "镜头不再因受击或重动作抖动")
	_check(is_equal_approx(player.camera.position_smoothing_speed, 7.0), "镜头恢复原先的平滑跟随参数")
	player.velocity.x = 0.0

	var audio = root.get_node("AudioManager")
	_check(audio._streams.has("pipe") and audio._streams.has("secret"), "管道与发现副本具有独立音效")

	level.queue_free()
	await process_frame
	current_scene = null
	manager.run_active = false
	manager.set_campaign_stage(0)
	manager.persistence_enabled = true
	Input.action_release("move_down")
	if failures.is_empty():
		print("PIPE/DUNGEON/GAMEPAD PROBE: %d checks passed" % checks)
		quit(0)
		return
	for failure: String in failures:
		push_error("PIPE/DUNGEON/GAMEPAD PROBE: " + failure)
	quit(1)


func _check_gamepad_map() -> void:
	_check(InputMap.has_action("move_down"), "输入映射包含管道下方向")
	_check(_has_joy_axis("move_left", 0, -1.0) and _has_joy_axis("move_right", 0, 1.0), "左摇杆支持横向移动")
	_check(_has_joy_axis("move_down", 1, 1.0), "左摇杆下方向支持进入管道")
	_check(_has_joy_button("move_down", 12), "十字键下支持进入管道")
	_check(_has_joy_button("jump", 0), "手柄 A / 叉映射跳跃")
	_check(_has_joy_button("pause", 6), "手柄菜单键映射暂停设置")


func _has_joy_axis(action: StringName, axis: int, axis_value: float) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, axis_value):
			return true
	return false


func _has_joy_button(action: StringName, button_index: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button_index:
			return true
	return false


func _children_with_script(parent: Node, script_path: String) -> Array[Node]:
	var matches: Array[Node] = []
	for child: Node in parent.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == script_path:
			matches.append(child)
	return matches


func _find_pipe(pipes: Array[Node], travel_mode: int) -> Node:
	for pipe: Node in pipes:
		if int(pipe.travel_mode) == travel_mode:
			return pipe
	return null


func _has_child_script(parent: Node, script_path: String) -> bool:
	for child: Node in parent.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == script_path:
			return true
	return false


func _bonus_power_block_count(blocks: Array[Node]) -> int:
	var count := 0
	for block: Node2D in blocks:
		if block.position.y > 320.0 and int(block.get("content")) == 2:
			count += 1
	return count


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
