class_name PixelTouchButton
extends TouchScreenButton

@export var caption: String = "A"
@export var tint: Color = Color("59a18e")
@export var radius: float = 20.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, 0.42))
	draw_arc(Vector2.ZERO, radius - 1.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.85), 2.0)
	var font := ThemeDB.fallback_font
	var font_size := 10
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, -text_size * 0.5 + Vector2(0, text_size.y * 0.35), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

