extends Node

const CAMPAIGN_STAGE_COUNT := 20
const LAST_CAMPAIGN_STAGE := CAMPAIGN_STAGE_COUNT - 1
const CAMPAIGN_SCENE := "res://levels/campaign_level.tscn"

signal score_changed(value: int)
signal collectibles_changed(value: int)
signal time_changed(value: float)
signal level_started(level_id: String)
signal time_expired
signal reserve_bloom_changed(count: int)

var score: int = 0
var collectibles: int = 0
var time_left: float = 180.0
var current_level_id: String = "forest"
var checkpoint_position: Vector2 = Vector2.ZERO
var run_active: bool = false
var carried_power_level: int = 0
var carried_reserve_bloom_count: int = 0
var campaign_stage: int = 0
var persistence_enabled: bool = true


func _ready() -> void:
	score = SaveManager.run_score
	collectibles = SaveManager.run_collectibles
	carried_power_level = SaveManager.carried_power_level
	carried_reserve_bloom_count = SaveManager.carried_reserve_bloom_count
	campaign_stage = SaveManager.campaign_stage
	GameEvents.collectible_collected.connect(_on_collectible_collected)


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
	var resumes_saved_checkpoint := SaveManager.checkpoint_level_id == level_id
	checkpoint_position = SaveManager.get_checkpoint(level_id, spawn)
	run_active = true
	if reset_score and not resumes_saved_checkpoint:
		score = 0
		collectibles = 0
		carried_power_level = 0
		carried_reserve_bloom_count = 0
	score_changed.emit(score)
	collectibles_changed.emit(collectibles)
	time_changed.emit(time_left)
	level_started.emit(level_id)
	_persist_run()


func add_score(amount: int) -> void:
	score = maxi(0, score + amount)
	score_changed.emit(score)


func add_collectible(amount: int = 1) -> void:
	collectibles += amount
	add_score(100 * amount)
	collectibles_changed.emit(collectibles)
	_persist_run()


func set_checkpoint(world_position: Vector2) -> void:
	checkpoint_position = world_position
	if persistence_enabled:
		SaveManager.save_checkpoint(
			current_level_id,
			checkpoint_position,
			campaign_stage,
			score,
			collectibles,
			carried_power_level,
			carried_reserve_bloom_count
		)
	GameEvents.checkpoint_activated.emit(current_level_id, checkpoint_position)


func set_carried_power_level(level: int) -> void:
	carried_power_level = clampi(level, 0, 2)


func set_carried_reserve_bloom_count(count: int) -> void:
	count = clampi(count, 0, 2)
	if carried_reserve_bloom_count == count:
		return
	carried_reserve_bloom_count = count
	reserve_bloom_changed.emit(carried_reserve_bloom_count)


func set_campaign_stage(stage: int, persist: bool = false) -> void:
	campaign_stage = clampi(stage, 0, LAST_CAMPAIGN_STAGE)
	if persist:
		_persist_run()


func select_campaign_stage(stage: int) -> void:
	if SceneTransition.busy:
		return
	get_tree().paused = false
	run_active = false
	if persistence_enabled:
		SaveManager.submit_score(score)
	campaign_stage = clampi(stage, 0, LAST_CAMPAIGN_STAGE)
	# 选关按一次新的单关挑战处理：保留已通关记录和最高分，但清空本次分数、
	# 检查点与携带能力，避免从别的关卡把出生点或状态带过来。
	score = 0
	collectibles = 0
	carried_power_level = 0
	carried_reserve_bloom_count = 0
	checkpoint_position = Vector2.ZERO
	if persistence_enabled:
		SaveManager.clear_checkpoint(false)
		SaveManager.save_run_progress(
			campaign_stage, score, collectibles, carried_power_level, carried_reserve_bloom_count
		)
	score_changed.emit(score)
	collectibles_changed.emit(collectibles)
	SceneTransition.change_scene(CAMPAIGN_SCENE)


func advance_campaign_stage() -> void:
	var completed_level := current_level_id
	campaign_stage = mini(campaign_stage + 1, LAST_CAMPAIGN_STAGE)
	if persistence_enabled:
		SaveManager.complete_stage(
			completed_level,
			campaign_stage,
			score,
			collectibles,
			carried_power_level,
			carried_reserve_bloom_count
		)
	GameEvents.campaign_progressed.emit(campaign_stage)


func complete_campaign() -> void:
	if persistence_enabled:
		SaveManager.complete_stage(
			current_level_id,
			LAST_CAMPAIGN_STAGE,
			score,
			collectibles,
			carried_power_level,
			carried_reserve_bloom_count
		)
	GameEvents.campaign_progressed.emit(LAST_CAMPAIGN_STAGE)


func respawn_player(player: Node2D) -> void:
	player.global_position = checkpoint_position
	if player.has_method("restore_after_respawn"):
		player.restore_after_respawn()


func freeze_level_timer() -> void:
	# Used by scripted goal sequences. The remaining time is preserved and
	# converted to score only after the animation has finished.
	run_active = false


func reload_current_level() -> void:
	if SceneTransition.busy:
		return
	get_tree().paused = false
	run_active = false
	_persist_run()
	SceneTransition.reload_current_scene()


func finish_level(unlock_id: String, next_scene: String) -> void:
	run_active = false
	add_score(int(ceil(time_left)) * 10)
	SaveManager.submit_score(score)
	if not unlock_id.is_empty():
		SaveManager.unlock_level(unlock_id)
	if not next_scene.is_empty():
		SceneTransition.change_scene(next_scene)


func end_run() -> void:
	run_active = false
	SaveManager.submit_score(score)
	_persist_run()


func _on_collectible_collected(_collectible_id: String, value: int, _heals: bool) -> void:
	add_collectible(value)


func _persist_run() -> void:
	if not persistence_enabled:
		return
	SaveManager.save_run_progress(
		campaign_stage,
		score,
		collectibles,
		carried_power_level,
		carried_reserve_bloom_count
	)
