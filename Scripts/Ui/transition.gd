extends CanvasLayer

## Emitted once the screen is fully covered, the scene behind it is the new one
signal covered

## Emitted when the last cube has cleared the screen again
signal finished

const SHADER := preload("res://Assets/shaders/transition.gdshader")

## Seconds the cubes take to swallow the screen
@export var cover_duration: float = 0.5

## Seconds they take to clear it again, the new map is already up behind them
@export var clear_duration: float = 0.6

## Beats between the screen going black and the new scene being built, gives the
## cover a moment to sit before the load hitches
@export var hold_duration: float = 0.15

## True while a transition runs, a second call is dropped instead of cutting
## the running one short
var is_running: bool = false

var _overlay: ColorRect = null

var _material: ShaderMaterial = null


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()


## Swaps in the scene at that path behind the cover. Do not await this from a
## node that lives in the old scene, it is gone by the time this returns
func change_scene(scene_path: String) -> void:
	await _swap(scene_path)


## Builds the current scene again, this is the restart after a death or a win
func reload_scene() -> void:
	await _swap("")


## Covers, swaps and clears. An empty path is read as reload, both go through
## the same cover so a restart looks like any other scene change
func _swap(scene_path: String) -> void:
	if is_running:
		return

	is_running = true
	await _cover()
	covered.emit()

	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration, true, false, true).timeout

	if scene_path.is_empty():
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame
	await _clear()

	is_running = false
	finished.emit()


## Cubes tumble in from the top left corner until nothing is left of the map
func _cover() -> void:
	_set_flip(0.0)
	_set_progress(0.0)
	_overlay.visible = true

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_set_progress, 0.0, 1.0, cover_duration)
	await tween.finished


## The same sweep runs on, the corner that went dark first opens up first
func _clear() -> void:
	_set_flip(1.0)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_set_progress, 1.0, 0.0, clear_duration)
	await tween.finished

	_overlay.visible = false


## One screen filling rect over everything, it never eats a click because the
## game keeps running underneath while the cubes are up
func _build_overlay() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER

	_overlay = ColorRect.new()
	_overlay.material = _material
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _set_progress(value: float) -> void:
	_material.set_shader_parameter("progress", value)


func _set_flip(value: float) -> void:
	_material.set_shader_parameter("flip", value)
