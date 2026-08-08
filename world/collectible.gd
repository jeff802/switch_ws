class_name GearSeed
extends Area2D

@export var value: int = 1
@export var heals: bool = false

var age: float = 0.0
var collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	GameManager.add_collectible(value)
	if heals and body.has_method("heal"):
		body.heal(1)
	set_deferred("monitoring", false)
	visible = false
	queue_free()


func _draw() -> void:
	var bob := sin(age * 4.0) * 2.0
	PixelArt.diamond(self, Vector2(0, bob), 6.0, Color("f5c45e") if not heals else Color("72df9b"))
	PixelArt.rect(self, Vector2(-1, -3 + bob), Vector2(2, 6), Color("fff0aa"))
