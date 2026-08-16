class_name GearBlock
extends StaticBody2D

enum Type { BRICK, QUESTION }
enum Content { NONE, COIN, MUSHROOM, MULTI_COIN }

const COIN_POP_SCENE := preload("res://world/coin_pop.tscn")
const MUSHROOM_SCENE := preload("res://world/powerup_mushroom.tscn")
const ENERGY_BLOOM_SCENE := preload("res://world/energy_bloom.tscn")

@export var block_type: int = Type.BRICK
@export var content: int = Content.NONE
@export_range(2, 10, 1) var multi_coin_hits: int = 5
@export_range(0, 9, 1) var visual_theme: int = 0

var used: bool = false
var bump_offset: float = 0.0
var bump_locked: bool = false
var remaining_hits: int = 0

func _ready() -> void:
	add_to_group("blocks")
	remaining_hits = multi_coin_hits if content == Content.MULTI_COIN else 1
	queue_redraw()


# Called by the player when its head hits this block from below.
func bump_by_player(body: Node2D) -> void:
	if bump_locked:
		return
	_bump_action(body)


func _bump_action(body: Node2D) -> void:
	if block_type == Type.BRICK:
		if content != Content.NONE:
			_bump_hidden_content(body)
			return
		if body.get("is_big") == true:
			_break()
		else:
			_animate_bump()
		return
	# Question block.
	if used:
		_animate_bump()
		return
	_animate_bump()
	AudioManager.play("bump")
	match content:
		Content.COIN:
			_spawn_coin()
			used = true
		Content.MUSHROOM:
			_spawn_powerup(body)
			used = true
		Content.MULTI_COIN:
			_spawn_coin()
			remaining_hits -= 1
			used = remaining_hits <= 0
		_:
			used = true
	queue_redraw()


func _bump_hidden_content(body: Node2D) -> void:
	if used:
		_animate_bump()
		return
	_animate_bump()
	AudioManager.play("bump")
	match content:
		Content.COIN:
			_spawn_coin()
			used = true
		Content.MUSHROOM:
			_spawn_powerup(body)
			used = true
		Content.MULTI_COIN:
			_spawn_coin()
			remaining_hits -= 1
			used = remaining_hits <= 0
	queue_redraw()


func _animate_bump() -> void:
	if bump_locked:
		return
	bump_locked = true
	var tween := create_tween()
	tween.tween_property(self, "bump_offset", -6.0, 0.07)
	tween.tween_property(self, "bump_offset", 0.0, 0.09)
	tween.tween_callback(func() -> void:
		bump_locked = false
		queue_redraw()
	)


func _break() -> void:
	AudioManager.play("brick")
	GameManager.add_score(50)
	var fragment_colors: Array[Color] = [
		Color("c4663a"), Color("a8522e"), Color("8a3f22"), Color("e08a4f"),
	]
	for index: int in 4:
		var fragment := Sprite2D.new()
		fragment.texture = PixelArt.circle_texture(fragment_colors[index], 6)
		fragment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fragment.position = global_position + Vector2(-4 + index * 3, -4 + (index % 2) * 3)
		fragment.scale = Vector2(0.5, 0.5)
		fragment.z_index = 6
		get_tree().current_scene.add_child(fragment)
		var tween := create_tween()
		var dir := Vector2(-1.0 if index % 2 == 0 else 1.0, -1.0)
		tween.tween_property(fragment, "position", global_position + dir * Vector2(14, 20) + Vector2(0, 26), 0.55)
		tween.parallel().tween_property(fragment, "rotation", (1.0 if index % 2 == 0 else -1.0) * 3.0, 0.55)
		tween.parallel().tween_property(fragment, "modulate:a", 0.0, 0.5)
		tween.tween_callback(fragment.queue_free)
	queue_free()


func _spawn_coin() -> void:
	AudioManager.play("coin")
	var pop := COIN_POP_SCENE.instantiate()
	pop.global_position = global_position + Vector2(0, -8)
	get_tree().current_scene.add_child(pop)
	GameManager.add_score(100)
	GameManager.add_collectible(1)


func _spawn_powerup(body: Node2D) -> void:
	AudioManager.play("mushroom")
	if body.get("is_big") == true:
		var bloom := ENERGY_BLOOM_SCENE.instantiate()
		bloom.global_position = global_position + Vector2(0, -4)
		get_tree().current_scene.add_child(bloom)
		bloom.emerge()
		return
	var mushroom := MUSHROOM_SCENE.instantiate()
	mushroom.global_position = global_position + Vector2(0, -4)
	get_tree().current_scene.add_child(mushroom)
	mushroom.emerge()


func _process(_delta: float) -> void:
	if bump_offset != 0.0:
		queue_redraw()


func _draw() -> void:
	var draw_y := int(bump_offset)
	if block_type == Type.BRICK:
		if used and content != Content.NONE:
			_draw_used_block(draw_y)
		else:
			_draw_brick(draw_y)
	else:
		_draw_question(draw_y)


func _draw_brick(draw_y: int) -> void:
	var top := draw_y - 8
	var palette := _brick_palette()
	var base: Color = palette[0]
	var light: Color = palette[1]
	var dark: Color = palette[2]
	var mortar: Color = palette[3]
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 16), base)
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 2), light)
	PixelArt.rect(self, Vector2(-8, top + 14), Vector2(16, 2), dark)
	PixelArt.rect(self, Vector2(-8, top + 6), Vector2(16, 2), dark)
	PixelArt.rect(self, Vector2(-1, top), Vector2(2, 16), mortar)
	PixelArt.rect(self, Vector2(-8, top), Vector2(2, 6), light)
	PixelArt.rect(self, Vector2(6, top), Vector2(2, 6), light)
	PixelArt.rect(self, Vector2(-8, top + 8), Vector2(2, 6), light)
	PixelArt.rect(self, Vector2(6, top + 8), Vector2(2, 6), light)
	match visual_theme:
		1:
			PixelArt.diamond(self, Vector2(4, top + 11), 2.0, Color("79d9ca"))
		2:
			PixelArt.rect(self, Vector2(-6, top + 2), Vector2(5, 1), Color("ecffff"))
		3:
			PixelArt.rect(self, Vector2(-6, top + 10), Vector2(2, 2), Color("e0ad68"))
			PixelArt.rect(self, Vector2(4, top + 3), Vector2(2, 2), Color("e0ad68"))
		4:
			PixelArt.rect(self, Vector2(2, top + 7), Vector2(2, 5), Color("d26078"))
			PixelArt.rect(self, Vector2(4, top + 7), Vector2(2, 2), Color("ffad74"))
		5:
			PixelArt.rect(self, Vector2(-7, top + 2), Vector2(3, 5), Color("6ea85a"))
			PixelArt.rect(self, Vector2(3, top + 9), Vector2(4, 2), Color("91c66f"))
		6:
			PixelArt.rect(self, Vector2(-5, top + 3), Vector2(9, 2), Color("ff7b39"))
			PixelArt.rect(self, Vector2(1, top + 5), Vector2(2, 5), Color("ffb449"))
		7:
			PixelArt.diamond(self, Vector2(4, top + 5), 3.0, Color("65e4e5"))
		8:
			PixelArt.diamond(self, Vector2(-4, top + 5), 3.0, Color("c98aff"))
			PixelArt.rect(self, Vector2(3, top + 10), Vector2(4, 2), Color("7a65b6"))
		9:
			PixelArt.diamond(self, Vector2(0, top + 7), 3.0, Color("ffd45e"))
			PixelArt.rect(self, Vector2(-6, top + 2), Vector2(3, 2), Color("b05767"))


func _brick_palette() -> Array[Color]:
	match visual_theme:
		1:
			return [Color("52646a"), Color("789096"), Color("2d3b42"), Color("405158")]
		2:
			return [Color("78a6b8"), Color("bce3e8"), Color("456979"), Color("5b8798")]
		3:
			return [Color("9b633f"), Color("d0935d"), Color("563827"), Color("734a32")]
		4:
			return [Color("4b3e50"), Color("796079"), Color("251f2c"), Color("382d40")]
		5:
			return [Color("58654a"), Color("83926a"), Color("30392b"), Color("44503c")]
		6:
			return [Color("713a2e"), Color("b55b3c"), Color("3d2222"), Color("572b26")]
		7:
			return [Color("385b67"), Color("61a8ab"), Color("1f3943"), Color("2b4852")]
		8:
			return [Color("514766"), Color("806f9b"), Color("29243b"), Color("3c3450")]
		9:
			return [Color("5b3240"), Color("945269"), Color("2d1d29"), Color("422633")]
		_:
			return [Color("b25b2c"), Color("d97f45"), Color("7c3d1d"), Color("8f4c24")]


func _draw_question(draw_y: int) -> void:
	if used:
		_draw_used_block(draw_y)
		return
	var top := draw_y - 8
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 16), Color("f2a93b"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 2), Color("ffd675"))
	PixelArt.rect(self, Vector2(-8, top + 14), Vector2(16, 2), Color("b26f1d"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(2, 16), Color("ffcf6e"))
	PixelArt.rect(self, Vector2(6, top), Vector2(2, 16), Color("c07c20"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(2, 2), Color("ffe9b0"))
	PixelArt.rect(self, Vector2(6, top), Vector2(2, 2), Color("ffe9b0"))
	if content == Content.MUSHROOM:
		_draw_power_icon(draw_y)
	elif content == Content.MULTI_COIN:
		_draw_multi_coin_icon(draw_y)
	else:
		_draw_question_mark(draw_y, Color.WHITE)


func _draw_used_block(draw_y: int) -> void:
	var top := draw_y - 8
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 16), Color("6b6257"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 2), Color("8d8376"))
	PixelArt.rect(self, Vector2(-8, top + 14), Vector2(16, 2), Color("4c453d"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(2, 16), Color("4c453d"))
	PixelArt.rect(self, Vector2(6, top), Vector2(2, 16), Color("4c453d"))
	PixelArt.rect(self, Vector2(-2, draw_y - 2), Vector2(4, 4), Color("4c453d"))


func _draw_question_mark(draw_y: int, color: Color) -> void:
	# 使用固定像素块，不依赖设备字体，缩放后也不会丢失问号。
	var shadow := color.darkened(0.58)
	PixelArt.rect(self, Vector2(-3, draw_y - 5), Vector2(6, 2), shadow)
	PixelArt.rect(self, Vector2(2, draw_y - 3), Vector2(2, 4), shadow)
	PixelArt.rect(self, Vector2(-1, draw_y), Vector2(4, 2), shadow)
	PixelArt.rect(self, Vector2(-1, draw_y + 4), Vector2(2, 2), shadow)
	PixelArt.rect(self, Vector2(-4, draw_y - 6), Vector2(6, 2), color)
	PixelArt.rect(self, Vector2(1, draw_y - 4), Vector2(2, 4), color)
	PixelArt.rect(self, Vector2(-2, draw_y - 1), Vector2(4, 2), color)
	PixelArt.rect(self, Vector2(-2, draw_y + 3), Vector2(2, 2), color)


func _draw_power_icon(draw_y: int) -> void:
	# 明示强化砖使用绿色花蕾徽记；隐藏强化砖仍保持普通土砖外观。
	var outline := Color("174737")
	var green := Color("54dc83")
	var highlight := Color("b8f58a")
	PixelArt.diamond(self, Vector2(0, draw_y - 1), 6.0, outline)
	PixelArt.diamond(self, Vector2(0, draw_y - 2), 4.0, green)
	PixelArt.rect(self, Vector2(-1, draw_y + 1), Vector2(2, 5), outline)
	PixelArt.rect(self, Vector2(0, draw_y - 4), Vector2(2, 2), highlight)


func _draw_multi_coin_icon(draw_y: int) -> void:
	# 三层亮片清楚提示这是可连续顶击的金币砖。
	var outline := Color("704515")
	var gold := Color("ffe36a")
	var highlight := Color("fff6bd")
	for row: int in 3:
		var y := draw_y - 5 + row * 4
		PixelArt.rect(self, Vector2(-5, y), Vector2(10, 3), outline)
		PixelArt.rect(self, Vector2(-3, y), Vector2(7, 1), gold)
		PixelArt.rect(self, Vector2(-2, y), Vector2(3, 1), highlight)
