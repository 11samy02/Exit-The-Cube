extends Node
class_name ItemEffect

## Emitted once the duration has run out or the effect was cut short
signal finished

const VIGNETTE_SHADER := "res://Assets/shaders/ItemVignette.gdshader"

## The item this effect was spawned from, handed over by the ItemSystem
var data: ItemData = null

## The player the effect runs on, handed over by the ItemSystem
var player: CharacterBody3D = null

## Seconds the effect started with, the UI draws its ring from this
var duration: float = 0.0

## Seconds left before the effect ends
var time_left: float = 0.0

## True from the first stop() on, a second one does nothing
var is_stopping: bool = false

var _vignette: CanvasLayer = null
var _vignette_material: ShaderMaterial = null
var _perspective: PlayerPerspective = null


func _ready() -> void:
	duration = maxf(data.duration, 0.01) if data != null else 0.01
	time_left = duration
	_start()


func _process(delta: float) -> void:
	_tick(delta)

	if _vignette_material != null:
		_vignette_material.set_shader_parameter("life", progress())

	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		stop(false)


## Puts a glow in the item color around the edge of the screen, but only while
## the player is in ego perspective. From the outside the cube itself carries
## the effect, from the inside there is nothing to see it on
func show_vignette(strength: float = 0.9) -> void:
	if _vignette != null:
		return

	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = load(VIGNETTE_SHADER)
	_vignette_material.set_shader_parameter("tint", data.accent_color if data != null else Color.WHITE)
	_vignette_material.set_shader_parameter("strength", strength)

	var glow := ColorRect.new()
	glow.material = _vignette_material
	glow.color = Color(1, 1, 1, 1)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vignette = CanvasLayer.new()
	_vignette.layer = 8
	_vignette.add_child(glow)
	add_child(_vignette)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_perspective = get_tree().get_first_node_in_group("player_perspective") as PlayerPerspective
	if _perspective != null:
		_perspective.perspective_changed.connect(_on_perspective_changed)

	_on_perspective_changed(_perspective.is_first_person if _perspective != null else false)


func _on_perspective_changed(first_person: bool) -> void:
	if _vignette != null:
		_vignette.visible = first_person


## How much of the duration is still left, 1 at the start and 0 at the end
func progress() -> float:
	return clampf(time_left / duration, 0.0, 1.0)


## Winds the duration back up, used when the same item is activated a second
## time while its effect is still running
func restart() -> void:
	time_left = duration


## Ends the effect. Cancelled means the run itself is over, the effect is not
## allowed to touch the player in that case, it is being torn down with it
func stop(cancelled: bool) -> void:
	if is_stopping:
		return

	is_stopping = true
	set_process(false)
	_stop(cancelled)
	finished.emit()
	queue_free()


## Hook for the actual item, runs once when the effect starts
func _start() -> void:
	pass


## Hook for the actual item, runs every frame while the effect is up
func _tick(_delta: float) -> void:
	pass


## Hook for the actual item, undoes whatever _start did
func _stop(_cancelled: bool) -> void:
	pass


## True while the effect is close enough to its end to blink a warning
func is_running_out(warning_time: float) -> bool:
	return time_left <= warning_time


## Square blink over the last seconds, always on outside of them
func warning_blink(warning_time: float, blink_speed: float) -> bool:
	if not is_running_out(warning_time):
		return true

	return sin(time_left * blink_speed * TAU) > -0.2
