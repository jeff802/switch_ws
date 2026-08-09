extends ForestGearLevel


func _build_level() -> void:
	# Glowroot Cavern: narrower ledges, falling rocks and vertical routes.
	solid_rect(0, 12, 20, 4, 2)
	solid_rect(24, 12, 18, 4, 2)
	solid_rect(47, 12, 22, 4, 2)
	solid_rect(74, 12, 20, 4, 2)
	solid_rect(98, 12, 42, 4, 2)
	solid_rect(9, 8, 6, 1, 1)
	solid_rect(27, 9, 6, 1, 1)
	solid_rect(34, 6, 5, 1, 1)
	solid_rect(52, 9, 7, 1, 1)
	solid_rect(64, 6, 5, 1, 1)
	solid_rect(78, 8, 7, 1, 1)
	solid_rect(88, 5, 5, 1, 1)
	solid_rect(105, 8, 8, 1, 1)
	solid_rect(120, 6, 7, 1, 1)
	add_collectible_arc(Vector2(430, 120), 5)
	add_collectible_arc(Vector2(835, 112), 6)
	add_collectible_arc(Vector2(1675, 112), 6)
	add_enemy(Vector2(245, 174), PooledEnemy.Kind.BOUNCECAP, 60)
	add_enemy(Vector2(580, 174), PooledEnemy.Kind.BEETLE_BOT, 75)
	add_enemy(Vector2(1050, 82), PooledEnemy.Kind.GEARWING, 110)
	add_enemy(Vector2(1570, 174), PooledEnemy.Kind.BOUNCECAP, 80)
	add_entity(FALLING_ROCK_SCENE, Vector2(520, 45))
	add_entity(FALLING_ROCK_SCENE, Vector2(1180, 35))
	add_entity(FALLING_ROCK_SCENE, Vector2(1810, 50))
	add_entity(SPIKE_SCENE, Vector2(840, 184))
	add_entity(SPIKE_SCENE, Vector2(1430, 184))
	add_entity(SPRING_SCENE, Vector2(1100, 181), {"launch_strength": 535.0})
	add_entity(MOVING_PLATFORM_SCENE, Vector2(1475, 137), {"offset": Vector2(0, -68), "travel_time": 2.2})
	add_entity(CHECKPOINT_SCENE, Vector2(1245, 188))
	add_entity(HIDDEN_AREA_SCENE, Vector2(640, 85), {"cover_size": Vector2(90, 64)})
	add_collectible(Vector2(620, 72), true)
	add_entity(EXIT_SCENE, Vector2(2180, 188), {
		"unlock_level_id": "snow", "next_scene": "res://levels/snow_level.tscn",
	})

