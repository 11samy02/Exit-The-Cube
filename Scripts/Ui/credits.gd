class_name CreditsScreen
extends Control

## Who made this and what it was made of. A panel over the title screen like the
## options are, one row per entry, and the honest bug report at the bottom

## Emitted after the panel closed itself, the screen underneath takes its focus
## back with it
signal closed

## The rows of the panel, in the order they come up. Left is what the entry is
## for, right is who or what it was.
##
## Short on purpose. Nothing the game is built from asks to be named here: the
## icons are CC0, the fonts only want their license file shipped alongside them
## and it is, the sound packs are royalty free, and the engine carries its own
## notice inside the binary. Where every asset came from is written down beside
## it in the SOURCES.md files, which is the place that has to be right
const ENTRIES := [
	["GAME, CODE & DESIGN", "Samy Abuaisheh"],
	["ENGINE", "Godot Engine 4.7"],
]

## How wide the left column is. Every entry is read as a pair, so the values
## have to start on the same pixel or the panel reads as a heap of text
const KEY_WIDTH := 380.0

## A credit row is read once and from a distance, the menu default is set for
## rows that are pointed at instead
const ROW_FONT_SIZE := 25

## Seconds between two rows arriving
@export var row_delay: float = 0.07

## Seconds one row takes to come in
@export var row_duration: float = 0.3

## How far a row comes in from the left
@export var row_slide: float = 40.0

@onready var _list: VBoxContainer = %List
@onready var _back_button: Button = %BackButton

## Every row that was built, in the order the intro walks them
var _rows: Array[Control] = []

## The arrival of the rows, killed when the panel is closed while it still runs
var _intro: Tween = null


func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)
	_back_button.pressed.connect(close)

	_build_rows()
	UiFeedback.attach_all(self)
	UiFeedback.use_back_sound(_back_button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UiFeedback.play_back()
		close()


func open() -> void:
	visible = true
	set_process_unhandled_input(true)
	_back_button.grab_focus()
	_play_intro()


func close() -> void:
	if not visible:
		return

	if _intro != null and _intro.is_valid():
		_intro.kill()

	_intro = null
	visible = false
	set_process_unhandled_input(false)
	closed.emit()


## One row per entry. Built in code because the rows are all the same shape and
## a scene full of copies of it would only be another place to keep the list in
## step with itself
func _build_rows() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	_rows.clear()

	for entry in ENTRIES:
		_rows.append(_build_row(String(entry[0]), String(entry[1]), Color.WHITE))


## A row is the pair it shows: the key right aligned against the column, the
## value left aligned off it
func _build_row(key: String, value: String, tint: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var key_label := Label.new()
	key_label.text = key
	key_label.custom_minimum_size = Vector2(KEY_WIDTH, 0)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.add_theme_color_override(&"font_color", Color(0.52, 0.48, 0.68))
	key_label.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
	row.add_child(key_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_color_override(&"font_color", tint)
	value_label.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
	row.add_child(value_label)

	row.offset_transform_enabled = true
	row.offset_transform_visual_only = true
	_list.add_child(row)
	return row


## The rows walk in one after the other instead of the whole block appearing at
## once, the same way the title screen brings its buttons up
func _play_intro() -> void:
	if _intro != null and _intro.is_valid():
		_intro.kill()

	for row in _rows:
		row.modulate = Color(1, 1, 1, 0)
		row.offset_transform_position = Vector2(-row_slide, 0)

	_intro = create_tween()
	_intro.set_parallel(true)

	for index in _rows.size():
		var row: Control = _rows[index]
		var at := index * row_delay
		_intro.tween_property(row, "modulate", Color(1, 1, 1, 1), row_duration).set_delay(at)
		_intro.tween_property(row, "offset_transform_position", Vector2.ZERO, row_duration) \
			.set_delay(at).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
