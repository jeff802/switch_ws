class_name EnemySpawner
extends Node2D

@export_enum("Beetle Bot", "Bouncecap", "Gearwing") var enemy_kind: int = 0
@export var patrol_distance: float = 80.0
@export var respawn_delay: float = 5.0
@export var respawn_enabled: bool = true

var current_enemy: Node2D
var respawn_timer: float = 0.0


func _ready() -> void:
	_spawn()


func _process(delta: float) -> void:
	if current_enemy != null and current_enemy.get("active") == true:
		return
	if not respawn_enabled:
		return
	respawn_timer -= delta
	if respawn_timer <= 0.0:
		_spawn()


func _spawn() -> void:
	current_enemy = ObjectPool.acquire_enemy(enemy_kind, global_position, patrol_distance)
	respawn_timer = respawn_delay


func _draw() -> void:
	draw_line(Vector2(-5, 0), Vector2(5, 0), Color(0.4, 0.9, 0.8, 0.35), 1.0)
	draw_line(Vector2(0, -5), Vector2(0, 5), Color(0.4, 0.9, 0.8, 0.35), 1.0)

