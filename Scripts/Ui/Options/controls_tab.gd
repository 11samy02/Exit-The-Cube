extends VBoxContainer

## One row per action, one slot for keyboard and mouse and one for the pad. The
## icons in the slots follow whatever controller is plugged in

const DEFAULT_DESCRIPTION := "Pick a slot and press what you want. Right click clears it, ESC or the Back button on a pad cancels."

## Readable names in the order the rows should appear, actions that are not in
## here are still listed, they just come last under their raw name
const ACTION_LABELS := {
	"move_forward": "Move Forward",
	"move_back": "Move Back",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"look_left": "Look Left",
	"look_right": "Look Right",
	"look_up": "Look Up",
	"look_down": "Look Down",
	"toggle_perspective": "Switch Perspective",
	"use_item": "Use Item",
	"pause": "Pause / Menu",
}

## What each action is for, shown while one of its two slots is hovered
const ACTION_DESCRIPTIONS := {
	"move_forward": "Rolls the cube away from the camera. Movement is camera relative, so forward is always where you are looking.",
	"move_back": "Rolls the cube back towards the camera. Useful the moment you hear a saw.",
	"move_left": "Rolls the cube left. One tile per press, no half measures.",
	"move_right": "Rolls the cube right. One tile per press, no half measures.",
	"look_left": "Swings the camera left. The stick does this, a mouse does it on its own.",
	"look_right": "Swings the camera right. The stick does this, a mouse does it on its own.",
	"look_up": "Tilts the camera up, towards the ceiling you are trying to escape through.",
	"look_down": "Tilts the camera down, which is where the saws usually are.",
	"toggle_perspective": "Switches between watching the cube and being the cube. Ego view is harder and far more fun.",
	"use_item": "Spends whatever is sitting in the item slot. There is no confirmation, so mean it.",
	"pause": "Stops the world and opens this menu. Also the fastest way out of a bad run.",
}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	set_meta(OptionsUi.DEFAULT_DESCRIPTION_META, DEFAULT_DESCRIPTION)
	_build()


func _build() -> void:
	add_child(OptionsUi.make_heading("SENSITIVITY"))
	add_child(_make_sensitivity_row(
		"Mouse", Settings.mouse_sensitivity, Settings.set_mouse_sensitivity, _describe_mouse
	))
	add_child(_make_sensitivity_row(
		"Controller Stick", Settings.controller_sensitivity, Settings.set_controller_sensitivity,
		_describe_stick
	))
	add_child(OptionsUi.make_separator())

	add_child(OptionsUi.make_heading("KEY BINDINGS"))
	add_child(_make_header())

	for action in _ordered_actions():
		add_child(_make_row(action))

	add_child(OptionsUi.make_separator())

	var reset := Button.new()
	reset.text = "RESET TO DEFAULTS"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(Settings.reset_bindings)
	OptionsUi.describe(reset, "Puts every binding back to what the game shipped with. The sensitivity sliders stay where you left them.")
	add_child(reset)


## The known actions first in the order they are written down, anything the
## project gains later is appended so it can never be silently unbindable
func _ordered_actions() -> Array[StringName]:
	var remappable := Settings.get_remappable_actions()
	var ordered: Array[StringName] = []

	for name in ACTION_LABELS:
		var action := StringName(name)
		if remappable.has(action):
			ordered.append(action)

	for action in remappable:
		if not ordered.has(action):
			ordered.append(action)

	return ordered


## 1.00 is the speed the camera was tuned at, the slider only scales it. The
## setter is handed in so the same row serves the mouse and the stick
func _make_sensitivity_row(
	text: String, value: float, setter: Callable, description: Callable
) -> HBoxContainer:
	var slider := OptionsUi.make_slider(
		Settings.MIN_SENSITIVITY, Settings.MAX_SENSITIVITY, 0.05, value
	)
	var readout := OptionsUi.make_readout("%.2f x" % value)

	slider.value_changed.connect(func(moved: float) -> void:
		readout.text = "%.2f x" % moved
		setter.call(moved)
	)

	return OptionsUi.make_row(text, OptionsUi.make_slider_box(slider, readout), description)


func _describe_mouse() -> String:
	var value := Settings.mouse_sensitivity

	if value >= 2.5:
		return "%.2f x. At this speed a flick of the wrist is a full pirouette. Respect, and good luck." % value

	if value <= 0.35:
		return "%.2f x. Sniper slow. You will need desk space and patience." % value

	return "%.2f x how far the camera swings per centimetre of mouse. 1.00 is the speed the game was built around."


func _describe_stick() -> String:
	var value := Settings.controller_sensitivity

	if value >= 2.5:
		return "%.2f x. The camera now spins faster than the cube can roll. Chaotic, but it is your run." % value

	if value <= 0.35:
		return "%.2f x. Very steady, very slow. Turning around takes a moment of commitment." % value

	return "%.2f x how fast the camera turns at full stick. 1.00 is the speed the game was built around."


func _make_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.add_child(_make_column_title("Action", OptionsUi.LABEL_WIDTH))
	row.add_child(_make_column_title("Keyboard / Mouse", 190))
	row.add_child(_make_column_title("Gamepad", 190))
	return row


func _make_column_title(text: String, width: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", OptionsUi.HINT_COLOR)
	return label


func _make_row(action: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var label := Label.new()
	label.text = ACTION_LABELS.get(String(action), String(action).capitalize())
	label.custom_minimum_size = Vector2(OptionsUi.LABEL_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	for slot in [Settings.SLOT_KEYBOARD, Settings.SLOT_GAMEPAD]:
		var button := RebindButton.new()
		row.add_child(button)
		button.setup(action, slot)

	OptionsUi.describe(row, _describe_action.bind(action, label.text))
	return row


func _describe_action(action: StringName, label: String) -> String:
	var text: String = ACTION_DESCRIPTIONS.get(String(action), "Sets what triggers this action.")
	var keyboard := Settings.get_binding(action, Settings.SLOT_KEYBOARD)
	var pad := Settings.get_binding(action, Settings.SLOT_GAMEPAD)

	if keyboard == null and pad == null:
		return "%s is not bound to anything at all. It will never happen. %s" % [label, text]

	return text
