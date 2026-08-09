class_name PooledEnemy
extends CharacterBody2D

signal defeated(enemy: PooledEnemy)

enum Kind { BEETLE_BOT, BOUNCECAP, GEARWING }

const GRAVITY := 980.0

var kind: Kind = Kind.BEETLE_BOT
var health: int = 2
var active: bool = false
var spawn_position: Vector2
var patrol_distance: float = 80.0
var direction: float = -1.0
var action_timer: float = 0.0
var age: float = 0.0
var hit_flash: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")


func activate(new_kind: Kind, origin: Vector2, new_patrol_distance: float) -> void:
	kind = new_kind
	spawn_position = origin
	global_position = origin
	patrol_distance = new_patrol_distance
	health = 3 if kind == Kind.BEETLE_BOT else (1 if kind == Kind.BOUNCECAP else 2)
	direction = -1.0
	action_timer = 0.8
	age = 0.0
	active = true
	visible = true
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", false)
	set_physics_process(true)
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	velocity = Vector2.ZERO
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not active:
		return
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	match kind:
		Kind.BEETLE_BOT:
			_update_beetle(delta)
		Kind.BOUNCECAP:
			_update_bouncecap(delta)
		Kind.GEARWING:
			_update_gearwing(delta)
	queue_redraw()


func _update_beetle(delta: float) -> void:
	velocity.x = direction * 48.0
	velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	move_and_slide()
	if is_on_wall() or absf(global_position.x - spawn_position.x) > patrol_distance:
		direction *= -1.0
	_handle_player_contacts()


func _update_bouncecap(delta: float) -> void:
	action_timer -= delta
	velocity.x = direction * 42.0
	velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	if is_on_floor() and action_timer <= 0.0:
		velocity.y = -155.0
		action_timer = 2.1
	move_and_slide()
	if is_on_wall() or absf(global_position.x - spawn_position.x) > patrol_distance:
		direction *= -1.0
	_handle_player_contacts()


func _update_gearwing(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var center_y := spawn_position.y + sin(age * 2.5) * 28.0
	global_position.y = move_toward(global_position.y, center_y, 65.0 * delta)
	if player != null and global_position.distance_to(player.global_position) < 190.0:
		direction = signf(player.global_position.x - global_position.x)
	global_position.x += direction * 42.0 * delta
	if absf(global_position.x - spawn_position.x) > patrol_distance:
		direction *= -1.0
	_handle_overlapping_player()


func _handle_player_contacts() -> void:
	for index: int in get_slide_collision_count():
		var body := get_slide_collision(index).get_collider() as Node
		if body != null and body.is_in_group("player") and body.has_method("handle_enemy_contact"):
			body.handle_enemy_contact(self)


func _handle_overlapping_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) < 18.0 and player.has_method("handle_enemy_contact"):
		player.handle_enemy_contact(self)


func take_damage(amount: int, stomped: bool = false) -> void:
	if not active:
		return
	# Standard roaming enemies are defeated by one clean stomp. Projectiles
	# still use their normal damage values, preserving the original orb system.
	health = 0 if stomped else health - amount
	hit_flash = 0.1
	if stomped:
		velocity.y = 110.0
	if health <= 0:
		active = false
		if not stomped:
			GameManager.add_score(250 if kind == Kind.GEARWING else 200)
		defeated.emit(self)
		ObjectPool.release_enemy.call_deferred(self)


func notify_attack() -> void:
	# Called when this enemy damages the player: flash so the player can see it.
	hit_flash = 0.35


func _draw() -> void:
	match kind:
		Kind.BEETLE_BOT:
			_draw_beetle()
		Kind.BOUNCECAP:
			_draw_bouncecap()
		Kind.GEARWING:
			_draw_gearwing()
	if hit_flash > 0.0:
		# Semi-transparent flash keeps the monster visible while it highlights.
		PixelArt.rect(self, Vector2(-12, -13), Vector2(24, 25), Color(1.0, 1.0, 1.0, 0.55))


func _draw_beetle() -> void:
	# Dark outline makes the enemy readable on any background.
	PixelArt.rect(self, Vector2(-11, -11), Vector2(22, 22), Color("101820"))
	PixelArt.rect(self, Vector2(-10, -7), Vector2(20, 11), Color("2b3d47"))
	PixelArt.rect(self, Vector2(-7, -10), Vector2(14, 11), Color("e0643f"))
	PixelArt.rect(self, Vector2(-7, -10), Vector2(14, 3), Color("ff9468"))
	PixelArt.rect(self, Vector2(-1, -9), Vector2(2, 9), Color("502f35"))
	PixelArt.rect(self, Vector2(direction * 5.0 - 2, -6), Vector2(3, 2), Color.WHITE)
	PixelArt.rect(self, Vector2(-10, 4), Vector2(5, 3), Color("93a6ad"))
	PixelArt.rect(self, Vector2(5, 4), Vector2(5, 3), Color("93a6ad"))


func _draw_bouncecap() -> void:
	var squash := 1.0 if is_on_floor() and action_timer < 0.18 else 0.0
	var outline := Color("101820")
	# Coppercap: squat gear-rimmed cap, pale stalk and two heavy tread-like feet.
	PixelArt.rect(self, Vector2(-12, -11 + squash), Vector2(24, 12), outline)
	PixelArt.rect(self, Vector2(-9, -9 + squash), Vector2(18, 8), Color("a94f35"))
	PixelArt.rect(self, Vector2(-6, -11 + squash), Vector2(12, 3), Color("e17b45"))
	PixelArt.rect(self, Vector2(-8, -6 + squash), Vector2(4, 3), Color("efb253"))
	PixelArt.rect(self, Vector2(4, -7 + squash), Vector2(4, 3), Color("6c3029"))
	PixelArt.rect(self, Vector2(-6, 0 + squash), Vector2(12, 9 - squash), outline)
	PixelArt.rect(self, Vector2(-4, 0 + squash), Vector2(8, 7 - squash), Color("e8d6a6"))
	PixelArt.rect(self, Vector2(-3, 1 + squash), Vector2(2, 3), Color("26343a"))
	PixelArt.rect(self, Vector2(2, 1 + squash), Vector2(2, 3), Color("26343a"))
	PixelArt.rect(self, Vector2(-9, 7), Vector2(7, 4), outline)
	PixelArt.rect(self, Vector2(2, 7), Vector2(7, 4), outline)
	PixelArt.rect(self, Vector2(direction * 7.0 - 1, -5 + squash), Vector2(2, 2), Color("ffe477"))


func _draw_gearwing() -> void:
	var flap := 4.0 if int(age * 10.0) % 2 == 0 else 1.0
	PixelArt.diamond(self, Vector2.ZERO, 10.0, Color("101820"))
	PixelArt.diamond(self, Vector2.ZERO, 8.0, Color("8fb4c6"))
	PixelArt.rect(self, Vector2(-3, -3), Vector2(6, 6), Color("f0a848"))
	PixelArt.rect(self, Vector2(-13, -flap), Vector2(7, 3), Color("b7dbe8"))
	PixelArt.rect(self, Vector2(6, -flap), Vector2(7, 3), Color("b7dbe8"))
	PixelArt.rect(self, Vector2(direction * 5.0 - 1, -2), Vector2(2, 2), Color("ffe66d"))
