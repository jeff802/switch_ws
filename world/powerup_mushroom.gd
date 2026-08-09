class_name GearMushroom
extends CharacterBody2D

const SPEED := 55.0
const GRAVITY := 900.0
const MAX_FALL := 400.0

var direction: float = 1.0
var emerged: bool = false

@onready var touch_area: Area2D = $TouchArea


func _ready() -> void:
	add_to_group("powerups")
	z_index = 3
	touch_area.body_entered.connect(_on_touch_area_entered)
	visible = false
	touch_area.monitoring = false
	set_physics_process(false)


func emerge() -> void:
	visible = true
	var emerge_to := global_position + Vector2(0.0, -16.0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", emerge_to, 0.38)
	await tween.finished
	emerged = true
	touch_area.monitoring = true
	set_physics_process(true)
	velocity = Vector2(direction * SPEED, 0.0)


func _physics_process(delta: float) -> void:
	if not emerged:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	velocity.x = direction * SPEED
	move_and_slide()
	if is_on_wall():
		direction *= -1.0
	queue_redraw()


func _on_touch_area_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("grow"):
		return
	body.grow()
	GameManager.add_score(1000)
	queue_free()


func _draw() -> void:
	# Original amber power mushroom (not a Nintendo asset).
	PixelArt.rect(self, Vector2(-3, -6), Vector2(6, 5), Color("ffe3b0"))
	PixelArt.rect(self, Vector2(-4, -11), Vector2(8, 5), Color("e8722c"))
	PixelArt.rect(self, Vector2(-6, -8), Vector2(12, 4), Color("f08a3a"))
	PixelArt.rect(self, Vector2(-3, -10), Vector2(2, 2), Color("fff0c9"))
	PixelArt.rect(self, Vector2(2, -7), Vector2(2, 2), Color("fff0c9"))
	PixelArt.rect(self, Vector2(-1, 1), Vector2(2, 5), Color("ffd98a"))
