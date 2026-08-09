class_name PlayerStateMachine
extends RefCounted
## Callback state machine that keeps transitions and state-owned physics apart.

signal transitioned(previous_state: int, current_state: int)

var current_state: int = -1
var _enter_callbacks: Dictionary = {}
var _physics_callbacks: Dictionary = {}


func register_state(state_id: int, enter_callback: Callable = Callable(), physics_callback: Callable = Callable()) -> void:
	_enter_callbacks[state_id] = enter_callback
	_physics_callbacks[state_id] = physics_callback


func start(initial_state: int) -> void:
	transition_to(initial_state, true)


func transition_to(next_state: int, force: bool = false) -> bool:
	if not force and current_state == next_state:
		return false
	var previous := current_state
	current_state = next_state
	transitioned.emit(previous, current_state)
	var enter_callback: Callable = _enter_callbacks.get(current_state, Callable())
	if enter_callback.is_valid():
		enter_callback.call(previous)
	return true


func physics_process(delta: float) -> bool:
	var physics_callback: Callable = _physics_callbacks.get(current_state, Callable())
	if not physics_callback.is_valid():
		return false
	return bool(physics_callback.call(delta))
