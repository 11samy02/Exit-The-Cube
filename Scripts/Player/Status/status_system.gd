extends Node

## What has been done to this cube by somebody else, and for how long.
##
## Separate from the item system on purpose: an item is something the player
## picked up and chose to spend, a status is something that happened to them.
## They need announcing rather than displaying — hence the sound, and a badge
## that appears rather than a slot that was already there

## Emitted whenever something starts or runs out, for the badge strip
signal status_changed

const FOLDER := "res://Resources/Status/"
const WOOZY_SHADER := "res://Assets/shaders/Woozy.gdshader"

## Which layer the swimming screen sits on. Over the world, under every panel
const SCREEN_LAYER := 9

## Seconds the view takes to settle once the effect has gone
const SETTLE := 0.6

## Everything running right now: id to seconds left
var running: Dictionary = {}

var _data: Dictionary = {}
var _sfx: AudioStreamPlayer = null
var _screen: ColorRect = null
var _screen_material: ShaderMaterial = null
var _wobble: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_effects()
	_build_screen()

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"sfx"
	add_child(_sfx)


## Every .tres in the folder counts as an effect. Dropping one in is all it
## takes to have another
func _load_effects() -> void:
	for file in ResourceLoader.list_directory(FOLDER):
		if not file.ends_with(".tres"):
			continue

		var effect := load(FOLDER + file) as StatusEffectData
		if effect != null and not effect.id.is_empty():
			_data[effect.id] = effect


## Puts an effect on this cube. Seconds of 0 uses whatever the effect carries,
## and applying one that is already running winds it back up rather than
## stacking, so being hit twice is not twice as bad
func apply(id: String, seconds: float = 0.0) -> void:
	var effect := _data.get(id, null) as StatusEffectData
	if effect == null:
		return

	var fresh := not running.has(id)
	running[id] = maxf(seconds, 0.0) if seconds > 0.0 else effect.duration

	if fresh:
		_announce(effect)
		_hold_still(effect)

	_rebuild()
	status_changed.emit()


func clear() -> void:
	running.clear()
	_rebuild()
	status_changed.emit()


## True while that effect is on the cube
func has(id: String) -> bool:
	return running.has(id)


## Seconds left of it, 0 when it is not running
func left(id: String) -> float:
	return float(running.get(id, 0.0))


## Everything running, for the badge strip to draw
func active() -> Array[StatusEffectData]:
	var found: Array[StatusEffectData] = []

	for id: String in running:
		found.append(_data[id])

	return found


func _process(delta: float) -> void:
	var expired: Array[String] = []

	for id: String in running:
		running[id] = float(running[id]) - delta
		if float(running[id]) <= 0.0:
			expired.append(id)

	if not expired.is_empty():
		for id in expired:
			running.erase(id)

		_rebuild()
		status_changed.emit()

	_settle_screen(delta)


## Puts the sound up and, in a moment, the badge
func _announce(effect: StatusEffectData) -> void:
	if effect.sound != null:
		_sfx.stream = effect.sound
		_sfx.play()


## Some effects take the cube's feet out from under it for a moment
func _hold_still(effect: StatusEffectData) -> void:
	if effect.stun_seconds <= 0.0:
		return

	var movement := get_tree().get_first_node_in_group("player_movement") as PlayerMovement
	if movement == null:
		return

	movement.input_enabled = false
	await get_tree().create_timer(effect.stun_seconds).timeout

	if is_instance_valid(movement):
		movement.input_enabled = true


## Works out what everything running adds up to and puts it on the cube. Read
## from the whole list rather than applied one at a time, so an effect ending
## cannot undo one that is still going
func _rebuild() -> void:
	var speed := 1.0
	var wobble := 0.0
	var tint := Color(0.6, 0.4, 1.0)

	for effect in active():
		speed *= effect.speed_multiplier
		if effect.wobble > wobble:
			wobble = effect.wobble
			tint = effect.accent_color

	var movement := get_tree().get_first_node_in_group("player_movement") as PlayerMovement
	if movement != null:
		if is_equal_approx(speed, 1.0):
			movement.clear_boost(&"status")
		else:
			movement.set_boost(&"status", speed)

	_wobble = wobble
	_screen_material.set_shader_parameter("tint", tint)


## The view swims in and out rather than snapping, so an effect ending does not
## read as a rendering glitch
func _settle_screen(delta: float) -> void:
	var shown := float(_screen_material.get_shader_parameter("amount"))
	var wanted := _wobble

	if is_equal_approx(shown, wanted):
		_screen.visible = wanted > 0.001
		return

	var stepped := move_toward(shown, wanted, delta / SETTLE)
	_screen_material.set_shader_parameter("amount", stepped)
	_screen.visible = stepped > 0.001


func _build_screen() -> void:
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = load(WOOZY_SHADER)
	_screen_material.set_shader_parameter("amount", 0.0)

	_screen = ColorRect.new()
	_screen.material = _screen_material
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.visible = false

	var layer := CanvasLayer.new()
	layer.layer = SCREEN_LAYER
	layer.add_child(_screen)
	add_child(layer)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
