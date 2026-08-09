class_name EnergyBloom
extends Area2D

var age: float = 0.0
var collected: bool = false


func _ready() -> void:
	add_to_group("powerups")
	body_entered.connect(_on_body_entered)
	visible = false
	monitoring = false
	z_index = 4


func emerge() -> void:
	visible = true
	var emerge_to := global_position + Vector2(0.0, -16.0)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", emerge_to, 0.42)
	await tween.finished
	monitoring = true


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player") or not body.has_method("grant_orb_power"):
		return
	collected = true
	monitoring = false
	body.grant_orb_power()
	GameManager.add_score(1000)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.12)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# Original mechanical blossom: four copper petals around an energy core.
	var pulse := 1.0 + sin(age * 7.0) * 0.08
	draw_circle(Vector2.ZERO, 8.0 * pulse, Color(0.25, 0.9, 1.0, 0.16))
	for offset: Vector2 in [Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)]:
		PixelArt.diamond(self, offset, 4.0, Color("e88445"))
		PixelArt.diamond(self, offset, 2.0, Color("ffd36b"))
	PixelArt.diamond(self, Vector2.ZERO, 4.0, Color("65e6f5"))
	PixelArt.rect(self, Vector2(-1, -1), Vector2(2, 2), Color.WHITE)
