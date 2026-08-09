extends ForestGearLevel

const CAMPAIGN_SCENE := "res://levels/campaign_level.tscn"
const WORLD_BIOMES: Array[String] = [
	"forest", "cave", "snow", "city", "forest", "cave", "snow", "city",
]

var stage_index: int = 0
var world_number: int = 1
var stage_number: int = 1
var pit_ranges: Array[Vector2i] = []
var boss: GearheartGuardian
var arena_gate: StaticBody2D
var arena_gate_collision: CollisionShape2D
var final_exit: LevelExit


func _enter_tree() -> void:
	stage_index = clampi(GameManager.campaign_stage, 0, 31)
	world_number = stage_index / 4 + 1
	stage_number = stage_index % 4 + 1
	biome = WORLD_BIOMES[world_number - 1]
	level_id = "world_%d_%d" % [world_number, stage_number]
	time_limit = maxf(150.0, 230.0 - float(world_number - 1) * 8.0)
	spawn_point = Vector2(64, 150)
	level_width_tiles = 120 + world_number * 5 if stage_number == 4 else 138 + world_number * 6 + stage_number * 4


func _build_level() -> void:
	if stage_number == 4:
		_build_boss_stage()
	else:
		_build_standard_stage()


func _build_standard_stage() -> void:
	solid_rect(0, 12, level_width_tiles, 4, 0)
	_build_pits()
	_build_platform_route()
	_build_power_blocks()
	_build_obstacles()
	_build_enemies_and_hazards()
	var checkpoint_cell := _nearest_safe_cell(level_width_tiles / 2)
	add_entity(CHECKPOINT_SCENE, Vector2(checkpoint_cell * TILE_SIZE + 8, 188))
	var flag := add_flag(
		Vector2(level_width_tiles * TILE_SIZE - 50, 188),
		"",
		CAMPAIGN_SCENE
	)
	flag.activated.connect(_on_stage_goal_reached)


func _build_pits() -> void:
	var pit_count := 2 + (world_number - 1) / 2 + (stage_number - 1)
	var usable_width := level_width_tiles - 44
	var spacing := maxi(18, usable_width / maxi(pit_count, 1))
	for index: int in pit_count:
		var pit_width := 2 + posmod(world_number + stage_number + index, 3)
		var pit_x := 22 + index * spacing + posmod(world_number * 7 + stage_number * 5 + index * 3, 7)
		pit_x = mini(pit_x, level_width_tiles - 18 - pit_width)
		pit_ranges.append(Vector2i(pit_x, pit_width))
		erase_rect(pit_x, 12, pit_width, 4)
		add_collectible_arc(Vector2((pit_x + pit_width * 0.5) * TILE_SIZE, 142), pit_width + 2, 14.0, 22.0)
		if world_number >= 3 and index % 2 == 0:
			add_entity(MOVING_PLATFORM_SCENE, Vector2((pit_x + pit_width * 0.5) * TILE_SIZE, 165), {
				"offset": Vector2(0, -42 - world_number * 2),
				"travel_time": maxf(1.2, 2.4 - world_number * 0.1),
			})


func _build_platform_route() -> void:
	var platform_index := 0
	for cell_x: int in range(16, level_width_tiles - 16, 16):
		var safe_x := _nearest_safe_cell(cell_x)
		var platform_y := 9 - posmod(world_number + stage_number + platform_index, 3)
		var platform_width := 3 + posmod(world_number + platform_index, 4)
		solid_rect(safe_x, platform_y, platform_width, 1, 2)
		for coin_x: int in range(safe_x, safe_x + platform_width):
			add_collectible(Vector2(coin_x * TILE_SIZE + 8, (platform_y - 2) * TILE_SIZE + 8))
		platform_index += 1


func _build_power_blocks() -> void:
	var first_power_x := _nearest_safe_cell(30 + stage_number * 2)
	var second_power_x := _nearest_safe_cell(level_width_tiles / 2 + 10)
	add_block(Vector2(first_power_x * TILE_SIZE + 8, 8 * TILE_SIZE + 8), GearBlock.Type.QUESTION, GearBlock.Content.MUSHROOM)
	add_block(Vector2(second_power_x * TILE_SIZE + 8, 7 * TILE_SIZE + 8), GearBlock.Type.QUESTION, GearBlock.Content.MUSHROOM)
	for offset: int in [-2, -1, 1, 2]:
		add_block(Vector2((first_power_x + offset) * TILE_SIZE + 8, 8 * TILE_SIZE + 8), GearBlock.Type.BRICK)


func _build_obstacles() -> void:
	for obstacle_index: int in 3 + stage_number:
		var cell_x := _nearest_safe_cell(42 + obstacle_index * 27 + world_number * 2)
		if obstacle_index % 2 == 0:
			add_pipe(Vector2(cell_x * TILE_SIZE, 12 * TILE_SIZE), 42.0 + posmod(obstacle_index + world_number, 3) * 8.0)
		elif world_number >= 2:
			add_entity(SPRING_SCENE, Vector2(cell_x * TILE_SIZE + 8, 181), {
				"launch_strength": 470.0 + world_number * 12.0,
			})


func _build_enemies_and_hazards() -> void:
	var enemy_count := 3 + world_number + stage_number
	for enemy_index: int in enemy_count:
		var cell_x := _nearest_safe_cell(20 + enemy_index * maxi(12, (level_width_tiles - 38) / enemy_count))
		var kind := posmod(world_number + stage_number + enemy_index, 3)
		add_enemy(Vector2(cell_x * TILE_SIZE + 8, 174), kind, 52.0 + world_number * 6.0)
		if world_number >= 3 and enemy_index % 3 == 1:
			add_entity(SPIKE_SCENE, Vector2((cell_x + 5) * TILE_SIZE, 184))
		if world_number >= 5 and enemy_index % 4 == 2:
			add_entity(FALLING_ROCK_SCENE, Vector2(cell_x * TILE_SIZE + 8, 60))
	if world_number >= 6:
		add_entity(HIDDEN_AREA_SCENE, Vector2((level_width_tiles - 24) * TILE_SIZE, 128), {
			"cover_size": Vector2(112, 80),
		})


func _build_boss_stage() -> void:
	solid_rect(0, 12, level_width_tiles, 4, 3)
	for platform_index: int in 4:
		var cell_x := 10 + platform_index * ((level_width_tiles - 32) / 4)
		var platform_y := 9 - posmod(platform_index + world_number, 3)
		solid_rect(cell_x, platform_y, 7, 1, 2)
	add_entity(SPIKE_SCENE, Vector2(480, 184))
	add_entity(SPIKE_SCENE, Vector2(760 + world_number * 10, 184))
	add_entity(SPRING_SCENE, Vector2(260, 181), {"launch_strength": 500.0 + world_number * 8.0})
	var gate_x := (level_width_tiles - 18) * TILE_SIZE
	var boss_x := gate_x - 250
	boss = add_entity(BOSS_SCENE, Vector2(boss_x, 150), {
		"max_health": 8 + world_number * 3,
	}) as GearheartGuardian
	hud.bind_boss(boss)
	boss.defeated.connect(_on_boss_defeated)
	_create_arena_gate(gate_x)
	final_exit = add_entity(EXIT_SCENE, Vector2(level_width_tiles * TILE_SIZE - 50, 188), {
		"unlock_level_id": "complete" if stage_index == 31 else "",
		"next_scene": "" if stage_index == 31 else CAMPAIGN_SCENE,
	}) as LevelExit
	final_exit.activated.connect(_on_stage_goal_reached)


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
	glow.default_color = Color(0.25, 0.95, 1.0, 0.25)
	arena_gate.add_child(glow)
	var beam := Line2D.new()
	beam.points = glow.points
	beam.width = 4.0
	beam.default_color = Color("73edf5")
	arena_gate.add_child(beam)
	entity_root.add_child(arena_gate)


func _on_boss_defeated() -> void:
	arena_gate_collision.set_deferred("disabled", true)
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_property(arena_gate, "modulate:a", 0.0, 0.4)
	fade.tween_callback(arena_gate.queue_free)
	hud.show_path_open()


func _on_stage_goal_reached(_body: Node2D) -> void:
	if stage_index >= 31:
		player.controls_locked = true
		player.velocity = Vector2.ZERO
		hud.show_campaign_complete()
		return
	GameManager.advance_campaign_stage()


func _nearest_safe_cell(requested_x: int) -> int:
	var cell_x := clampi(requested_x, 8, level_width_tiles - 12)
	for search_offset: int in 12:
		for candidate: int in [cell_x + search_offset, cell_x - search_offset]:
			if _is_safe_ground(candidate):
				return candidate
	return cell_x


func _is_safe_ground(cell_x: int) -> bool:
	for pit: Vector2i in pit_ranges:
		if cell_x >= pit.x - 2 and cell_x <= pit.x + pit.y + 2:
			return false
	return cell_x >= 4 and cell_x < level_width_tiles - 8
