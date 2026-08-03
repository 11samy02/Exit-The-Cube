extends Node

## Sound and motion for every menu control in the game. Buttons are built in
## code in half the menus and in the editor in the other half, so the wiring
## lives here instead of on a script per button

const HOVER_SOUND := preload("res://Assets/Sounds/UI & Menus/Hover Over.wav")
const CLICK_SOUND := preload("res://Assets/Sounds/UI & Menus/Select.wav")
const BACK_SOUND := preload("res://Assets/Sounds/UI & Menus/Quit Out.wav")

## Marks a control that is already wired, a menu inside a menu would otherwise
## get its signals connected twice
const ATTACHED_FLAG := &"ui_feedback_attached"

## Pixels a hovered control grows by in total. Scaling by a percentage instead
## would blow a full width dropdown far out of its row while a small button
## barely moved, and the wide one would then be clipped by the scroll view
const HOVER_GROW := 16.0

## Ceiling for narrow controls, without it a small button would balloon
const HOVER_SCALE_MAX := 1.06

## How far a hovered control leans to the right once the glitch has settled
const HOVER_SHIFT := 5.0

## The two frames the control jumps sideways before it settles, this is the
## retro part, a clean ease looks modern and expensive instead of arcade
const GLITCH_OUT := -9.0
const GLITCH_BACK := 7.0
const GLITCH_STEP := 0.035

const PRESS_SCALE := Vector2(0.94, 0.94)

const FLASH := Color(1.35, 1.35, 1.45, 1)

## Both mouse_entered and focus_entered can land in the same frame, without this
## the hover sound is heard twice
const SOUND_COOLDOWN := 0.05

var _sfx: AudioStreamPlayer

var _last_sound_at: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"sfx"
	_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx)


## Wires one control. Only buttons get the motion, a slider that jumps around
## while it is being dragged would fight the thumb
func attach(control: Control) -> void:
	if control == null or control.has_meta(ATTACHED_FLAG):
		return

	control.set_meta(ATTACHED_FLAG, true)

	if control is Range:
		control.mouse_entered.connect(_on_range_hover.bind(control))
		control.focus_entered.connect(_on_range_hover.bind(control))
		control.mouse_exited.connect(_on_range_unhover.bind(control))
		control.focus_exited.connect(_on_range_unhover.bind(control))
		return

	if not (control is BaseButton):
		return

	control.offset_transform_enabled = true
	control.offset_transform_visual_only = true
	control.offset_transform_pivot_ratio = Vector2(0.5, 0.5)

	control.mouse_entered.connect(_on_hover.bind(control))
	control.focus_entered.connect(_on_hover.bind(control))
	control.mouse_exited.connect(_on_unhover.bind(control))
	control.focus_exited.connect(_on_unhover.bind(control))

	var button := control as BaseButton
	button.button_down.connect(_on_press.bind(control))
	button.pressed.connect(_on_pressed.bind(control))


## Marks a button as one that steps back out of a menu, it then answers with
## the softer sound instead of the confirmation one
func use_back_sound(button: BaseButton) -> void:
	button.set_meta(&"ui_feedback_back", true)


## Walks a finished menu and wires everything in it at once
func attach_all(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			attach(child)

		attach_all(child)


func play_hover() -> void:
	_play(HOVER_SOUND)


func play_click() -> void:
	_play(CLICK_SOUND)


## For anything that steps back out of a menu, it is a softer sound than the
## one a confirmation gets
func play_back() -> void:
	_play(BACK_SOUND)


func _on_pressed(control: Control) -> void:
	if control.get_meta(&"ui_feedback_back", false):
		play_back()
	else:
		play_click()


func _on_hover(control: Control) -> void:
	if control is BaseButton and (control as BaseButton).disabled:
		return

	play_hover()

	var tween := _restart(control)
	tween.tween_property(control, "offset_transform_scale", _hover_scale(control), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate", FLASH, 0.08)
	tween.tween_property(control, "modulate", Color(1, 1, 1, 1), 0.2).set_delay(0.08)
	tween.tween_property(control, "offset_transform_position", Vector2(GLITCH_OUT, 0), GLITCH_STEP)
	tween.tween_property(control, "offset_transform_position", Vector2(GLITCH_BACK, 0), GLITCH_STEP) \
		.set_delay(GLITCH_STEP)
	tween.tween_property(control, "offset_transform_position", Vector2(HOVER_SHIFT, 0), 0.08) \
		.set_delay(GLITCH_STEP * 2.0)


## A slider must not be shoved sideways while the thumb is being dragged, so it
## only brightens. The track already swaps to its highlight style underneath
func _on_range_hover(control: Control) -> void:
	play_hover()

	var tween := _restart(control)
	tween.tween_property(control, "modulate", Color(1.3, 1.3, 1.4, 1), 0.12)


func _on_range_unhover(control: Control) -> void:
	if control.has_focus() or control.get_global_rect().has_point(control.get_global_mouse_position()):
		return

	var tween := _restart(control)
	tween.tween_property(control, "modulate", Color(1, 1, 1, 1), 0.14)


func _on_unhover(control: Control) -> void:
	if control.has_focus() or control.get_global_rect().has_point(control.get_global_mouse_position()):
		return

	var tween := _restart(control)
	tween.tween_property(control, "offset_transform_scale", Vector2.ONE, 0.14)
	tween.tween_property(control, "offset_transform_position", Vector2.ZERO, 0.14)
	tween.tween_property(control, "modulate", Color(1, 1, 1, 1), 0.14)


## Short punch inwards, it lands back on the hover pose because the pointer is
## still on the control when the click is over
func _on_press(control: Control) -> void:
	var tween := _restart(control)
	tween.tween_property(control, "offset_transform_scale", PRESS_SCALE, 0.05)
	tween.tween_property(control, "offset_transform_scale", _hover_scale(control), 0.14).set_delay(0.05)


## The same number of pixels on every control, so a row wide dropdown leans out
## just as far as a menu button and stays inside the list it lives in
func _hover_scale(control: Control) -> Vector2:
	var factor := minf(1.0 + HOVER_GROW / maxf(control.size.x, 1.0), HOVER_SCALE_MAX)
	return Vector2(factor, factor)


## One tween per control, a second hover before the first one finished would
## otherwise leave the control stuck between two poses
func _restart(control: Control) -> Tween:
	if control.has_meta(&"ui_feedback_tween"):
		var running: Tween = control.get_meta(&"ui_feedback_tween")
		if running != null and running.is_valid():
			running.kill()

	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	control.set_meta(&"ui_feedback_tween", tween)
	return tween


func _play(stream: AudioStream) -> void:
	var now := float(Time.get_ticks_msec()) * 0.001
	if now - _last_sound_at < SOUND_COOLDOWN:
		return

	_last_sound_at = now
	_sfx.stream = stream
	_sfx.play()
