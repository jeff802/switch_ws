extends SceneTree

var failures: Array[String] = []
var checks: int = 0
var collected_events: int = 0
var platform_events: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	var events := root.get_node("GameEvents")
	manager.persistence_enabled = false
	root.get_node("SaveManager").checkpoint_level_id = ""
	events.collectible_collected.connect(
		func(_collectible_id: String, _value: int, _heals: bool) -> void: collected_events += 1
	)
	events.platform_endpoint_reached.connect(
		func(_platform: Node2D, _at_destination: bool) -> void: platform_events += 1
	)

	var level = (load("res://levels/forest_level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	for _frame: int in 20:
		await physics_frame
	var player = level.get_node("Player")
	player.invulnerability_timer = 999.0
	_check(player.state_machine != null, "callback state machine is active")
	_check(player.max_air_jumps == 0, "air-jump capacity is disabled")
	_check(player.air_jumps_remaining == 0, "no air jump is granted after landing")

	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for _frame: int in 4:
		await physics_frame
	var velocity_before_second: float = player.velocity.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	_check(player.air_jumps_remaining == 0, "airborne jump does not create a second jump")
	_check(player.velocity.y >= velocity_before_second - 20.0, "second airborne jump press is rejected")
	_check(player.velocity.y > -210.0, "airborne jump does not renew launch velocity")

	var wall := StaticBody2D.new()
	wall.position = Vector2(190, 112)
	wall.collision_layer = 1
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(18, 176)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	level.add_child(wall)
	player.global_position = Vector2(166, 88)
	player.velocity = Vector2(80, 130)
	Input.action_press("move_right")
	for _frame: int in 16:
		await physics_frame
	_check(not player.wall_slide_active, "holding toward a wall does not enter wall slide")
	_check(player.velocity.y > 180.0, "touching a wall keeps normal falling gravity")
	var wall_velocity_before_jump: Vector2 = player.velocity
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	Input.action_release("move_right")
	_check(player.velocity.x > -30.0, "wall jump no longer launches away from the wall")
	_check(player.velocity.y >= wall_velocity_before_jump.y - 20.0, "wall contact cannot renew upward velocity")

	var platform = (load("res://world/moving_platform.tscn") as PackedScene).instantiate()
	platform.position = Vector2(430, 150)
	platform.offset = Vector2(32, 0)
	platform.travel_time = 0.08
	platform.wait_time = 0.02
	level.add_child(platform)
	for _frame: int in 20:
		await physics_frame
	_check(platform_events >= 2, "moving platform publishes endpoint events")
	_check(platform.position.distance_to(platform.origin) > 1.0 or platform.clock > 0.2, "moving platform advances on its route")

	var coins_before: int = manager.collectibles
	var coin = (load("res://world/collectible.tscn") as PackedScene).instantiate()
	coin.collectible_id = "probe:coin"
	level.add_child(coin)
	coin._on_body_entered(player)
	await process_frame
	_check(collected_events == 1, "collectible publishes through the event bus")
	_check(manager.collectibles == coins_before + 1, "game manager consumes the collectible event")
	_check(not level.hud.ability_label.visible, "HUD hides removed air-mobility prompts")

	Input.action_release("jump")
	Input.action_release("move_right")
	manager.persistence_enabled = true
	manager.run_active = false
	if failures.is_empty():
		print("MOBILITY/EVENT PROBE: %d checks passed" % checks)
		quit(0)
		return
	for failure: String in failures:
		push_error("MOBILITY/EVENT PROBE: " + failure)
	quit(1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
