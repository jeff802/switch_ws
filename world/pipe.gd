class_name GearPipe
extends StaticBody2D

enum TravelMode { NONE, ENTER_BONUS, EXIT_BONUS }

@export var pipe_height: float = 48.0
@export var travel_mode: TravelMode = TravelMode.NONE

var age: float = 0.0
var nearby_player: Node2D
var down_was_pressed: bool = false
var travel_locked: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var entry_area: Area2D = $EntryArea
@onready var entry_shape: CollisionShape2D = $EntryArea/CollisionShape2D


func _ready() -> void:
	# pipe_height is the TOTAL visual height (10px lip + body).
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, pipe_height)
	collision_shape.shape = shape
	collision_shape.position = Vector2(0, -pipe_height * 0.5)
	var sensor_shape := RectangleShape2D.new()
	sensor_shape.size = Vector2(28, 14)
	entry_shape.shape = sensor_shape
	entry_shape.position = Vector2(0, -pipe_height - 6)
	entry_area.body_entered.connect(_on_entry_body_entered)
	entry_area.body_exited.connect(_on_entry_body_exited)
	entry_area.monitoring = travel_mode != TravelMode.NONE
	if travel_mode != TravelMode.NONE:
		add_to_group("travel_pipes")
	queue_redraw()


func _physics_process(delta: float) -> void:
	age += delta
	var down_pressed := Input.is_action_pressed("move_down") or Input.is_action_pressed("stomp")
	var down_just_pressed := down_pressed and not down_was_pressed
	down_was_pressed = down_pressed
	if travel_mode == TravelMode.NONE or nearby_player == null or travel_locked:
		queue_redraw()
		return
	if down_just_pressed and absf(nearby_player.global_position.x - global_position.x) <= 13.0:
		var level := _find_level()
		if level != null and level.has_method("travel_through_pipe"):
			travel_locked = true
			level.travel_through_pipe(self, nearby_player, travel_mode)
	queue_redraw()


func unlock_travel() -> void:
	travel_locked = false
	down_was_pressed = Input.is_action_pressed("move_down") or Input.is_action_pressed("stomp")


func _on_entry_body_entered(body: Node2D) -> void:
	if travel_mode == TravelMode.NONE or not body.is_in_group("player"):
		return
	nearby_player = body
	var level := _find_level()
	if level != null and level.has_method("show_pipe_prompt"):
		level.show_pipe_prompt(travel_mode)


func _on_entry_body_exited(body: Node2D) -> void:
	if body != nearby_player:
		return
	nearby_player = null
	var level := _find_level()
	if level != null and level.has_method("hide_pipe_prompt"):
		level.hide_pipe_prompt()


func _find_level() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("travel_through_pipe"):
			return node
		node = node.get_parent()
	return null


func _draw() -> void:
	var body_height := pipe_height - 10.0
	var body_color := Color("2e9e4f") if travel_mode == TravelMode.NONE else Color("247f68")
	var light_color := Color("58c96f") if travel_mode == TravelMode.NONE else Color("52c9aa")
	var dark_color := Color("1d6e33") if travel_mode == TravelMode.NONE else Color("145247")
	PixelArt.rect(self, Vector2(-16, -body_height), Vector2(32, body_height), body_color)
	PixelArt.rect(self, Vector2(-13, -body_height + 2), Vector2(6, body_height - 4), light_color)
	PixelArt.rect(self, Vector2(7, -body_height + 2), Vector2(6, body_height - 4), dark_color)
	PixelArt.rect(self, Vector2(-18, -pipe_height), Vector2(36, 10), body_color.lightened(0.12))
	PixelArt.rect(self, Vector2(-15, -pipe_height), Vector2(8, 10), light_color.lightened(0.08))
	PixelArt.rect(self, Vector2(7, -pipe_height), Vector2(8, 10), dark_color)
	PixelArt.rect(self, Vector2(-18, -pipe_height - 2), Vector2(36, 2), dark_color)
	if travel_mode != TravelMode.NONE:
		# 可进入管道使用青铜边、暗色管口和浮动方向符号，与仙人掌管道明确区分。
		PixelArt.rect(self, Vector2(-14, -pipe_height + 2), Vector2(28, 4), Color("07171a"))
		PixelArt.rect(self, Vector2(-11, -pipe_height + 2), Vector2(22, 2), Color("17383a"))
		var arrow_y := -pipe_height - 13.0 + sin(age * 5.0) * 2.0
		var arrow_color := Color("91f5dc") if nearby_player != null else Color(0.45, 0.82, 0.73, 0.62)
		if travel_mode == TravelMode.ENTER_BONUS:
			PixelArt.rect(self, Vector2(-1, arrow_y), Vector2(3, 7), arrow_color)
			PixelArt.diamond(self, Vector2(0.5, arrow_y + 7), 4.0, arrow_color)
		else:
			PixelArt.rect(self, Vector2(-1, arrow_y + 3), Vector2(3, 7), arrow_color)
			PixelArt.diamond(self, Vector2(0.5, arrow_y + 2), 4.0, arrow_color)
