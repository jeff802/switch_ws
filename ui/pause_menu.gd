class_name PauseMenu
extends Control

@onready var title_label: Label = $Panel/TitleLabel
@onready var sfx_button: Button = $Panel/SfxButton
@onready var volume_slider: HSlider = $Panel/VolumeSlider
@onready var volume_label: Label = $Panel/VolumeLabel
@onready var character_button: Button = $Panel/CharacterButton
@onready var character_desc: Label = $Panel/CharacterDesc
@onready var difficulty_button: Button = $Panel/DifficultyButton
@onready var difficulty_desc: Label = $Panel/DifficultyDesc
@onready var touch_controls_button: Button = $Panel/TouchControlsButton
@onready var stage_option: OptionButton = $Panel/StageOption
@onready var select_level_button: Button = $Panel/SelectLevelButton
@onready var resume_button: Button = $Panel/ResumeButton
@onready var restart_button: Button = $Panel/RestartButton

const STAGE_NAMES := [
	"草地教学", "断桥试炼", "纵深洞穴", "雪阶攀登", "城市屋顶",
	"管道花园", "水晶升降区", "冰封渡口", "熔炉冲刺", "最终要塞",
	"遗迹树冠", "回声矿井", "风暴铸厂", "冰川折返", "岩浆水道",
	"地核深潜", "藤蔓钟塔", "月霜王庭", "皇家齿轮道", "时序王座",
]

var completion_mode: bool = false
var difficulty_at_open: String = "normal"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	sfx_button.pressed.connect(_on_sfx_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	character_button.pressed.connect(_on_character_pressed)
	difficulty_button.pressed.connect(_on_difficulty_pressed)
	touch_controls_button.pressed.connect(_on_touch_controls_pressed)
	select_level_button.pressed.connect(_on_select_level_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	SettingsManager.changed.connect(_refresh)
	for stage_index: int in STAGE_NAMES.size():
		stage_option.add_item("第 %02d 关 · %s" % [stage_index + 1, STAGE_NAMES[stage_index]], stage_index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# HUD 统一负责 pause 动作；这里只接管 Esc 的关闭语义，避免一次输入
	# 同时被两个节点处理而造成菜单刚打开又关闭。
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()


func open_menu() -> void:
	completion_mode = false
	get_tree().paused = true
	_open()


func open_completion_menu() -> void:
	completion_mode = true
	get_tree().paused = true
	_open()


func close_menu() -> void:
	get_tree().paused = false
	visible = false
	if difficulty_at_open != SettingsManager.difficulty_id and not SceneTransition.busy:
		GameManager.reload_current_level()


func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()


func _open() -> void:
	visible = true
	difficulty_at_open = SettingsManager.difficulty_id
	_refresh()
	_refresh_mode_labels()
	stage_option.select(GameManager.campaign_stage)
	resume_button.grab_focus()


func _refresh_mode_labels() -> void:
	if completion_mode:
		title_label.text = "全部 20 关通关！"
		restart_button.text = "从第 01 关重新开始"
		resume_button.text = "继续浏览第 20 关"
		return
	title_label.text = "暂停、设置与选关"
	restart_button.text = "从检查点重新载入 (R)"
	resume_button.text = "继续游戏 (Esc)"


func _refresh() -> void:
	sfx_button.text = "音效：%s" % ("开" if SettingsManager.sfx_enabled else "关")
	volume_slider.set_value_no_signal(SettingsManager.sfx_volume * 100.0)
	volume_label.text = "音量：%d%%" % int(round(SettingsManager.sfx_volume * 100.0))
	var character := SettingsManager.get_character()
	character_button.text = "角色：%s" % character["name"]
	character_desc.text = character["desc"]
	character_desc.modulate = character["tint"]
	var difficulty := SettingsManager.get_difficulty()
	difficulty_button.text = "难度：%s" % difficulty["name"]
	difficulty_desc.text = "%s%s" % [
		difficulty["desc"],
		" · 继续时重载生效" if difficulty_at_open != SettingsManager.difficulty_id else "",
	]
	var touch_mode_names := {
		"auto": "自动（仅手机/触屏）",
		"show": "总是显示",
		"hide": "总是隐藏",
	}
	touch_controls_button.text = "触控按钮：%s" % touch_mode_names[SettingsManager.touch_controls_mode]


func _on_sfx_pressed() -> void:
	SettingsManager.set_sfx_enabled(not SettingsManager.sfx_enabled)
	AudioManager.play("ui")


func _on_volume_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value / 100.0)
	volume_label.text = "音量：%d%%" % int(round(value))


func _on_character_pressed() -> void:
	SettingsManager.cycle_character()
	AudioManager.play("ui")


func _on_difficulty_pressed() -> void:
	SettingsManager.cycle_difficulty()
	AudioManager.play("ui")


func _on_touch_controls_pressed() -> void:
	SettingsManager.cycle_touch_controls_mode()
	AudioManager.play("ui")


func _on_select_level_pressed() -> void:
	AudioManager.play("ui")
	visible = false
	get_tree().paused = false
	completion_mode = false
	GameManager.select_campaign_stage(stage_option.get_selected_id())


func _on_resume_pressed() -> void:
	AudioManager.play("ui")
	close_menu()


func _on_restart_pressed() -> void:
	AudioManager.play("ui")
	get_tree().paused = false
	visible = false
	if completion_mode:
		completion_mode = false
		GameManager.select_campaign_stage(0)
		return
	GameManager.reload_current_level()
