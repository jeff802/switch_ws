class_name ClockworkCactus
extends Area2D
## Original branching clockwork cactus that lives inside the existing green pipe.

const EXPOSED_Y := -48.0
const HIDDEN_Y := -12.0

@export var mobile: bool = false
@export_range(2.4, 8.0, 0.1) var cycle_duration: float = 3.8
@export var phase_offset: float = 0.0

var age: float = 0.0
var plant_y: float = EXPOSED_Y

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("cacti")
	body_entered.connect(_on_body_entered)
	_update_plant_pose()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if mobile:
		age += delta
	_update_plant_pose()
	queue_redraw()


func _update_plant_pose() -> void:
	plant_y = _plant_y_at_time(age)
	# The collision follows only the plant. When retracted it sits completely
	# inside the pipe's StaticBody2D and cannot damage a player above the rim.
	if is_instance_valid(collision_shape):
		collision_shape.position.y = plant_y - 12.0


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
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position + Vector2(0, plant_y))


func _draw() -> void:
	var outline := Color("101820")
	var dark_green := Color("176453") if not mobile else Color("236f70")
	var green := Color("28a476") if not mobile else Color("35c2a1")
	var highlight := Color("78e0aa") if not mobile else Color("8ef3da")
	# The plant is drawn by the parent before the instanced pipe child. The pipe
	# therefore masks the lower stalk naturally while the cactus retracts.
	PixelArt.rect(self, Vector2(-5, -30 + plant_y), Vector2(10, 34), outline)
	PixelArt.rect(self, Vector2(-3, -28 + plant_y), Vector2(6, 30), dark_green)
	PixelArt.rect(self, Vector2(-2, -26 + plant_y), Vector2(2, 25), green)
	PixelArt.rect(self, Vector2(-14, -22 + plant_y), Vector2(12, 7), outline)
	PixelArt.rect(self, Vector2(-12, -20 + plant_y), Vector2(10, 3), green)
	PixelArt.rect(self, Vector2(-14, -29 + plant_y), Vector2(7, 12), outline)
	PixelArt.rect(self, Vector2(-12, -27 + plant_y), Vector2(3, 9), dark_green)
	PixelArt.rect(self, Vector2(3, -16 + plant_y), Vector2(13, 7), outline)
	PixelArt.rect(self, Vector2(3, -14 + plant_y), Vector2(11, 3), green)
	PixelArt.rect(self, Vector2(9, -23 + plant_y), Vector2(7, 12), outline)
	PixelArt.rect(self, Vector2(11, -21 + plant_y), Vector2(3, 9), dark_green)
	PixelArt.rect(self, Vector2(-1, -23 + plant_y), Vector2(2, 12), highlight)
	PixelArt.rect(self, Vector2(-9, -18 + plant_y), Vector2(2, 2), Color("e6ad55"))
	PixelArt.rect(self, Vector2(9, -12 + plant_y), Vector2(2, 2), Color("e6ad55"))
