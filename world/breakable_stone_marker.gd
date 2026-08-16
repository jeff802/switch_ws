class_name BreakableStoneMarker
extends Node2D

## 覆盖在 TileMap 石砖上的像素裂纹。完整石砖没有该标记，因此玩家不用
## 试撞就能判断哪一块可由“能量·碎石”状态顶开。


func _ready() -> void:
	add_to_group("breakable_stone_markers")
	queue_redraw()


func _draw() -> void:
	var shadow := Color("26383c")
	var crack := Color("f0b45d")
	var highlight := Color("ffe0a0")
	# 中心主裂纹与两条分叉，使用整数坐标保持 16px 像素风清晰度。
	draw_polyline(PackedVector2Array([
		Vector2(-5, -7), Vector2(-2, -3), Vector2(-3, 0), Vector2(1, 3), Vector2(0, 7),
	]), shadow, 2.0, false)
	draw_polyline(PackedVector2Array([
		Vector2(-5, -7), Vector2(-2, -3), Vector2(-3, 0), Vector2(1, 3), Vector2(0, 7),
	]), crack, 1.0, false)
	draw_line(Vector2(-3, 0), Vector2(-7, 2), shadow, 2.0, false)
	draw_line(Vector2(-3, 0), Vector2(-7, 2), crack, 1.0, false)
	draw_line(Vector2(1, 3), Vector2(6, 0), shadow, 2.0, false)
	draw_line(Vector2(1, 3), Vector2(6, 0), crack, 1.0, false)
	# 小型高光铆点让裂纹在洞穴和城市深色砖面上仍然可辨。
	draw_rect(Rect2(5, -6, 2, 2), shadow, true)
	draw_rect(Rect2(5, -7, 1, 1), highlight, true)
