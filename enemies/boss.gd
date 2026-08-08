class_name GearheartGuardian
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal defeated

enum Phase { WATCH, CHARGE, LEAP, SUMMON, DEFEATED }

@export var max_health: int = 20

var health: int = 20
var phase: Phase = Phase.WATCH
var phase_timer: float = 1.5
var direction: float = -1.0
var summon_count: int = 0
var invulnerable_timer: float = 0.0
var age: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if phase == Phase.DEFEATED:
		velocity.y += 700.0 * delta
		move_and_slide()
		rotation += delta * 2.0
		return
	age += delta
	phase_timer -= delta
	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		direction = signf(player.global_position.x - global_position.x)
	match phase:
		Phase.WATCH:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if phase_timer <= 0.0:
				_choose_attack()
		Phase.CHARGE:
			velocity.x = direction * (175.0 if health > max_health / 2 else 225.0)
			if is_on_wall() or phase_timer <= 0.0:
				_enter_phase(Phase.WATCH, 1.0)
		Phase.LEAP:
			if is_on_floor() and phase_timer < 0.65:
				velocity = Vector2(direction * 95.0, -360.0)
				phase_timer = 0.6
			elif phase_timer <= 0.0:
				_enter_phase(Phase.WATCH, 0.8)
		Phase.SUMMON:
			velocity.x = 0.0
			if summon_count < 2 and phase_timer < 1.4 - summon_count * 0.45:
				ObjectPool.acquire_enemy(PooledEnemy.Kind.GEARWING, global_position + Vector2((summon_count * 2 - 1) * 42, -40), 95.0)
				summon_count += 1
			if phase_timer <= 0.0:
				_enter_phase(Phase.WATCH, 0.9)
	velocity.y = minf(velocity.y + 980.0 * delta, 500.0)
	move_and_slide()
	_handle_contacts()
	queue_redraw()


func _choose_attack() -> void:
	var options: Array[Phase] = [Phase.CHARGE, Phase.LEAP, Phase.SUMMON]
	var choice := options[randi() % options.size()]
	_enter_phase(choice, 1.8 if choice != Phase.LEAP else 0.9)


func _enter_phase(next_phase: Phase, duration: float) -> void:
	phase = next_phase
	phase_timer = duration
	if phase == Phase.SUMMON:
		summon_count = 0


func _handle_contacts() -> void:
	for index: int in get_slide_collision_count():
		var body := get_slide_collision(index).get_collider() as Node
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(1, global_position)


func take_damage(amount: int, stomped: bool = false) -> void:
	if phase == Phase.DEFEATED or invulnerable_timer > 0.0:
		return
	health = maxi(0, health - amount)
	invulnerable_timer = 0.12
	health_changed.emit(health, max_health)
	if stomped:
		velocity.x = -direction * 80.0
	if health <= 0:
		_defeat()


func _defeat() -> void:
	phase = Phase.DEFEATED
	collision_shape.set_deferred("disabled", true)
	velocity = Vector2(0, -260)
	GameManager.add_score(5000)
	defeated.emit()


func _draw() -> void:
	var flash := invulnerable_timer > 0.0
	var metal := Color.WHITE if flash else Color("46636b")
	# Original Gearheart Guardian: a squat antlered walking engine.
	PixelArt.rect(self, Vector2(-18, -18), Vector2(36, 28), Color("1d2b32"))
	PixelArt.rect(self, Vector2(-15, -16), Vector2(30, 23), metal)
	PixelArt.diamond(self, Vector2(0, -5), 8.0, Color("e0714b"))
	PixelArt.diamond(self, Vector2(0, -5), 4.0, Color("ffcf5c"))
	PixelArt.rect(self, Vector2(-24, -23), Vector2(10, 4), Color("8ca3a6"))
	PixelArt.rect(self, Vector2(14, -23), Vector2(10, 4), Color("8ca3a6"))
	PixelArt.rect(self, Vector2(-24, -30), Vector2(4, 10), Color("8ca3a6"))
	PixelArt.rect(self, Vector2(20, -30), Vector2(4, 10), Color("8ca3a6"))
	PixelArt.rect(self, Vector2(-15, 8), Vector2(10, 8), Color("27363c"))
	PixelArt.rect(self, Vector2(5, 8), Vector2(10, 8), Color("27363c"))
	PixelArt.rect(self, Vector2(direction * 10.0 - 2, -11), Vector2(4, 3), Color("b9fff2"))

