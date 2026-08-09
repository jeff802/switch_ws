class_name EnemySpawner
extends Node2D

@export_enum("Beetle Bot", "Coppercap", "Gearwing") var enemy_kind: int = 0
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
