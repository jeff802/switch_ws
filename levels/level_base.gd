class_name ForestGearLevel
extends Node2D

const TILE_SIZE := 16
const FOREST_TILESET_TEXTURE := preload("res://assets/generated/forest_tileset_16px.png")
const FOREST_TOP_VARIANTS := [0, 1, 5, 11]
const FOREST_SOIL_VARIANTS := [0, 1, 2, 3, 4, 5, 6]
const CHECKPOINT_SCENE := preload("res://world/checkpoint.tscn")
const COLLECTIBLE_SCENE := preload("res://world/collectible.tscn")
const MOVING_PLATFORM_SCENE := preload("res://world/moving_platform.tscn")
const SPRING_SCENE := preload("res://world/spring.tscn")
const SPIKE_SCENE := preload("res://world/spike.tscn")
const FALLING_ROCK_SCENE := preload("res://world/falling_rock.tscn")
const HIDDEN_AREA_SCENE := preload("res://world/hidden_area.tscn")
const EXIT_SCENE := preload("res://world/level_exit.tscn")
const BLOCK_SCENE := preload("res://world/block.tscn")
const PIPE_SCENE := preload("res://world/pipe.tscn")
const FLAGPOLE_SCENE := preload("res://world/flagpole.tscn")
const CACTUS_SCENE := preload("res://world/clockwork_cactus.tscn")
const BONUS_DECOR_SCRIPT := preload("res://world/bonus_dungeon_decor.gd")
const BREAKABLE_STONE_MARKER_SCRIPT := preload("res://world/breakable_stone_marker.gd")
const SPAWNER_SCENE := preload("res://enemies/enemy_spawner.tscn")
const BOSS_SCENE := preload("res://enemies/boss.tscn")

@export_enum("forest", "cave", "snow", "city", "ruins", "volcano", "night") var biome: String = "forest"
@export var level_id: String = "forest"
@export var time_limit: float = 180.0
@export var spawn_point: Vector2 = Vector2(64, 150)
@export var level_width_tiles: int = 140
@export var camera_look_ahead: float = 128.0

@onready var tile_map: TileMap = $TileMap
@onready var generated_backdrop: Node2D = $GeneratedBackdrop
@onready var entity_root: Node2D = $EntityRoot
@onready var player: ForestMechanic = $Player
@onready var hud: GameHUD = $HUD

var breakable_stone_cells: Dictionary = {}
var bonus_dungeon_built: bool = false
var bonus_variant: int = 0
var bonus_entry_pipe: GearPipe
var bonus_exit_pipe: GearPipe
var bonus_return_position: Vector2 = Vector2.ZERO
var bonus_spawn_position := Vector2(56, 590)
var inside_bonus_dungeon: bool = false
var pipe_travel_busy: bool = false


func _ready() -> void:
	ObjectPool.reset_all()
	_create_runtime_tileset()
	if biome == "forest":
		_add_generated_forest_background()
	_build_level()
	_configure_camera()
	GameManager.start_level(
		level_id,
		time_limit,
		spawn_point,
		level_id == "forest" or level_id == "world_1_1" or level_id == "stage_01"
	)
	player.global_position = GameManager.checkpoint_position
	player.restore_power_level(GameManager.carried_power_level)
	player.restore_reserve_bloom(GameManager.carried_reserve_bloom_count)
	hud.bind_player(player)
	queue_redraw()


func _process(_delta: float) -> void:
	var fall_limit := 700.0 if inside_bonus_dungeon else 330.0
	if player.global_position.y > fall_limit and player.state != ForestMechanic.State.DEAD:
		player.take_damage(player.max_health, player.global_position + Vector2(0, -1))


func _build_level() -> void:
	# Implemented by each biome script.
	pass


func _configure_camera() -> void:
	# 固定前瞻保持原先的镜头手感，不随朝向、速度或动作来回移动。
	player.camera.position = Vector2(camera_look_ahead, -28.0)
	player.camera.offset = Vector2.ZERO
	player.camera.limit_left = 0
	player.camera.limit_right = level_width_tiles * TILE_SIZE
	player.camera.limit_top = 0
	player.camera.limit_bottom = 300
	player.camera.make_current()
	player.camera.reset_smoothing()


func _create_runtime_tileset() -> void:
	if biome == "forest":
		_create_generated_forest_tileset()
		return
	_create_procedural_tileset()


func _create_generated_forest_tileset() -> void:
	var tileset := _new_tileset()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = FOREST_TILESET_TEXTURE
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_source(atlas, 0)
	# The first four atlas rows contain terrain, stone and crate tiles.
	for tile_y: int in 4:
		for tile_x: int in 16:
			var coords := Vector2i(tile_x, tile_y)
			atlas.create_tile(coords)
			_add_full_tile_collision(atlas, coords)
	tile_map.tile_set = tileset


func _create_procedural_tileset() -> void:
	var palette := _biome_palette()
	var image := Image.create(TILE_SIZE * 4, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for tile_index: int in 4:
		var base: Color = palette[tile_index]
		for y: int in TILE_SIZE:
			for x: int in TILE_SIZE:
				var color := base
				if y < 3:
					color = base.lightened(0.22)
				elif (x + y + tile_index * 3) % 11 == 0:
					color = base.darkened(0.16)
				image.set_pixel(tile_index * TILE_SIZE + x, y, color)
	var texture := ImageTexture.create_from_image(image)
	var tileset := _new_tileset()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_source(atlas, 0)
	for tile_index: int in 4:
		var coords := Vector2i(tile_index, 0)
		atlas.create_tile(coords)
		_add_full_tile_collision(atlas, coords)
	tile_map.tile_set = tileset


func _new_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 31)
	return tileset


func _add_full_tile_collision(atlas: TileSetAtlasSource, coords: Vector2i) -> void:
	var data := atlas.get_tile_data(coords, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	]))


func _biome_palette() -> Array[Color]:
	match biome:
		"cave":
			return [Color("3e4750"), Color("59646b"), Color("705a4c"), Color("34424a")]
		"snow":
			return [Color("6b8795"), Color("d7edf0"), Color("8cb8c4"), Color("506e7d")]
		"city":
			return [Color("35464d"), Color("65767a"), Color("a36a49"), Color("29383f")]
		"ruins":
			return [Color("4e6049"), Color("7d8d68"), Color("8b6544"), Color("36443a")]
		"volcano":
			return [Color("493035"), Color("77423a"), Color("a95332"), Color("30252b")]
		"night":
			return [Color("35364f"), Color("545572"), Color("744e68"), Color("26273b")]
		_:
			return [Color("3c6548"), Color("6fa657"), Color("7b5b3d"), Color("31513b")]


func solid_rect(x: int, y: int, width: int, height: int, tile: int = 0) -> void:
	for cell_y: int in range(y, y + height):
		for cell_x: int in range(x, x + width):
			var atlas_coords := Vector2i(tile, 0)
			if biome == "forest":
				atlas_coords = _forest_tile_coords(tile, cell_x, cell_y == y)
			tile_map.set_cell(0, Vector2i(cell_x, cell_y), 0, atlas_coords, 0)


func _forest_tile_coords(tile: int, cell_x: int, top_row: bool) -> Vector2i:
	match tile:
		0:
			if top_row:
				return Vector2i(FOREST_TOP_VARIANTS[posmod(cell_x, FOREST_TOP_VARIANTS.size())], 0)
			return Vector2i(FOREST_SOIL_VARIANTS[posmod(cell_x, FOREST_SOIL_VARIANTS.size())], 1)
		1:
			return Vector2i(posmod(cell_x, 2), 0)
		2:
			return Vector2i(posmod(cell_x, 9), 2)
		_:
			return Vector2i(9 + posmod(cell_x, 3), 2)


func erase_rect(x: int, y: int, width: int, height: int) -> void:
	for cell_y: int in range(y, y + height):
		for cell_x: int in range(x, x + width):
			tile_map.erase_cell(0, Vector2i(cell_x, cell_y))


func register_breakable_stone_rect(x: int, y: int, width: int, height: int = 1) -> void:
	for cell_y: int in range(y, y + height):
		for cell_x: int in range(x, x + width):
			var cell := Vector2i(cell_x, cell_y)
			if breakable_stone_cells.has(cell):
				continue
			var marker := BREAKABLE_STONE_MARKER_SCRIPT.new() as BreakableStoneMarker
			marker.z_index = -1
			entity_root.add_child(marker)
			marker.global_position = tile_map.to_global(tile_map.map_to_local(cell))
			breakable_stone_cells[cell] = marker


func break_stone_at_world_point(world_point: Vector2, body: Node) -> bool:
	var local_point := tile_map.to_local(world_point)
	return break_stone_cell(tile_map.local_to_map(local_point), body)


func break_stone_cell(cell: Vector2i, body: Node) -> bool:
	if body == null or body.get("has_orb_power") != true:
		return false
	if not breakable_stone_cells.has(cell) or tile_map.get_cell_source_id(0, cell) < 0:
		return false
	var marker := breakable_stone_cells[cell] as Node
	breakable_stone_cells.erase(cell)
	if is_instance_valid(marker):
		marker.queue_free()
	tile_map.erase_cell(0, cell)
	_spawn_stone_fragments(tile_map.to_global(tile_map.map_to_local(cell)))
	AudioManager.play("brick")
	GameManager.add_score(75)
	return true


func _spawn_stone_fragments(origin: Vector2) -> void:
	var colors: Array[Color] = [Color("7f9194"), Color("a8b8b7"), Color("596b70"), Color("d1dcce")]
	for index: int in 4:
		var fragment := Sprite2D.new()
		fragment.texture = PixelArt.circle_texture(colors[index], 5)
		fragment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fragment.global_position = origin + Vector2(-4 + index * 3, -2 + (index % 2) * 3)
		fragment.z_index = 7
		entity_root.add_child(fragment)
		var horizontal := -1.0 if index % 2 == 0 else 1.0
		var destination := origin + Vector2(horizontal * (12.0 + index * 2.0), 25.0)
		var tween := create_tween()
		tween.tween_property(fragment, "global_position", destination, 0.48)
		tween.parallel().tween_property(fragment, "rotation", horizontal * 2.8, 0.48)
		tween.parallel().tween_property(fragment, "modulate:a", 0.0, 0.45)
		tween.tween_callback(fragment.queue_free)


func add_collectible(world_position: Vector2, heals: bool = false) -> GearCoin:
	var collectible_id := "%s:%d:%d:%s" % [
		level_id,
		roundi(world_position.x),
		roundi(world_position.y),
		"heart" if heals else "coin",
	]
	return add_entity(COLLECTIBLE_SCENE, world_position, {
		"heals": heals,
		"collectible_id": collectible_id,
	}) as GearCoin


func add_checkpoint(world_position: Vector2) -> ForestCheckpoint:
	return add_entity(CHECKPOINT_SCENE, world_position, {
		"level_id": level_id,
	}) as ForestCheckpoint


func add_enemy(world_position: Vector2, kind: int, patrol: float = 80.0, respawns: bool = true) -> EnemySpawner:
	return add_entity(SPAWNER_SCENE, world_position, {
		"enemy_kind": kind, "patrol_distance": patrol, "respawn_enabled": respawns,
	}) as EnemySpawner


func add_cactus(world_position: Vector2, mobile: bool = false, phase: float = 0.0) -> ClockworkCactus:
	return add_entity(CACTUS_SCENE, world_position, {
		"mobile": mobile,
		"phase_offset": phase,
		"cycle_duration": 3.8,
	}) as ClockworkCactus


func add_entity(scene: PackedScene, world_position: Vector2, properties: Dictionary = {}) -> Node2D:
	var instance := scene.instantiate() as Node2D
	instance.position = world_position
	for property_name: String in properties:
		instance.set(property_name, properties[property_name])
	entity_root.add_child(instance)
	return instance


func add_block(world_position: Vector2, block_type: int, content: int = 0) -> GearBlock:
	return add_entity(BLOCK_SCENE, world_position, {
		"block_type": block_type, "content": content,
	}) as GearBlock


func add_pipe(
	world_position: Vector2,
	pipe_height: float = 48.0,
	travel_mode: int = GearPipe.TravelMode.NONE,
	dungeon_variant: int = 0
) -> GearPipe:
	var pipe := add_entity(PIPE_SCENE, world_position, {
		"pipe_height": pipe_height,
		"travel_mode": travel_mode,
	}) as GearPipe
	if travel_mode == GearPipe.TravelMode.ENTER_BONUS:
		bonus_entry_pipe = pipe
		if not bonus_dungeon_built:
			_build_bonus_dungeon(dungeon_variant)
	elif travel_mode == GearPipe.TravelMode.EXIT_BONUS:
		bonus_exit_pipe = pipe
	return pipe


func _build_bonus_dungeon(dungeon_variant: int) -> void:
	bonus_dungeon_built = true
	bonus_variant = dungeon_variant
	var decor := BONUS_DECOR_SCRIPT.new() as BonusDungeonDecor
	decor.position = Vector2(0, 320)
	decor.z_index = -1
	generated_backdrop.add_child(decor)
	# 640×360 的完整副本房间，镜头切换后不会露出主关卡或空白区域。
	solid_rect(0, 20, 40, 1, 1)
	solid_rect(0, 39, 40, 3, 1)
	solid_rect(0, 21, 1, 18, 1)
	solid_rect(39, 21, 1, 18, 1)
	solid_rect(10, 35, 7, 1, 2)
	register_breakable_stone_rect(10, 35, 7)
	solid_rect(23, 33, 6, 1, 2)
	# 两个明示强化砖让空手进入副本的玩家依次取得大形态和能量花。
	for offset: int in 5:
		var content := GearBlock.Content.MUSHROOM if offset in [1, 3] else GearBlock.Content.NONE
		var type := GearBlock.Type.QUESTION if offset in [1, 3] else GearBlock.Type.BRICK
		add_block(Vector2((17 + offset) * TILE_SIZE + 8, 35 * TILE_SIZE + 8), type, content)
	add_collectible_arc(Vector2(176, 535), 7, 18.0, 22.0)
	add_collectible_arc(Vector2(424, 500), 7, 18.0, 25.0)
	add_entity(SPRING_SCENE, Vector2(19 * TILE_SIZE + 8, 613), {"launch_strength": 525.0})
	var enemy_kind := PooledEnemy.Kind.BOUNCECAP if dungeon_variant == 0 else PooledEnemy.Kind.SHELLBACK
	add_enemy(Vector2(26 * TILE_SIZE + 8, 606), enemy_kind, 45.0, false)
	add_pipe(Vector2(36 * TILE_SIZE + 8, 624), 40.0, GearPipe.TravelMode.EXIT_BONUS)


func show_pipe_prompt(travel_mode: int) -> void:
	if travel_mode == GearPipe.TravelMode.ENTER_BONUS:
		hud.show_context_hint("↓ / S / 手柄下方向：进入奖励地窖")
	else:
		hud.show_context_hint("↓ / S / 手柄下方向：返回主关卡")


func hide_pipe_prompt() -> void:
	hud.hide_context_hint()


func travel_through_pipe(pipe: GearPipe, body: Node2D, travel_mode: int) -> void:
	if pipe_travel_busy or body != player:
		pipe.unlock_travel()
		return
	pipe_travel_busy = true
	hide_pipe_prompt()
	GameManager.run_active = false
	player.controls_locked = true
	player.velocity = Vector2.ZERO
	player.invulnerability_timer = maxf(player.invulnerability_timer, 0.8)
	player.set_physics_process(false)
	player.sprite.play(&"idle")
	var previous_z := player.z_index
	var previous_scale := player.sprite.scale
	player.z_index = 2
	AudioManager.play("pipe")
	var pipe_top := pipe.global_position.y - pipe.pipe_height
	var enter_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	enter_tween.tween_property(player, "global_position:y", pipe_top + 13.0, 0.3)
	enter_tween.parallel().tween_property(player.sprite, "scale:x", previous_scale.x * 0.82, 0.3)
	await enter_tween.finished
	if travel_mode == GearPipe.TravelMode.ENTER_BONUS:
		bonus_return_position = pipe.global_position + Vector2(0, -pipe.pipe_height - 18.0)
		inside_bonus_dungeon = true
		player.global_position = bonus_spawn_position
		_configure_bonus_camera()
		hud.show_area_banner("奖励副本 · 两次强化后可发射能量弹")
		AudioManager.play("secret")
	else:
		inside_bonus_dungeon = false
		player.global_position = bonus_return_position
		_configure_camera()
		hud.show_area_banner("返回第 %02d 关" % int(GameManager.campaign_stage + 1))
	player.z_index = previous_z
	player.sprite.scale = previous_scale
	player.camera.reset_smoothing()
	await get_tree().process_frame
	player.set_physics_process(true)
	player.controls_locked = false
	player.velocity = Vector2.ZERO
	GameManager.run_active = true
	pipe_travel_busy = false
	pipe.unlock_travel()


func _configure_bonus_camera() -> void:
	player.camera.position = Vector2(0.0, -28.0)
	player.camera.offset = Vector2.ZERO
	player.camera.limit_left = 0
	player.camera.limit_right = 640
	player.camera.limit_top = 320
	player.camera.limit_bottom = 680
	player.camera.make_current()
	player.camera.reset_smoothing()


func add_flag(world_position: Vector2, unlock_id: String = "", next_scene: String = "") -> GearFlagpole:
	return add_entity(FLAGPOLE_SCENE, world_position, {
		"unlock_level_id": unlock_id, "next_scene": next_scene,
	}) as GearFlagpole


func add_collectible_arc(center: Vector2, count: int, spacing: float = 22.0, height: float = 22.0) -> void:
	for index: int in count:
		var normalized := 0.0 if count <= 1 else float(index) / float(count - 1)
		var x := (float(index) - float(count - 1) * 0.5) * spacing
		var y := -sin(normalized * PI) * height
		add_collectible(center + Vector2(x, y))


func add_forest_crate(world_position: Vector2, variant: int = 0) -> StaticBody2D:
	var crate := StaticBody2D.new()
	crate.name = "ForestCrate"
	crate.position = world_position
	crate.collision_layer = 1
	crate.collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(15, 15)
	collision.shape = shape
	crate.add_child(collision)
	var sprite := _make_forest_sprite(Rect2i(9 + posmod(variant, 3), 2, 1, 1))
	crate.add_child(sprite)
	entity_root.add_child(crate)
	return crate


func add_forest_decoration(cells: Rect2i, world_position: Vector2, z: int = 2) -> Sprite2D:
	var sprite := _make_forest_sprite(cells)
	sprite.position = world_position
	sprite.z_index = z
	entity_root.add_child(sprite)
	return sprite


func _make_forest_sprite(cells: Rect2i) -> Sprite2D:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = FOREST_TILESET_TEXTURE
	atlas_texture.region = Rect2(
		Vector2(cells.position * TILE_SIZE),
		Vector2(cells.size * TILE_SIZE)
	)
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = atlas_texture
	return sprite


func _add_generated_forest_background() -> void:
	# The classic overworld backdrop is drawn procedurally in _draw().
	return
	var width := level_width_tiles * TILE_SIZE
	for x: int in range(0, width + 512, 512):
		# Distant ridge: same silhouette, pushed back with atmospheric tint.
		var far_ridge := _make_forest_sprite(Rect2i(0, 12, 16, 2))
		far_ridge.position = Vector2(x + 256, 96)
		far_ridge.scale = Vector2(2, 2)
		far_ridge.modulate = Color(0.5, 0.66, 0.58, 1.0)
		generated_backdrop.add_child(far_ridge)
		var mountains := _make_forest_sprite(Rect2i(0, 12, 16, 2))
		mountains.position = Vector2(x + 256, 122)
		mountains.scale = Vector2(2, 2)
		generated_backdrop.add_child(mountains)
		var forest_line := _make_forest_sprite(Rect2i(0, 14, 16, 2))
		forest_line.position = Vector2(x + 256, 158)
		forest_line.scale = Vector2(2, 2)
		generated_backdrop.add_child(forest_line)
	for x: int in range(0, width + 192, 192):
		var bushes := _make_forest_sprite(Rect2i(0, 16, 12, 2))
		bushes.position = Vector2(x + 96, 176)
		generated_backdrop.add_child(bushes)
	var tree_regions: Array[Rect2i] = [
		Rect2i(0, 4, 3, 6), Rect2i(3, 4, 4, 6), Rect2i(7, 4, 6, 6),
		Rect2i(0, 4, 3, 6), Rect2i(3, 4, 4, 6), Rect2i(7, 4, 6, 6),
	]
	var tree_positions: Array[Vector2] = [
		Vector2(270, 144), Vector2(575, 144), Vector2(990, 144),
		Vector2(1390, 144), Vector2(1775, 144), Vector2(2100, 144),
	]
	for index: int in tree_regions.size():
		var tree := _make_forest_sprite(tree_regions[index])
		tree.position = tree_positions[index]
		generated_backdrop.add_child(tree)
	for x: int in [780, 1540, 1980]:
		var vines := _make_forest_sprite(Rect2i(13, 4, 3, 6))
		vines.position = Vector2(x, 75)
		generated_backdrop.add_child(vines)


func _draw() -> void:
	var width := float(level_width_tiles * TILE_SIZE)
	var sky_top: Color
	var sky_mid: Color
	var sky_horizon: Color
	var sun_color := Color(1.0, 0.94, 0.72, 1.0)
	var cloud_color := Color(1.0, 1.0, 1.0, 0.1)
	var cloud_count := 4
	match biome:
		"cave":
			sky_top = Color("0c141b")
			sky_mid = Color("14212b")
			sky_horizon = Color("24343e")
			sun_color = Color(0.6, 0.95, 0.9, 1.0)
			cloud_color = Color(0.5, 0.8, 0.8, 0.06)
			cloud_count = 2
		"snow":
			sky_top = Color("5b8298")
			sky_mid = Color("86aebb")
			sky_horizon = Color("bcd9de")
			sun_color = Color(1.0, 0.98, 0.92, 1.0)
			cloud_color = Color(1.0, 1.0, 1.0, 0.16)
			cloud_count = 5
		"city":
			sky_top = Color("0d1921")
			sky_mid = Color("1a2a34")
			sky_horizon = Color("2e424c")
			sun_color = Color(1.0, 0.72, 0.42, 1.0)
			cloud_color = Color(0.7, 0.8, 0.85, 0.07)
			cloud_count = 2
		"ruins":
			sky_top = Color("243b45")
			sky_mid = Color("456a68")
			sky_horizon = Color("7e9b79")
			sun_color = Color("e9e2a5")
			cloud_color = Color(0.86, 0.95, 0.85, 0.16)
			cloud_count = 3
		"volcano":
			sky_top = Color("210f1d")
			sky_mid = Color("55222a")
			sky_horizon = Color("a84b32")
			sun_color = Color("ff8f42")
			cloud_color = Color(0.28, 0.18, 0.2, 0.42)
			cloud_count = 3
		"night":
			sky_top = Color("0b1028")
			sky_mid = Color("1d2850")
			sky_horizon = Color("4b5078")
			sun_color = Color("bde8ff")
			cloud_color = Color(0.7, 0.76, 0.95, 0.1)
			cloud_count = 2
		_:
			sky_top = Color("3f6fc4")
			sky_mid = Color("5a8fe8")
			sky_horizon = Color("8db9f2")
			sun_color = Color(1.0, 0.96, 0.8, 1.0)
			cloud_color = Color(1.0, 1.0, 1.0, 0.85)
			cloud_count = 5
	# Sky gradient bands across the full level width (crisp, integer-aligned).
	# Bands cover the whole camera range (world y 0..260) so no clear color shows.
	draw_rect(Rect2(-400, -300, width + 800, 370), sky_top, true)
	draw_rect(Rect2(-400, 70, width + 800, 90), sky_mid, true)
	draw_rect(Rect2(-400, 160, width + 800, 140), sky_horizon, true)
	# Dark band below the ground line so pits read as solid depth.
	var below_ground := Color("2c2020")
	match biome:
		"cave": below_ground = Color("0b1116")
		"snow": below_ground = Color("273d47")
		"city": below_ground = Color("131d24")
		"ruins": below_ground = Color("27352d")
		"volcano": below_ground = Color("210f14")
		"night": below_ground = Color("121326")
		_: below_ground = Color("4a3527")
	draw_rect(Rect2(-400, 256, width + 800, 44), below_ground, true)
	# Sun with a soft glow.
	draw_circle(Vector2(620, 58), 30, Color(sun_color.r, sun_color.g, sun_color.b, 0.16))
	draw_circle(Vector2(620, 58), 16, Color(sun_color.r, sun_color.g, sun_color.b, 0.9))
	# Soft pixel clouds for depth.
	if cloud_count > 0:
		var step := maxf(1.0, width / float(cloud_count))
		for index: int in cloud_count:
			var cloud_x := 60.0 + float(index) * step + float(posmod(index * 137, int(step) * 2))
			var cloud_y := 42.0 + float(posmod(index * 53, 34))
			_draw_cloud(Vector2(cloud_x, cloud_y), cloud_color, 1.0 + float(posmod(index, 2)) * 0.35)
	match biome:
		"forest": _draw_forest_backdrop(width)
		"cave": _draw_cave_backdrop(width)
		"snow": _draw_snow_backdrop(width)
		"city": _draw_city_backdrop(width)
		"ruins": _draw_ruins_backdrop(width)
		"volcano": _draw_volcano_backdrop(width)
		"night": _draw_night_backdrop(width)


func _draw_cloud(center: Vector2, color: Color, scale: float) -> void:
	draw_circle(center, 9.0 * scale, color)
	draw_circle(center + Vector2(9, 3) * scale, 7.0 * scale, color)
	draw_circle(center + Vector2(-9, 3) * scale, 7.0 * scale, color)
	draw_rect(Rect2(center + Vector2(-8, 1) * scale, Vector2(16, 5) * scale), color, true)


func _draw_forest_backdrop(width: float) -> void:
	# Classic overworld backdrop: rolling hills, bushes and a distant castle.
	var hill_green := Color("3fa44f")
	var hill_dark := Color("2e7f3d")
	var bush_green := Color("57c05f")
	for x: int in range(0, int(width) + 512, 512):
		draw_circle(Vector2(x + 256, 165), 118, hill_green)
		draw_circle(Vector2(x + 128, 180), 88, hill_dark)
	for x: int in range(0, int(width), 96):
		var bx := x + 48
		draw_circle(Vector2(bx, 178), 12, bush_green)
		draw_circle(Vector2(bx - 10, 183), 9, bush_green)
		draw_circle(Vector2(bx + 10, 183), 9, bush_green)
	_draw_castle(Vector2(1920, 158))


func _draw_castle(base: Vector2) -> void:
	var wall := Color("a9afb4")
	var dark := Color("6e757b")
	var roof := Color("c2503f")
	PixelArt.rect(self, base + Vector2(-34, -34), Vector2(68, 34), wall)
	PixelArt.rect(self, base + Vector2(-34, -34), Vector2(68, 6), dark)
	PixelArt.rect(self, base + Vector2(-30, -30), Vector2(8, 30), dark)
	PixelArt.rect(self, base + Vector2(22, -30), Vector2(8, 30), dark)
	PixelArt.rect(self, base + Vector2(-42, -50), Vector2(16, 16), wall)
	PixelArt.rect(self, base + Vector2(26, -50), Vector2(16, 16), wall)
	PixelArt.rect(self, base + Vector2(-46, -56), Vector2(24, 8), roof)
	PixelArt.rect(self, base + Vector2(22, -56), Vector2(24, 8), roof)
	PixelArt.rect(self, base + Vector2(-6, -58), Vector2(12, 26), wall)
	PixelArt.rect(self, base + Vector2(-8, -64), Vector2(16, 8), roof)
	PixelArt.rect(self, base + Vector2(-3, -70), Vector2(6, 6), roof)


func _draw_cave_backdrop(width: float) -> void:
	for x: int in range(0, int(width), 80):
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 18, 55), Vector2(x + 36, 0)]), Color("25333c"))
		draw_circle(Vector2(x + 52, 120 + sin(x) * 12), 3, Color("61c5bd"))


func _draw_snow_backdrop(width: float) -> void:
	for x: int in range(-100, int(width), 180):
		draw_colored_polygon(PackedVector2Array([Vector2(x, 190), Vector2(x + 90, 35), Vector2(x + 180, 190)]), Color("648995"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 55, 95), Vector2(x + 90, 35), Vector2(x + 125, 95)]), Color("d8ecee"))


func _draw_city_backdrop(width: float) -> void:
	for x: int in range(0, int(width), 72):
		PixelArt.rect(self, Vector2(x, 65 + (x % 3) * 14), Vector2(55, 140), Color("24363e"))
		for y: int in range(82, 170, 20):
			PixelArt.rect(self, Vector2(x + 9, y), Vector2(5, 7), Color("c78945"))


func _draw_ruins_backdrop(width: float) -> void:
	for x: int in range(-40, int(width), 150):
		PixelArt.rect(self, Vector2(x, 112), Vector2(18, 82), Color("354a42"))
		PixelArt.rect(self, Vector2(x - 7, 106), Vector2(32, 8), Color("526b57"))
		PixelArt.rect(self, Vector2(x + 55, 146), Vector2(74, 48), Color("3d5145"))
		PixelArt.rect(self, Vector2(x + 62, 134), Vector2(13, 12), Color("6c7f60"))
	for x: int in range(35, int(width), 230):
		draw_circle(Vector2(x, 174), 20.0, Color("426c4a"))
		draw_circle(Vector2(x + 21, 181), 13.0, Color("5b8052"))


func _draw_volcano_backdrop(width: float) -> void:
	for x: int in range(-100, int(width), 260):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 194), Vector2(x + 98, 70), Vector2(x + 150, 194),
		]), Color("3b2026"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + 77, 96), Vector2(x + 98, 70), Vector2(x + 118, 97),
		]), Color("c54b32"))
	for x: int in range(0, int(width), 96):
		PixelArt.rect(self, Vector2(x, 185), Vector2(54, 9), Color("702b2a"))
		PixelArt.rect(self, Vector2(x + 12, 187), Vector2(23, 3), Color("ff713c"))


func _draw_night_backdrop(width: float) -> void:
	for x: int in range(22, int(width), 71):
		var y := 26 + posmod(x * 17, 104)
		PixelArt.rect(self, Vector2(x, y), Vector2(2, 2), Color(0.8, 0.93, 1.0, 0.8))
	for x: int in range(-80, int(width), 190):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 194), Vector2(x + 88, 74), Vector2(x + 190, 194),
		]), Color("293151"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + 60, 113), Vector2(x + 88, 74), Vector2(x + 118, 114),
		]), Color("67739b"))
