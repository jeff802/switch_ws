extends ForestGearLevel


func _build_level() -> void:
	# Classic 8-bit overworld: bricks, question blocks, pipes, coins and a flag.
	# Ground segments with jumpable pits.
	solid_rect(0, 12, 20, 4, 0)
	solid_rect(24, 12, 20, 4, 0)
	solid_rect(48, 12, 32, 4, 0)
	solid_rect(84, 12, 56, 4, 0)

	# Brick row at jump height.
	for brick_x: int in [26, 27, 28, 29, 52, 53, 54, 55, 100, 101, 102, 103, 104]:
		add_block(Vector2(brick_x * 16 + 8, 8 * 16 + 8), GearBlock.Type.BRICK)

	# Question blocks: coins.
	add_block(Vector2(31 * 16 + 8, 8 * 16 + 8), GearBlock.Type.QUESTION, GearBlock.Content.COIN)
	add_block(Vector2(58 * 16 + 8, 8 * 16 + 8), GearBlock.Type.QUESTION, GearBlock.Content.MUSHROOM)
	add_block(Vector2(86 * 16 + 8, 8 * 16 + 8), GearBlock.Type.QUESTION, GearBlock.Content.COIN)
	# A second adaptive power block: mushroom when small, Energy Bloom when big.
	add_block(Vector2(110 * 16 + 8, 8 * 16 + 8), GearBlock.Type.QUESTION, GearBlock.Content.MUSHROOM)
	add_block(Vector2(126 * 16 + 8, 8 * 16 + 8), GearBlock.Type.QUESTION, GearBlock.Content.COIN)

	# Question blocks above platforms.
	add_block(Vector2(26 * 16 + 8, 6 * 16 + 8), GearBlock.Type.QUESTION, GearBlock.Content.COIN)
	add_block(Vector2(52 * 16 + 8, 6 * 16 + 8), GearBlock.Type.QUESTION, GearBlock.Content.COIN)

	# Pipes (heights are jumpable; spaced away from the question blocks).
	add_pipe(Vector2(37 * 16, 12 * 16), 48.0)
	add_pipe(Vector2(90 * 16, 12 * 16), 52.0)
	add_pipe(Vector2(132 * 16, 12 * 16), 48.0)

	# Tight, reachable arcs centered over each four-tile pit.
	add_collectible_arc(Vector2(22 * 16, 140), 5, 14.0, 22.0)
	add_collectible_arc(Vector2(46 * 16, 140), 5, 14.0, 22.0)
	add_collectible_arc(Vector2(82 * 16, 140), 5, 14.0, 22.0)
	# A readable late-level row above the five-brick platform, plus a cue coin
	# above the following question block.
	for coin_x: int in [100, 101, 102, 103, 104]:
		add_collectible(Vector2(coin_x * 16 + 8, 6 * 16 + 8), false)
	add_collectible(Vector2(110 * 16 + 8, 6 * 16 + 8), false)
	add_collectible(Vector2(2020, 108), true)

	# Walkers (stompable).
	add_enemy(Vector2(300, 174), PooledEnemy.Kind.BEETLE_BOT, 70)
	add_enemy(Vector2(900, 174), PooledEnemy.Kind.BEETLE_BOT, 80)
	add_enemy(Vector2(1400, 174), PooledEnemy.Kind.BEETLE_BOT, 80)
	add_enemy(Vector2(1900, 174), PooledEnemy.Kind.BOUNCECAP, 90)

	add_entity(CHECKPOINT_SCENE, Vector2(1100, 188))
	add_flag(Vector2(2190, 188), "cave", "res://levels/cave_level.tscn")
