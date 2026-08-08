class_name GameHUD
extends CanvasLayer

@export var force_virtual_controls: bool = false

@onready var health_bar: ProgressBar = $TopBar/HealthBar
@onready var stamina_bar: ProgressBar = $TopBar/StaminaBar
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var collectible_label: Label = $TopBar/CollectibleLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var state_label: Label = $TopBar/StateLabel
@onready var boss_panel: Control = $BossPanel
@onready var boss_bar: ProgressBar = $BossPanel/BossBar
@onready var pause_label: Label = $PauseLabel
@onready var mobile_controls: Node2D = $MobileControls

var bound_player: ForestMechanic


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.collectibles_changed.connect(_on_collectibles_changed)
	GameManager.time_changed.connect(_on_time_changed)
	_on_score_changed(GameManager.score)
	_on_collectibles_changed(GameManager.collectibles)
	_on_time_changed(GameManager.time_left)
	mobile_controls.visible = force_virtual_controls or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func _process(_delta: float) -> void:
	pause_label.visible = get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()


func bind_player(player: ForestMechanic) -> void:
	bound_player = player
	player.health_changed.connect(_on_health_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.state_changed.connect(_on_state_changed)
	_on_health_changed(player.health, player.max_health)
	_on_stamina_changed(player.stamina, player.max_stamina)
	_on_state_changed(str(ForestMechanic.State.keys()[player.state]))


func bind_boss(boss: GearheartGuardian) -> void:
	boss_panel.visible = true
	boss.health_changed.connect(_on_boss_health_changed)
	_on_boss_health_changed(boss.health, boss.max_health)


func show_victory() -> void:
	$VictoryLabel.visible = true
	boss_panel.visible = false


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func _on_score_changed(value: int) -> void:
	score_label.text = "SCORE %07d" % value


func _on_collectibles_changed(value: int) -> void:
	collectible_label.text = "SEEDS × %02d" % value


func _on_time_changed(value: float) -> void:
	timer_label.text = "TIME %03d" % int(ceil(value))


func _on_state_changed(value: String) -> void:
	state_label.text = value


func _on_boss_health_changed(current: int, maximum: int) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
