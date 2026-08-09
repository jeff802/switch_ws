class_name ThornSpikes
extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position)


func _draw() -> void:
	# Dark outline plate under everything (readable on any ground).
	PixelArt.rect(self, Vector2(-16, 4), Vector2(32, 4), Color("101820"))
	# Hazard base: yellow/black warning stripes.
	PixelArt.rect(self, Vector2(-16, 5), Vector2(32, 3), Color("f2c230"))
	for x: int in range(-16, 16, 8):
		PixelArt.rect(self, Vector2(x, 5), Vector2(4, 3), Color("161616"))
	# Bright metal spikes with dark outline and red tips.
	for x: int in range(-15, 16, 10):
		var base_x := float(x)
		draw_colored_polygon(PackedVector2Array([
			Vector2(base_x - 1, 6), Vector2(base_x + 5, -11), Vector2(base_x + 11, 6),
		]), Color("101820"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(base_x, 5), Vector2(base_x + 5, -9), Vector2(base_x + 10, 5),
		]), Color("e6edf0"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(base_x + 5, -9), Vector2(base_x + 2, -2), Vector2(base_x + 8, -2),
		]), Color("e53935"))
		PixelArt.rect(self, Vector2(base_x + 4, -6), Vector2(2, 8), Color.WHITE)
