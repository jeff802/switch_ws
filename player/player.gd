class_name ForestMechanic
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal state_changed(state_name: String)

enum State { IDLE, RUN, JUMP, FALL, ATTACK, HURT, DEAD }

const WALK_SPEED := 105.0
const RUN_SPEED := 165.0
const GROUND_ACCELERATION := 1100.0
const AIR_ACCELERATION := 650.0
const FRICTION := 1350.0
const JUMP_VELOCITY := -345.0
const STOMP_VELOCITY := 460.0
const GRAVITY := 1050.0
const MAX_FALL_SPEED := 520.0
const COYOTE_TIME := 0.11
const JUMP_BUFFER_TIME := 0.12

@export var max_health: int = 5
@export var max_stamina: float = 100.0

var health: int = 5
var stamina: float = 100.0
var state: State = State.IDLE
var facing: float = 1.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var attack_timer: float = 0.0
var invulnerability_timer: float = 0.0
var attack_projectile_pending: bool = false
var is_stomping: bool = false
var controls_locked: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var attack_cooldown: Timer = $AttackCooldown


func _ready() -> void:
	add_to_group("player")
	health = max_health
	stamina = max_stamina
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	GameManager.time_expired.connect(_on_time_expired)
	_play_state_animation()
	_update_sprite_visual()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME


func _physics_process(delta: float) -> void:
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	attack_timer = maxf(0.0, attack_timer - delta)

	if state == State.DEAD:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		move_and_slide()
		_update_sprite_visual()
		return

	if controls_locked:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	if state == State.HURT:
		_apply_gravity(delta)
		move_and_slide()
		_update_hurt_state()
		_update_sprite_visual()
		return

	var was_on_floor := is_on_floor()
	var input_axis := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(input_axis):
		facing = signf(input_axis)

	var wants_run := Input.is_action_pressed("run") and stamina > 0.0 and not is_zero_approx(input_axis)
	var target_speed := (RUN_SPEED if wants_run else WALK_SPEED) * input_axis
	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	if is_zero_approx(input_axis) and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	else:
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

	if wants_run and is_on_floor():
		_set_stamina(stamina - 24.0 * delta)
	else:
		_set_stamina(stamina + 17.0 * delta)

	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
		_apply_gravity(delta)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		is_stomping = false
		_set_state(State.JUMP)

	if Input.is_action_just_released("jump") and velocity.y < -110.0:
		velocity.y *= 0.48

	if Input.is_action_just_pressed("stomp") and not is_on_floor():
		velocity.y = STOMP_VELOCITY
		is_stomping = true
		_set_state(State.FALL)

	if Input.is_action_just_pressed("attack"):
		_try_attack()

	move_and_slide()
	_handle_slide_collisions()
	if not was_on_floor and is_on_floor() and is_stomping:
		is_stomping = false

	if attack_timer <= 0.0:
		_update_locomotion_state(input_axis)
	_update_sprite_visual()


func _apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)


func _try_attack() -> void:
	if state == State.ATTACK or not attack_cooldown.is_stopped() or stamina < 12.0:
		return
	_set_stamina(stamina - 12.0)
	attack_cooldown.start()
	attack_timer = 0.34
	attack_projectile_pending = true
	_set_state(State.ATTACK)


func _handle_slide_collisions() -> void:
	for index: int in get_slide_collision_count():
		var hit := get_slide_collision(index)
		var collider := hit.get_collider() as Node2D
		if collider == null or not collider.is_in_group("enemies"):
			continue
		if velocity.y >= 0.0 and global_position.y + 4.0 < collider.global_position.y:
			if collider.has_method("take_damage"):
				collider.take_damage(2 if is_stomping else 1, true)
			velocity.y = -235.0
			is_stomping = false
			GameManager.add_score(150)
		else:
			take_damage(1, collider.global_position)


func _update_locomotion_state(input_axis: float) -> void:
	if not is_on_floor():
		_set_state(State.JUMP if velocity.y < 0.0 else State.FALL)
	elif absf(input_axis) > 0.01:
		_set_state(State.RUN)
	else:
		_set_state(State.IDLE)


func _update_hurt_state() -> void:
	if invulnerability_timer <= 0.55:
		_set_state(State.FALL if not is_on_floor() else State.IDLE)


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if invulnerability_timer > 0.0 or state == State.DEAD:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()
		return
	invulnerability_timer = 1.0
	velocity = Vector2(signf(global_position.x - source_position.x) * 180.0, -220.0)
	_set_state(State.HURT)


func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


func bounce(strength: float = 460.0) -> void:
	velocity.y = -strength
	is_stomping = false
	_set_state(State.JUMP)


func _die() -> void:
	if state == State.DEAD:
		return
	_set_state(State.DEAD)
	collision_shape.set_deferred("disabled", true)
	velocity = Vector2(0.0, -280.0)
	GameManager.end_run()
	await get_tree().create_timer(1.35).timeout
	GameManager.respawn_player(self)


func restore_after_respawn() -> void:
	health = max_health
	stamina = max_stamina
	velocity = Vector2.ZERO
	invulnerability_timer = 1.5
	collision_shape.set_deferred("disabled", false)
	_set_state(State.IDLE)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	GameManager.run_active = true


func _on_time_expired() -> void:
	if state != State.DEAD:
		health = 0
		health_changed.emit(health, max_health)
		_die()


func _set_stamina(value: float) -> void:
	var previous := stamina
	stamina = clampf(value, 0.0, max_stamina)
	if not is_equal_approx(previous, stamina):
		stamina_changed.emit(stamina, max_stamina)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	if next_state != State.ATTACK:
		attack_projectile_pending = false
	state = next_state
	state_changed.emit(str(State.keys()[state]))
	_play_state_animation()


func _play_state_animation() -> void:
	match state:
		State.IDLE:
			sprite.play(&"idle")
		State.RUN:
			sprite.play(&"run")
		State.JUMP:
			sprite.play(&"jump")
		State.FALL:
			sprite.play(&"fall")
		State.ATTACK:
			sprite.play(&"attack")
		State.HURT:
			sprite.play(&"hurt")
		State.DEAD:
			sprite.play(&"hurt")
			sprite.frame = 1
			sprite.pause()


func _update_sprite_visual() -> void:
	sprite.flip_h = facing < 0.0
	sprite.visible = not (
		state != State.DEAD
		and invulnerability_timer > 0.0
		and int(invulnerability_timer * 16.0) % 2 == 0
	)


func _on_sprite_frame_changed() -> void:
	if state != State.ATTACK or not attack_projectile_pending or sprite.frame < 2:
		return
	attack_projectile_pending = false
	ObjectPool.acquire_projectile(
		global_position + Vector2(facing * 12.0, -5.0), facing, self
	)
