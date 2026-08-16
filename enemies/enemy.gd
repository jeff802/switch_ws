class_name PooledEnemy
extends CharacterBody2D

signal defeated(enemy: PooledEnemy)

enum Kind { BEETLE_BOT, BOUNCECAP, GEARWING, WADDLEDUCK, SHELLBACK }
enum TurtleState { WALKING, SHELL_IDLE, SHELL_SLIDING }

const GRAVITY := 980.0
const SHELL_WAKE_TIME := 4.5
const SHELL_SPEED := 235.0

var kind: Kind = Kind.BEETLE_BOT
var health: int = 2
var active: bool = false
var spawn_position: Vector2
var patrol_distance: float = 80.0
var direction: float = -1.0
var action_timer: float = 0.0
var age: float = 0.0
var hit_flash: float = 0.0
var turtle_state: TurtleState = TurtleState.WALKING
var shell_timer: float = 0.0
var difficulty_speed_scale: float = 1.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")


func activate(new_kind: Kind, origin: Vector2, new_patrol_distance: float) -> void:
	kind = new_kind
	spawn_position = origin
	global_position = origin
	patrol_distance = new_patrol_distance
	match kind:
		Kind.BEETLE_BOT:
			health = 3
		Kind.BOUNCECAP, Kind.WADDLEDUCK:
			health = 1
		Kind.SHELLBACK:
			health = 2
		_:
			health = 2
	var difficulty := SettingsManager.get_difficulty()
	difficulty_speed_scale = float(difficulty["enemy_speed"])
	health = maxi(1, ceili(float(health) * float(difficulty["enemy_health"])))
	direction = -1.0
	action_timer = 0.8
	age = 0.0
	turtle_state = TurtleState.WALKING
	shell_timer = 0.0
	active = true
	visible = true
	collision_mask = 3
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", false)
	set_physics_process(true)
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	collision_mask = 3
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
		Kind.WADDLEDUCK:
			_update_waddleduck(delta)
		Kind.SHELLBACK:
			_update_shellback(delta)
	queue_redraw()


func _update_beetle(delta: float) -> void:
	velocity.x = direction * 48.0 * difficulty_speed_scale
	velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	move_and_slide()
	if is_on_wall() or absf(global_position.x - spawn_position.x) > patrol_distance:
		direction *= -1.0
	_handle_player_contacts()


func _update_bouncecap(delta: float) -> void:
	action_timer -= delta
	velocity.x = direction * 42.0 * difficulty_speed_scale
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
	global_position.y = move_toward(global_position.y, center_y, 65.0 * difficulty_speed_scale * delta)
	if player != null and global_position.distance_to(player.global_position) < 190.0:
		direction = signf(player.global_position.x - global_position.x)
	global_position.x += direction * 42.0 * difficulty_speed_scale * delta
	if absf(global_position.x - spawn_position.x) > patrol_distance:
		direction *= -1.0
	_handle_overlapping_player()


func _update_waddleduck(delta: float) -> void:
	# 发条鸭会在玩家靠近时加快脚步，并用短跳改变地面敌人的单一节奏。
	action_timer -= delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var is_alert := player != null and global_position.distance_to(player.global_position) < 145.0
	if is_alert and absf(player.global_position.x - global_position.x) > 24.0:
		direction = signf(player.global_position.x - global_position.x)
	velocity.x = direction * (72.0 if is_alert else 48.0) * difficulty_speed_scale
	velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	if is_on_floor() and action_timer <= 0.0:
		velocity.y = -185.0
		action_timer = 1.45 if is_alert else 2.2
	move_and_slide()
	if is_on_wall() or absf(global_position.x - spawn_position.x) > patrol_distance:
		direction *= -1.0
		action_timer = maxf(action_timer, 0.35)
	_handle_player_contacts()


func _update_shellback(delta: float) -> void:
	match turtle_state:
		TurtleState.WALKING:
			collision_mask = 3
			velocity.x = direction * 34.0 * difficulty_speed_scale
			velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
			move_and_slide()
			if is_on_wall() or absf(global_position.x - spawn_position.x) > patrol_distance:
				direction *= -1.0
			_handle_player_contacts()
		TurtleState.SHELL_IDLE:
			collision_mask = 3
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
			move_and_slide()
			shell_timer -= delta
			_handle_player_contacts()
			if shell_timer <= 0.0 and turtle_state == TurtleState.SHELL_IDLE:
				_emerge_from_shell()
		TurtleState.SHELL_SLIDING:
			_update_sliding_shell(delta)


func _update_sliding_shell(delta: float) -> void:
	collision_mask = 7
	velocity.x = direction * SHELL_SPEED * difficulty_speed_scale
	velocity.y = minf(velocity.y + GRAVITY * delta, 460.0)
	move_and_slide()
	var hit_solid_wall := false
	for index: int in get_slide_collision_count():
		var hit := get_slide_collision(index)
		var collider := hit.get_collider() as Node
		if collider == null:
			continue
		if collider.is_in_group("player") and collider.has_method("handle_enemy_contact"):
			collider.handle_enemy_contact(self, -hit.get_normal())
		elif collider.is_in_group("enemies") and collider != self and collider.has_method("take_damage"):
			# 普通敌人会被龟壳直接撞倒；首领只承受一次普通重击，避免连续贴身秒杀。
			if collider is PooledEnemy:
				var pooled_target := collider as PooledEnemy
				var target_was_active: bool = pooled_target.active
				pooled_target.take_damage(999, false)
				if target_was_active:
					GameManager.add_score(200)
			else:
				collider.take_damage(2, false)
			direction *= -1.0
			AudioManager.play("bump")
		elif absf(hit.get_normal().x) > 0.55:
			hit_solid_wall = true
	if hit_solid_wall:
		direction *= -1.0
		AudioManager.play("bump")


func is_waiting_shell() -> bool:
	return kind == Kind.SHELLBACK and turtle_state == TurtleState.SHELL_IDLE


func is_sliding_shell() -> bool:
	return kind == Kind.SHELLBACK and turtle_state == TurtleState.SHELL_SLIDING


func kick_shell(kicker: Node2D) -> void:
	if not is_waiting_shell():
		return
	var away_from_kicker := global_position.x - kicker.global_position.x
	if absf(away_from_kicker) < 2.0:
		var kicker_facing: Variant = kicker.get("facing")
		direction = float(kicker_facing) if kicker_facing != null else 1.0
	else:
		direction = signf(away_from_kicker)
	turtle_state = TurtleState.SHELL_SLIDING
	shell_timer = 0.0
	collision_mask = 7
	velocity = Vector2(direction * SHELL_SPEED * difficulty_speed_scale, 0.0)
	AudioManager.play("stomp")
	GameManager.add_score(50)
	queue_redraw()


func _enter_shell_idle() -> void:
	turtle_state = TurtleState.SHELL_IDLE
	shell_timer = SHELL_WAKE_TIME
	collision_mask = 3
	velocity.x = 0.0
	AudioManager.play("stomp")
	queue_redraw()


func _emerge_from_shell() -> void:
	turtle_state = TurtleState.WALKING
	shell_timer = 0.0
	collision_mask = 3
	velocity.x = direction * 34.0 * difficulty_speed_scale
	queue_redraw()


func _handle_player_contacts() -> void:
	for index: int in get_slide_collision_count():
		var hit := get_slide_collision(index)
		var body := hit.get_collider() as Node
		if body != null and body.is_in_group("player") and body.has_method("handle_enemy_contact"):
			body.handle_enemy_contact(self, -hit.get_normal())


func _handle_overlapping_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) < 18.0 and player.has_method("handle_enemy_contact"):
		player.handle_enemy_contact(self)


func take_damage(amount: int, stomped: bool = false) -> void:
	if not active:
		return
	if kind == Kind.SHELLBACK and stomped:
		# 第一次踩踏缩壳；滑行中的龟壳被再次从上方踩中则停下。
		if turtle_state == TurtleState.WALKING or turtle_state == TurtleState.SHELL_SLIDING:
			_enter_shell_idle()
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
		Kind.WADDLEDUCK:
			_draw_waddleduck()
		Kind.SHELLBACK:
			_draw_shellback()
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


func _draw_waddleduck() -> void:
	var foot_step := 1.0 if int(age * 9.0) % 2 == 0 else 0.0
	var outline := Color("101820")
	# 原创发条鸭：铜黄机身、扁嘴、背部上弦钥匙和交替迈步的小脚。
	PixelArt.rect(self, Vector2(-10, -8), Vector2(19, 15), outline)
	PixelArt.rect(self, Vector2(-8, -7), Vector2(15, 12), Color("d99a35"))
	PixelArt.rect(self, Vector2(-5, -10), Vector2(10, 8), outline)
	PixelArt.rect(self, Vector2(-4, -9), Vector2(8, 7), Color("f2be4f"))
	var beak_x := 7.0 if direction > 0.0 else -14.0
	PixelArt.rect(self, Vector2(beak_x, -6), Vector2(7, 4), Color("ef7841"))
	PixelArt.rect(self, Vector2(direction * 2.0 - 1, -7), Vector2(2, 2), Color("15222a"))
	PixelArt.rect(self, Vector2(-2, -14), Vector2(3, 5), Color("8aa0a5"))
	PixelArt.rect(self, Vector2(-5, -15), Vector2(9, 2), Color("b9c9cc"))
	PixelArt.rect(self, Vector2(-8, 6 + foot_step), Vector2(6, 3), outline)
	PixelArt.rect(self, Vector2(3, 7 - foot_step), Vector2(6, 3), outline)


func _draw_shellback() -> void:
	var outline := Color("101820")
	var shell_dark := Color("376b4c")
	var shell_light := Color("69a85e")
	if turtle_state == TurtleState.SHELL_SLIDING:
		var streak_direction := -direction
		PixelArt.rect(self, Vector2(streak_direction * 13.0 - 4.0, -3), Vector2(7, 2), Color("d6f2dd"))
		PixelArt.rect(self, Vector2(streak_direction * 17.0 - 3.0, 2), Vector2(5, 2), Color("8fd6ae"))
	# 龟壳在三种状态下始终保持相同轮廓，便于玩家识别其碰撞范围。
	PixelArt.rect(self, Vector2(-11, -8), Vector2(22, 16), outline)
	PixelArt.rect(self, Vector2(-9, -7), Vector2(18, 13), shell_dark)
	PixelArt.rect(self, Vector2(-6, -6), Vector2(12, 9), shell_light)
	PixelArt.rect(self, Vector2(-2, -5), Vector2(4, 8), Color("b2d27a"))
	PixelArt.rect(self, Vector2(-7, -1), Vector2(14, 3), Color("2f5a43"))
	if turtle_state != TurtleState.WALKING:
		PixelArt.rect(self, Vector2(-8, 7), Vector2(16, 3), outline)
		return
	var head_x := 9.0 if direction > 0.0 else -15.0
	PixelArt.rect(self, Vector2(head_x, -5), Vector2(6, 9), outline)
	PixelArt.rect(self, Vector2(head_x + 1, -4), Vector2(4, 7), Color("d6b65f"))
	PixelArt.rect(self, Vector2(head_x + (4 if direction > 0.0 else 1), -2), Vector2(1, 2), Color("17242c"))
	PixelArt.rect(self, Vector2(-9, 7), Vector2(6, 3), outline)
	PixelArt.rect(self, Vector2(3, 7), Vector2(6, 3), outline)
