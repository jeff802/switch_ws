class_name PixelTouchButton
extends TouchScreenButton

@export var caption: String = "A"
@export var tint: Color = Color("59a18e")
@export var radius: float = 20.0


func _ready() -> void:
	var touch_shape := shape.duplicate() as CircleShape2D
	touch_shape.radius = radius + 5.0
	shape = touch_shape
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(1, 3), radius + 2.0, Color(0.02, 0.04, 0.06, 0.42))
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, 0.68))
	draw_arc(Vector2.ZERO, radius - 1.5, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.88), 2.5)
	if action == &"move_left" or action == &"move_right":
		_draw_direction_arrow(-1.0 if action == &"move_left" else 1.0)
		return
	if action == &"pause":
		draw_rect(Rect2(-6, -8, 4, 16), Color.WHITE, true)
		draw_rect(Rect2(2, -8, 4, 16), Color.WHITE, true)
		return
	var font := ThemeDB.fallback_font
	var font_size := clampi(roundi(radius * 0.55), 12, 19)
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)


func _draw_direction_arrow(direction: float) -> void:
	var tip := Vector2(direction * radius * 0.48, 0)
	var back_x := -direction * radius * 0.28
	var points := PackedVector2Array([
		tip,
		Vector2(back_x, -radius * 0.42),
		Vector2(back_x, radius * 0.42),
	])
	draw_colored_polygon(points, Color("ffffff"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color("17242c"), 2.0)
