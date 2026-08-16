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
	z_index = 14
	z_as_relative = false


func activate(new_direction: float, new_source: Node) -> void:
	direction = signf(new_direction) if not is_zero_approx(new_direction) else 1.0
	source = new_source
	lifetime = MAX_LIFETIME
	active = true
	visible = true
	modulate = Color.WHITE
	self_modulate = Color.WHITE
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
	var vertical_limit := 340.0
	if source != null:
		var level := source.get_parent()
		if level != null and level.get("inside_bonus_dungeon") == true:
			vertical_limit = 700.0
	if lifetime <= 0.0 or global_position.y > vertical_limit:
		ObjectPool.release_projectile(self)


func _handle_collision(collision: KinematicCollision2D) -> void:
	if not active:
		return
	var body := collision.get_collider() as Node2D
	if body == source:
		return
	if body != null and body.is_in_group("enemies") and body.has_method("take_damage"):
		hit_damageable(body)
		return
	var normal := collision.get_normal()
	if normal.y < -0.55:
		velocity.y = BOUNCE_VELOCITY
		AudioManager.play("land")
	else:
		ObjectPool.release_projectile(self)


func hit_damageable(target: Node) -> void:
	if not active or target == null or not target.has_method("take_damage"):
		return
	target.take_damage(3 if target is PooledEnemy else 1, false)
	GameManager.add_score(25)
	ObjectPool.release_projectile(self)


func _draw() -> void:
	var radius := 5.2 + sin(pulse * 18.0) * 0.45
	# 深色描边与暖色弹芯在蓝天、雪地、洞穴和城市背景上都保持清晰。
	PixelArt.diamond(self, Vector2.ZERO, radius + 5.0, Color(0.05, 0.1, 0.14, 0.72))
	PixelArt.diamond(self, Vector2.ZERO, radius + 3.0, Color(0.2, 0.95, 1.0, 0.72))
	PixelArt.diamond(self, Vector2.ZERO, radius + 0.5, Color("ff7438"))
	PixelArt.diamond(self, Vector2.ZERO, radius - 2.0, Color("ffe45e"))
	PixelArt.rect(self, Vector2(-10.0 * direction - 2.0, -2), Vector2(6, 4), Color("18323c"))
	PixelArt.rect(self, Vector2(-9.0 * direction - 1.0, -1), Vector2(5, 2), Color("7ff6ff"))
	PixelArt.rect(self, Vector2(-1.5, -1.5), Vector2(3, 3), Color.WHITE)
