class_name ForestMechanic
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal power_changed(current: int, maximum: int)
signal state_changed(state_name: String)

enum State { IDLE, RUN, JUMP, FALL, ATTACK, HURT, DEAD }

const WALK_SPEED := 96.0
const RUN_SPEED := 168.0
const GROUND_ACCELERATION := 720.0
const RUN_ACCELERATION := 520.0
const TURN_ACCELERATION := 1500.0
const AIR_ACCELERATION := 420.0
const FRICTION := 900.0
const JUMP_VELOCITY := -345.0
const RUN_JUMP_BONUS := 42.0
const STOMP_VELOCITY := 460.0
const STOMP_HOP_VELOCITY := -190.0
const RISING_GRAVITY := 850.0
const RELEASE_GRAVITY := 1850.0
const FALLING_GRAVITY := 1250.0
const MAX_FALL_SPEED := 520.0
const COYOTE_TIME := 0.11
const JUMP_BUFFER_TIME := 0.12
const STOMP_BUFFER_TIME := 0.16
const SPRINT_DUST_INTERVAL := 0.09
const SKID_SPEED := 90.0
const STOMP_GRACE_TIME := 0.12
const DUST_LIMIT := 24
const DUST_COLOR := Color(0.62, 0.72, 0.6, 0.85)
const BIG_SCALE := 1.35
const SMALL_CAPSULE_HEIGHT := 25.0
const SMALL_CAPSULE_RADIUS := 8.0
const BIG_CAPSULE_HEIGHT := 37.0
const BIG_CAPSULE_RADIUS := 12.0

@export var max_health: int = 5
@export var max_stamina: float = 100.0

var health: int = 5
var stamina: float = 100.0
var state: State = State.IDLE
var facing: float = 1.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var stomp_buffer_timer: float = 0.0
var attack_timer: float = 0.0
var invulnerability_timer: float = 0.0
var attack_projectile_pending: bool = false
var is_stomping: bool = false
var controls_locked: bool = false
var sprint_dust_timer: float = 0.0
var stomp_grace_timer: float = 0.0
var stomp_chain: int = 0
var skid_dust_played: bool = false
var jump_was_pressed: bool = false
var attack_was_pressed: bool = false
var stomp_was_pressed: bool = false
var dust_count: int = 0
var is_big: bool = false
var has_orb_power: bool = false
var walk_speed := WALK_SPEED
var run_speed := RUN_SPEED
var jump_velocity := JUMP_VELOCITY
var dust_color := DUST_COLOR

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var attack_cooldown: Timer = $AttackCooldown


func _ready() -> void:
	add_to_group("player")
	_apply_character()
	SettingsManager.changed.connect(_apply_character)
	health = max_health
	stamina = max_stamina
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	power_changed.emit(get_power_level(), 2)
	GameManager.time_expired.connect(_on_time_expired)
	_play_state_animation()
	_update_sprite_visual()


func _apply_character() -> void:
	var character := SettingsManager.get_character()
	walk_speed = WALK_SPEED * character["speed"]
	run_speed = RUN_SPEED * character["speed"]
	jump_velocity = JUMP_VELOCITY * character["jump"]
	dust_color = character["dust"]
	_update_power_visual()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME


func _physics_process(delta: float) -> void:
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	stomp_buffer_timer = maxf(0.0, stomp_buffer_timer - delta)
	stomp_grace_timer = maxf(0.0, stomp_grace_timer - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	# TouchScreenButton changes the Input action state directly and does not
	# reliably emit an unhandled event or just-pressed flag on every platform.
	# Track the edge ourselves so keyboard, gamepad and touch behave identically.
	var jump_pressed := Input.is_action_pressed("jump")
	var jump_just_pressed := jump_pressed and not jump_was_pressed
	var jump_just_released := not jump_pressed and jump_was_pressed
	var attack_pressed := Input.is_action_pressed("attack")
	var attack_just_pressed := attack_pressed and not attack_was_pressed
	var stomp_pressed := Input.is_action_pressed("stomp")
	var stomp_just_pressed := stomp_pressed and not stomp_was_pressed
	jump_was_pressed = jump_pressed
	attack_was_pressed = attack_pressed
	stomp_was_pressed = stomp_pressed
	if jump_just_pressed:
		jump_buffer_timer = JUMP_BUFFER_TIME

	if state == State.DEAD:
		velocity.y = minf(velocity.y + FALLING_GRAVITY * delta, MAX_FALL_SPEED)
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

	var wants_run := Input.is_action_pressed("run") and not is_zero_approx(input_axis)
	var target_speed := (run_speed if wants_run else walk_speed) * input_axis
	var reversing := (
		is_on_floor()
		and not is_zero_approx(input_axis)
		and not is_zero_approx(velocity.x)
		and signf(input_axis) != signf(velocity.x)
	)
	if is_on_floor() and is_zero_approx(input_axis):
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		skid_dust_played = false
	elif reversing:
		velocity.x = move_toward(velocity.x, target_speed, TURN_ACCELERATION * delta)
		if absf(velocity.x) >= SKID_SPEED and not skid_dust_played:
			skid_dust_played = true
			_spawn_dust(Vector2(-signf(velocity.x) * 7.0, 10.0), 6.0)
	else:
		var acceleration := AIR_ACCELERATION
		if is_on_floor():
			acceleration = RUN_ACCELERATION if wants_run else GROUND_ACCELERATION
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		skid_dust_played = false

	# Running is unlimited, like a classic platformer. Energy is reserved for
	# the original orb ability, so holding run never interrupts a long jump.
	_set_stamina(stamina + 18.0 * delta)
	if wants_run and is_on_floor() and absf(velocity.x) > walk_speed * 0.9:
		sprint_dust_timer -= delta
		if sprint_dust_timer <= 0.0:
			sprint_dust_timer = SPRINT_DUST_INTERVAL
			_spawn_dust(Vector2(-facing * 7.0, 9.0), 4.0)
	else:
		sprint_dust_timer = 0.0
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
		_apply_gravity(delta)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		var run_ratio := clampf(absf(velocity.x) / maxf(run_speed, 1.0), 0.0, 1.0)
		velocity.y = jump_velocity - RUN_JUMP_BONUS * run_ratio
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		is_stomping = false
		AudioManager.play("jump")
		_spawn_dust(Vector2(0.0, 10.0), 5.0)
		_set_state(State.JUMP)

	if jump_just_released and velocity.y < -120.0:
		velocity.y *= 0.46

	if stomp_just_pressed:
		stomp_buffer_timer = STOMP_BUFFER_TIME
		if is_on_floor():
			# Ground pound: a quick hop that always gives the key a visible reaction.
			velocity.y = STOMP_HOP_VELOCITY
			is_stomping = true
			AudioManager.play("stomp")
			_spawn_dust(Vector2(0.0, 11.0), 5.0)
			_set_state(State.FALL)
		elif stomp_buffer_timer > 0.0:
			velocity.y = STOMP_VELOCITY
			is_stomping = true
			AudioManager.play("stomp")
			_set_state(State.FALL)

	if attack_just_pressed:
		_try_attack()

	move_and_slide()
	_handle_slide_collisions()
	_bump_blocks_from_below()
	if not was_on_floor and is_on_floor():
		# Landing feedback: bigger puff when finishing a stomp/ground pound.
		AudioManager.play("stomp" if is_stomping else "land")
		_spawn_dust(Vector2(0.0, 11.0), 7.0 if is_stomping else 4.0)
		if is_stomping:
			is_stomping = false
		stomp_chain = 0

	if attack_timer <= 0.0:
		_update_locomotion_state(input_axis)
	_update_sprite_visual()


func _apply_gravity(delta: float) -> void:
	var gravity := FALLING_GRAVITY
	if velocity.y < 0.0:
		gravity = RISING_GRAVITY if Input.is_action_pressed("jump") else RELEASE_GRAVITY
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)


func _try_attack() -> void:
	if (
		not has_orb_power
		or state == State.ATTACK
		or not attack_cooldown.is_stopped()
		or ObjectPool.active_projectile_count(self) >= 2
	):
		return
	attack_cooldown.start()
	attack_timer = 0.34
	attack_projectile_pending = true
	AudioManager.play("attack")
	_set_state(State.ATTACK)


func _bump_blocks_from_below() -> void:
	for index: int in get_slide_collision_count():
		var hit := get_slide_collision(index)
		var collider := hit.get_collider() as Node2D
		if collider == null or not collider.is_in_group("blocks"):
			continue
		# Ceiling hit: the collision normal points down when hitting a block
		# from below while moving upward.
		if hit.get_normal().y > 0.5 and collider.has_method("bump_by_player"):
			collider.bump_by_player(self)


func _handle_slide_collisions() -> void:
	for index: int in get_slide_collision_count():
		var hit := get_slide_collision(index)
		var collider := hit.get_collider() as Node2D
		if collider == null or not collider.is_in_group("enemies"):
			continue
		handle_enemy_contact(collider)


func handle_enemy_contact(enemy: Node2D) -> void:
	if state == State.DEAD or enemy == null:
		return
	if enemy is PooledEnemy and not enemy.active:
		return
	# A short grace window prevents the enemy's own physics pass from turning a
	# successful stomp into damage on the following frame.
	if stomp_grace_timer > 0.0 and velocity.y < 0.0:
		return
	var feet_above_enemy := global_position.y <= enemy.global_position.y - 4.0
	var can_stomp := (velocity.y > 35.0 or is_stomping) and feet_above_enemy
	if not can_stomp:
		take_damage(1, enemy.global_position)
		return
	if enemy.has_method("take_damage"):
		enemy.take_damage(2 if is_stomping else 1, true)
	stomp_chain += 1
	var chain_score := mini(100 * int(pow(2, mini(stomp_chain - 1, 3))), 800)
	GameManager.add_score(chain_score)
	velocity.y = -275.0 if Input.is_action_pressed("jump") else -225.0
	is_stomping = false
	stomp_grace_timer = STOMP_GRACE_TIME
	AudioManager.play("stomp")


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
	if has_orb_power:
		lose_orb_power()
		_hurt_visual_feedback(source_position)
		velocity = Vector2(signf(global_position.x - source_position.x) * 130.0, -220.0)
		_set_state(State.HURT)
		return
	if is_big:
		# Big form absorbs one hit by shrinking back to small.
		shrink()
		_hurt_visual_feedback(source_position)
		velocity = Vector2(signf(global_position.x - source_position.x) * 130.0, -220.0)
		_set_state(State.HURT)
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0:
		AudioManager.play("death")
		_die()
		return
	invulnerability_timer = 1.0
	AudioManager.play("hurt")
	_hurt_visual_feedback(source_position)
	velocity = Vector2(signf(global_position.x - source_position.x) * 130.0, -220.0)
	_set_state(State.HURT)


func _hurt_visual_feedback(source_position: Vector2) -> void:
	# Flash the attacker and mark the hit location so the player can see
	# what damaged them even after the knockback.
	var nearest: Node2D = null
	var nearest_dist := 130.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or enemy.get("active") != true:
			continue
		var dist := enemy.global_position.distance_to(source_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	if nearest != null and nearest.has_method("notify_attack"):
		nearest.notify_attack()
	if source_position != Vector2.ZERO and get_tree().current_scene != null:
		var marker := load("res://world/damage_marker.tscn").instantiate() as Node2D
		marker.global_position = source_position
		get_tree().current_scene.add_child(marker)


func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


func grow() -> void:
	if is_big:
		return
	is_big = true
	AudioManager.play("grow")
	sprite.scale = Vector2(BIG_SCALE, BIG_SCALE)
	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule != null:
		capsule.height = BIG_CAPSULE_HEIGHT
		capsule.radius = BIG_CAPSULE_RADIUS
	power_changed.emit(get_power_level(), 2)
	GameManager.set_carried_power_level(get_power_level())
	_spawn_dust(Vector2(0.0, 12.0), 7.0)
	_spawn_dust(Vector2(-5.0, 10.0), 5.0)
	_spawn_dust(Vector2(5.0, 10.0), 5.0)


func shrink() -> void:
	if not is_big:
		return
	is_big = false
	has_orb_power = false
	AudioManager.play("shrink")
	sprite.scale = Vector2.ONE
	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule != null:
		capsule.height = SMALL_CAPSULE_HEIGHT
		capsule.radius = SMALL_CAPSULE_RADIUS
	invulnerability_timer = 1.2
	_update_power_visual()
	power_changed.emit(get_power_level(), 2)
	GameManager.set_carried_power_level(get_power_level())
	_spawn_dust(Vector2(0.0, 10.0), 5.0)


func grant_orb_power() -> void:
	if not is_big:
		grow()
	if has_orb_power:
		GameManager.add_score(500)
		return
	has_orb_power = true
	invulnerability_timer = 0.5
	AudioManager.play("power")
	_update_power_visual()
	power_changed.emit(get_power_level(), 2)
	GameManager.set_carried_power_level(get_power_level())
	_spawn_dust(Vector2(0.0, 4.0), 9.0)


func lose_orb_power() -> void:
	if not has_orb_power:
		return
	has_orb_power = false
	invulnerability_timer = 1.2
	AudioManager.play("shrink")
	_update_power_visual()
	power_changed.emit(get_power_level(), 2)
	GameManager.set_carried_power_level(get_power_level())


func get_power_level() -> int:
	if has_orb_power:
		return 2
	return 1 if is_big else 0


func _update_power_visual() -> void:
	var base_tint: Color = SettingsManager.get_character()["tint"]
	sprite.self_modulate = base_tint.lerp(Color("76e8f4"), 0.38) if has_orb_power else base_tint


func restore_power_level(level: int) -> void:
	level = clampi(level, 0, 2)
	is_big = level >= 1
	has_orb_power = level >= 2
	sprite.scale = Vector2(BIG_SCALE, BIG_SCALE) if is_big else Vector2.ONE
	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule != null:
		capsule.height = BIG_CAPSULE_HEIGHT if is_big else SMALL_CAPSULE_HEIGHT
		capsule.radius = BIG_CAPSULE_RADIUS if is_big else SMALL_CAPSULE_RADIUS
	_update_power_visual()
	power_changed.emit(get_power_level(), 2)


func bounce(strength: float = 460.0) -> void:
	velocity.y = -strength
	is_stomping = false
	_set_state(State.JUMP)


func play_flagpole_finish(pole_x: float, ground_y: float, slide_time: float) -> void:
	controls_locked = true
	velocity = Vector2.ZERO
	facing = 1.0
	set_physics_process(false)
	global_position.x = pole_x - 8.0
	sprite.flip_h = false
	sprite.play(&"idle")
	var slide := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slide.tween_property(self, "global_position:y", ground_y - 14.0, slide_time)
	await slide.finished
	sprite.play(&"run")
	var walk := create_tween().set_trans(Tween.TRANS_LINEAR)
	walk.tween_property(self, "global_position:x", pole_x + 48.0, 0.55)
	await walk.finished
	sprite.play(&"idle")


func _die() -> void:
	if state == State.DEAD:
		return
	_set_state(State.DEAD)
	collision_shape.set_deferred("disabled", true)
	velocity = Vector2(0.0, -280.0)
	GameManager.set_carried_power_level(0)
	GameManager.end_run()
	await get_tree().create_timer(1.35).timeout
	GameManager.respawn_player(self)


func restore_after_respawn() -> void:
	health = max_health
	stamina = max_stamina
	velocity = Vector2.ZERO
	invulnerability_timer = 1.5
	stomp_chain = 0
	stomp_grace_timer = 0.0
	jump_was_pressed = Input.is_action_pressed("jump")
	attack_was_pressed = Input.is_action_pressed("attack")
	stomp_was_pressed = Input.is_action_pressed("stomp")
	controls_locked = false
	set_physics_process(true)
	if is_big:
		is_big = false
		has_orb_power = false
		sprite.scale = Vector2.ONE
		var capsule := collision_shape.shape as CapsuleShape2D
		if capsule != null:
			capsule.height = SMALL_CAPSULE_HEIGHT
			capsule.radius = SMALL_CAPSULE_RADIUS
	else:
		has_orb_power = false
	collision_shape.set_deferred("disabled", false)
	_update_power_visual()
	GameManager.set_carried_power_level(0)
	_set_state(State.IDLE)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	power_changed.emit(get_power_level(), 2)
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


func _spawn_dust(local_offset: Vector2, size: float) -> void:
	if dust_count >= DUST_LIMIT:
		return
	var dust := Sprite2D.new()
	dust.texture = PixelArt.circle_texture(dust_color, 8)
	dust.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dust.position = global_position + local_offset
	dust.scale = Vector2(size, size) / 8.0
	dust.z_index = 4
	dust.modulate.a = 0.85
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		return
	scene_root.add_child(dust)
	dust_count += 1
	var tween := create_tween()
	tween.tween_property(dust, "scale", dust.scale * 1.7, 0.38)
	tween.parallel().tween_property(dust, "modulate:a", 0.0, 0.38)
	tween.tween_callback(func() -> void:
		dust_count -= 1
		dust.queue_free()
	)
