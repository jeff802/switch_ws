class_name ClockworkCactus
extends Area2D
## Original branching clockwork cactus that lives inside the existing green pipe.

const EXPOSED_Y := -48.0
const HIDDEN_Y := -12.0
const VISUAL_HALF_WIDTH := 7.0
const VISUAL_TOP_OFFSET := -30.0
const VISUAL_BOTTOM_OFFSET := 4.0

@export var mobile: bool = false
@export_range(2.4, 8.0, 0.1) var cycle_duration: float = 3.8
@export var phase_offset: float = 0.0

var age: float = 0.0
var plant_y: float = EXPOSED_Y
var defeated: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("cacti")
	body_entered.connect(_on_body_entered)
	_update_plant_pose()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if defeated:
		return
	if mobile:
		age += delta
	_update_plant_pose()
	queue_redraw()


func _update_plant_pose() -> void:
	plant_y = _plant_y_at_time(age)
	# The collision follows only the plant. When retracted it sits completely
	# inside the pipe's StaticBody2D and cannot damage a player above the rim.
	if is_instance_valid(collision_shape):
		collision_shape.position.y = plant_y + (VISUAL_TOP_OFFSET + VISUAL_BOTTOM_OFFSET) * 0.5
		var shape := collision_shape.shape as RectangleShape2D
		if shape != null:
			shape.size = Vector2(VISUAL_HALF_WIDTH * 2.0, VISUAL_BOTTOM_OFFSET - VISUAL_TOP_OFFSET)


func _plant_y_at_time(time_value: float) -> float:
	if not mobile:
		return EXPOSED_Y
	var normalized := fposmod(time_value + phase_offset, cycle_duration) / cycle_duration
	return _plant_y_at_phase(normalized)


func _plant_y_at_phase(normalized: float) -> float:
	# Fixed cycle: exposed 32%, retract 14%, hidden 28%, rise 26%.
	if normalized < 0.32:
		return EXPOSED_Y
	if normalized < 0.46:
		var retract_t := _smooth_unit((normalized - 0.32) / 0.14)
		return lerpf(EXPOSED_Y, HIDDEN_Y, retract_t)
	if normalized < 0.74:
		return HIDDEN_Y
	var rise_t := _smooth_unit((normalized - 0.74) / 0.26)
	return lerpf(HIDDEN_Y, EXPOSED_Y, rise_t)


func _smooth_unit(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _on_body_entered(body: Node2D) -> void:
	if defeated:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position + collision_shape.position)
	elif body.is_in_group("player_projectiles") and body.has_method("hit_damageable"):
		body.hit_damageable(self)


func take_damage(_amount: int, _stomped: bool = false) -> void:
	if defeated:
		return
	defeated = true
	collision_shape.set_deferred("disabled", true)
	AudioManager.play("brick")
	GameManager.add_score(200)
	_spawn_defeat_fragments()
	queue_redraw()


func _spawn_defeat_fragments() -> void:
	var colors: Array[Color] = [Color("35c2a1"), Color("78e0aa"), Color("e6ad55"), Color("176453")]
	for index: int in 4:
		var fragment := Sprite2D.new()
		fragment.texture = PixelArt.circle_texture(colors[index], 5)
		fragment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fragment.global_position = global_position + Vector2(-6 + index * 4, plant_y - 18)
		fragment.z_index = 8
		get_tree().current_scene.add_child(fragment)
		var direction := -1.0 if index % 2 == 0 else 1.0
		var tween := fragment.create_tween()
		tween.tween_property(fragment, "global_position", fragment.global_position + Vector2(direction * 18, 24), 0.38)
		tween.parallel().tween_property(fragment, "rotation", direction * 2.5, 0.38)
		tween.parallel().tween_property(fragment, "modulate:a", 0.0, 0.36)
		tween.tween_callback(fragment.queue_free)


func _draw() -> void:
	if defeated:
		return
	var outline := Color("101820")
	var dark_green := Color("176453") if not mobile else Color("236f70")
	var green := Color("28a476") if not mobile else Color("35c2a1")
	var highlight := Color("78e0aa") if not mobile else Color("8ef3da")
	# The plant is drawn by the parent before the instanced pipe child. The pipe
	# therefore masks the lower stalk naturally while the cactus retracts.
	# 全部可见尖刺都收在 ±7px 的伤害框中，视觉轮廓与实际受伤区域一致。
	PixelArt.rect(self, Vector2(-4, -30 + plant_y), Vector2(8, 34), outline)
	PixelArt.rect(self, Vector2(-2, -28 + plant_y), Vector2(4, 30), dark_green)
	PixelArt.rect(self, Vector2(-1, -26 + plant_y), Vector2(2, 25), green)
	PixelArt.rect(self, Vector2(-7, -22 + plant_y), Vector2(5, 6), outline)
	PixelArt.rect(self, Vector2(-6, -21 + plant_y), Vector2(4, 3), green)
	PixelArt.rect(self, Vector2(-7, -28 + plant_y), Vector2(4, 11), outline)
	PixelArt.rect(self, Vector2(-6, -26 + plant_y), Vector2(2, 8), dark_green)
	PixelArt.rect(self, Vector2(2, -16 + plant_y), Vector2(5, 6), outline)
	PixelArt.rect(self, Vector2(2, -15 + plant_y), Vector2(4, 3), green)
	PixelArt.rect(self, Vector2(4, -23 + plant_y), Vector2(3, 12), outline)
	PixelArt.rect(self, Vector2(5, -21 + plant_y), Vector2(1, 9), dark_green)
	PixelArt.rect(self, Vector2(-1, -23 + plant_y), Vector2(2, 12), highlight)
	PixelArt.rect(self, Vector2(-6, -19 + plant_y), Vector2(2, 2), Color("e6ad55"))
	PixelArt.rect(self, Vector2(5, -13 + plant_y), Vector2(2, 2), Color("e6ad55"))
