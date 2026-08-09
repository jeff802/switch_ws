class_name EnergyBall
extends CharacterBody2D

const SPEED := 245.0
const BOUNCE_VELOCITY := -205.0
const GRAVITY := 880.0
const MAX_FALL_SPEED := 360.0
const MAX_LIFETIME := 4.0

var direction: float = 1.0
var lifetime: float = 0.0
var source: Node
var active: bool = false
var pulse: float = 0.0


func _ready() -> void:
	add_to_group("player_projectiles")


func activate(new_direction: float, new_source: Node) -> void:
	direction = signf(new_direction) if not is_zero_approx(new_direction) else 1.0
	source = new_source
	lifetime = MAX_LIFETIME
	active = true
	visible = true
	velocity = Vector2(direction * SPEED, -90.0)
	set_physics_process(true)
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	source = null


func _physics_process(delta: float) -> void:
	if not active:
		return
	velocity.x = direction * SPEED
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		_handle_collision(collision)
	pulse += delta
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0 or global_position.y > 340.0:
		ObjectPool.release_projectile(self)


func _handle_collision(collision: KinematicCollision2D) -> void:
	if not active:
		return
	var body := collision.get_collider() as Node2D
	if body == source:
		return
	if body != null and body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(3 if body is PooledEnemy else 1, false)
		GameManager.add_score(25)
		ObjectPool.release_projectile(self)
		return
	var normal := collision.get_normal()
	if normal.y < -0.55:
		velocity.y = BOUNCE_VELOCITY
		AudioManager.play("land")
	else:
		ObjectPool.release_projectile(self)


func _draw() -> void:
	var radius := 4.0 + sin(pulse * 18.0) * 0.45
	PixelArt.diamond(self, Vector2.ZERO, radius + 3.0, Color(0.2, 0.9, 1.0, 0.22))
	PixelArt.diamond(self, Vector2.ZERO, radius, Color("57d8eb"))
	PixelArt.rect(self, Vector2(-5.0 * direction, -1), Vector2(3, 2), Color("ed8a47"))
	PixelArt.rect(self, Vector2(-1, -1), Vector2(2, 2), Color.WHITE)
