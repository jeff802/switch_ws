extends ForestGearLevel

## 二十关制战役。每一关都使用独立编排，后十关继续引入新材质、
## 复合墙体、隐藏补给比例与首领技能，而不是复制前十关的区段。
const CAMPAIGN_SCENE := "res://levels/campaign_level.tscn"
const STAGE_COUNT := 20
const STAGE_BIOMES: Array[String] = [
	"forest", "forest", "cave", "snow", "city",
	"forest", "cave", "snow", "city", "city",
	"ruins", "cave", "city", "snow", "volcano",
	"cave", "ruins", "night", "city", "volcano",
]
const STAGE_WIDTHS: Array[int] = [
	128, 138, 144, 140, 146, 160, 142, 150, 158, 128,
	152, 158, 146, 162, 166, 150, 164, 154, 170, 142,
]
const STAGE_TIMES: Array[float] = [
	185.0, 185.0, 220.0, 190.0, 195.0, 230.0, 200.0, 195.0, 205.0, 240.0,
	205.0, 215.0, 245.0, 220.0, 225.0, 255.0, 230.0, 250.0, 235.0, 285.0,
]
const STAGE_BLOCK_THEMES: Array[int] = [
	0, 0, 1, 2, 3, 0, 1, 2, 3, 4,
	5, 1, 6, 2, 6, 7, 5, 8, 3, 9,
]
enum BlockPattern { ROW, WAVE, STEPS, CROWN, SPLIT }

var stage_index: int = 0
var stage_number: int = 1
var pit_ranges: Array[Vector2i] = []
var boss: GearheartGuardian
var arena_gate: StaticBody2D
var arena_gate_collision: CollisionShape2D
var final_exit: LevelExit
var occupied_block_positions: Dictionary = {}
var occupied_coin_positions: Dictionary = {}
var used_block_patterns: Dictionary = {}
var enemy_spawn_counter: int = 0
var collectible_spawn_counter: int = 0


func _enter_tree() -> void:
	stage_index = clampi(GameManager.campaign_stage, 0, STAGE_COUNT - 1)
	stage_number = stage_index + 1
	biome = STAGE_BIOMES[stage_index]
	level_id = "stage_%02d" % stage_number
	time_limit = STAGE_TIMES[stage_index]
	spawn_point = Vector2(64, 150)
	level_width_tiles = STAGE_WIDTHS[stage_index]


func _build_level() -> void:
	match stage_number:
		1: _build_meadow_tutorial()
		2: _build_broken_bridge()
		3: _build_deep_cavern()
		4: _build_snowy_steps()
		5: _build_rooftop_run()
		6: _build_pipe_garden()
		7: _build_crystal_lifts()
		8: _build_frozen_crossing()
		9: _build_foundry_gauntlet()
		10: _build_final_stronghold()
		11: _build_ruined_canopy()
		12: _build_echo_mines()
		13: _build_storm_foundry()
		14: _build_glacier_switchbacks()
		15: _build_magma_aqueduct()
		16: _build_core_descent()
		17: _build_overgrown_clocktower()
		18: _build_lunar_frost_keep()
		19: _build_royal_gearway()
		_: _build_chrono_throne()
	_apply_difficulty_support()


func _build_meadow_tutorial() -> void:
	_build_ground()
	_add_block_row(15, 8, 5, 2, GearBlock.Content.MUSHROOM)
	_add_coin_line(12, 158, 3)
	_add_coin_arc_cells(17, 102, 5, 15.0, 14.0)
	_add_ground_enemy(29, PooledEnemy.Kind.BOUNCECAP, 42.0)
	add_pipe(Vector2(40 * TILE_SIZE + 8, 192), 40.0, GearPipe.TravelMode.ENTER_BONUS, 0)
	_add_stone_platform(49, 9, 5, 2, true)
	_add_coin_line(49, 132, 5)
	_add_ground_enemy(58, PooledEnemy.Kind.WADDLEDUCK, 54.0)
	_add_block_row(66, 8, 4, 1, GearBlock.Content.MULTI_COIN, false, BlockPattern.WAVE)
	add_checkpoint(Vector2(75 * TILE_SIZE + 8, 188))
	_cut_pit(85, 2, true)
	_add_block_row(94, 7, 6, 3, GearBlock.Content.MUSHROOM, false, BlockPattern.WAVE)
	_add_coin_arc_cells(97, 92, 6, 15.0, 17.0)
	_add_spring(108, 470.0)
	_add_vertical_coins(108, 148, 4, 18)
	_add_ground_enemy(115, PooledEnemy.Kind.BOUNCECAP, 38.0)
	_finish_standard_stage()


func _build_broken_bridge() -> void:
	_build_ground()
	_add_block_row(12, 8, 6, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.STEPS)
	_add_ground_enemy(20, PooledEnemy.Kind.WADDLEDUCK, 48.0)
	_cut_pit(27, 3, true)
	_add_spring(37, 510.0)
	_add_stone_platform(40, 7, 7, 2, true)
	_add_coin_arc_cells(43, 92, 7, 15.0, 18.0)
	_add_ground_enemy(48, PooledEnemy.Kind.SHELLBACK, 30.0)
	_cut_pit(54, 5, true, true)
	_add_ground_enemy(65, PooledEnemy.Kind.BOUNCECAP, 42.0)
	_add_block_row(70, 8, 5, 2, GearBlock.Content.MULTI_COIN, false, BlockPattern.CROWN)
	add_checkpoint(Vector2(78 * TILE_SIZE + 8, 188))
	_cut_pit(88, 4, true, true)
	_add_stone_platform(96, 9, 4)
	_add_stone_platform(102, 7, 4, 2, true)
	_add_coin_arc_cells(103, 92, 6, 15.0, 20.0)
	_add_ground_enemy(109, PooledEnemy.Kind.WADDLEDUCK, 40.0)
	_cut_pit(116, 3, true)
	_add_block_row(123, 8, 5, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.SPLIT)
	_finish_standard_stage()


func _build_deep_cavern() -> void:
	_build_ground(1)
	_add_spring(13, 535.0)
	_add_stone_platform(16, 9, 7)
	_add_stone_platform(27, 7, 6, 2, true)
	_add_stone_platform(38, 5, 6)
	_add_coin_line(16, 132, 7)
	_add_coin_line(27, 100, 6)
	_add_coin_line(38, 68, 6)
	_add_block_row(48, 8, 5, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.WAVE)
	_cut_pit(58, 3, true)
	_add_enemy_at(64, 110, PooledEnemy.Kind.GEARWING, 78.0)
	_add_ground_enemy(70, PooledEnemy.Kind.BOUNCECAP, 42.0)
	add_checkpoint(Vector2(76 * TILE_SIZE + 8, 188))
	_add_spring(82, 520.0)
	_add_stone_platform(86, 7, 8)
	_add_block_row(87, 3, 5, 2, GearBlock.Content.MUSHROOM)
	_cut_pit(99, 4, true, true)
	_add_stone_platform(107, 9, 4, 2, true)
	_add_stone_platform(113, 7, 4)
	_add_ground_enemy(123, PooledEnemy.Kind.WADDLEDUCK, 36.0)
	_add_coin_arc_cells(116, 94, 7, 15.0, 20.0)
	_finish_boss_stage(GearheartGuardian.Variant.CAVERN_DRILLER, 132, 138, 12)


func _build_snowy_steps() -> void:
	_build_ground()
	_add_block_row(13, 8, 5, 1, GearBlock.Content.MUSHROOM, false, BlockPattern.STEPS)
	_add_stone_platform(23, 10, 3)
	_add_stone_platform(27, 9, 3, 2, true)
	_add_stone_platform(31, 8, 3)
	_add_stone_platform(35, 7, 4, 2, true)
	_add_coin_arc_cells(32, 102, 8, 14.0, 22.0)
	_add_ground_enemy(42, PooledEnemy.Kind.WADDLEDUCK, 50.0)
	_cut_pit(49, 4, true, true)
	_add_ground_enemy(55, PooledEnemy.Kind.SHELLBACK, 28.0)
	_add_entity_falling_rock(59)
	_add_block_row(62, 7, 6, 3, GearBlock.Content.MULTI_COIN, false, BlockPattern.CROWN)
	add_checkpoint(Vector2(72 * TILE_SIZE + 8, 188))
	_add_spring(79, 545.0)
	_add_stone_platform(83, 6, 7, 2, true)
	_add_coin_line(83, 84, 7)
	_add_enemy_at(93, 105, PooledEnemy.Kind.GEARWING, 74.0)
	_cut_pit(102, 5, true, true)
	_add_entity_falling_rock(113)
	_add_ground_enemy(118, PooledEnemy.Kind.BOUNCECAP, 46.0)
	_add_block_row(123, 8, 5, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.WAVE)
	_finish_standard_stage()


func _build_rooftop_run() -> void:
	_build_ground(3)
	_add_stone_platform(12, 9, 8, 3)
	_add_block_row(14, 5, 5, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.CROWN)
	_cut_pit(26, 5, true, true)
	_add_ground_enemy(36, PooledEnemy.Kind.WADDLEDUCK, 56.0)
	_add_stone_platform(42, 8, 8, 3, true)
	_add_coin_arc_cells(46, 106, 8, 15.0, 18.0)
	_cut_pit(56, 6, true, true)
	_add_enemy_at(66, 112, PooledEnemy.Kind.GEARWING, 92.0)
	_add_block_row(69, 8, 6, 1, GearBlock.Content.COIN, false, BlockPattern.WAVE)
	add_checkpoint(Vector2(79 * TILE_SIZE + 8, 188))
	_add_stone_platform(84, 6, 7, 3, true)
	_add_spring(82, 540.0)
	_add_coin_line(84, 84, 7)
	_cut_pit(96, 4, true, true)
	_add_ground_enemy(105, PooledEnemy.Kind.BEETLE_BOT, 48.0)
	_add_ground_enemy(112, PooledEnemy.Kind.WADDLEDUCK, 48.0)
	add_entity(HIDDEN_AREA_SCENE, Vector2(119 * TILE_SIZE, 122), {"cover_size": Vector2(96, 70)})
	_add_block_row(122, 7, 6, 3, GearBlock.Content.MUSHROOM, true, BlockPattern.SPLIT)
	_add_coin_arc_cells(127, 92, 7, 14.0, 18.0)
	_finish_standard_stage()


func _build_pipe_garden() -> void:
	_build_ground()
	_add_block_row(12, 8, 5, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.CROWN)
	add_pipe(Vector2(25 * TILE_SIZE + 8, 192), 40.0)
	_add_ground_enemy(34, PooledEnemy.Kind.WADDLEDUCK, 48.0)
	add_cactus(Vector2(45 * TILE_SIZE + 8, 192), false)
	_add_coin_arc_cells(45, 126, 5, 15.0, 16.0)
	_cut_pit(56, 3, true)
	_add_block_row(63, 7, 6, 2, GearBlock.Content.MULTI_COIN, true, BlockPattern.WAVE)
	_add_ground_enemy(71, PooledEnemy.Kind.SHELLBACK, 32.0)
	add_checkpoint(Vector2(75 * TILE_SIZE + 8, 188))
	add_cactus(Vector2(84 * TILE_SIZE + 8, 192), true, 1.35)
	_add_spring(94, 510.0)
	_add_stone_platform(98, 7, 7, 2, true)
	_add_coin_line(98, 100, 7)
	add_pipe(Vector2(111 * TILE_SIZE + 8, 192), 56.0, GearPipe.TravelMode.ENTER_BONUS, 1)
	_add_ground_enemy(120, PooledEnemy.Kind.BOUNCECAP, 48.0)
	_cut_pit(128, 4, true, true)
	_add_block_row(136, 8, 5, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.STEPS)
	_finish_boss_stage(GearheartGuardian.Variant.THORN_REACTOR, 148, 154, 18)


func _build_crystal_lifts() -> void:
	_build_ground(1)
	_add_spring(12, 565.0)
	_add_stone_platform(16, 8, 6)
	_add_stone_platform(27, 5, 7, 2, true)
	_add_coin_arc_cells(29, 76, 7, 14.0, 18.0)
	_add_enemy_at(39, 100, PooledEnemy.Kind.GEARWING, 82.0)
	_cut_pit(45, 5, true, true)
	_add_block_row(55, 8, 5, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.WAVE)
	_add_ground_enemy(64, PooledEnemy.Kind.BOUNCECAP, 45.0)
	add_checkpoint(Vector2(72 * TILE_SIZE + 8, 188))
	_add_spring(78, 550.0)
	_add_stone_platform(82, 7, 5, 2, true)
	_add_stone_platform(91, 5, 6)
	_add_coin_line(91, 68, 6)
	add_entity(HIDDEN_AREA_SCENE, Vector2(99 * TILE_SIZE, 92), {"cover_size": Vector2(112, 76)})
	_cut_pit(104, 4, true, true)
	_add_enemy_at(114, 108, PooledEnemy.Kind.GEARWING, 76.0)
	_add_ground_enemy(121, PooledEnemy.Kind.WADDLEDUCK, 46.0)
	_add_block_row(127, 7, 5, 1, GearBlock.Content.MUSHROOM, true, BlockPattern.SPLIT)
	_finish_standard_stage()


func _build_frozen_crossing() -> void:
	_build_ground()
	_add_block_row(12, 8, 6, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.STEPS)
	_add_ground_enemy(23, PooledEnemy.Kind.WADDLEDUCK, 54.0)
	_cut_pit(31, 5, true, true)
	_add_stone_platform(40, 9, 4, 2, true)
	_add_stone_platform(46, 7, 4)
	_add_entity_falling_rock(43)
	_add_coin_arc_cells(47, 98, 7, 15.0, 22.0)
	_cut_pit(57, 6, true, true)
	_add_ground_enemy(69, PooledEnemy.Kind.BOUNCECAP, 46.0)
	add_checkpoint(Vector2(77 * TILE_SIZE + 8, 188))
	_add_ground_enemy(80, PooledEnemy.Kind.SHELLBACK, 28.0)
	_add_spring(84, 535.0)
	_add_stone_platform(88, 6, 7, 2, true)
	_add_enemy_at(98, 108, PooledEnemy.Kind.GEARWING, 86.0)
	_cut_pit(105, 5, true, true)
	_add_entity_falling_rock(116)
	_add_ground_enemy(122, PooledEnemy.Kind.WADDLEDUCK, 48.0)
	_add_block_row(128, 8, 6, 3, GearBlock.Content.MUSHROOM, false, BlockPattern.WAVE)
	_add_coin_arc_cells(132, 102, 7, 14.0, 18.0)
	_finish_standard_stage()


func _build_foundry_gauntlet() -> void:
	_build_ground(3)
	_add_block_row(11, 8, 6, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.CROWN)
	_add_ground_enemy(22, PooledEnemy.Kind.BEETLE_BOT, 48.0)
	add_cactus(Vector2(31 * TILE_SIZE + 8, 192), true, 0.6)
	_cut_pit(42, 4, true, true)
	_add_stone_platform(50, 8, 7, 3, true)
	_add_enemy_at(54, 104, PooledEnemy.Kind.GEARWING, 78.0)
	_add_spring(61, 535.0)
	_add_stone_platform(65, 5, 7, 3)
	_add_coin_line(65, 68, 7)
	_add_ground_enemy(76, PooledEnemy.Kind.WADDLEDUCK, 50.0)
	add_checkpoint(Vector2(83 * TILE_SIZE + 8, 188))
	_add_ground_enemy(87, PooledEnemy.Kind.SHELLBACK, 30.0)
	_cut_pit(91, 5, true, true)
	_add_block_row(101, 7, 6, 3, GearBlock.Content.MULTI_COIN, false, BlockPattern.WAVE)
	add_cactus(Vector2(113 * TILE_SIZE + 8, 192), false)
	_add_entity_falling_rock(122)
	_add_ground_enemy(128, PooledEnemy.Kind.BOUNCECAP, 45.0)
	_cut_pit(136, 4, true, true)
	_add_ground_enemy(145, PooledEnemy.Kind.WADDLEDUCK, 42.0)
	_add_block_row(149, 8, 5, 2, GearBlock.Content.MUSHROOM, true, BlockPattern.SPLIT)
	_finish_standard_stage()


func _build_final_stronghold() -> void:
	_build_ground(3)
	_add_block_row(12, 8, 7, 3, GearBlock.Content.MUSHROOM, false, BlockPattern.CROWN)
	_add_ground_enemy(24, PooledEnemy.Kind.WADDLEDUCK, 46.0)
	_add_stone_platform(30, 8, 7, 3, true)
	_add_coin_arc_cells(33, 103, 7, 15.0, 20.0)
	add_cactus(Vector2(43 * TILE_SIZE + 8, 192), true, 1.1)
	_add_ground_enemy(52, PooledEnemy.Kind.BOUNCECAP, 44.0)
	add_checkpoint(Vector2(59 * TILE_SIZE + 8, 188))
	_add_block_row(63, 7, 6, 2, GearBlock.Content.MUSHROOM, true, BlockPattern.STEPS)
	_add_ground_enemy(70, PooledEnemy.Kind.SHELLBACK, 28.0)
	_add_spring(73, 505.0)
	_add_stone_platform(77, 6, 6, 3)
	_finish_boss_stage(GearheartGuardian.Variant.GEARHEART, 78, 88, 26)


func _build_ruined_canopy() -> void:
	_build_ground()
	_add_block_row(11, 8, 7, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.CROWN)
	_add_stone_platform(24, 10, 4, 2, true)
	_add_stone_platform(28, 8, 4, 3)
	_add_coin_arc_cells(28, 108, 7, 14.0, 23.0)
	_add_ground_enemy(37, PooledEnemy.Kind.WADDLEDUCK, 55.0)
	_cut_pit(44, 4, true, true)
	add_pipe(Vector2(54 * TILE_SIZE + 8, 192), 48.0, GearPipe.TravelMode.ENTER_BONUS, 2)
	_add_block_row(61, 7, 6, 3, GearBlock.Content.MULTI_COIN, true, BlockPattern.SPLIT)
	add_checkpoint(Vector2(72 * TILE_SIZE + 8, 188))
	add_cactus(Vector2(80 * TILE_SIZE + 8, 192), true, 0.35)
	_add_stone_platform(88, 9, 5, 2, true)
	_add_stone_platform(94, 7, 5, 3)
	_add_enemy_at(99, 100, PooledEnemy.Kind.GEARWING, 90.0)
	_cut_pit(106, 5, true, true)
	_add_spring(116, 555.0)
	_add_stone_platform(120, 6, 8, 2, true)
	_add_block_row(132, 8, 6, 2, GearBlock.Content.MUSHROOM, true, BlockPattern.WAVE)
	_add_ground_enemy(141, PooledEnemy.Kind.SHELLBACK, 34.0)
	_finish_standard_stage()


func _build_echo_mines() -> void:
	_build_ground(1)
	_add_spring(12, 570.0)
	_add_stone_platform(16, 9, 5, 2, true)
	_add_stone_platform(24, 6, 6, 1)
	_add_block_row(25, 2, 5, 1, GearBlock.Content.MUSHROOM, false, BlockPattern.WAVE)
	_add_enemy_at(35, 92, PooledEnemy.Kind.GEARWING, 98.0)
	_cut_pit(42, 6, true, true)
	_add_stone_platform(53, 8, 8, 3, true)
	_add_entity_falling_rock(57)
	_add_ground_enemy(65, PooledEnemy.Kind.BOUNCECAP, 52.0)
	add_checkpoint(Vector2(75 * TILE_SIZE + 8, 188))
	_add_block_row(81, 8, 7, 3, GearBlock.Content.MULTI_COIN, false, BlockPattern.CROWN)
	_add_stone_platform(94, 6, 5, 2, true)
	_add_stone_platform(102, 4, 5, 3)
	_add_coin_arc_cells(104, 66, 8, 14.0, 21.0)
	_add_enemy_at(112, 102, PooledEnemy.Kind.GEARWING, 105.0)
	_cut_pit(120, 5, true, true)
	_add_entity_falling_rock(132)
	_add_block_row(137, 7, 6, 2, GearBlock.Content.MUSHROOM, true, BlockPattern.SPLIT)
	_add_ground_enemy(147, PooledEnemy.Kind.SHELLBACK, 35.0)
	_finish_standard_stage()


func _build_storm_foundry() -> void:
	_build_ground(3)
	_add_block_row(11, 8, 7, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.STEPS)
	_add_ground_enemy(23, PooledEnemy.Kind.WADDLEDUCK, 58.0)
	_cut_pit(31, 5, true, true)
	_add_stone_platform(40, 8, 7, 3, true)
	_add_enemy_at(45, 103, PooledEnemy.Kind.GEARWING, 104.0)
	add_cactus(Vector2(52 * TILE_SIZE + 8, 192), true, 0.8)
	_add_block_row(59, 6, 6, 3, GearBlock.Content.MULTI_COIN, false, BlockPattern.CROWN)
	add_checkpoint(Vector2(70 * TILE_SIZE + 8, 188))
	_cut_pit(77, 5, true, true)
	_add_spring(87, 545.0)
	_add_stone_platform(91, 6, 7, 3, true)
	_add_block_row(100, 8, 6, 2, GearBlock.Content.MUSHROOM, true, BlockPattern.SPLIT)
	_add_ground_enemy(111, PooledEnemy.Kind.SHELLBACK, 38.0)
	_add_ground_enemy(119, PooledEnemy.Kind.BEETLE_BOT, 45.0)
	_finish_boss_stage(GearheartGuardian.Variant.STORM_FORGE, 132, 138, 32)


func _build_glacier_switchbacks() -> void:
	_build_ground()
	_add_block_row(12, 8, 6, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.CROWN)
	_add_stone_platform(23, 10, 4)
	_add_stone_platform(28, 8, 4, 2, true)
	_add_stone_platform(33, 6, 4)
	_add_stone_platform(38, 4, 5, 2, true)
	_add_coin_arc_cells(36, 70, 9, 14.0, 25.0)
	_add_enemy_at(48, 91, PooledEnemy.Kind.GEARWING, 105.0)
	_cut_pit(55, 6, true, true)
	_add_entity_falling_rock(63)
	_add_block_row(67, 7, 7, 3, GearBlock.Content.MULTI_COIN, true, BlockPattern.WAVE)
	add_checkpoint(Vector2(78 * TILE_SIZE + 8, 188))
	_add_ground_enemy(84, PooledEnemy.Kind.SHELLBACK, 34.0)
	_add_spring(90, 575.0)
	_add_stone_platform(94, 5, 8, 2, true)
	_add_enemy_at(105, 92, PooledEnemy.Kind.GEARWING, 110.0)
	_cut_pit(113, 6, true, true)
	_add_stone_platform(124, 8, 5, 3)
	_add_block_row(131, 6, 7, 3, GearBlock.Content.MUSHROOM, true, BlockPattern.STEPS)
	_add_entity_falling_rock(143)
	_add_ground_enemy(150, PooledEnemy.Kind.WADDLEDUCK, 58.0)
	_finish_standard_stage()


func _build_magma_aqueduct() -> void:
	_build_ground(3)
	_add_block_row(11, 8, 7, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.WAVE)
	add_cactus(Vector2(23 * TILE_SIZE + 8, 192), true, 0.25)
	_cut_pit(31, 6, true, true)
	_add_stone_platform(42, 9, 6, 3, true)
	_add_stone_platform(50, 7, 6, 2)
	_add_coin_arc_cells(52, 97, 8, 15.0, 24.0)
	_add_ground_enemy(61, PooledEnemy.Kind.BEETLE_BOT, 52.0)
	_add_block_row(67, 6, 7, 3, GearBlock.Content.MULTI_COIN, false, BlockPattern.CROWN)
	add_checkpoint(Vector2(78 * TILE_SIZE + 8, 188))
	_cut_pit(84, 6, true, true)
	_add_spring(95, 575.0)
	_add_stone_platform(99, 5, 8, 3, true)
	_add_enemy_at(108, 92, PooledEnemy.Kind.GEARWING, 112.0)
	add_cactus(Vector2(118 * TILE_SIZE + 8, 192), true, 1.7)
	_add_block_row(124, 7, 6, 2, GearBlock.Content.MUSHROOM, true, BlockPattern.SPLIT)
	_cut_pit(137, 5, true, true)
	_add_ground_enemy(148, PooledEnemy.Kind.SHELLBACK, 38.0)
	_add_ground_enemy(155, PooledEnemy.Kind.WADDLEDUCK, 60.0)
	_finish_standard_stage()


func _build_core_descent() -> void:
	_build_ground(1)
	_add_spring(11, 585.0)
	_add_stone_platform(15, 8, 6, 2, true)
	_add_stone_platform(24, 5, 6, 3, true)
	_add_block_row(25, 1, 5, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.CROWN)
	_add_enemy_at(36, 87, PooledEnemy.Kind.GEARWING, 110.0)
	_cut_pit(44, 6, true, true)
	_add_stone_platform(55, 7, 7, 3, true)
	_add_entity_falling_rock(59)
	_add_ground_enemy(67, PooledEnemy.Kind.SHELLBACK, 37.0)
	add_checkpoint(Vector2(74 * TILE_SIZE + 8, 188))
	_add_block_row(80, 7, 7, 3, GearBlock.Content.MULTI_COIN, false, BlockPattern.SPLIT)
	_add_stone_platform(94, 5, 7, 2, true)
	_add_spring(103, 570.0)
	_add_block_row(108, 7, 6, 2, GearBlock.Content.MUSHROOM, true, BlockPattern.WAVE)
	_add_ground_enemy(119, PooledEnemy.Kind.BEETLE_BOT, 50.0)
	_finish_boss_stage(GearheartGuardian.Variant.MAGMA_COLOSSUS, 136, 143, 38)


func _build_overgrown_clocktower() -> void:
	_build_ground()
	_add_block_row(10, 8, 7, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.SPLIT)
	_add_stone_platform(22, 10, 4, 2, true)
	_add_stone_platform(27, 8, 4, 3)
	_add_stone_platform(32, 6, 4, 2, true)
	_add_stone_platform(37, 4, 5, 3)
	_add_enemy_at(42, 80, PooledEnemy.Kind.GEARWING, 115.0)
	add_pipe(Vector2(50 * TILE_SIZE + 8, 192), 56.0, GearPipe.TravelMode.ENTER_BONUS, 3)
	_cut_pit(60, 5, true, true)
	_add_block_row(69, 7, 7, 3, GearBlock.Content.MULTI_COIN, true, BlockPattern.CROWN)
	add_checkpoint(Vector2(80 * TILE_SIZE + 8, 188))
	add_cactus(Vector2(88 * TILE_SIZE + 8, 192), true, 0.9)
	_add_spring(96, 575.0)
	_add_stone_platform(100, 5, 8, 2, true)
	_add_enemy_at(111, 95, PooledEnemy.Kind.GEARWING, 118.0)
	_cut_pit(119, 6, true, true)
	_add_block_row(130, 6, 7, 3, GearBlock.Content.MUSHROOM, true, BlockPattern.STEPS)
	_add_ground_enemy(143, PooledEnemy.Kind.SHELLBACK, 40.0)
	_add_ground_enemy(151, PooledEnemy.Kind.WADDLEDUCK, 62.0)
	_finish_standard_stage()


func _build_lunar_frost_keep() -> void:
	_build_ground(2)
	_add_block_row(11, 8, 7, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.CROWN)
	_add_stone_platform(24, 8, 6, 2, true)
	_cut_pit(33, 6, true, true)
	_add_stone_platform(44, 6, 8, 3, true)
	_add_entity_falling_rock(48)
	_add_enemy_at(55, 93, PooledEnemy.Kind.GEARWING, 118.0)
	_add_block_row(62, 8, 7, 3, GearBlock.Content.MULTI_COIN, false, BlockPattern.WAVE)
	add_checkpoint(Vector2(73 * TILE_SIZE + 8, 188))
	_add_ground_enemy(80, PooledEnemy.Kind.SHELLBACK, 40.0)
	_add_spring(87, 590.0)
	_add_stone_platform(91, 5, 8, 2, true)
	_cut_pit(104, 6, true, true)
	_add_block_row(115, 7, 7, 3, GearBlock.Content.MUSHROOM, true, BlockPattern.SPLIT)
	_add_ground_enemy(126, PooledEnemy.Kind.WADDLEDUCK, 62.0)
	_finish_boss_stage(GearheartGuardian.Variant.FROST_CROWN, 140, 147, 44)


func _build_royal_gearway() -> void:
	_build_ground(3)
	_add_block_row(10, 8, 7, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.STEPS)
	_add_ground_enemy(22, PooledEnemy.Kind.BEETLE_BOT, 55.0)
	_cut_pit(30, 6, true, true)
	_add_stone_platform(41, 9, 6, 3, true)
	_add_stone_platform(49, 7, 6, 2, true)
	_add_enemy_at(55, 98, PooledEnemy.Kind.GEARWING, 120.0)
	_add_block_row(63, 5, 7, 3, GearBlock.Content.MULTI_COIN, false, BlockPattern.CROWN)
	add_checkpoint(Vector2(75 * TILE_SIZE + 8, 188))
	add_cactus(Vector2(83 * TILE_SIZE + 8, 192), true, 1.2)
	_add_ground_enemy(91, PooledEnemy.Kind.SHELLBACK, 42.0)
	_cut_pit(98, 6, true, true)
	_add_spring(109, 590.0)
	_add_stone_platform(113, 5, 9, 3, true)
	_add_block_row(126, 7, 7, 3, GearBlock.Content.MUSHROOM, true, BlockPattern.SPLIT)
	_add_enemy_at(140, 98, PooledEnemy.Kind.GEARWING, 122.0)
	_cut_pit(148, 6, true, true)
	_add_ground_enemy(159, PooledEnemy.Kind.WADDLEDUCK, 64.0)
	_finish_standard_stage()


func _build_chrono_throne() -> void:
	_build_ground(3)
	_add_block_row(10, 8, 7, 2, GearBlock.Content.MUSHROOM, false, BlockPattern.CROWN)
	_add_ground_enemy(22, PooledEnemy.Kind.SHELLBACK, 40.0)
	_add_stone_platform(29, 8, 7, 3, true)
	_cut_pit(39, 6, true, true)
	_add_enemy_at(50, 98, PooledEnemy.Kind.GEARWING, 124.0)
	_add_block_row(57, 6, 7, 3, GearBlock.Content.MULTI_COIN, true, BlockPattern.SPLIT)
	add_checkpoint(Vector2(69 * TILE_SIZE + 8, 188))
	add_cactus(Vector2(77 * TILE_SIZE + 8, 192), true, 0.4)
	_add_spring(84, 600.0)
	_add_stone_platform(88, 5, 8, 3, true)
	_add_block_row(99, 7, 7, 3, GearBlock.Content.MUSHROOM, true, BlockPattern.WAVE)
	_add_ground_enemy(111, PooledEnemy.Kind.BEETLE_BOT, 54.0)
	_add_ground_enemy(118, PooledEnemy.Kind.WADDLEDUCK, 64.0)
	_finish_boss_stage(GearheartGuardian.Variant.CHRONO_SOVEREIGN, 128, 135, 54, true)


func _apply_difficulty_support() -> void:
	# Easy adds a clearly marked early safety pickup in every stage. Hard keeps
	# the authored power route but trims loose coins and adds patrol pressure in
	# the enemy helpers below, so all three modes remain finishable.
	if SettingsManager.difficulty_id == "easy":
		add_block(Vector2(7 * TILE_SIZE + 8, 8 * TILE_SIZE + 8), GearBlock.Type.QUESTION, GearBlock.Content.MUSHROOM)


func _build_ground(tile: int = 0) -> void:
	solid_rect(0, 12, level_width_tiles, 4, tile)


func _finish_standard_stage() -> void:
	var flag := add_flag(Vector2(level_width_tiles * TILE_SIZE - 50, 188), "", CAMPAIGN_SCENE)
	flag.activated.connect(_on_stage_goal_reached)


func _finish_boss_stage(
	variant: int,
	boss_cell: int,
	gate_cell: int,
	boss_health: int,
	is_final: bool = false
) -> void:
	boss = add_entity(BOSS_SCENE, Vector2(boss_cell * TILE_SIZE, 150), {
		"boss_variant": variant,
		"max_health": boss_health,
	}) as GearheartGuardian
	hud.bind_boss(boss)
	boss.defeated.connect(_on_boss_defeated)
	_create_arena_gate(gate_cell * TILE_SIZE)
	if is_final:
		final_exit = add_entity(EXIT_SCENE, Vector2(level_width_tiles * TILE_SIZE - 50, 188), {
			"unlock_level_id": "complete",
			"next_scene": "",
		}) as LevelExit
		final_exit.activated.connect(_on_stage_goal_reached)
		return
	var flag := add_flag(Vector2(level_width_tiles * TILE_SIZE - 50, 188), "", CAMPAIGN_SCENE)
	flag.activated.connect(_on_stage_goal_reached)


func _cut_pit(cell_x: int, width: int, add_coins: bool = true, moving_platform: bool = false) -> void:
	pit_ranges.append(Vector2i(cell_x, width))
	erase_rect(cell_x, 12, width, 4)
	if add_coins:
		add_collectible_arc(
			Vector2((cell_x + width * 0.5) * TILE_SIZE, 151),
			width + 2,
			14.0,
			22.0
		)
	if moving_platform:
		add_entity(MOVING_PLATFORM_SCENE, Vector2((cell_x + width * 0.5) * TILE_SIZE, 166), {
			"offset": Vector2(0, -34.0 if width <= 4 else -48.0),
			"travel_time": 2.0 + width * 0.08,
		})


func _add_block_row(
	cell_x: int,
	cell_y: int,
	count: int,
	question_index: int = -1,
	content: int = GearBlock.Content.COIN,
	hidden_reward: bool = false,
	pattern: int = BlockPattern.ROW
) -> void:
	used_block_patterns[pattern] = true
	for offset: int in count:
		var type := GearBlock.Type.QUESTION if offset == question_index else GearBlock.Type.BRICK
		var item_content := content if offset == question_index else GearBlock.Content.NONE
		if hidden_reward and offset == question_index:
			type = GearBlock.Type.BRICK
		var shaped_y := cell_y - _block_pattern_lift(pattern, offset, count)
		add_block(Vector2((cell_x + offset) * TILE_SIZE + 8, shaped_y * TILE_SIZE + 8), type, item_content)


func _block_pattern_lift(pattern: int, offset: int, count: int) -> int:
	match pattern:
		BlockPattern.WAVE:
			return offset % 2
		BlockPattern.STEPS:
			return mini(offset / 2, 2)
		BlockPattern.CROWN:
			return mini(mini(offset, count - 1 - offset), 2)
		BlockPattern.SPLIT:
			var center := count / 2
			return 2 if offset == center else (1 if abs(offset - center) == 2 else 0)
		_:
			return 0


func _add_stone_platform(
	cell_x: int,
	cell_y: int,
	width: int,
	tile: int = 2,
	breakable: bool = false
) -> void:
	solid_rect(cell_x, cell_y, width, 1, tile)
	if breakable:
		register_breakable_stone_rect(cell_x, cell_y, width)


func _add_coin_line(cell_x: int, world_y: int, count: int, spacing_cells: int = 1) -> void:
	for offset: int in count:
		add_collectible(Vector2((cell_x + offset * spacing_cells) * TILE_SIZE + 8, world_y))


func _add_vertical_coins(cell_x: int, start_y: int, count: int, spacing: int) -> void:
	for offset: int in count:
		add_collectible(Vector2(cell_x * TILE_SIZE + 8, start_y - offset * spacing))


func _add_coin_arc_cells(
	center_cell: int,
	world_y: int,
	count: int,
	spacing: float,
	height: float
) -> void:
	add_collectible_arc(Vector2(center_cell * TILE_SIZE + 8, world_y), count, spacing, height)


func _add_spring(cell_x: int, strength: float) -> void:
	add_entity(SPRING_SCENE, Vector2(cell_x * TILE_SIZE + 8, 181), {"launch_strength": strength})


func _add_entity_falling_rock(cell_x: int) -> void:
	add_entity(FALLING_ROCK_SCENE, Vector2(cell_x * TILE_SIZE + 8, 58))


func _add_ground_enemy(cell_x: int, kind: int, patrol: float) -> void:
	enemy_spawn_counter += 1
	if SettingsManager.difficulty_id == "easy" and enemy_spawn_counter % 4 == 0:
		return
	add_enemy(Vector2(cell_x * TILE_SIZE + 8, 174), kind, patrol, false)
	if SettingsManager.difficulty_id == "hard" and enemy_spawn_counter % 4 == 0 and _is_safe_ground(cell_x + 2):
		add_enemy(Vector2((cell_x + 2) * TILE_SIZE + 8, 174), kind, patrol * 0.75, false)


func _add_enemy_at(cell_x: int, world_y: int, kind: int, patrol: float) -> void:
	enemy_spawn_counter += 1
	if SettingsManager.difficulty_id == "easy" and enemy_spawn_counter % 4 == 0:
		return
	add_enemy(Vector2(cell_x * TILE_SIZE + 8, world_y), kind, patrol, false)
	if SettingsManager.difficulty_id == "hard" and enemy_spawn_counter % 4 == 0:
		add_enemy(Vector2((cell_x + 2) * TILE_SIZE + 8, world_y - 10), kind, patrol * 0.8, false)


func _create_arena_gate(gate_x: float) -> void:
	arena_gate = StaticBody2D.new()
	arena_gate.name = "CampaignArenaGate"
	arena_gate.position = Vector2(gate_x, 116)
	arena_gate.collision_layer = 1
	arena_gate_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 152)
	arena_gate_collision.shape = shape
	arena_gate.add_child(arena_gate_collision)
	var glow := Line2D.new()
	glow.points = PackedVector2Array([Vector2(0, -76), Vector2(0, 76)])
	glow.width = 11.0
	glow.default_color = Color(0.25, 0.95, 1.0, 0.28)
	arena_gate.add_child(glow)
	var beam := Line2D.new()
	beam.points = glow.points
	beam.width = 4.0
	beam.default_color = Color("9cffff")
	arena_gate.add_child(beam)
	entity_root.add_child(arena_gate)


func _on_boss_defeated() -> void:
	arena_gate_collision.set_deferred("disabled", true)
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_property(arena_gate, "modulate:a", 0.0, 0.4)
	fade.tween_callback(arena_gate.queue_free)
	hud.show_path_open()


func _on_stage_goal_reached(_body: Node2D) -> void:
	if stage_index >= STAGE_COUNT - 1:
		GameManager.complete_campaign()
		# 通关菜单关闭后允许玩家继续浏览最终关；计时仍由 finish_level 停止。
		player.controls_locked = false
		player.velocity = Vector2.ZERO
		hud.show_campaign_complete()
		return
	GameManager.advance_campaign_stage()


func _is_safe_ground(cell_x: int) -> bool:
	for pit: Vector2i in pit_ranges:
		if cell_x >= pit.x - 1 and cell_x <= pit.x + pit.y:
			return false
	return cell_x >= 4 and cell_x < level_width_tiles - 5


func add_block(world_position: Vector2, block_type: int, content: int = 0) -> GearBlock:
	var key := Vector2i(roundi(world_position.x), roundi(world_position.y))
	if occupied_block_positions.has(key):
		return null
	occupied_block_positions[key] = true
	var block := super.add_block(world_position, block_type, content)
	if block != null:
		block.visual_theme = STAGE_BLOCK_THEMES[stage_index]
		block.queue_redraw()
	return block


func add_collectible(world_position: Vector2, heals: bool = false) -> GearCoin:
	collectible_spawn_counter += 1
	if SettingsManager.difficulty_id == "hard" and not heals and collectible_spawn_counter % 5 == 0:
		return null
	var key := Vector2i(roundi(world_position.x), roundi(world_position.y))
	if occupied_coin_positions.has(key):
		return null
	occupied_coin_positions[key] = true
	return super.add_collectible(world_position, heals)
