class_name GameHUD
extends CanvasLayer

@export var force_virtual_controls: bool = false

@onready var health_bar: ProgressBar = $TopBar/HealthBar
@onready var stamina_bar: ProgressBar = $TopBar/StaminaBar
@onready var power_title: Label = $TopBar/StaminaTitle
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var collectible_label: Label = $TopBar/CollectibleLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var world_label: Label = $TopBar/WorldLabel
@onready var boss_panel: Control = $BossPanel
@onready var boss_bar: ProgressBar = $BossPanel/BossBar
@onready var boss_name: Label = $BossPanel/BossName
@onready var mobile_controls: Node2D = $MobileControls
@onready var controls_hint: Label = $ControlsHint
@onready var ability_label: Label = $TopBar/AbilityLabel
@onready var reserve_bloom_button: Button = $TopBar/ReserveBloomButton
@onready var save_label: Label = $SaveLabel
@onready var fullscreen_button: Button = $FullscreenButton
@onready var menu_button: Button = $MenuButton
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var context_hint: Label = $ContextHint
@onready var area_banner: Label = $AreaBanner

var bound_player: ForestMechanic
var path_message_tween: Tween
var save_message_tween: Tween
var area_banner_tween: Tween
var bound_boss_name: String = "区域守卫"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.collectibles_changed.connect(_on_collectibles_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.level_started.connect(_on_level_started)
	GameEvents.mobility_changed.connect(_on_mobility_changed)
	GameEvents.collectible_collected.connect(_on_collectible_collected)
	GameEvents.ability_used.connect(_on_ability_used)
	GameEvents.save_completed.connect(_on_save_completed)
	SettingsManager.changed.connect(_refresh_virtual_controls_visibility)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_on_score_changed(GameManager.score)
	_on_collectibles_changed(GameManager.collectibles)
	_on_time_changed(GameManager.time_left)
	_on_level_started(GameManager.current_level_id)
	_refresh_virtual_controls_visibility()
	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	get_tree().root.size_changed.connect(_on_window_size_changed)
	_refresh_fullscreen_button()
	_update_mobile_controls_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload_level") and not SceneTransition.busy:
		get_viewport().set_input_as_handled()
		GameManager.reload_current_level()
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		pause_menu.toggle_menu()


func bind_player(player: ForestMechanic) -> void:
	bound_player = player
	player.health_changed.connect(_on_health_changed)
	player.power_changed.connect(_on_power_changed)
	player.reserve_bloom_changed.connect(_on_reserve_bloom_changed)
	_on_health_changed(player.health, player.max_health)
	_on_power_changed(player.get_power_level(), 2)
	_on_reserve_bloom_changed(player.reserve_bloom_count)
	_on_mobility_changed(player.air_jumps_remaining, player.wall_slide_active)

func bind_boss(boss: GearheartGuardian) -> void:
	bound_boss_name = boss.display_name
	boss_name.text = bound_boss_name
	boss_panel.visible = boss.activated
	boss.health_changed.connect(_on_boss_health_changed)
	boss.engaged.connect(_on_boss_engaged.bind(boss))
	_on_boss_health_changed(boss.health, boss.max_health)


func _on_boss_engaged(boss: GearheartGuardian) -> void:
	bound_boss_name = boss.display_name
	boss_name.text = bound_boss_name
	boss_panel.visible = true


func show_victory() -> void:
	if path_message_tween != null and path_message_tween.is_valid():
		path_message_tween.kill()
	$VictoryLabel.modulate.a = 1.0
	$VictoryLabel.text = "熔炉已恢复！\n本次挑战完成"
	$VictoryLabel.visible = true
	boss_panel.visible = false


func show_path_open() -> void:
	if path_message_tween != null and path_message_tween.is_valid():
		path_message_tween.kill()
	$VictoryLabel.modulate.a = 1.0
	$VictoryLabel.text = "%s已击败！\n前方通道已开启 →" % bound_boss_name
	$VictoryLabel.visible = true
	boss_panel.visible = false
	path_message_tween = create_tween()
	path_message_tween.tween_interval(1.5)
	path_message_tween.tween_property($VictoryLabel, "modulate:a", 0.0, 0.35)
	path_message_tween.tween_callback(func() -> void:
		$VictoryLabel.visible = false
		$VictoryLabel.modulate.a = 1.0
	)


func show_campaign_complete() -> void:
	if path_message_tween != null and path_message_tween.is_valid():
		path_message_tween.kill()
	$VictoryLabel.modulate.a = 1.0
	$VictoryLabel.text = "齿轮王国已恢复！\n全部 20 关通关"
	$VictoryLabel.visible = true
	boss_panel.visible = false
	# 结算后给出明确下一步，避免只锁住角色而看起来像游戏卡死。
	pause_menu.call_deferred("open_completion_menu")


func show_context_hint(message: String) -> void:
	context_hint.text = message
	context_hint.visible = true
	context_hint.modulate.a = 1.0


func hide_context_hint() -> void:
	context_hint.visible = false


func show_area_banner(message: String) -> void:
	if area_banner_tween != null and area_banner_tween.is_valid():
		area_banner_tween.kill()
	area_banner.text = message
	area_banner.visible = true
	area_banner.modulate.a = 0.0
	area_banner.position.y = 69.0
	area_banner_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	area_banner_tween.tween_property(area_banner, "modulate:a", 1.0, 0.16)
	area_banner_tween.parallel().tween_property(area_banner, "position:y", 77.0, 0.22)
	area_banner_tween.tween_interval(1.15)
	area_banner_tween.tween_property(area_banner, "modulate:a", 0.0, 0.3)
	area_banner_tween.tween_callback(func() -> void: area_banner.visible = false)


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_power_changed(current: int, maximum: int) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	var power_names := ["状态：小型", "状态：强化", "状态：能量·碎石"]
	power_title.text = power_names[clampi(current, 0, power_names.size() - 1)]
	_refresh_reserve_bloom_button()


func _on_reserve_bloom_changed(_count: int) -> void:
	_refresh_reserve_bloom_button()


func _refresh_reserve_bloom_button() -> void:
	if bound_player == null or bound_player.reserve_bloom_count <= 0:
		reserve_bloom_button.text = "备用花：0 / 2"
		reserve_bloom_button.disabled = true
		reserve_bloom_button.modulate = Color(0.62, 0.68, 0.7, 0.72)
		reserve_bloom_button.tooltip_text = "能量状态下继续拾取能力花，最多可储存两朵"
		return
	reserve_bloom_button.modulate = Color.WHITE
	reserve_bloom_button.text = "备用花：%d / 2" % bound_player.reserve_bloom_count
	reserve_bloom_button.disabled = true
	reserve_bloom_button.tooltip_text = "受伤失去能量能力后会自动使用"


func _on_ability_used(ability_name: String) -> void:
	match ability_name:
		"reserve_bloom_stored":
			show_area_banner("备用能力花已存入 · 最多储存 2 朵")
		"reserve_bloom_auto_used":
			show_area_banner("备用能力花已自动使用 · 恢复能量·碎石")
		"reserve_bloom_score":
			show_area_banner("备用栏已满 · 能力花转换为 1500 分")


func _on_score_changed(value: int) -> void:
	score_label.text = "分数 %07d" % value


func _on_collectibles_changed(value: int) -> void:
	collectible_label.text = "金币 × %02d" % value


func _on_time_changed(value: float) -> void:
	timer_label.text = "时间 %03d" % int(ceil(value))


func _on_level_started(level_id: String) -> void:
	if level_id.begins_with("stage_"):
		var stage_text := level_id.trim_prefix("stage_")
		world_label.text = "第 %02d 关 / 20" % int(stage_text)
		return
	var world_names := {
		"forest": "森林关",
		"cave": "洞穴关",
		"snow": "雪原关",
		"boss": "首领关",
	}
	world_label.text = world_names.get(level_id, level_id)


func _on_boss_health_changed(current: int, maximum: int) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current


func _on_mobility_changed(_air_jumps_remaining: int, _wall_sliding: bool) -> void:
	# 二段跳和碰墙跳已经取消，HUD 不再显示误导性的空中能力提示。
	ability_label.visible = false


func _on_collectible_collected(_collectible_id: String, _value: int, _heals: bool) -> void:
	collectible_label.modulate = Color("fff1a3")
	var flash := create_tween()
	flash.tween_property(collectible_label, "modulate", Color.WHITE, 0.18)


func _on_save_completed(_save_path: String) -> void:
	if save_message_tween != null and save_message_tween.is_valid():
		save_message_tween.kill()
	save_label.visible = true
	save_label.modulate.a = 1.0
	save_message_tween = create_tween()
	save_message_tween.tween_interval(0.55)
	save_message_tween.tween_property(save_label, "modulate:a", 0.0, 0.35)
	save_message_tween.tween_callback(func() -> void:
		save_label.visible = false
		save_label.modulate.a = 1.0
	)


func _on_fullscreen_pressed() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if _is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	call_deferred("_refresh_fullscreen_button")


func _on_menu_pressed() -> void:
	pause_menu.open_menu()


func _on_window_size_changed() -> void:
	call_deferred("_refresh_fullscreen_button")
	call_deferred("_update_mobile_controls_layout")


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	show_area_banner("手柄已连接 · 左摇杆移动 · A 跳跃" if connected else "手柄已断开")


func _refresh_virtual_controls_visibility() -> void:
	mobile_controls.visible = force_virtual_controls or SettingsManager.should_show_touch_controls()
	controls_hint.visible = not mobile_controls.visible
	# 设置与选关入口在所有平台保持可见，避免强制显示触控键时失去入口。
	menu_button.visible = true
	if mobile_controls.visible:
		call_deferred("_update_mobile_controls_layout")


func _refresh_fullscreen_button() -> void:
	fullscreen_button.text = "退出" if _is_fullscreen() else "全屏"


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _update_mobile_controls_layout() -> void:
	if not mobile_controls.visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	# 与右上角“选关 / 设置”和“全屏”按钮错开。
	$MobileControls/Pause.position = Vector2(viewport_size.x - 192.0, 62.0)
	$MobileControls/Left.position = Vector2(48.0, viewport_size.y - 50.0)
	$MobileControls/Right.position = Vector2(126.0, viewport_size.y - 50.0)
	$MobileControls/Attack.position = Vector2(viewport_size.x - 208.0, viewport_size.y - 49.0)
	$MobileControls/Run.position = Vector2(viewport_size.x - 132.0, viewport_size.y - 48.0)
	$MobileControls/Stomp.position = Vector2(viewport_size.x - 82.0, viewport_size.y - 126.0)
	$MobileControls/Jump.position = Vector2(viewport_size.x - 47.0, viewport_size.y - 49.0)
