class_name CoinPop
extends Node2D

var age: float = 0.0


func _ready() -> void:
	z_index = 6

func _process(delta: float) -> void:
	age += delta
	position.y -= 55.0 * delta
	queue_redraw()
	if age > 0.5:
		queue_free()


func _draw() -> void:
	var scale_factor := 1.0 + minf(age * 2.0, 0.4)
	draw_circle(Vector2.ZERO, 6.0 * scale_factor, Color("f7c948"))
	draw_circle(Vector2.ZERO, 4.0 * scale_factor, Color("e8a33d"))
	PixelArt.rect(self, Vector2(-1, -5) * scale_factor, Vector2(2, 10) * scale_factor, Color("ffdf80"))
	PixelArt.rect(self, Vector2(-3, -2) * scale_factor, Vector2(6, 2) * scale_factor, Color("c97b1c"))
	PixelArt.rect(self, Vector2(-3, 0) * scale_factor, Vector2(6, 2) * scale_factor, Color("c97b1c"))
