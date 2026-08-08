class_name HiddenArea
extends Area2D

@export var cover_size: Vector2 = Vector2(96, 64)
var revealed: bool = false
var opacity: float = 1.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if revealed:
		opacity = move_toward(opacity, 0.0, delta * 2.5)
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not revealed and body.is_in_group("player"):
		revealed = true
		GameManager.add_score(500)
		set_deferred("monitoring", false)


func _draw() -> void:
	if opacity > 0.01:
		draw_rect(Rect2(-cover_size * 0.5, cover_size), Color(0.025, 0.035, 0.045, opacity), true)
