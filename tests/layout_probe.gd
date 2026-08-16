extends SceneTree

const CAMPAIGN_SCENE_PATH := "res://levels/campaign_level.tscn"
const BLOCK_SCRIPT := "res://world/block.gd"
const COIN_SCRIPT := "res://world/collectible.gd"
const SPAWNER_SCRIPT := "res://enemies/enemy_spawner.gd"
const SPRING_SCRIPT := "res://world/spring.gd"
const CHECKPOINT_SCRIPT := "res://world/checkpoint.gd"
const CACTUS_SCRIPT := "res://world/clockwork_cactus.gd"
const PIPE_SCRIPT := "res://world/pipe.gd"
const STAGE_COUNT := 20
const DUCK_KIND := 3
const TURTLE_KIND := 4
const DUCK_STAGES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 16, 17, 18, 19]
const TURTLE_STAGES := [1, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
const HIDDEN_POWER_COUNTS := [0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
const HIDDEN_MULTI_STAGES := [5, 10, 13, 16, 19]
const MULTI_COIN_STAGES := [0, 1, 3, 5, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
const BONUS_PIPE_STAGES := [0, 5, 10, 16]
const STAGE_BLOCK_THEMES := [
	0, 0, 1, 2, 3, 0, 1, 2, 3, 4,
	5, 1, 6, 2, 6, 7, 5, 8, 3, 9,
]
const BRICK_BLOCK := 0
const QUESTION_BLOCK := 1
const MUSHROOM_CONTENT := 2
const MULTI_COIN_CONTENT := 3

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	manager.persistence_enabled = false
	root.get_node("SettingsManager").set_difficulty("normal")
	var campaign_scene := load(CAMPAIGN_SCENE_PATH) as PackedScene
	var signatures: Dictionary = {}
	var total_power_blocks := 0
	var hidden_power_blocks := 0
	var total_multi_coin_blocks := 0
	var hidden_multi_coin_blocks := 0

	for stage_index: int in STAGE_COUNT:
		manager.set_campaign_stage(stage_index)
		manager.set_carried_power_level(0)
		manager.set_carried_reserve_bloom_count(0)
		var level = campaign_scene.instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame

		var label := "第 %02d 关" % (stage_index + 1)
		var blocks := _children_with_script(level.entity_root, BLOCK_SCRIPT)
		var coins := _children_with_script(level.entity_root, COIN_SCRIPT)
		var spawners := _children_with_script(level.entity_root, SPAWNER_SCRIPT)
		var springs := _children_with_script(level.entity_root, SPRING_SCRIPT)
		var checkpoints := _children_with_script(level.entity_root, CHECKPOINT_SCRIPT)
		var cacti := _children_with_script(level.entity_root, CACTUS_SCRIPT)
		var pipes := _children_with_script(level.entity_root, PIPE_SCRIPT)
		var ducks: Array[Node] = []
		var turtles: Array[Node] = []
		for spawner: Node in spawners:
			if int(spawner.enemy_kind) == DUCK_KIND:
				ducks.append(spawner)
			elif int(spawner.enemy_kind) == TURTLE_KIND:
				turtles.append(spawner)

		var duplicate_blocks := _duplicate_positions(blocks)
		var duplicate_coins := _duplicate_positions(coins)
		_check(duplicate_blocks.is_empty(), label + "砖块位置不重复" + duplicate_blocks)
		_check(duplicate_coins.is_empty(), label + "金币位置不重复" + duplicate_coins)
		_check(blocks.size() >= 5, label + "有可互动砖块")
		_check(coins.size() >= 5, label + "有奖励路线")
		_check(_has_power_block(blocks), label + "有合理放置的强化道具")
		_check(_power_block_count(blocks) >= 2, label + "可从小型状态连续取得能量花")
		_check(_visible_power_block_count(blocks) >= 1, label + "至少一个强化砖有明显徽记")
		_check(
			_hidden_power_block_count(blocks) == HIDDEN_POWER_COUNTS[stage_index],
			label + "隐藏强化砖比例按关卡进度递增"
		)
		total_power_blocks += _power_block_count(blocks)
		hidden_power_blocks += _hidden_power_block_count(blocks)
		if stage_index in MULTI_COIN_STAGES:
			_check(_multi_coin_block_count(blocks) >= 1, label + "包含可有限次数连续顶出的金币砖")
		total_multi_coin_blocks += _multi_coin_block_count(blocks)
		hidden_multi_coin_blocks += _hidden_multi_coin_block_count(blocks)
		_check(
			_hidden_multi_coin_block_count(blocks) == (1 if stage_index in HIDDEN_MULTI_STAGES else 0),
			label + "多金币隐藏外观按中段关卡引入"
		)
		_check(_all_blocks_use_theme(blocks, STAGE_BLOCK_THEMES[stage_index]), label + "砖块材质匹配关卡主题")
		_check(level.used_block_patterns.size() >= 2, label + "使用至少两种错层顶砖编排")
		_check(springs.size() >= 1, label + "有弹簧玩法")
		_check(_all_on_safe_ground(level, springs), label + "弹簧不在坑边")
		_check(_all_on_safe_ground(level, spawners), label + "敌人不生成在坑中")
		if DUCK_STAGES.has(stage_index):
			_check(ducks.size() >= 1, label + "包含发条鸭")
		if TURTLE_STAGES.has(stage_index):
			_check(turtles.size() >= 1, label + "包含铜甲龟玩法")
		_check(_all_inside_route(level, blocks), label + "砖块位于关卡范围")
		_check(_all_inside_route(level, coins), label + "金币位于关卡范围")
		_check(_blocks_have_headroom(level, blocks), label + "砖块下方保留可跳跃空间")
		_check(_pits_are_valid(level.pit_ranges), label + "坑洞宽度和间距合理")
		_check(_upper_solid_count(level) >= 3, label + "有独立石砖平台")
		_check(level.breakable_stone_cells.size() >= 3, label + "石砖平台支持碎石能力")
		_check(checkpoints.size() == 1, label + "有一个中段检查点")
		_check(_all_cactus_modes_valid(cacti), label + "仙人掌模式有效")
		var entry_pipe_count := 0
		var exit_pipe_count := 0
		for pipe: Node in pipes:
			if int(pipe.travel_mode) == 1:
				entry_pipe_count += 1
			elif int(pipe.travel_mode) == 2:
				exit_pipe_count += 1
		if stage_index in BONUS_PIPE_STAGES:
			_check(entry_pipe_count == 1 and exit_pipe_count == 1, label + "包含完整奖励管道往返")
			_check(level.bonus_dungeon_built, label + "奖励副本已构建")
		else:
			_check(entry_pipe_count == 0 and exit_pipe_count == 0, label + "普通管道不会误触副本")

		var signature := _layout_signature(level, blocks, coins, springs)
		_check(not signatures.has(signature), label + "编排与其他关不同")
		signatures[signature] = label

		level.queue_free()
		await process_frame
		current_scene = null

	_check(hidden_power_blocks >= 10, "后十关逐步增加普通土砖外观的隐藏强化奖励")
	_check(hidden_power_blocks * 2 < total_power_blocks, "隐藏强化砖始终是少数，明示补给仍占多数")
	_check(hidden_multi_coin_blocks >= 1, "多金币砖保留少量普通土砖伪装")
	_check(hidden_multi_coin_blocks * 2 < total_multi_coin_blocks, "隐藏多金币砖保持为少数探索奖励")
	_check(total_multi_coin_blocks - hidden_multi_coin_blocks > hidden_multi_coin_blocks, "多数多金币砖使用明显徽记外观")
	manager.set_campaign_stage(0)
	manager.set_carried_power_level(0)
	manager.set_carried_reserve_bloom_count(0)
	manager.run_active = false
	manager.persistence_enabled = true
	if failures.is_empty():
		print("LAYOUT PROBE: %d checks passed across 20 curated stages" % checks)
		quit(0)
		return
	for failure: String in failures:
		push_error("LAYOUT PROBE: " + failure)
	quit(1)


func _children_with_script(parent: Node, script_path: String) -> Array[Node]:
	var matches: Array[Node] = []
	for child: Node in parent.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == script_path:
			matches.append(child)
	return matches


func _duplicate_positions(nodes: Array[Node]) -> String:
	var occupied: Dictionary = {}
	var duplicates: Array[String] = []
	for node: Node2D in nodes:
		var key := Vector2i(roundi(node.position.x), roundi(node.position.y))
		if occupied.has(key):
			duplicates.append(str(key))
		occupied[key] = true
	return "" if duplicates.is_empty() else " at " + ", ".join(duplicates)


func _has_power_block(blocks: Array[Node]) -> bool:
	for block: Node in blocks:
		if int(block.content) == MUSHROOM_CONTENT:
			return true
	return false


func _power_block_count(blocks: Array[Node]) -> int:
	var count := 0
	for block: Node in blocks:
		if int(block.content) == MUSHROOM_CONTENT:
			count += 1
	return count


func _visible_power_block_count(blocks: Array[Node]) -> int:
	var count := 0
	for block: Node in blocks:
		if int(block.block_type) == QUESTION_BLOCK and int(block.content) == MUSHROOM_CONTENT:
			count += 1
	return count


func _hidden_power_block_count(blocks: Array[Node]) -> int:
	var count := 0
	for block: Node in blocks:
		if int(block.block_type) == BRICK_BLOCK and int(block.content) == MUSHROOM_CONTENT:
			count += 1
	return count


func _multi_coin_block_count(blocks: Array[Node]) -> int:
	var count := 0
	for block: Node in blocks:
		if int(block.content) == MULTI_COIN_CONTENT:
			count += 1
	return count


func _hidden_multi_coin_block_count(blocks: Array[Node]) -> int:
	var count := 0
	for block: Node in blocks:
		if int(block.block_type) == BRICK_BLOCK and int(block.content) == MULTI_COIN_CONTENT:
			count += 1
	return count


func _all_blocks_use_theme(blocks: Array[Node], expected_theme: int) -> bool:
	for block: Node in blocks:
		if int(block.visual_theme) != expected_theme:
			return false
	return true


func _all_on_safe_ground(level: Node, nodes: Array[Node]) -> bool:
	for node: Node2D in nodes:
		# 飞行敌人只验证横向落点；其 y 位置本来就在空中。
		var cell_x := roundi((node.position.x - 8.0) / float(level.TILE_SIZE))
		if not level._is_safe_ground(cell_x):
			return false
	return true


func _all_inside_route(level: Node, nodes: Array[Node]) -> bool:
	var route_width: float = level.level_width_tiles * level.TILE_SIZE
	for node: Node2D in nodes:
		if node.position.x < 32.0 or node.position.x > route_width - 32.0:
			return false
	return true


func _blocks_have_headroom(level: Node, blocks: Array[Node]) -> bool:
	var used_cells: Array[Vector2i] = level.tile_map.get_used_cells(0)
	for block: Node2D in blocks:
		var block_cell := Vector2i(
			roundi((block.position.x - 8.0) / float(level.TILE_SIZE)),
			roundi((block.position.y - 8.0) / float(level.TILE_SIZE))
		)
		var nearest_below := 99
		for tile_cell: Vector2i in used_cells:
			if tile_cell.x == block_cell.x and tile_cell.y > block_cell.y:
				nearest_below = mini(nearest_below, tile_cell.y)
		# 大号角色高 35px；保留三个完整空格（48px），兼顾跑跳动画的形变余量。
		if nearest_below - block_cell.y < 4:
			return false
	return true


func _pits_are_valid(pits: Array[Vector2i]) -> bool:
	var previous_end := -99
	for pit: Vector2i in pits:
		if pit.y < 2 or pit.y > 6 or pit.x - previous_end < 6:
			return false
		previous_end = pit.x + pit.y
	return true


func _upper_solid_count(level: Node) -> int:
	var count := 0
	for cell: Vector2i in level.tile_map.get_used_cells(0):
		if cell.y < 12:
			count += 1
	return count


func _all_cactus_modes_valid(nodes: Array[Node]) -> bool:
	for node: Node in nodes:
		var shape := node.get_node("CollisionShape2D").shape as RectangleShape2D
		if shape == null or shape.size != Vector2(14, 34):
			return false
		var exposed := float(node._plant_y_at_phase(0.0))
		if bool(node.mobile):
			var hidden := float(node._plant_y_at_phase(0.60))
			if not hidden > exposed or float(node.cycle_duration) <= 0.0:
				return false
		elif not is_equal_approx(float(node.plant_y), exposed):
			return false
	return true


func _layout_signature(level: Node, blocks: Array[Node], coins: Array[Node], springs: Array[Node]) -> String:
	var parts: Array[String] = [level.biome, str(level.level_width_tiles)]
	for pit: Vector2i in level.pit_ranges:
		parts.append("p%d:%d" % [pit.x, pit.y])
	for block: Node2D in blocks:
		parts.append("b%d:%d" % [roundi(block.position.x), roundi(block.position.y)])
	for coin: Node2D in coins:
		parts.append("c%d:%d" % [roundi(coin.position.x), roundi(coin.position.y)])
	for spring: Node2D in springs:
		parts.append("s%d" % roundi(spring.position.x))
	parts.sort()
	return "|".join(parts)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
