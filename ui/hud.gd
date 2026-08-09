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
@onready var mobile_controls: Node2D = $MobileControls
@onready var controls_hint: Label = $ControlsHint

var bound_player: ForestMechanic
var path_message_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.collectibles_changed.connect(_on_collectibles_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.level_started.connect(_on_level_started)
	_on_score_changed(GameManager.score)
	_on_collectibles_changed(GameManager.collectibles)
	_on_time_changed(GameManager.time_left)
	_on_level_started(GameManager.current_level_id)
	mobile_controls.visible = force_virtual_controls or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	controls_hint.visible = not mobile_controls.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()


func bind_player(player: ForestMechanic) -> void:
	bound_player = player
	player.health_changed.connect(_on_health_changed)
	player.power_changed.connect(_on_power_changed)
	_on_health_changed(player.health, player.max_health)
	_on_power_changed(player.get_power_level(), 2)

func bind_boss(boss: GearheartGuardian) -> void:
	boss_panel.visible = true
	boss.health_changed.connect(_on_boss_health_changed)
	_on_boss_health_changed(boss.health, boss.max_health)


func show_victory() -> void:
	if path_message_tween != null and path_message_tween.is_valid():
		path_message_tween.kill()
	$VictoryLabel.modulate.a = 1.0
	$VictoryLabel.text = "FOUNDRY RESTORED!\nRUN COMPLETE"
	$VictoryLabel.visible = true
	boss_panel.visible = false


func show_path_open() -> void:
	if path_message_tween != null and path_message_tween.is_valid():
		path_message_tween.kill()
	$VictoryLabel.modulate.a = 1.0
	$VictoryLabel.text = "GUARDIAN DEFEATED!\nPATH OPEN  →"
	$VictoryLabel.visible = true
	boss_panel.visible = false
	path_message_tween = create_tween()
	path_message_tween.tween_interval(1.5)
	path_message_tween.tween_property($VictoryLabel, "modulate:a", 0.0, 0.35)
	path_message_tween.tween_callback(func() -> void:
		$VictoryLabel.visible = false
		$VictoryLabel.modulate.a = 1.0
	)


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_power_changed(current: int, maximum: int) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	var power_names := ["PWR SMALL", "PWR GEAR", "PWR BOLT"]
	power_title.text = power_names[clampi(current, 0, power_names.size() - 1)]


func _on_score_changed(value: int) -> void:
	score_label.text = "SCORE %07d" % value


func _on_collectibles_changed(value: int) -> void:
	collectible_label.text = "COINS × %02d" % value


func _on_time_changed(value: float) -> void:
	timer_label.text = "TIME %03d" % int(ceil(value))


func _on_level_started(level_id: String) -> void:
	var world_names := {
		"forest": "WORLD 1-1",
		"cave": "WORLD 1-2",
		"snow": "WORLD 1-3",
		"boss": "WORLD 1-4",
	}
	world_label.text = world_names.get(level_id, level_id.to_upper())


func _on_boss_health_changed(current: int, maximum: int) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
