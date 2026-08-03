class_name OptionsUi
extends RefCounted

## Shared row builders for the options tabs. Every tab fills itself from what
## the machine reports at runtime, so none of these rows can be laid out in the
## editor ahead of time

## Keeps the labels of all three tabs on the same column
const LABEL_WIDTH := 340

const HINT_COLOR := Color(0.616, 0.588, 0.749, 1)

## Where a control keeps the line the menu prints while it is hovered. Holds
## either a plain String or a Callable that builds one from the current value
const DESCRIPTION_META := &"ui_description"

## Where a tab keeps the line shown while nothing in particular is hovered
const DEFAULT_DESCRIPTION_META := &"ui_default_description"

## Drawn once and shared by every slider. The default theme grabber is a small
## grey circle that vanishes against this menu
static var _grabber_normal: ImageTexture = null
static var _grabber_hover: ImageTexture = null


## Turns whatever a row handed over into the line the menu prints. A dropdown
## describes one entry of its list, so its Callable takes the index the pointer
## is on, and -1 for "whatever is set right now". Everything else only ever
## describes itself
static func resolve_description(control: Control, source: Variant, index: int) -> String:
	if not (source is Callable):
		return String(source)

	var callable: Callable = source
	return String(callable.call(index) if control is OptionButton else callable.call())


## Hangs a description on a control and on everything interactive inside it, so
## a row that wraps its slider in a box still answers as one thing
static func describe(node: Node, source: Variant) -> void:
	if node is Range or node is BaseButton:
		node.set_meta(DESCRIPTION_META, source)

	for child in node.get_children():
		describe(child, source)


## A label on the left and whatever control the setting needs on the right
static func make_row(text: String, control: Control, description: Variant = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var stretches := not (control is NeonSwitch)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stretches else Control.SIZE_SHRINK_BEGIN
	row.add_child(control)

	if not (description is String and String(description).is_empty()):
		describe(control, description)

	return row


## Section title, sits above a group of rows
static func make_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.129, 0.855, 1, 1))
	return label


static func make_separator() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	return spacer


static func make_dropdown(entries: Array, selected: int) -> OptionButton:
	var dropdown := OptionButton.new()
	dropdown.fit_to_longest_item = false
	dropdown.clip_text = true
	refill_dropdown(dropdown, entries, selected)
	return dropdown


## Fills a dropdown again without firing item_selected, used when the monitor
## changed and the list behind it is a different one now
static func refill_dropdown(dropdown: OptionButton, entries: Array, selected: int) -> void:
	dropdown.clear()
	for entry in entries:
		dropdown.add_item(str(entry))

	if selected >= 0 and selected < dropdown.item_count:
		dropdown.select(selected)


static func make_toggle(pressed: bool) -> NeonSwitch:
	var toggle := NeonSwitch.new()
	toggle.custom_minimum_size = NeonSwitch.TRACK_SIZE
	toggle.set_pressed_no_signal(pressed)
	return toggle


static func make_slider(min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(260, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.add_theme_icon_override(&"grabber", _grabber(false))
	slider.add_theme_icon_override(&"grabber_highlight", _grabber(true))
	return slider


## The number to the right of a slider, fixed width so it does not shove the
## slider around while it counts
static func make_readout(text: String) -> Label:
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(84, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	readout.text = text
	return readout


## A slider and its readout side by side, ready to be dropped into make_row
static func make_slider_box(slider: HSlider, readout: Label) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(slider)
	box.add_child(readout)
	return box


static func _grabber(highlight: bool) -> ImageTexture:
	if highlight and _grabber_hover != null:
		return _grabber_hover

	if not highlight and _grabber_normal != null:
		return _grabber_normal

	var texture := _build_grabber(highlight)
	if highlight:
		_grabber_hover = texture
	else:
		_grabber_normal = texture

	return texture


## An upright capsule with a brighter core, drawn straight into an image so the
## menu needs no extra art files. The hovered one is wider and brighter, that is
## the whole point of it existing
static func _build_grabber(highlight: bool) -> ImageTexture:
	var box := Vector2(22.0, 34.0) if highlight else Vector2(18.0, 30.0)
	var radius := box.x * 0.5
	var body := Color(0.42, 0.9, 1.0) if highlight else Color(0.3, 0.62, 0.76)
	var core := Color(1, 1, 1)
	var core_mix := 0.75 if highlight else 0.45

	var image := Image.create_empty(int(box.x), int(box.y), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var point := Vector2(x + 0.5, y + 0.5)
			var alpha := clampf(0.5 - _rounded_distance(point, box, radius), 0.0, 1.0)
			if alpha <= 0.0:
				continue

			var middle := 1.0 - clampf(absf(point.x - box.x * 0.5) / radius, 0.0, 1.0)
			image.set_pixel(x, y, Color(body.lerp(core, middle * core_mix), alpha))

	return ImageTexture.create_from_image(image)


## Signed distance to a rounded box, negative inside. Gives the capsule a clean
## edge without having to render a polygon
static func _rounded_distance(point: Vector2, box: Vector2, radius: float) -> float:
	var q := (point - box * 0.5).abs() - (box * 0.5 - Vector2(radius, radius))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
