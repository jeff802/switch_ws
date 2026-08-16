extends Node
## Settings persistence: sound, character, difficulty and virtual controls.

const SETTINGS_PATH := "user://settings.json"

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "gear",
		"name": "齿轮工",
		"tint": Color(1.0, 1.0, 1.0, 1.0),
		"dust": Color(0.62, 0.72, 0.6, 0.85),
		"speed": 1.0,
		"jump": 1.0,
		"desc": "速度与跳跃均衡，适合初次游玩",
	},
	{
		"id": "blaze",
		"name": "烈焰",
		"tint": Color(1.0, 0.62, 0.45, 1.0),
		"dust": Color(0.95, 0.6, 0.35, 0.85),
		"speed": 1.12,
		"jump": 0.95,
		"desc": "奔跑更快，但跳跃稍低",
	},
	{
		"id": "frost",
		"name": "霜跃",
		"tint": Color(0.5, 0.8, 1.0, 1.0),
		"dust": Color(0.6, 0.85, 1.0, 0.85),
		"speed": 0.92,
		"jump": 1.12,
		"desc": "跳得更高，但奔跑稍慢",
	},
]

const DIFFICULTIES: Array[Dictionary] = [
	{
		"id": "easy",
		"name": "简单",
		"desc": "补给更多，普通怪生命较低，首领招式更宽松",
		"enemy_health": 0.72,
		"enemy_speed": 0.88,
		"boss_health": 0.72,
		"boss_speed": 0.86,
		"skill_tier": 0,
	},
	{
		"id": "normal",
		"name": "普通",
		"desc": "按设计节奏体验完整的 20 关与首领技能",
		"enemy_health": 1.0,
		"enemy_speed": 1.0,
		"boss_health": 1.0,
		"boss_speed": 1.0,
		"skill_tier": 1,
	},
	{
		"id": "hard",
		"name": "困难",
		"desc": "补给更隐蔽，怪物更强，首领拥有追加弹幕与增援",
		"enemy_health": 1.45,
		"enemy_speed": 1.15,
		"boss_health": 1.38,
		"boss_speed": 1.14,
		"skill_tier": 2,
	},
]

signal changed

var sfx_enabled: bool = true
var sfx_volume: float = 0.8
var character_id: String = "gear"
var difficulty_id: String = "normal"
var touch_controls_mode: String = "auto"
# Deliberately not persisted: every new browser/game launch opens the start
# setup once, while scene changes inside the same run keep the chosen options.
var session_start_configured: bool = false


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
	var saved_difficulty := str(parsed.get("difficulty_id", "normal"))
	difficulty_id = saved_difficulty if _difficulty_exists(saved_difficulty) else "normal"
	var saved_touch_mode := str(parsed.get("touch_controls_mode", "auto"))
	touch_controls_mode = saved_touch_mode if saved_touch_mode in ["auto", "show", "hide"] else "auto"


func save_settings() -> void:
	var data := {
		"sfx_enabled": sfx_enabled,
		"sfx_volume": sfx_volume,
		"character_id": character_id,
		"difficulty_id": difficulty_id,
		"touch_controls_mode": touch_controls_mode,
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


func set_difficulty(difficulty: String) -> void:
	if not _difficulty_exists(difficulty) or difficulty_id == difficulty:
		return
	difficulty_id = difficulty
	save_settings()
	changed.emit()


func cycle_difficulty() -> void:
	var index := 0
	for i: int in DIFFICULTIES.size():
		if DIFFICULTIES[i]["id"] == difficulty_id:
			index = i
			break
	set_difficulty(DIFFICULTIES[(index + 1) % DIFFICULTIES.size()]["id"])


func set_touch_controls_mode(mode: String) -> void:
	if mode not in ["auto", "show", "hide"] or touch_controls_mode == mode:
		return
	touch_controls_mode = mode
	save_settings()
	changed.emit()


func cycle_touch_controls_mode() -> void:
	var modes := ["auto", "show", "hide"]
	var current_index := modes.find(touch_controls_mode)
	set_touch_controls_mode(modes[(current_index + 1) % modes.size()])


func should_show_touch_controls() -> bool:
	match touch_controls_mode:
		"show":
			return true
		"hide":
			return false
		_:
			# 自动模式仅在移动平台显示。部分桌面浏览器会暴露触屏能力，
			# 仅依赖 is_touchscreen_available() 会让电脑端误显示整套触控按钮。
			return OS.has_feature("mobile")


func get_character(character: String = "") -> Dictionary:
	var target := character if not character.is_empty() else character_id
	for entry: Dictionary in CHARACTERS:
		if entry["id"] == target:
			return entry
	return CHARACTERS[0]


func get_difficulty(difficulty: String = "") -> Dictionary:
	var target := difficulty if not difficulty.is_empty() else difficulty_id
	for entry: Dictionary in DIFFICULTIES:
		if entry["id"] == target:
			return entry
	return DIFFICULTIES[1]


func get_difficulty_skill_tier() -> int:
	return int(get_difficulty()["skill_tier"])


func _character_exists(character: String) -> bool:
	for entry: Dictionary in CHARACTERS:
		if entry["id"] == character:
			return true
	return false


func _difficulty_exists(difficulty: String) -> bool:
	for entry: Dictionary in DIFFICULTIES:
		if entry["id"] == difficulty:
			return true
	return false
