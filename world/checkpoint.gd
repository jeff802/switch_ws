class_name ForestCheckpoint
extends Area2D

@export var level_id: String = ""

var activated: bool = false
var glow: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var saved_spawn := global_position + Vector2(0, -20)
	if (
		SaveManager.checkpoint_level_id == level_id
		and SaveManager.checkpoint_position.distance_to(saved_spawn) < 2.0
	):
		activated = true
		queue_redraw()


func _process(delta: float) -> void:
	glow += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if activated or not body.is_in_group("player"):
		return
	activated = true
	AudioManager.play("checkpoint")
	GameManager.set_checkpoint(global_position + Vector2(0, -20))
	GameManager.add_score(300)
	queue_redraw()


func _draw() -> void:
	var light := Color("8ff3ff") if activated else Color("566b73")
	PixelArt.rect(self, Vector2(-2, -28), Vector2(4, 32), Color("394b50"))
	PixelArt.diamond(self, Vector2(0, -28), 7.0, light)
	if activated:
		draw_circle(Vector2(0, -28), 10.0 + sin(glow * 4.0) * 2.0, Color(0.55, 0.95, 1.0, 0.15))
