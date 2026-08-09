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
var occupied_block_positions: Dictionary = {}
var occupied_coin_positions: Dictionary = {}


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
	_build_obstacles()
	_build_enemies_and_hazards()
	var checkpoint_cell := _nearest_safe_cell(level_width_tiles / 2)
	add_checkpoint(Vector2(checkpoint_cell * TILE_SIZE + 8, 188))
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
	# Each 24-tile section follows a readable setup → reward → threat rhythm.
	# Blocks stay in the opening third; the final third is reserved for a pipe.
	var section_index := 0
	for section_start: int in range(13, level_width_tiles - 22, 24):
		var anchor := section_start + 2
		var pattern := _section_pattern(section_index)
		var reward_content := GearBlock.Content.MUSHROOM if section_index in [0, 3] else GearBlock.Content.COIN
		_add_section_blocks(anchor, pattern, reward_content)
		_add_section_coins(anchor, pattern)
		section_index += 1


func _section_pattern(section_index: int) -> int:
	# World 1-1 deliberately teaches with low, simple rows before introducing
	# stairs and elevated arrangements in later stages.
	if world_number == 1 and stage_number == 1:
		return [0, 3, 0, 3][section_index % 4]
	return posmod(world_number * 3 + stage_number + section_index, 4)


func _add_section_blocks(anchor: int, pattern: int, reward_content: int) -> void:
	match pattern:
		0:
			for offset: int in [0, 1, 3, 4]:
				add_block(Vector2((anchor + offset) * TILE_SIZE + 8, 8 * TILE_SIZE + 8), GearBlock.Type.BRICK)
			add_block(Vector2((anchor + 2) * TILE_SIZE + 8, 8 * TILE_SIZE + 8), GearBlock.Type.QUESTION, reward_content)
		1:
			for offset: int in [0, 1, 2, 3]:
				add_block(Vector2((anchor + offset) * TILE_SIZE + 8, 7 * TILE_SIZE + 8), GearBlock.Type.BRICK)
			add_block(Vector2((anchor + 1) * TILE_SIZE + 8, 5 * TILE_SIZE + 8), GearBlock.Type.QUESTION, reward_content)
		2:
			for offset: int in 4:
				add_block(Vector2((anchor + offset) * TILE_SIZE + 8, (9 - offset) * TILE_SIZE + 8), GearBlock.Type.BRICK)
			add_block(Vector2((anchor + 4) * TILE_SIZE + 8, 8 * TILE_SIZE + 8), GearBlock.Type.QUESTION, reward_content)
		3:
			for offset: int in [0, 1, 4, 5]:
				add_block(Vector2((anchor + offset) * TILE_SIZE + 8, 8 * TILE_SIZE + 8), GearBlock.Type.BRICK)
			add_block(Vector2((anchor + 2) * TILE_SIZE + 8, 7 * TILE_SIZE + 8), GearBlock.Type.QUESTION, reward_content)
			add_block(Vector2((anchor + 3) * TILE_SIZE + 8, 7 * TILE_SIZE + 8), GearBlock.Type.BRICK)


func _add_section_coins(anchor: int, pattern: int) -> void:
	# Low coins teach the route; the upper row rewards using the blocks as platforms.
	for offset: int in [-3, -2, -1]:
		var coin_cell := _nearest_open_coin_cell(anchor + offset, 158)
		if coin_cell >= 0:
			add_collectible(Vector2(coin_cell * TILE_SIZE + 8, 158))
	var upper_y := 78.0 if pattern == 1 else 96.0
	for offset: int in range(0, 5):
		var wave := sin(float(offset) / 4.0 * PI) * 12.0
		add_collectible(Vector2((anchor + offset) * TILE_SIZE + 8, upper_y - wave))


func _build_obstacles() -> void:
	# Pipes are section fixtures and are built with enemies below. Keep only
	# later-world mobility helpers here so no second pipe can crowd a cactus pipe.
	if world_number < 2:
		return
	for obstacle_index: int in 3 + stage_number:
		if obstacle_index % 2 == 1:
			var cell_x := _nearest_safe_cell(42 + obstacle_index * 27 + world_number * 2)
			add_entity(SPRING_SCENE, Vector2(cell_x * TILE_SIZE + 8, 181), {
				"launch_strength": 470.0 + world_number * 12.0,
			})


func _build_enemies_and_hazards() -> void:
	var section_starts: Array[int] = []
	var fixture_entries: Array[Vector2i] = []
	for section_start: int in range(13, level_width_tiles - 22, 24):
		var section_index := section_starts.size()
		section_starts.append(section_start)
		var fixture_cell := _safe_cell_in_band(section_start + 19, section_start + 17, section_start + 21)
		if fixture_cell >= 0:
			fixture_entries.append(Vector2i(section_index, fixture_cell))
	var cactus_sections: Array[int] = []
	if fixture_entries.size() >= 2:
		var first_cactus_slot := 1 if fixture_entries.size() >= 3 else 0
		var second_cactus_slot := fixture_entries.size() - 1
		if second_cactus_slot == first_cactus_slot:
			second_cactus_slot = 0
		cactus_sections.append(fixture_entries[first_cactus_slot].x)
		cactus_sections.append(fixture_entries[second_cactus_slot].x)

	var cactus_index := 0
	for section_index: int in section_starts.size():
		var section_start := section_starts[section_index]
		var cap_cell := _safe_cell_in_band(section_start + 12, section_start + 9, section_start + 15)
		if cap_cell >= 0:
			add_enemy(
				Vector2(cap_cell * TILE_SIZE + 8, 174),
				PooledEnemy.Kind.BOUNCECAP,
				38.0 + world_number * 4.0,
				false
			)
			if (world_number >= 2 or stage_number >= 2) and section_index % 2 == 1:
				var pair_cell := _safe_cell_in_band(cap_cell + 3, section_start + 9, section_start + 16)
				if pair_cell >= 0 and pair_cell != cap_cell:
					add_enemy(
						Vector2(pair_cell * TILE_SIZE + 8, 174),
						PooledEnemy.Kind.BOUNCECAP,
						34.0 + world_number * 3.0,
						false
					)
		if world_number >= 3 and section_index % 3 == 2:
			var support_cell := _safe_cell_in_band(section_start + 10, section_start + 9, section_start + 15)
			var support_kind := PooledEnemy.Kind.GEARWING if stage_number == 3 else PooledEnemy.Kind.BEETLE_BOT
			var support_y := 112.0 if support_kind == PooledEnemy.Kind.GEARWING else 174.0
			if support_cell >= 0:
				add_enemy(Vector2(support_cell * TILE_SIZE + 8, support_y), support_kind, 64.0 + world_number * 5.0, false)

		var fixture_cell := -1
		for entry: Vector2i in fixture_entries:
			if entry.x == section_index:
				fixture_cell = entry.y
				break
		if fixture_cell >= 0:
			if cactus_sections.has(section_index):
				var retracting_cactus := cactus_index == 1
				var cactus_phase := fposmod(cactus_index * 0.91 + world_number * 0.19 + stage_number * 0.31, 3.8)
				add_cactus(
					Vector2(fixture_cell * TILE_SIZE + 8, 192),
					retracting_cactus,
					cactus_phase
				)
				cactus_index += 1
			else:
				var pipe_height := 40.0 + posmod(floori(section_index / 2.0) + world_number, 3) * 8.0
				add_pipe(Vector2(fixture_cell * TILE_SIZE + 8, 192), pipe_height)
		if world_number >= 4 and section_index % 4 == 2:
			add_entity(SPIKE_SCENE, Vector2(_nearest_safe_cell(section_start + 10) * TILE_SIZE + 8, 184))
		if world_number >= 5 and section_index % 3 == 1 and cap_cell >= 0:
			add_entity(FALLING_ROCK_SCENE, Vector2(cap_cell * TILE_SIZE + 8, 60))
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
	_build_boss_approach(gate_x)
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


func _build_boss_approach(gate_x: float) -> void:
	# Strongholds retain the same visual language before the isolated boss arena.
	for cluster_index: int in 3:
		var anchor := 17 + cluster_index * 20 + posmod(world_number, 3)
		for offset: int in 5:
			var block_type := GearBlock.Type.QUESTION if offset == 2 else GearBlock.Type.BRICK
			var content := GearBlock.Content.COIN if offset == 2 else GearBlock.Content.NONE
			add_block(Vector2((anchor + offset) * TILE_SIZE + 8, 8 * TILE_SIZE + 8), block_type, content)
		add_collectible_arc(Vector2((anchor + 2) * TILE_SIZE + 8, 96), 5, 15.0, 12.0)
	add_enemy(Vector2(365, 174), PooledEnemy.Kind.BOUNCECAP, 48.0, false)
	add_enemy(Vector2(gate_x - 520, 174), PooledEnemy.Kind.BOUNCECAP, 52.0, false)
	add_cactus(Vector2(560, 192), false)
	add_cactus(Vector2(gate_x - 430, 192), true, world_number * 0.37)


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
		GameManager.complete_campaign()
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


func _safe_cell_in_band(preferred_x: int, minimum_x: int, maximum_x: int) -> int:
	var band_width := maximum_x - minimum_x + 1
	for search_offset: int in band_width:
		for candidate: int in [preferred_x + search_offset, preferred_x - search_offset]:
			if candidate >= minimum_x and candidate <= maximum_x and _is_safe_ground(candidate):
				return candidate
	return -1


func _nearest_open_coin_cell(requested_x: int, y: int) -> int:
	var start_x := _nearest_safe_cell(requested_x)
	for search_offset: int in 12:
		for candidate: int in [start_x + search_offset, start_x - search_offset]:
			var key := Vector2i(candidate * TILE_SIZE + 8, y)
			if _is_safe_ground(candidate) and not occupied_coin_positions.has(key):
				return candidate
	return -1


func add_block(world_position: Vector2, block_type: int, content: int = 0) -> GearBlock:
	var key := Vector2i(roundi(world_position.x), roundi(world_position.y))
	if occupied_block_positions.has(key):
		return null
	occupied_block_positions[key] = true
	return super.add_block(world_position, block_type, content)


func add_collectible(world_position: Vector2, heals: bool = false) -> GearCoin:
	var key := Vector2i(roundi(world_position.x), roundi(world_position.y))
	if occupied_coin_positions.has(key):
		return null
	occupied_coin_positions[key] = true
	return super.add_collectible(world_position, heals)
