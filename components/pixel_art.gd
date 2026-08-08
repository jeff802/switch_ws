class_name PixelArt
extends RefCounted


static func rect(canvas: CanvasItem, position: Vector2, size: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(position.floor(), size.floor()), color, true)


static func outline_rect(canvas: CanvasItem, position: Vector2, size: Vector2, fill: Color, outline: Color) -> void:
	rect(canvas, position, size, outline)
	rect(canvas, position + Vector2(1, 1), size - Vector2(2, 2), fill)


static func diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	]), color)


static func circle_texture(color: Color, diameter: int = 40) -> ImageTexture:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(diameter, diameter) * 0.5
	for y: int in diameter:
		for x: int in diameter:
			var distance := Vector2(x, y).distance_to(center)
			if distance <= diameter * 0.48:
				var alpha := 0.48 if distance < diameter * 0.40 else 0.24
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)
