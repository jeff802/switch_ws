class_name GearheartGuardian
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal engaged
signal defeated

enum Variant {
	CAVERN_DRILLER,
	THORN_REACTOR,
	GEARHEART,
	STORM_FORGE,
	MAGMA_COLOSSUS,
	FROST_CROWN,
	CHRONO_SOVEREIGN,
}
enum Phase { WATCH, CHARGE, LEAP, SUMMON, VOLLEY, DEFEATED }

const BOSS_BOLT_SCENE := preload("res://projectiles/boss_bolt.tscn")

@export var max_health: int = 20
@export var boss_variant: Variant = Variant.GEARHEART
@export var activation_distance: float = 330.0

var display_name: String = "齿轮核心守卫"
var health: int = 20
var phase: Phase = Phase.WATCH
var phase_timer: float = 1.0
var direction: float = -1.0
var summon_count: int = 0
var invulnerable_timer: float = 0.0
var age: float = 0.0
var activated: bool = false
var attack_cursor: int = 0
var phase_action_done: bool = false
var volley_fired: bool = false
var difficulty_skill_tier: int = 1
var difficulty_speed_scale: float = 1.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	var difficulty := SettingsManager.get_difficulty()
	difficulty_skill_tier = int(difficulty["skill_tier"])
	difficulty_speed_scale = float(difficulty["boss_speed"])
	max_health = maxi(1, ceili(float(max_health) * float(difficulty["boss_health"])))
	display_name = _variant_name()
	health = max_health
	health_changed.emit(health, max_health)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if phase == Phase.DEFEATED:
		velocity.y += 700.0 * delta
		move_and_slide()
		rotation += delta * 2.0
		return
	age += delta
	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not activated:
		velocity.x = 0.0
		velocity.y = minf(velocity.y + 980.0 * delta, 500.0)
		move_and_slide()
		if player != null and global_position.distance_to(player.global_position) <= activation_distance:
			_activate()
		queue_redraw()
		return
	phase_timer -= delta
	if player != null and absf(player.global_position.x - global_position.x) > 2.0:
		direction = signf(player.global_position.x - global_position.x)
	match phase:
		Phase.WATCH:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if phase_timer <= 0.0:
				_choose_attack()
		Phase.CHARGE:
			velocity.x = direction * _charge_speed()
			if is_on_wall() or phase_timer <= 0.0:
				_enter_phase(Phase.WATCH, _watch_time())
		Phase.LEAP:
			_update_leap()
		Phase.SUMMON:
			_update_summon()
		Phase.VOLLEY:
			_update_volley()
	velocity.y = minf(velocity.y + 980.0 * delta, 500.0)
	move_and_slide()
	_handle_contacts()
	queue_redraw()


func _activate() -> void:
	if activated or phase == Phase.DEFEATED:
		return
	activated = true
	phase_timer = 0.75
	engaged.emit()
	AudioManager.play("checkpoint")


func _choose_attack() -> void:
	var sequence: Array[Phase]
	match boss_variant:
		Variant.CAVERN_DRILLER:
			sequence = [Phase.CHARGE, Phase.LEAP, Phase.SUMMON]
		Variant.THORN_REACTOR:
			sequence = [Phase.VOLLEY, Phase.CHARGE, Phase.SUMMON, Phase.VOLLEY]
		Variant.GEARHEART:
			sequence = [Phase.CHARGE, Phase.LEAP, Phase.VOLLEY, Phase.SUMMON]
		Variant.STORM_FORGE:
			sequence = [Phase.VOLLEY, Phase.LEAP, Phase.CHARGE, Phase.VOLLEY]
		Variant.MAGMA_COLOSSUS:
			sequence = [Phase.LEAP, Phase.CHARGE, Phase.SUMMON, Phase.LEAP]
		Variant.FROST_CROWN:
			sequence = [Phase.VOLLEY, Phase.SUMMON, Phase.LEAP, Phase.VOLLEY]
		_:
			sequence = [Phase.CHARGE, Phase.VOLLEY, Phase.SUMMON, Phase.LEAP, Phase.VOLLEY]
	if difficulty_skill_tier == 0:
		sequence.erase(Phase.SUMMON)
	elif difficulty_skill_tier >= 2:
		sequence.append(Phase.VOLLEY)
	if health <= max_health / 2:
		match boss_variant:
			Variant.CAVERN_DRILLER: sequence.append(Phase.LEAP)
			Variant.THORN_REACTOR: sequence.append(Phase.VOLLEY)
			_: sequence.append_array([Phase.CHARGE, Phase.VOLLEY])
	var choice: Phase = sequence[attack_cursor % sequence.size()]
	attack_cursor += 1
	_enter_phase(choice, _phase_duration(choice))


func _phase_duration(next_phase: Phase) -> float:
	match next_phase:
		Phase.CHARGE: return 1.35 if boss_variant == Variant.GEARHEART else 1.55
		Phase.LEAP: return 1.8
		Phase.SUMMON: return 2.0
		Phase.VOLLEY: return 1.25
		_: return _watch_time()


func _watch_time() -> float:
	var base := 0.9 if boss_variant == Variant.CAVERN_DRILLER else 0.78
	return base * (0.72 if health <= max_health / 2 else 1.0) / difficulty_speed_scale


func _charge_speed() -> float:
	var base := 175.0
	match boss_variant:
		Variant.CAVERN_DRILLER: base = 205.0
		Variant.THORN_REACTOR: base = 155.0
		Variant.GEARHEART: base = 220.0
		Variant.STORM_FORGE: base = 190.0
		Variant.MAGMA_COLOSSUS: base = 238.0
		Variant.FROST_CROWN: base = 172.0
		Variant.CHRONO_SOVEREIGN: base = 248.0
	return base * (1.18 if health <= max_health / 2 else 1.0) * difficulty_speed_scale


func _update_leap() -> void:
	if not phase_action_done and is_on_floor():
		velocity = Vector2(direction * (110.0 if boss_variant != Variant.THORN_REACTOR else 82.0), -365.0)
		phase_action_done = true
		return
	if phase_action_done and is_on_floor() and velocity.y >= 0.0:
		_spawn_landing_burst()
		_enter_phase(Phase.WATCH, _watch_time())
	elif phase_timer <= 0.0:
		_enter_phase(Phase.WATCH, _watch_time())


func _update_summon() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 700.0 * get_physics_process_delta_time())
	var target_count := 2
	if health <= max_health / 2 or difficulty_skill_tier >= 2:
		target_count += 1
	if difficulty_skill_tier == 0:
		target_count = 1
	if summon_count < target_count and phase_timer < 1.55 - summon_count * 0.45:
		_spawn_summoned_hazard(summon_count)
		summon_count += 1
	if phase_timer <= 0.0:
		_enter_phase(Phase.WATCH, _watch_time())


func _spawn_summoned_hazard(index: int) -> void:
	match boss_variant:
		Variant.CAVERN_DRILLER:
			var player := get_tree().get_first_node_in_group("player") as Node2D
			var target_x := global_position.x + direction * 50.0
			if player != null:
				target_x = player.global_position.x + (float(index) - 0.5) * 42.0
			_spawn_bolt(Vector2(target_x, 32.0), Vector2(0, 55.0), BossBolt.Style.STONE, 690.0)
		Variant.THORN_REACTOR:
			var kind := PooledEnemy.Kind.BOUNCECAP if index % 2 == 0 else PooledEnemy.Kind.WADDLEDUCK
			ObjectPool.acquire_enemy(kind, global_position + Vector2((index * 2 - 1) * 42, -18), 58.0)
		Variant.GEARHEART:
			ObjectPool.acquire_enemy(
				PooledEnemy.Kind.GEARWING,
				global_position + Vector2((index * 2 - 1) * 42, -42),
				105.0
			)
		Variant.STORM_FORGE:
			_spawn_bolt(global_position + Vector2((index * 2 - 1) * 28, -34), Vector2(direction * 125.0, -115.0), BossBolt.Style.LIGHTNING, 340.0)
		Variant.MAGMA_COLOSSUS:
			_spawn_bolt(global_position + Vector2((index * 2 - 1) * 24, -18), Vector2((index * 2 - 1) * 72.0, -245.0), BossBolt.Style.MAGMA, 620.0)
		Variant.FROST_CROWN:
			ObjectPool.acquire_enemy(PooledEnemy.Kind.SHELLBACK, global_position + Vector2((index * 2 - 1) * 46, -20), 66.0)
		_:
			var kind := PooledEnemy.Kind.GEARWING if index % 2 == 0 else PooledEnemy.Kind.BEETLE_BOT
			ObjectPool.acquire_enemy(kind, global_position + Vector2((index * 2 - 1) * 46, -35), 115.0)


func _update_volley() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 700.0 * get_physics_process_delta_time())
	if not volley_fired and phase_timer < 0.78:
		volley_fired = true
		_fire_volley()
	if phase_timer <= 0.0:
		_enter_phase(Phase.WATCH, _watch_time())


func _fire_volley() -> void:
	match boss_variant:
		Variant.CAVERN_DRILLER:
			_spawn_landing_burst()
		Variant.THORN_REACTOR:
			for y_speed: float in [-105.0, -35.0, 35.0]:
				_spawn_bolt(global_position + Vector2(direction * 18, -8), Vector2(direction * 165.0, y_speed), BossBolt.Style.SEED, 170.0)
		Variant.GEARHEART:
			var spread: Array = [-120.0, -60.0, 0.0, 60.0, 120.0] if health <= max_health / 2 else [-75.0, 0.0, 75.0]
			for y_speed: float in spread:
				_spawn_bolt(global_position + Vector2(direction * 18, -9), Vector2(direction * 195.0, y_speed), BossBolt.Style.GEAR)
		Variant.STORM_FORGE:
			_fire_styled_spread(BossBolt.Style.LIGHTNING, 210.0, 4 if difficulty_skill_tier >= 2 else 3, 62.0)
		Variant.MAGMA_COLOSSUS:
			for side: float in [-1.0, 0.0, 1.0]:
				_spawn_bolt(global_position + Vector2(side * 12.0, -14), Vector2(side * 110.0, -250.0), BossBolt.Style.MAGMA, 650.0)
		Variant.FROST_CROWN:
			_fire_styled_spread(BossBolt.Style.FROST, 188.0, 5 if difficulty_skill_tier >= 2 else 3, 48.0)
		_:
			_fire_styled_spread(BossBolt.Style.CHRONO, 235.0, 7 if difficulty_skill_tier >= 2 else 5, 46.0)
	AudioManager.play("attack")


func _fire_styled_spread(style: int, speed: float, count: int, vertical_step: float) -> void:
	for index: int in count:
		var centered := float(index) - float(count - 1) * 0.5
		_spawn_bolt(
			global_position + Vector2(direction * 18, -9),
			Vector2(direction * speed, centered * vertical_step),
			style
		)


func _spawn_landing_burst() -> void:
	var style := BossBolt.Style.STONE if boss_variant == Variant.CAVERN_DRILLER else BossBolt.Style.GEAR
	match boss_variant:
		Variant.STORM_FORGE: style = BossBolt.Style.LIGHTNING
		Variant.MAGMA_COLOSSUS: style = BossBolt.Style.MAGMA
		Variant.FROST_CROWN: style = BossBolt.Style.FROST
		Variant.CHRONO_SOVEREIGN: style = BossBolt.Style.CHRONO
	var speed := 185.0 if boss_variant == Variant.CAVERN_DRILLER else 215.0
	for side: float in [-1.0, 1.0]:
		_spawn_bolt(global_position + Vector2(side * 18, 7), Vector2(side * speed, -12), style, 75.0)
	AudioManager.play("stomp")


func _spawn_bolt(origin: Vector2, bolt_velocity: Vector2, style: int, bolt_gravity: float = 0.0) -> void:
	var bolt := BOSS_BOLT_SCENE.instantiate() as BossBolt
	get_tree().current_scene.add_child(bolt)
	bolt.launch(origin, bolt_velocity, style, bolt_gravity)


func _enter_phase(next_phase: Phase, duration: float) -> void:
	phase = next_phase
	phase_timer = duration
	phase_action_done = false
	volley_fired = false
	if phase == Phase.SUMMON:
		summon_count = 0


func _handle_contacts() -> void:
	for index: int in get_slide_collision_count():
		var hit := get_slide_collision(index)
		var body := hit.get_collider() as Node
		if body != null and body.is_in_group("player") and body.has_method("handle_enemy_contact"):
			body.handle_enemy_contact(self, -hit.get_normal())


func take_damage(amount: int, stomped: bool = false) -> void:
	if phase == Phase.DEFEATED or invulnerable_timer > 0.0:
		return
	_activate()
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
	GameManager.add_score(2200 + int(boss_variant) * 1400)
	defeated.emit()


func _variant_name() -> String:
	match boss_variant:
		Variant.CAVERN_DRILLER: return "岩窟钻虎机"
		Variant.THORN_REACTOR: return "荆棘反应炉"
		Variant.GEARHEART: return "齿轮心脏守卫"
		Variant.STORM_FORGE: return "雷铸风暴机"
		Variant.MAGMA_COLOSSUS: return "熔岩巨像"
		Variant.FROST_CROWN: return "霜冠统领"
		_: return "时序王座"


func get_skill_names() -> Array[String]:
	match boss_variant:
		Variant.CAVERN_DRILLER: return ["钻头冲锋", "震地飞跃", "落石锁定"]
		Variant.THORN_REACTOR: return ["荆棘散射", "孢子召唤", "低血加速"]
		Variant.GEARHEART: return ["高速冲锋", "齿轮弹幕", "飞虫增援", "震地波"]
		Variant.STORM_FORGE: return ["雷弧扇射", "风暴跃击", "导电追击"]
		Variant.MAGMA_COLOSSUS: return ["熔核喷发", "重甲冲锋", "岩浆落点"]
		Variant.FROST_CROWN: return ["寒霜弹幕", "龟甲增援", "冰冠跃击"]
		_: return ["时序加速", "七相弹幕", "机械增援", "王座震波"]


func _draw() -> void:
	if boss_variant == Variant.CAVERN_DRILLER:
		_draw_cavern_driller()
	elif boss_variant == Variant.THORN_REACTOR:
		_draw_thorn_reactor()
	elif boss_variant == Variant.GEARHEART:
		_draw_gearheart()
	else:
		_draw_advanced_guardian()
	if activated and phase in [Phase.SUMMON, Phase.VOLLEY]:
		var pulse := 7.0 + sin(age * 12.0) * 2.0
		draw_circle(Vector2(0, -7), pulse, Color(1.0, 0.72, 0.3, 0.18))


func _draw_cavern_driller() -> void:
	var flash := invulnerable_timer > 0.0
	var armor := Color.WHITE if flash else Color("59666b")
	PixelArt.rect(self, Vector2(-20, -17), Vector2(37, 27), Color("202b30"))
	PixelArt.rect(self, Vector2(-17, -15), Vector2(31, 21), armor)
	PixelArt.rect(self, Vector2(-18, 7), Vector2(34, 7), Color("303d42"))
	for x: float in [-13.0, -4.0, 5.0]:
		PixelArt.rect(self, Vector2(x, 9), Vector2(6, 3), Color("9a6f48"))
	PixelArt.diamond(self, Vector2(direction * 21, -5), 9.0, Color("342b26"))
	PixelArt.diamond(self, Vector2(direction * 23, -5), 6.0, Color("d28a4c"))
	PixelArt.diamond(self, Vector2(-4, -6), 5.0, Color("ffd36a"))


func _draw_thorn_reactor() -> void:
	var flash := invulnerable_timer > 0.0
	var shell := Color.WHITE if flash else Color("2f765d")
	PixelArt.rect(self, Vector2(-13, -25), Vector2(26, 37), Color("142c28"))
	PixelArt.rect(self, Vector2(-10, -22), Vector2(20, 31), shell)
	PixelArt.diamond(self, Vector2(0, -8), 8.0, Color("d64c78"))
	PixelArt.diamond(self, Vector2(0, -8), 4.0, Color("ffe27a"))
	for side: float in [-1.0, 1.0]:
		PixelArt.diamond(self, Vector2(side * 16, -17), 6.0, Color("183d32"))
		PixelArt.rect(self, Vector2(side * 13 - 2, -18), Vector2(5, 16), Color("55b96e"))
	PixelArt.rect(self, Vector2(-11, 9), Vector2(8, 7), Color("1d493b"))
	PixelArt.rect(self, Vector2(3, 9), Vector2(8, 7), Color("1d493b"))


func _draw_gearheart() -> void:
	var flash := invulnerable_timer > 0.0
	var metal := Color.WHITE if flash else Color("46636b")
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


func _draw_advanced_guardian() -> void:
	var armor := Color("4c7893")
	var core := Color("7ee8ff")
	var accent := Color("d7f6ff")
	match boss_variant:
		Variant.MAGMA_COLOSSUS:
			armor = Color("71362c")
			core = Color("ff6238")
			accent = Color("ffd261")
		Variant.FROST_CROWN:
			armor = Color("547b9d")
			core = Color("91f1ff")
			accent = Color.WHITE
		Variant.CHRONO_SOVEREIGN:
			armor = Color("523d6e")
			core = Color("c676ff")
			accent = Color("fff09c")
	if invulnerable_timer > 0.0:
		armor = Color.WHITE
	PixelArt.rect(self, Vector2(-19, -19), Vector2(38, 30), Color("151d27"))
	PixelArt.rect(self, Vector2(-16, -17), Vector2(32, 25), armor)
	PixelArt.diamond(self, Vector2(0, -6), 9.0, Color("1a2230"))
	PixelArt.diamond(self, Vector2(0, -6), 6.0, core)
	PixelArt.diamond(self, Vector2(0, -6), 2.0, accent)
	# Each late guardian carries a distinct readable silhouette.
	if boss_variant == Variant.STORM_FORGE:
		PixelArt.rect(self, Vector2(-27, -24), Vector2(11, 4), accent)
		PixelArt.rect(self, Vector2(16, -24), Vector2(11, 4), accent)
		PixelArt.diamond(self, Vector2(0, -29), 6.0, core)
	elif boss_variant == Variant.MAGMA_COLOSSUS:
		PixelArt.diamond(self, Vector2(-17, -21), 7.0, accent)
		PixelArt.diamond(self, Vector2(17, -21), 7.0, accent)
		PixelArt.rect(self, Vector2(-24, 8), Vector2(15, 8), Color("3a2423"))
		PixelArt.rect(self, Vector2(9, 8), Vector2(15, 8), Color("3a2423"))
	elif boss_variant == Variant.FROST_CROWN:
		for x: float in [-13.0, 0.0, 13.0]:
			PixelArt.diamond(self, Vector2(x, -27), 6.0, accent)
	else:
		for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			PixelArt.diamond(self, Vector2(cos(angle), sin(angle)) * 23.0 + Vector2(0, -5), 4.0, accent)
	PixelArt.rect(self, Vector2(-15, 8), Vector2(10, 8), Color("202a35"))
	PixelArt.rect(self, Vector2(5, 8), Vector2(10, 8), Color("202a35"))
