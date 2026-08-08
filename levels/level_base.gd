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
const SPAWNER_SCENE := preload("res://enemies/enemy_spawner.tscn")
const BOSS_SCENE := preload("res://enemies/boss.tscn")

@export_enum("forest", "cave", "snow", "city") var biome: String = "forest"
@export var level_id: String = "forest"
@export var time_limit: float = 180.0
@export var spawn_point: Vector2 = Vector2(64, 150)
@export var level_width_tiles: int = 140

@onready var tile_map: TileMap = $TileMap
@onready var generated_backdrop: Node2D = $GeneratedBackdrop
@onready var entity_root: Node2D = $EntityRoot
@onready var player: ForestMechanic = $Player
@onready var hud: GameHUD = $HUD


func _ready() -> void:
	ObjectPool.reset_all()
	_create_runtime_tileset()
	if biome == "forest":
		_add_generated_forest_background()
	_build_level()
	player.global_position = spawn_point
	_configure_camera()
	GameManager.start_level(level_id, time_limit, spawn_point, level_id == "forest")
	hud.bind_player(player)
	queue_redraw()


func _process(_delta: float) -> void:
	if player.global_position.y > 330.0 and player.state != ForestMechanic.State.DEAD:
		player.take_damage(player.max_health, player.global_position + Vector2(0, -1))


func _build_level() -> void:
	# Implemented by each biome script.
	pass


func _configure_camera() -> void:
	player.camera.limit_left = 0
	player.camera.limit_right = level_width_tiles * TILE_SIZE
	player.camera.limit_top = 0
	player.camera.limit_bottom = 260


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
	# The first four atlas rows contain terrain, stone and crate tiles.
	for tile_y: int in 4:
		for tile_x: int in 16:
			var coords := Vector2i(tile_x, tile_y)
			atlas.create_tile(coords)
			_add_full_tile_collision(atlas, coords)
	tileset.add_source(atlas, 0)
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
	for tile_index: int in 4:
		var coords := Vector2i(tile_index, 0)
		atlas.create_tile(coords)
		_add_full_tile_collision(atlas, coords)
	tileset.add_source(atlas, 0)
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


func add_collectible(world_position: Vector2, heals: bool = false) -> GearSeed:
	return add_entity(COLLECTIBLE_SCENE, world_position, {"heals": heals}) as GearSeed


func add_enemy(world_position: Vector2, kind: int, patrol: float = 80.0, respawns: bool = true) -> EnemySpawner:
	return add_entity(SPAWNER_SCENE, world_position, {
		"enemy_kind": kind, "patrol_distance": patrol, "respawn_enabled": respawns,
	}) as EnemySpawner


func add_entity(scene: PackedScene, world_position: Vector2, properties: Dictionary = {}) -> Node2D:
	var instance := scene.instantiate() as Node2D
	instance.position = world_position
	for property_name: String in properties:
		instance.set(property_name, properties[property_name])
	entity_root.add_child(instance)
	return instance


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
	var width := level_width_tiles * TILE_SIZE
	for x: int in range(0, width + 512, 512):
		var mountains := _make_forest_sprite(Rect2i(0, 12, 16, 2))
		mountains.position = Vector2(x + 256, 118)
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
	var sky: Color
	match biome:
		"cave": sky = Color("101820")
		"snow": sky = Color("86aebb")
		"city": sky = Color("17242c")
		_: sky = Color("79a887")
	draw_rect(Rect2(-400, -300, width + 800, 700), sky, true)
	match biome:
		"forest": pass
		"cave": _draw_cave_backdrop(width)
		"snow": _draw_snow_backdrop(width)
		"city": _draw_city_backdrop(width)


func _draw_forest_backdrop(width: float) -> void:
	for x: int in range(0, int(width), 96):
		PixelArt.rect(self, Vector2(x + 14, 72), Vector2(13, 120), Color("315d4a"))
		draw_circle(Vector2(x + 20, 66), 34, Color("467b55"))
		draw_circle(Vector2(x + 45, 80), 25, Color("568f5c"))


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
