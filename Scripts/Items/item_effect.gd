extends Node
class_name ItemEffect

## Emitted once the duration has run out or the effect was cut short
signal finished

const VIGNETTE_SHADER := "res://Assets/shaders/ItemVignette.gdshader"

## The item this effect was spawned from, handed over by the ItemSystem
var data: ItemData = null

## The cube the effect runs on, handed over by the ItemSystem. Every script the
## effect needs hangs off it, so an effect never has to search the tree for a
## player and can never pick up somebody else's
var player: Player = null

## Seconds the effect started with, the UI draws its ring from this
var duration: float = 0.0

## Seconds left before the effect ends
var time_left: float = 0.0

## True from the first stop() on, a second one does nothing
var is_stopping: bool = false

## Which seat this effect belongs to, so its glow lands on that player's own
## piece of the window rather than over everybody's
var seat: int = 0

var _vignette: CanvasLayer = null
var _glow: ColorRect = null
var _vignette_material: ShaderMaterial = null
var _perspective: PlayerPerspective = null


func _ready() -> void:
	duration = maxf(data.duration, 0.01) if data != null else 0.01
	time_left = duration
	_start()
	_keep_to_myself()


## Whatever the item put into the world is put on its owner's own layer, so a
## race stays a race of your own: an arrow pointing somebody else's way out is
## not something the player next to them should be reading.
##
## Run after the effect has built itself, and again a frame later for the ones
## that finish building on the frame after that
func _keep_to_myself() -> void:
	if not Match.is_private_race():
		return

	claim(self)
	await get_tree().process_frame

	if is_inside_tree():
		claim(self)


## Puts something this item made onto its owner's own layer. Called for the
## effect itself, and by hand for anything an item hands to the level instead of
## keeping as a child of its own — that is out of reach of the walk above.
##
## A bot owns no piece of the window, and what its items draw is its own reading
## of the maze: an arrow pointing a CPU's way out is the one thing the players
## racing it must not be shown
func claim(node: Node) -> void:
	if not Match.is_private_race():
		return

	var bot := player != null and player.is_bot
	SeatView.mark(node, 0 if bot else SeatView.private_bit(seat))


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
	if _glow != null or (player != null and player.is_bot):
		return

	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = load(VIGNETTE_SHADER)
	_vignette_material.set_shader_parameter("tint", data.accent_color if data != null else Color.WHITE)
	_vignette_material.set_shader_parameter("strength", strength)

	_glow = ColorRect.new()
	_glow.material = _vignette_material
	_glow.color = Color(1, 1, 1, 1)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var holder := _hud_holder()

	if holder != null:
		holder.add_child(_glow)
	else:
		_vignette = CanvasLayer.new()
		_vignette.layer = 8
		_vignette.add_child(_glow)
		add_child(_vignette)

	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_perspective = player.perspective if player != null else null
	if _perspective != null:
		_perspective.perspective_changed.connect(_on_perspective_changed)

	_on_perspective_changed(_perspective.is_first_person if _perspective != null else false)


## The piece of the window this seat owns, null while there is no split screen
## and the glow may simply cover the whole of it
func _hud_holder() -> Control:
	for node in get_tree().get_nodes_in_group(SeatHud.GROUP):
		var hud := node as SeatHud
		if hud.seat == seat:
			return hud.vignette_parent()

	return null


func _on_perspective_changed(first_person: bool) -> void:
	if _glow != null:
		_glow.visible = first_person


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

	if _glow != null and _vignette == null and is_instance_valid(_glow):
		_glow.queue_free()

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
