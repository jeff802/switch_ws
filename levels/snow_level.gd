extends ForestGearLevel


func _build_level() -> void:
	# Frostspine Pass: longer jumps and moving machinery over icy chasms.
	solid_rect(0, 12, 23, 4, 1)
	solid_rect(28, 12, 19, 4, 1)
	solid_rect(52, 12, 16, 4, 1)
	solid_rect(73, 12, 20, 4, 1)
	solid_rect(99, 12, 41, 4, 1)
	solid_rect(11, 8, 7, 1, 1)
	solid_rect(33, 7, 6, 1, 1)
	solid_rect(57, 8, 6, 1, 1)
	solid_rect(78, 6, 7, 1, 1)
	solid_rect(103, 8, 7, 1, 1)
	solid_rect(119, 6, 6, 1, 1)
	add_collectible_arc(Vector2(420, 118), 6)
	add_collectible_arc(Vector2(785, 105), 6)
	add_collectible_arc(Vector2(1510, 108), 7)
	add_enemy(Vector2(270, 174), PooledEnemy.Kind.BEETLE_BOT, 85)
	add_enemy(Vector2(610, 96), PooledEnemy.Kind.GEARWING, 125)
	add_enemy(Vector2(1290, 174), PooledEnemy.Kind.BOUNCECAP, 100)
	add_enemy(Vector2(1810, 105), PooledEnemy.Kind.GEARWING, 110)
	add_entity(MOVING_PLATFORM_SCENE, Vector2(500, 155), {"offset": Vector2(72, 0), "travel_time": 1.8})
	add_entity(MOVING_PLATFORM_SCENE, Vector2(1200, 150), {"offset": Vector2(95, -28), "travel_time": 2.4})
	add_entity(SPRING_SCENE, Vector2(910, 181), {"launch_strength": 550.0})
	add_entity(SPIKE_SCENE, Vector2(1350, 184))
	add_entity(SPIKE_SCENE, Vector2(1735, 184))
	add_entity(FALLING_ROCK_SCENE, Vector2(1885, 42))
	add_entity(CHECKPOINT_SCENE, Vector2(1215, 188))
	add_entity(HIDDEN_AREA_SCENE, Vector2(2025, 140), {"cover_size": Vector2(96, 76)})
	add_collectible(Vector2(2025, 130), true)
	add_entity(EXIT_SCENE, Vector2(2180, 188), {
		"unlock_level_id": "boss", "next_scene": "res://levels/boss_level.tscn",
	})

