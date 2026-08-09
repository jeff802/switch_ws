class_name DamageMarker
extends Node2D

var age: float = 0.0


func _process(delta: float) -> void:
	age += delta
	position.y -= 26.0 * delta
	queue_redraw()
	if age > 0.65:
		queue_free()


func _draw() -> void:
	var alpha := clampf(1.0 - age / 0.65, 0.0, 1.0)
	PixelArt.rect(self, Vector2(-2, -14), Vector2(4, 10), Color(1.0, 0.28, 0.22, alpha))
	PixelArt.rect(self, Vector2(-2, -2), Vector2(4, 4), Color(1.0, 0.28, 0.22, alpha))
	draw_circle(Vector2.ZERO, 16.0 * (1.0 - age / 0.65) + 3.0, Color(1.0, 0.22, 0.18, 0.16 * alpha))
