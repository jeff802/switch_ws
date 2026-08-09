extends ForestGearLevel

var boss: GearheartGuardian
var arena_gate: StaticBody2D
var arena_gate_collision: CollisionShape2D
var final_exit: LevelExit


func _build_level() -> void:
	# Foundry Crown: boss arena followed by a victory corridor and core relay.
	solid_rect(0, 12, 120, 4, 3)
	solid_rect(8, 8, 7, 1, 2)
	solid_rect(28, 8, 7, 1, 2)
	solid_rect(49, 8, 7, 1, 2)
	solid_rect(76, 9, 8, 1, 2)
	solid_rect(92, 7, 6, 1, 2)
	for brick_x: int in [18, 19, 21, 22, 64, 65, 67, 68, 100, 101, 103, 104]:
		add_block(Vector2(brick_x * 16 + 8, 8 * 16 + 8), GearBlock.Type.BRICK)
	for question_x: int in [20, 66, 102]:
		add_block(Vector2(question_x * 16 + 8, 8 * 16 + 8), GearBlock.Type.QUESTION, GearBlock.Content.COIN)
	add_entity(SPIKE_SCENE, Vector2(530, 184))
	add_entity(SPIKE_SCENE, Vector2(855, 184))
	add_entity(SPRING_SCENE, Vector2(265, 181), {"launch_strength": 500.0})
	add_collectible(Vector2(175, 112), true)
	add_collectible(Vector2(925, 112), true)
	add_collectible_arc(Vector2(1280, 138), 6, 24.0, 25.0)
	add_collectible_arc(Vector2(1530, 106), 5, 22.0, 20.0)
	add_enemy(Vector2(365, 174), PooledEnemy.Kind.BOUNCECAP, 52.0, false)
	add_enemy(Vector2(1280, 174), PooledEnemy.Kind.BOUNCECAP, 58.0, false)
	add_cactus(Vector2(640, 192), false)
	add_cactus(Vector2(1430, 192), true, 2.6)
	boss = add_entity(BOSS_SCENE, Vector2(780, 150)) as GearheartGuardian
	hud.bind_boss(boss)
	boss.defeated.connect(_on_boss_defeated)
	_create_arena_gate()
	final_exit = add_entity(EXIT_SCENE, Vector2(1870, 188), {
		"unlock_level_id": "complete",
	}) as LevelExit
	final_exit.activated.connect(_on_final_exit_reached)


func _create_arena_gate() -> void:
	arena_gate = StaticBody2D.new()
	arena_gate.name = "ArenaEnergyGate"
	arena_gate.position = Vector2(1120, 116)
	arena_gate.collision_layer = 1
	arena_gate.collision_mask = 6
	arena_gate_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 152)
	arena_gate_collision.shape = shape
	arena_gate.add_child(arena_gate_collision)
	var glow := Line2D.new()
	glow.name = "Glow"
	glow.points = PackedVector2Array([Vector2(0, -76), Vector2(0, 76)])
	glow.width = 12.0
	glow.default_color = Color(0.25, 0.95, 1.0, 0.2)
	arena_gate.add_child(glow)
	var beam := Line2D.new()
	beam.name = "Beam"
	beam.points = glow.points
	beam.width = 4.0
	beam.default_color = Color("73edf5")
	arena_gate.add_child(beam)
	entity_root.add_child(arena_gate)


func _on_boss_defeated() -> void:
	arena_gate_collision.set_deferred("disabled", true)
	var gate_fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	gate_fade.tween_property(arena_gate, "modulate:a", 0.0, 0.45)
	gate_fade.tween_callback(arena_gate.queue_free)
	hud.show_path_open()


func _on_final_exit_reached(_body: Node2D) -> void:
	player.controls_locked = true
	player.velocity = Vector2.ZERO
	hud.show_victory()
