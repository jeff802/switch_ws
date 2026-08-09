class_name GearBlock
extends StaticBody2D

enum Type { BRICK, QUESTION }
enum Content { NONE, COIN, MUSHROOM }

const COIN_POP_SCENE := preload("res://world/coin_pop.tscn")
const MUSHROOM_SCENE := preload("res://world/powerup_mushroom.tscn")
const ENERGY_BLOOM_SCENE := preload("res://world/energy_bloom.tscn")

@export var block_type: int = Type.BRICK
@export var content: int = Content.NONE

var used: bool = false
var bump_offset: float = 0.0

func _ready() -> void:
	add_to_group("blocks")
	queue_redraw()


# Called by the player when its head hits this block from below.
func bump_by_player(body: Node2D) -> void:
	_bump_action(body)


func _bump_action(body: Node2D) -> void:
	if block_type == Type.BRICK:
		if body.get("is_big") == true:
			_break()
		else:
			_animate_bump()
		return
	# Question block.
	if used:
		_animate_bump()
		return
	used = true
	_animate_bump()
	AudioManager.play("bump")
	match content:
		Content.COIN:
			_spawn_coin()
		Content.MUSHROOM:
			_spawn_powerup(body)
	queue_redraw()


func _animate_bump() -> void:
	if bump_offset != 0.0:
		return
	var tween := create_tween()
	tween.tween_property(self, "bump_offset", -6.0, 0.07)
	tween.tween_property(self, "bump_offset", 0.0, 0.09)
	tween.tween_callback(queue_redraw)


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
		_draw_brick(draw_y)
	else:
		_draw_question(draw_y)


func _draw_brick(draw_y: int) -> void:
	var top := draw_y - 8
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 16), Color("b25b2c"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 2), Color("d97f45"))
	PixelArt.rect(self, Vector2(-8, top + 14), Vector2(16, 2), Color("7c3d1d"))
	PixelArt.rect(self, Vector2(-8, top + 6), Vector2(16, 2), Color("7c3d1d"))
	PixelArt.rect(self, Vector2(-1, top), Vector2(2, 16), Color("8f4c24"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(2, 6), Color("d97f45"))
	PixelArt.rect(self, Vector2(6, top), Vector2(2, 6), Color("d97f45"))
	PixelArt.rect(self, Vector2(-8, top + 8), Vector2(2, 6), Color("d97f45"))
	PixelArt.rect(self, Vector2(6, top + 8), Vector2(2, 6), Color("d97f45"))


func _draw_question(draw_y: int) -> void:
	var top := draw_y - 8
	if used:
		PixelArt.rect(self, Vector2(-8, top), Vector2(16, 16), Color("6b6257"))
		PixelArt.rect(self, Vector2(-8, top), Vector2(16, 2), Color("8d8376"))
		PixelArt.rect(self, Vector2(-8, top + 14), Vector2(16, 2), Color("4c453d"))
		PixelArt.rect(self, Vector2(-8, top), Vector2(2, 16), Color("4c453d"))
		PixelArt.rect(self, Vector2(6, top), Vector2(2, 16), Color("4c453d"))
		_draw_question_mark(draw_y, Color(0.35, 0.32, 0.28, 1))
		return
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 16), Color("f2a93b"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(16, 2), Color("ffd675"))
	PixelArt.rect(self, Vector2(-8, top + 14), Vector2(16, 2), Color("b26f1d"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(2, 16), Color("ffcf6e"))
	PixelArt.rect(self, Vector2(6, top), Vector2(2, 16), Color("c07c20"))
	PixelArt.rect(self, Vector2(-8, top), Vector2(2, 2), Color("ffe9b0"))
	PixelArt.rect(self, Vector2(6, top), Vector2(2, 2), Color("ffe9b0"))
	_draw_question_mark(draw_y, Color.WHITE)


func _draw_question_mark(draw_y: int, color: Color) -> void:
	# Center the "?" horizontally and vertically inside the 16x16 block.
	var font := ThemeDB.fallback_font
	var font_size := 10
	var text_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := draw_y + (font.get_ascent(font_size) - font.get_height(font_size) * 0.5)
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, baseline),
		"?",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)
