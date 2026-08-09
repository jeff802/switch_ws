class_name GearFlagpole
extends Area2D

@export var unlock_level_id: String = ""
@export_file("*.tscn") var next_scene: String = ""
var finished: bool = false
var flag_drop_offset: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if finished or not body.is_in_group("player"):
		return
	finished = true
	monitoring = false
	GameManager.freeze_level_timer()
	AudioManager.play("flag")
	var height_ratio := clampf((global_position.y - body.global_position.y) / 108.0, 0.0, 1.0)
	var height_scores: Array[int] = [100, 200, 400, 800, 1000]
	var height_index := mini(int(height_ratio * height_scores.size()), height_scores.size() - 1)
	GameManager.add_score(height_scores[height_index])
	var slide_time := clampf((global_position.y - 14.0 - body.global_position.y) / 150.0, 0.45, 0.85)
	var flag_drop := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flag_drop.tween_property(self, "flag_drop_offset", 84.0, slide_time)
	flag_drop.tween_callback(queue_redraw)
	if body.has_method("play_flagpole_finish"):
		await body.play_flagpole_finish(global_position.x, global_position.y, slide_time)
	await get_tree().create_timer(0.25).timeout
	GameManager.finish_level(unlock_level_id, next_scene)


func _process(_delta: float) -> void:
	if flag_drop_offset > 0.0 and flag_drop_offset < 84.0:
		queue_redraw()


func _draw() -> void:
	PixelArt.rect(self, Vector2(-2, -108), Vector2(4, 112), Color("cfd6d8"))
	PixelArt.rect(self, Vector2(-3, -110), Vector2(6, 6), Color("f0c33c"))
	PixelArt.rect(self, Vector2(-12, -3), Vector2(22, 5), Color("e8eef0"))
	var flag_y := -104.0 + flag_drop_offset
	PixelArt.rect(self, Vector2(-10, flag_y), Vector2(16, 22), Color("3aa85c"))
	PixelArt.rect(self, Vector2(-4, flag_y + 2.0), Vector2(4, 18), Color("6fdc86"))
	PixelArt.diamond(self, Vector2(-2, flag_y + 11.0), 4.0, Color("ffd675"))
