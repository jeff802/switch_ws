extends Node

const PROJECTILE_SCENE := preload("res://projectiles/energy_ball.tscn")
const ENEMY_SCENE := preload("res://enemies/enemy.tscn")
const INITIAL_PROJECTILES := 12
const INITIAL_ENEMIES := 16

var _projectile_pool: Array[Node2D] = []
var _enemy_pool: Array[Node2D] = []


func _ready() -> void:
	for index: int in INITIAL_PROJECTILES:
		_projectile_pool.append(_make_inactive(PROJECTILE_SCENE))
	for index: int in INITIAL_ENEMIES:
		_enemy_pool.append(_make_inactive(ENEMY_SCENE))


func _make_inactive(scene: PackedScene) -> Node2D:
	var item := scene.instantiate() as Node2D
	add_child(item)
	if item.has_method("deactivate"):
		item.deactivate()
	return item


func acquire_projectile(world_position: Vector2, direction: float, source: Node) -> Node2D:
	var item: Node2D
	if _projectile_pool.is_empty():
		item = _make_inactive(PROJECTILE_SCENE)
	else:
		item = _projectile_pool.pop_back()
	item.global_position = world_position
	item.call("activate", direction, source)
	return item


func release_projectile(item: Node2D) -> void:
	if item.has_method("deactivate"):
		item.deactivate()
	if not _projectile_pool.has(item):
		_projectile_pool.append(item)


func acquire_enemy(kind: int, world_position: Vector2, patrol_distance: float = 80.0) -> Node2D:
	var item: Node2D
	if _enemy_pool.is_empty():
		item = _make_inactive(ENEMY_SCENE)
	else:
		item = _enemy_pool.pop_back()
	item.global_position = world_position
	item.call("activate", kind, world_position, patrol_distance)
	return item


func release_enemy(item: Node2D) -> void:
	if item.has_method("deactivate"):
		item.deactivate()
	if not _enemy_pool.has(item):
		_enemy_pool.append(item)


func reset_all() -> void:
	for child: Node in get_children():
		var item := child as Node2D
		if item == null:
			continue
		if child.has_method("deactivate"):
			child.call("deactivate")
		if child.scene_file_path.ends_with("energy_ball.tscn") and not _projectile_pool.has(child):
			_projectile_pool.append(item)
		elif child.scene_file_path.ends_with("enemy.tscn") and not _enemy_pool.has(child):
			_enemy_pool.append(item)
