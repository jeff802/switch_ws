class_name FallingRock
extends Area2D

@export var trigger_distance: float = 80.0
@export var reset_delay: float = 2.0

var origin: Vector2
var velocity_y: float = 0.0
var falling: bool = false
var reset_timer: float = 0.0


func _ready() -> void:
	origin = global_position
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not falling and reset_timer <= 0.0 and player != null:
		if absf(player.global_position.x - global_position.x) < trigger_distance and player.global_position.y > global_position.y:
			falling = true
	if falling:
		velocity_y = minf(velocity_y + 850.0 * delta, 420.0)
		global_position.y += velocity_y * delta
		if global_position.y > origin.y + 260.0:
			_reset()
	elif reset_timer > 0.0:
		reset_timer -= delta
		if reset_timer <= 0.0:
			global_position = origin
			visible = true
			set_deferred("monitoring", true)
	queue_redraw()


func _reset() -> void:
	falling = false
	velocity_y = 0.0
	visible = false
	set_deferred("monitoring", false)
	reset_timer = reset_delay


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position)
		_reset()


func _draw() -> void:
	PixelArt.rect(self, Vector2(-9, -9), Vector2(18, 18), Color("37474d"))
	PixelArt.rect(self, Vector2(-6, -7), Vector2(8, 5), Color("65777a"))
	PixelArt.rect(self, Vector2(2, 2), Vector2(5, 5), Color("263238"))
