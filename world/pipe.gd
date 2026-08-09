class_name GearPipe
extends StaticBody2D

@export var pipe_height: float = 48.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# pipe_height is the TOTAL visual height (10px lip + body).
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, pipe_height)
	collision_shape.shape = shape
	collision_shape.position = Vector2(0, -pipe_height * 0.5)
	queue_redraw()


func _draw() -> void:
	var body_height := pipe_height - 10.0
	PixelArt.rect(self, Vector2(-16, -body_height), Vector2(32, body_height), Color("2e9e4f"))
	PixelArt.rect(self, Vector2(-13, -body_height + 2), Vector2(6, body_height - 4), Color("58c96f"))
	PixelArt.rect(self, Vector2(7, -body_height + 2), Vector2(6, body_height - 4), Color("1d6e33"))
	PixelArt.rect(self, Vector2(-18, -pipe_height), Vector2(36, 10), Color("3ab75c"))
	PixelArt.rect(self, Vector2(-15, -pipe_height), Vector2(8, 10), Color("6fdc86"))
	PixelArt.rect(self, Vector2(7, -pipe_height), Vector2(8, 10), Color("237a3a"))
	PixelArt.rect(self, Vector2(-18, -pipe_height - 2), Vector2(36, 2), Color("1d6e33"))
