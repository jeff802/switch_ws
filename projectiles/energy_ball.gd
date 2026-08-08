class_name EnergyBall
extends Area2D

const SPEED := 290.0
const MAX_LIFETIME := 1.6

var direction: float = 1.0
var lifetime: float = 0.0
var source: Node
var active: bool = false
var pulse: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func activate(new_direction: float, new_source: Node) -> void:
	direction = signf(new_direction) if not is_zero_approx(new_direction) else 1.0
	source = new_source
	lifetime = MAX_LIFETIME
	active = true
	visible = true
	monitoring = true
	set_process(true)
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	set_deferred("monitoring", false)
	set_process(false)
	source = null


func _process(delta: float) -> void:
	if not active:
		return
	global_position.x += direction * SPEED * delta
	pulse += delta
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0:
		ObjectPool.release_projectile(self)


func _on_body_entered(body: Node2D) -> void:
	if not active or body == source:
		return
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(1, false)
		GameManager.add_score(25)
	ObjectPool.release_projectile(self)


func _draw() -> void:
	var radius := 4.0 + sin(pulse * 18.0)
	PixelArt.diamond(self, Vector2.ZERO, radius + 2.0, Color(0.2, 0.9, 1.0, 0.25))
	PixelArt.diamond(self, Vector2.ZERO, radius, Color("8ff3ff"))
	PixelArt.rect(self, Vector2(-1, -1), Vector2(2, 2), Color.WHITE)
