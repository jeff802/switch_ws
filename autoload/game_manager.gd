extends Node

signal score_changed(value: int)
signal collectibles_changed(value: int)
signal time_changed(value: float)
signal level_started(level_id: String)
signal time_expired

var score: int = 0
var collectibles: int = 0
var time_left: float = 180.0
var current_level_id: String = "forest"
var checkpoint_position: Vector2 = Vector2.ZERO
var run_active: bool = false
var carried_power_level: int = 0


func _process(delta: float) -> void:
	if not run_active or get_tree().paused:
		return
	time_left = maxf(0.0, time_left - delta)
	time_changed.emit(time_left)
	if is_zero_approx(time_left):
		run_active = false
		time_expired.emit()


func start_level(level_id: String, time_limit: float, spawn: Vector2, reset_score: bool = false) -> void:
	current_level_id = level_id
	time_left = time_limit
	checkpoint_position = spawn
	run_active = true
	if reset_score:
		score = 0
		collectibles = 0
		carried_power_level = 0
	score_changed.emit(score)
	collectibles_changed.emit(collectibles)
	time_changed.emit(time_left)
	level_started.emit(level_id)


func add_score(amount: int) -> void:
	score = maxi(0, score + amount)
	score_changed.emit(score)


func add_collectible(amount: int = 1) -> void:
	collectibles += amount
	add_score(100 * amount)
	collectibles_changed.emit(collectibles)


func set_checkpoint(world_position: Vector2) -> void:
	checkpoint_position = world_position


func set_carried_power_level(level: int) -> void:
	carried_power_level = clampi(level, 0, 2)


func respawn_player(player: Node2D) -> void:
	player.global_position = checkpoint_position
	if player.has_method("restore_after_respawn"):
		player.restore_after_respawn()


func freeze_level_timer() -> void:
	# Used by scripted goal sequences. The remaining time is preserved and
	# converted to score only after the animation has finished.
	run_active = false


func finish_level(unlock_id: String, next_scene: String) -> void:
	run_active = false
	add_score(int(ceil(time_left)) * 10)
	SaveManager.submit_score(score)
	if not unlock_id.is_empty():
		SaveManager.unlock_level(unlock_id)
	if not next_scene.is_empty():
		# Scene changes must be deferred: finish_level can be called from a
		# physics callback (e.g. Area2D.body_entered on the level exit).
		get_tree().call_deferred("change_scene_to_file", next_scene)


func end_run() -> void:
	run_active = false
	SaveManager.submit_score(score)
