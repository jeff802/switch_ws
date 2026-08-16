class_name BonusDungeonDecor
extends Node2D

var age: float = 0.0
var room_size := Vector2(640, 360)


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _draw() -> void:
	# 独立的地窖色调：深青石墙、暖铜灯与漂浮微尘，和主关卡保持同一像素语言。
	draw_rect(Rect2(Vector2.ZERO, room_size), Color("071116"), true)
	draw_rect(Rect2(0, 70, room_size.x, 290), Color("0d1d24"), true)
	draw_rect(Rect2(0, 225, room_size.x, 135), Color("142a30"), true)
	for y: int in range(24, 340, 24):
		var row_offset := 12 if (y / 24) % 2 == 1 else 0
		for x: int in range(-24 + row_offset, 660, 48):
			draw_line(Vector2(x, y), Vector2(x + 40, y), Color(0.18, 0.34, 0.37, 0.28), 2.0)
			draw_line(Vector2(x, y), Vector2(x, y + 18), Color(0.08, 0.17, 0.2, 0.4), 1.0)
	for lamp_x: float in [104.0, 320.0, 536.0]:
		var pulse := 1.0 + sin(age * 3.2 + lamp_x * 0.03) * 0.08
		draw_circle(Vector2(lamp_x, 82), 34.0 * pulse, Color(0.2, 0.9, 0.82, 0.055))
		draw_circle(Vector2(lamp_x, 82), 16.0 * pulse, Color(0.32, 0.94, 0.84, 0.1))
		PixelArt.rect(self, Vector2(lamp_x - 6, 74), Vector2(12, 16), Color("172c31"))
		PixelArt.rect(self, Vector2(lamp_x - 3, 77), Vector2(6, 9), Color("75f0d5"))
		PixelArt.rect(self, Vector2(lamp_x - 1, 78), Vector2(2, 7), Color("efffc2"))
	for mote_index: int in 18:
		var mote_x := fposmod(float(mote_index * 83) + age * (5.0 + mote_index % 3), room_size.x)
		var mote_y := 112.0 + fposmod(float(mote_index * 47) - age * (4.0 + mote_index % 4), 205.0)
		var alpha := 0.18 + 0.12 * sin(age * 2.0 + mote_index)
		draw_circle(Vector2(mote_x, mote_y), 1.0 + float(mote_index % 2), Color(0.5, 0.95, 0.84, alpha))
