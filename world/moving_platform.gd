class_name MovingPlatform
extends AnimatableBody2D

@export var offset: Vector2 = Vector2(96, 0)
@export var travel_time: float = 2.4
@export var wait_time: float = 0.35

var origin: Vector2
var clock: float = 0.0


func _ready() -> void:
	origin = position


func _physics_process(delta: float) -> void:
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
