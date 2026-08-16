class_name StartSetup
extends Control

@onready var character_option: OptionButton = $Panel/CharacterOption
@onready var character_desc: Label = $Panel/CharacterDesc
@onready var difficulty_option: OptionButton = $Panel/DifficultyOption
@onready var difficulty_desc: Label = $Panel/DifficultyDesc
@onready var start_button: Button = $Panel/StartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for index: int in SettingsManager.CHARACTERS.size():
		var character: Dictionary = SettingsManager.CHARACTERS[index]
		character_option.add_item(str(character["name"]), index)
	for index: int in SettingsManager.DIFFICULTIES.size():
		var difficulty: Dictionary = SettingsManager.DIFFICULTIES[index]
		difficulty_option.add_item(str(difficulty["name"]), index)
	character_option.item_selected.connect(_on_character_selected)
	difficulty_option.item_selected.connect(_on_difficulty_selected)
	start_button.pressed.connect(_on_start_pressed)
	_select_saved_values()
	if GameManager.persistence_enabled and not SettingsManager.session_start_configured:
		call_deferred("open")


func open() -> void:
	visible = true
	get_tree().paused = true
	_select_saved_values()
	character_option.grab_focus()


func _select_saved_values() -> void:
	for index: int in SettingsManager.CHARACTERS.size():
		if SettingsManager.CHARACTERS[index]["id"] == SettingsManager.character_id:
			character_option.select(index)
			break
	for index: int in SettingsManager.DIFFICULTIES.size():
		if SettingsManager.DIFFICULTIES[index]["id"] == SettingsManager.difficulty_id:
			difficulty_option.select(index)
			break
	_refresh_descriptions()


func _refresh_descriptions() -> void:
	var character: Dictionary = SettingsManager.CHARACTERS[character_option.selected]
	character_desc.text = str(character["desc"])
	character_desc.modulate = character["tint"]
	var difficulty: Dictionary = SettingsManager.DIFFICULTIES[difficulty_option.selected]
	difficulty_desc.text = str(difficulty["desc"])
	match str(difficulty["id"]):
		"easy": difficulty_desc.modulate = Color("91e8a4")
		"hard": difficulty_desc.modulate = Color("ff9b78")
		_: difficulty_desc.modulate = Color("8fdcf0")


func _on_character_selected(_index: int) -> void:
	_refresh_descriptions()
	AudioManager.play("ui")


func _on_difficulty_selected(_index: int) -> void:
	_refresh_descriptions()
	AudioManager.play("ui")


func _on_start_pressed() -> void:
	var character: Dictionary = SettingsManager.CHARACTERS[character_option.selected]
	var difficulty: Dictionary = SettingsManager.DIFFICULTIES[difficulty_option.selected]
	SettingsManager.set_character(str(character["id"]))
	SettingsManager.set_difficulty(str(difficulty["id"]))
	SettingsManager.session_start_configured = true
	visible = false
	get_tree().paused = false
	AudioManager.play("checkpoint")
	# The preview scene was constructed before a difficulty was selected. Reload
	# the selected stage once so item counts, enemy packs and boss rules all use
	# the chosen mode from their first frame.
	GameManager.select_campaign_stage(GameManager.campaign_stage)
