extends CanvasLayer
## Persistent, shader-driven scene transition used by reloads and stage changes.

const TRANSITION_SHADER := preload("res://ui/gear_wipe.gdshader")
const COVER_TIME := 0.24
const REVEAL_TIME := 0.3

var busy: bool = false
var overlay: ColorRect
var transition_material: ShaderMaterial


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.name = "GearWipe"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_material = ShaderMaterial.new()
	transition_material.shader = TRANSITION_SHADER
	transition_material.set_shader_parameter("progress", 0.0)
	overlay.material = transition_material
	overlay.visible = false
	add_child(overlay)


func reload_current_scene() -> bool:
	if busy or get_tree().current_scene == null:
		return false
	busy = true
	var level_id := get_tree().current_scene.scene_file_path
	GameEvents.level_reload_requested.emit(level_id)
	await _animate_progress(0.0, 1.0, COVER_TIME)
	var error := get_tree().reload_current_scene()
	if error != OK:
		await _animate_progress(1.0, 0.0, REVEAL_TIME)
		busy = false
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	GameEvents.level_reloaded.emit(level_id)
	await _animate_progress(1.0, 0.0, REVEAL_TIME)
	busy = false
	return true


func change_scene(scene_path: String) -> bool:
	if busy or scene_path.is_empty():
		return false
	busy = true
	await _animate_progress(0.0, 1.0, COVER_TIME)
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		await _animate_progress(1.0, 0.0, REVEAL_TIME)
		busy = false
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	GameEvents.level_reloaded.emit(scene_path)
	await _animate_progress(1.0, 0.0, REVEAL_TIME)
	busy = false
	return true


func _animate_progress(from: float, to: float, duration: float) -> void:
	overlay.visible = true
	transition_material.set_shader_parameter("progress", from)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(value: float) -> void:
			transition_material.set_shader_parameter("progress", value),
		from,
		to,
		duration
	)
	await tween.finished
	if is_zero_approx(to):
		overlay.visible = false
