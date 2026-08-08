class_name RootSpring
extends Area2D

@export var launch_strength: float = 485.0
var compression: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	compression = move_toward(compression, 0.0, delta * 8.0)
	sprite.scale.y = lerpf(1.0, 0.72, compression)
	sprite.position.y = compression * 4.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("bounce"):
		body.bounce(launch_strength)
		compression = 1.0
