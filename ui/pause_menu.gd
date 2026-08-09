class_name PauseMenu
extends Control

@onready var title_label: Label = $Panel/TitleLabel
@onready var sfx_button: Button = $Panel/SfxButton
@onready var volume_slider: HSlider = $Panel/VolumeSlider
@onready var volume_label: Label = $Panel/VolumeLabel
@onready var character_button: Button = $Panel/CharacterButton
@onready var character_desc: Label = $Panel/CharacterDesc
@onready var resume_button: Button = $Panel/ResumeButton
@onready var restart_button: Button = $Panel/RestartButton

var _initialized := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	sfx_button.pressed.connect(_on_sfx_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	character_button.pressed.connect(_on_character_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	SettingsManager.changed.connect(_refresh)


func _process(_delta: float) -> void:
	if get_tree().paused and not visible:
		_open()
	elif not get_tree().paused and visible:
		visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()


func _open() -> void:
	visible = true
	_refresh()
	resume_button.grab_focus()


func _refresh() -> void:
	sfx_button.text = "音效：%s" % ("开" if SettingsManager.sfx_enabled else "关")
	volume_slider.set_value_no_signal(SettingsManager.sfx_volume * 100.0)
	volume_label.text = "音量：%d%%" % int(round(SettingsManager.sfx_volume * 100.0))
	var character := SettingsManager.get_character()
	character_button.text = "角色：%s" % character["name"]
	character_desc.text = "%s（%s）" % [character["desc"], character["id"].to_upper()]
	character_desc.modulate = character["tint"]


func _on_sfx_pressed() -> void:
	SettingsManager.set_sfx_enabled(not SettingsManager.sfx_enabled)
	AudioManager.play("ui")


func _on_volume_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value / 100.0)
	volume_label.text = "音量：%d%%" % int(round(value))


func _on_character_pressed() -> void:
	SettingsManager.cycle_character()
	AudioManager.play("ui")


func _on_resume_pressed() -> void:
	AudioManager.play("ui")
	get_tree().paused = false
	visible = false


func _on_restart_pressed() -> void:
	AudioManager.play("ui")
	get_tree().paused = false
	visible = false
	GameManager.reload_current_level()
