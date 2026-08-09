extends SceneTree

const CAMPAIGN_SCENE_PATH := "res://levels/campaign_level.tscn"
const BLOCK_SCRIPT := "res://world/block.gd"
const COIN_SCRIPT := "res://world/collectible.gd"
const SPAWNER_SCRIPT := "res://enemies/enemy_spawner.gd"
const CACTUS_SCRIPT := "res://world/clockwork_cactus.gd"
const PIPE_SCRIPT := "res://world/pipe.gd"

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	manager.persistence_enabled = false
	var campaign_scene := load(CAMPAIGN_SCENE_PATH) as PackedScene
	var standard_signatures: Dictionary = {}

	for stage_index: int in 32:
		manager.set_campaign_stage(stage_index)
		manager.set_carried_power_level(0)
		var level = campaign_scene.instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame

		var world_number: int = stage_index / 4 + 1
		var stage_number: int = stage_index % 4 + 1
		var label := "%d-%d" % [world_number, stage_number]
		var blocks := _children_with_script(level.entity_root, BLOCK_SCRIPT)
		var coins := _children_with_script(level.entity_root, COIN_SCRIPT)
		var spawners := _children_with_script(level.entity_root, SPAWNER_SCRIPT)
		var cacti := _children_with_script(level.entity_root, CACTUS_SCRIPT)
		var pipes := _children_with_script(level.entity_root, PIPE_SCRIPT)
		var fixtures: Array[Node] = cacti.duplicate()
		fixtures.append_array(pipes)
		var coppercaps: Array[Node] = []
		for spawner: Node in spawners:
			if int(spawner.enemy_kind) == 1:
				coppercaps.append(spawner)

		var duplicate_blocks := _duplicate_positions(blocks)
		var duplicate_coins := _duplicate_positions(coins)
		_check(duplicate_blocks.is_empty(), label + " block positions are unique" + duplicate_blocks)
		_check(duplicate_coins.is_empty(), label + " coin positions are unique" + duplicate_coins)
		_check(cacti.size() >= 2, label + " has two or more cacti")
		_check(_count_mobile(cacti, false) >= 1, label + " has a static cactus")
		_check(_count_mobile(cacti, true) >= 1, label + " has a retracting cactus")
		_check(_all_on_safe_ground(level, cacti), label + " cacti stay off pits")
		_check(_all_cacti_use_pipes(cacti), label + " cacti grow from existing pipes")
		_check(_all_cactus_modes_valid(cacti), label + " static/retracting cactus poses are valid")
		_check(_all_cactus_rims_are_safe(cacti), label + " cactus pipes keep safe standing rims")
		_check(_fixtures_clear_of_blocks(fixtures, blocks), label + " pipes do not intersect block groups")
		_check(_fixtures_are_separated(fixtures), label + " pipe fixtures have readable spacing")
		_check(_all_on_safe_ground(level, coppercaps), label + " Coppercaps stay off pits")
		_check(_all_inside_route(level, blocks), label + " blocks stay inside route")
		_check(_all_inside_route(level, coins), label + " coins stay inside route")

		if stage_number == 4:
			_check(blocks.size() >= 15, label + " boss approach has block clusters")
			_check(coins.size() >= 15, label + " boss approach has coin arcs")
			_check(coppercaps.size() >= 2, label + " boss approach has Coppercaps")
		else:
			_check(blocks.size() >= 25, label + " has a full block route")
			_check(coins.size() >= 35, label + " has a full coin route")
			_check(coppercaps.size() >= 4, label + " has repeated Coppercap encounters")
			var signature := _layout_signature(level, blocks, coins, cacti)
			_check(not standard_signatures.has(signature), label + " layout is distinct")
			standard_signatures[signature] = label

		level.queue_free()
		await process_frame
		current_scene = null

	manager.set_campaign_stage(0)
	manager.set_carried_power_level(0)
	manager.run_active = false
	manager.persistence_enabled = true
	if failures.is_empty():
		print("LAYOUT PROBE: %d checks passed across 32 stages" % checks)
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


func _count_mobile(nodes: Array[Node], expected: bool) -> int:
	var count := 0
	for node: Node in nodes:
		if bool(node.mobile) == expected:
			count += 1
	return count


func _all_on_safe_ground(level: Node, nodes: Array[Node]) -> bool:
	for node: Node2D in nodes:
		var cell_x := roundi((node.position.x - 8.0) / float(level.TILE_SIZE))
		if not level._is_safe_ground(cell_x):
			return false
	return true


func _all_cacti_use_pipes(nodes: Array[Node]) -> bool:
	for node: Node in nodes:
		var pipe := node.get_node_or_null("Pipe")
		if pipe == null or not is_equal_approx(float(pipe.pipe_height), 48.0):
			return false
	return true


func _all_cactus_modes_valid(nodes: Array[Node]) -> bool:
	for node: Node in nodes:
		var exposed := float(node._plant_y_at_phase(0.0))
		if bool(node.mobile):
			var hidden := float(node._plant_y_at_phase(0.60))
			if not hidden > exposed or float(node.cycle_duration) <= 0.0:
				return false
		elif not is_equal_approx(float(node.plant_y), exposed):
			return false
	return true


func _all_cactus_rims_are_safe(nodes: Array[Node]) -> bool:
	for node: Node in nodes:
		var plant_collision := node.get_node("CollisionShape2D") as CollisionShape2D
		var pipe_collision := node.get_node("Pipe/CollisionShape2D") as CollisionShape2D
		var plant_shape := plant_collision.shape as RectangleShape2D
		var pipe_shape := pipe_collision.shape as RectangleShape2D
		if plant_shape == null or pipe_shape == null:
			return false
		var safe_rim_each_side := (pipe_shape.size.x - plant_shape.size.x) * 0.5
		if safe_rim_each_side < 12.0:
			return false
	return true


func _fixtures_clear_of_blocks(fixtures: Array[Node], blocks: Array[Node]) -> bool:
	for fixture: Node2D in fixtures:
		for block: Node2D in blocks:
			if absf(fixture.position.x - block.position.x) < 30.0:
				return false
	return true


func _fixtures_are_separated(fixtures: Array[Node]) -> bool:
	for first_index: int in fixtures.size():
		var first := fixtures[first_index] as Node2D
		for second_index: int in range(first_index + 1, fixtures.size()):
			var second := fixtures[second_index] as Node2D
			if absf(first.position.x - second.position.x) < 48.0:
				return false
	return true


func _all_inside_route(level: Node, nodes: Array[Node]) -> bool:
	var route_width: float = level.level_width_tiles * level.TILE_SIZE
	for node: Node2D in nodes:
		if node.position.x < 32.0 or node.position.x > route_width - 32.0:
			return false
	return true


func _layout_signature(level: Node, blocks: Array[Node], coins: Array[Node], cacti: Array[Node]) -> String:
	var parts: Array[String] = []
	for pit: Vector2i in level.pit_ranges:
		parts.append("p%d:%d" % [pit.x, pit.y])
	for block: Node2D in blocks:
		parts.append("b%d:%d" % [roundi(block.position.x), roundi(block.position.y)])
	for coin: Node2D in coins:
		parts.append("c%d:%d" % [roundi(coin.position.x), roundi(coin.position.y)])
	for cactus: Node2D in cacti:
		parts.append("x%d:%d:%d" % [roundi(cactus.position.x), roundi(cactus.position.y), int(cactus.mobile)])
	parts.sort()
	return "|".join(parts)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
