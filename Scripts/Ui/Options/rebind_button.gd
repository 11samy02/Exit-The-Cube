class_name RebindButton
extends Button

## One slot of one action. Click it, press whatever should trigger the action
## from now on, right click to leave the slot empty.
## Cancelling is ESC on the keyboard and Back/View/Select on a pad, that button
## stays reserved so a pad only player is never stuck in an armed slot

const LISTENING_TEXT := "PRESS ..."

## How far a stick has to be pushed before it counts as a binding
const AXIS_THRESHOLD := 0.6

## How far it has to travel away from where it rested when the slot was armed.
## Triggers on some pads sit at a hard -1 while untouched, without this they
## would bind themselves before the player reached for anything
const AXIS_TRAVEL := 0.5

## Seconds after arming in which no axis is taken at all, the stick that
## confirmed the slot is usually still on its way back
const ARM_GRACE := 0.25

var action: StringName = &""

var slot: int = Settings.SLOT_KEYBOARD

var _listening: bool = false

## Where every axis of every pad sat the moment this slot was armed
var _axis_rest: Dictionary = {}

var _armed_at: float = 0.0


func _ready() -> void:
	set_process_input(false)
	custom_minimum_size = Vector2(190, 58)
	expand_icon = true
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	pressed.connect(_start_listening)
	Settings.bindings_changed.connect(refresh)
	InputIcons.device_changed.connect(_on_device_changed)


## Called right after the button was added, the row knows which slot it is
func setup(new_action: StringName, new_slot: int) -> void:
	action = new_action
	slot = new_slot
	refresh()


## Right click drops the binding, that is the only way to end up with an empty
## slot on purpose
func _gui_input(event: InputEvent) -> void:
	if _listening:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		Settings.clear_binding(action, slot)
		accept_event()


## Runs before the UI sees anything, so the key that is being bound cannot press
## this button again on its way through
func _input(event: InputEvent) -> void:
	if not _listening:
		return

	if event is InputEventKey:
		if not event.pressed or event.echo:
			_swallow()
			return

		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_stop_listening()
			_swallow()
			return

		if slot == Settings.SLOT_KEYBOARD:
			var key := InputEventKey.new()
			key.physical_keycode = event.physical_keycode
			key.keycode = event.keycode
			_assign(key)

		_swallow()
		return

	if event is InputEventMouseButton:
		if not event.pressed:
			_swallow()
			return

		if slot == Settings.SLOT_KEYBOARD:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = event.button_index
			_assign(mouse)

		_swallow()
		return

	if event is InputEventJoypadButton:
		if not event.pressed:
			_swallow()
			return

		if event.button_index == JOY_BUTTON_BACK:
			_stop_listening()
			_swallow()
			return

		if slot == Settings.SLOT_GAMEPAD:
			var button := InputEventJoypadButton.new()
			button.button_index = event.button_index
			_assign(button)

		_swallow()
		return

	if event is InputEventJoypadMotion:
		if not _is_deliberate_axis(event):
			return

		if slot == Settings.SLOT_GAMEPAD:
			var motion := InputEventJoypadMotion.new()
			motion.axis = event.axis
			motion.axis_value = signf(event.axis_value)
			_assign(motion)

		_swallow()


## Reads the binding back out of the InputMap and draws it in the style of the
## controller that is plugged in
func refresh() -> void:
	if _listening:
		return

	var event := Settings.get_binding(action, slot)
	var texture := InputIcons.get_event_texture(event)

	icon = texture
	if texture != null:
		text = ""
		tooltip_text = InputIcons.get_event_text(event)
	else:
		text = InputIcons.get_event_text(event) if event != null else "- - -"
		tooltip_text = ""


func _start_listening() -> void:
	if _listening:
		return

	_listening = true
	icon = null
	text = LISTENING_TEXT
	_snapshot_axes()
	set_process_input(true)


## An axis only counts once it has both been pushed far enough and travelled
## away from where it was resting when the slot opened
func _is_deliberate_axis(event: InputEventJoypadMotion) -> bool:
	if absf(event.axis_value) < AXIS_THRESHOLD:
		return false

	if float(Time.get_ticks_msec()) * 0.001 - _armed_at < ARM_GRACE:
		return false

	var rest := float(_axis_rest.get(_axis_key(event.device, event.axis), 0.0))
	return absf(event.axis_value - rest) >= AXIS_TRAVEL


func _snapshot_axes() -> void:
	_armed_at = float(Time.get_ticks_msec()) * 0.001
	_axis_rest.clear()

	for device in Input.get_connected_joypads():
		for axis in JOY_AXIS_MAX:
			_axis_rest[_axis_key(device, axis)] = Input.get_joy_axis(device, axis)


func _axis_key(device: int, axis: int) -> int:
	return device * 100 + axis


func _stop_listening() -> void:
	_listening = false
	set_process_input(false)
	refresh()


func _assign(event: InputEvent) -> void:
	Settings.set_binding(action, slot, event)
	_stop_listening()


func _swallow() -> void:
	get_viewport().set_input_as_handled()


func _on_device_changed(_device: int) -> void:
	refresh()
