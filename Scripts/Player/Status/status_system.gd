extends Node

## What has been done to a cube by somebody else, and for how long.
##
## Separate from the item system on purpose: an item is something the player
## picked up and chose to spend, a status is something that happened to them.
## They need announcing rather than displaying — hence the sound, and a badge
## that appears rather than a slot that was already there.
##
## Everything in here is kept per seat. A jolt thrown across a splitscreen round
## has to woozy the cube it caught and nobody else, which means both the slowed
## feet and the swimming screen belong to one player rather than to the machine

## Emitted whenever something starts or runs out on a seat, for the badge strip
signal status_changed(seat: int)

const FOLDER := "res://Resources/Status/"
const WOOZY_SHADER := "res://Assets/shaders/Woozy.gdshader"

## Which layer the swimming screen sits on. Over the world, under every panel
const SCREEN_LAYER := 9

## Seconds the view takes to settle once the effect has gone
const SETTLE := 0.6

## Everything running right now: seat to { id: seconds left }
var running: Dictionary = {}

var _data: Dictionary = {}
var _sfx: AudioStreamPlayer = null

## One swimming screen per seat, built when that seat first needs one
var _screens: Dictionary = {}
var _materials: Dictionary = {}
var _wobble: Dictionary = {}

## The layer seat 0's screen hangs on while there is no split to put it in
var _own_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_effects()

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


## Puts an effect on the first cube, which is what everything written when there
## was only one of them means
func apply(id: String, seconds: float = 0.0) -> void:
	apply_to(0, id, seconds)


## Puts an effect on that cube. Seconds of 0 uses whatever the effect carries,
## and applying one that is already running winds it back up rather than
## stacking, so being hit twice is not twice as bad
func apply_to(seat: int, id: String, seconds: float = 0.0) -> void:
	var effect := _data.get(id, null) as StatusEffectData
	if effect == null:
		return

	var held: Dictionary = running.get(seat, {})
	var fresh := not held.has(id)
	held[id] = maxf(seconds, 0.0) if seconds > 0.0 else effect.duration
	running[seat] = held

	if fresh:
		if not Match.is_bot_seat(seat):
			_announce(effect)

		_show_landing(seat, effect)
		_hold_still(seat, effect)

	_rebuild(seat)
	status_changed.emit(seat)


## Takes everything off one seat, or off every one of them at -1
func clear(seat: int = -1) -> void:
	if seat < 0:
		for at: int in running.keys():
			clear(at)

		return

	running.erase(seat)
	_rebuild(seat)
	status_changed.emit(seat)


## True while that effect is on that cube
func has(seat: int, id: String) -> bool:
	return (running.get(seat, {}) as Dictionary).has(id)


## Seconds left of it, 0 when it is not running
func left(seat: int, id: String) -> float:
	return float((running.get(seat, {}) as Dictionary).get(id, 0.0))


## Everything running on that cube, for the badge strip to draw
func active(seat: int) -> Array[StatusEffectData]:
	var found: Array[StatusEffectData] = []

	for id: String in running.get(seat, {}):
		found.append(_data[id])

	return found


## How hard that player's view is swimming right now
func wobble_of(seat: int) -> float:
	return float(_wobble.get(seat, 0.0))


## Hands the swimming screen of a seat over to its own piece of the window. The
## seat HUD calls this as it comes up; without a split, seat 0 keeps the layer
## this node builds for itself, which is exactly what it always did
func set_screen_parent(seat: int, parent: Node) -> void:
	var screen := _screen_of(seat)
	var holder := screen.get_parent()

	if holder == parent:
		return

	if holder != null:
		holder.remove_child(screen)

	if parent == null:
		_own_holder().add_child(screen)
	else:
		parent.add_child(screen)

	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	for seat: int in running.keys():
		var held: Dictionary = running[seat]
		var expired: Array[String] = []

		for id: String in held:
			held[id] = float(held[id]) - delta
			if float(held[id]) <= 0.0:
				expired.append(id)

		if expired.is_empty():
			continue

		for id in expired:
			held.erase(id)

		_rebuild(seat)
		status_changed.emit(seat)

	for seat: int in _screens:
		_settle_screen(seat, delta)


## Puts the sound up and, in a moment, the badge
func _announce(effect: StatusEffectData) -> void:
	if effect.sound != null:
		_sfx.stream = effect.sound
		_sfx.play()


## The jolt landing, drawn on the cube it landed on.
##
## Everything else about a status is on the screen of whoever is wearing it —
## the badge, the swimming view — which the rest of the room cannot see. This is
## the half everybody gets: the cube that just got caught visibly gets caught
func _show_landing(seat: int, effect: StatusEffectData) -> void:
	if effect.burst_reach <= 0.0:
		return

	var cube := Player.at_seat(get_tree(), seat)
	var holder := cube.get_parent() if cube != null else null
	if holder == null:
		return

	for at in range(maxi(effect.burst_rings, 1)):
		BurstRing.burst(holder, cube.global_position, effect.accent_color,
			effect.burst_reach * (1.0 + 0.3 * at), effect.burst_time,
			at % 2 == 1, effect.burst_delay * at)


## Some effects take a cube's feet out from under it for a moment
func _hold_still(seat: int, effect: StatusEffectData) -> void:
	if effect.stun_seconds <= 0.0:
		return

	var movement := _movement_of(seat)
	if movement == null:
		return

	movement.input_enabled = false
	await get_tree().create_timer(effect.stun_seconds).timeout

	if is_instance_valid(movement):
		movement.input_enabled = true


## Works out what everything running on that seat adds up to and puts it on the
## cube. Read from the whole list rather than applied one at a time, so an
## effect ending cannot undo one that is still going
func _rebuild(seat: int) -> void:
	var speed := 1.0
	var wobble := 0.0
	var tint := Color(0.6, 0.4, 1.0)

	for effect in active(seat):
		speed *= effect.speed_multiplier
		if effect.wobble > wobble:
			wobble = effect.wobble
			tint = effect.accent_color

	var movement := _movement_of(seat)
	if movement != null:
		if is_equal_approx(speed, 1.0):
			movement.clear_boost(&"status")
		else:
			movement.set_boost(&"status", speed)

	_wobble[seat] = wobble

	if Match.is_bot_seat(seat):
		return

	if wobble > 0.0 or _screens.has(seat):
		(_material_of(seat)).set_shader_parameter("tint", tint)


func _movement_of(seat: int) -> PlayerMovement:
	var cube := Player.at_seat(get_tree(), seat)
	return cube.movement if cube != null else null


## The view swims in and out rather than snapping, so an effect ending does not
## read as a rendering glitch
func _settle_screen(seat: int, delta: float) -> void:
	var screen := _screens[seat] as ColorRect
	var material := _materials[seat] as ShaderMaterial
	var shown := float(material.get_shader_parameter("amount"))
	var wanted := wobble_of(seat)

	if is_equal_approx(shown, wanted):
		screen.visible = wanted > 0.001
		return

	var stepped := move_toward(shown, wanted, delta / SETTLE)
	material.set_shader_parameter("amount", stepped)
	screen.visible = stepped > 0.001


func _screen_of(seat: int) -> ColorRect:
	if _screens.has(seat):
		return _screens[seat]

	var material := ShaderMaterial.new()
	material.shader = load(WOOZY_SHADER)
	material.set_shader_parameter("amount", 0.0)

	var screen := ColorRect.new()
	screen.material = material
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.visible = false

	_screens[seat] = screen
	_materials[seat] = material

	_own_holder().add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return screen


func _material_of(seat: int) -> ShaderMaterial:
	_screen_of(seat)
	return _materials[seat]


## Where a screen hangs while nothing else has claimed it
func _own_holder() -> CanvasLayer:
	if _own_layer == null:
		_own_layer = CanvasLayer.new()
		_own_layer.layer = SCREEN_LAYER
		add_child(_own_layer)

	return _own_layer
