extends Node
## Settings persistence: sound toggle, volume and selected character.

const SETTINGS_PATH := "user://settings.json"

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "gear",
		"name": "GEAR",
		"tint": Color(1.0, 1.0, 1.0, 1.0),
		"dust": Color(0.62, 0.72, 0.6, 0.85),
		"speed": 1.0,
		"jump": 1.0,
		"desc": "Balanced all-rounder",
	},
	{
		"id": "blaze",
		"name": "BLAZE",
		"tint": Color(1.0, 0.62, 0.45, 1.0),
		"dust": Color(0.95, 0.6, 0.35, 0.85),
		"speed": 1.12,
		"jump": 0.95,
		"desc": "Fast runner, shorter hops",
	},
	{
		"id": "frost",
		"name": "FROST",
		"tint": Color(0.5, 0.8, 1.0, 1.0),
		"dust": Color(0.6, 0.85, 1.0, 0.85),
		"speed": 0.92,
		"jump": 1.12,
		"desc": "Higher jumps, slower run",
	},
]

signal changed

var sfx_enabled: bool = true
var sfx_volume: float = 0.8
var character_id: String = "gear"


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		save_settings()
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	sfx_enabled = bool(parsed.get("sfx_enabled", true))
	sfx_volume = clampf(float(parsed.get("sfx_volume", 0.8)), 0.0, 1.0)
	var saved_character := str(parsed.get("character_id", "gear"))
	character_id = saved_character if _character_exists(saved_character) else "gear"


func save_settings() -> void:
	var data := {
		"sfx_enabled": sfx_enabled,
		"sfx_volume": sfx_volume,
		"character_id": character_id,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))


func set_sfx_enabled(value: bool) -> void:
	if sfx_enabled == value:
		return
	sfx_enabled = value
	save_settings()
	changed.emit()


func set_sfx_volume(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(sfx_volume, value):
		return
	sfx_volume = value
	save_settings()
	changed.emit()


func set_character(character: String) -> void:
	if not _character_exists(character) or character_id == character:
		return
	character_id = character
	save_settings()
	changed.emit()


func cycle_character() -> void:
	var index := 0
	for i: int in CHARACTERS.size():
		if CHARACTERS[i]["id"] == character_id:
			index = i
			break
	set_character(CHARACTERS[(index + 1) % CHARACTERS.size()]["id"])


func get_character(character: String = "") -> Dictionary:
	var target := character if not character.is_empty() else character_id
	for entry: Dictionary in CHARACTERS:
		if entry["id"] == target:
			return entry
	return CHARACTERS[0]


func _character_exists(character: String) -> bool:
	for entry: Dictionary in CHARACTERS:
		if entry["id"] == character:
			return true
	return false
