class_name ThornSpikes
extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position)


func _draw() -> void:
	for x: int in range(-16, 16, 8):
		draw_colored_polygon(PackedVector2Array([Vector2(x, 7), Vector2(x + 4, -7), Vector2(x + 8, 7)]), Color("c8d3d1"))
	PixelArt.rect(self, Vector2(-16, 7), Vector2(32, 3), Color("59696c"))

