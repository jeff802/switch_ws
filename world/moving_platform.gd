class_name MovingPlatform
extends AnimatableBody2D

@export var offset: Vector2 = Vector2(96, 0)
@export var travel_time: float = 2.4
@export var wait_time: float = 0.35
@export var motion_enabled: bool = true

var origin: Vector2
var clock: float = 0.0
var reported_endpoint: int = -1


func _ready() -> void:
	add_to_group("platforms")
	origin = position


func _physics_process(delta: float) -> void:
	if not motion_enabled:
		return
	clock += delta
	var moving_duration := maxf(0.1, travel_time)
	var full_segment := moving_duration + wait_time
	var cycle := fmod(clock, full_segment * 2.0)
	var progress: float
	if cycle < moving_duration:
		progress = cycle / moving_duration
	elif cycle < full_segment:
		progress = 1.0
	elif cycle < full_segment + moving_duration:
		progress = 1.0 - (cycle - full_segment) / moving_duration
	else:
		progress = 0.0
	position = origin.lerp(origin + offset, smoothstep(0.0, 1.0, progress))
	var endpoint := -1
	if progress >= 0.999:
		endpoint = 1
	elif progress <= 0.001:
		endpoint = 0
	if endpoint >= 0 and endpoint != reported_endpoint:
		reported_endpoint = endpoint
		GameEvents.platform_endpoint_reached.emit(self, endpoint == 1)


func set_motion_enabled(value: bool) -> void:
	motion_enabled = value


func reset_motion() -> void:
	clock = 0.0
	reported_endpoint = -1
	position = origin
