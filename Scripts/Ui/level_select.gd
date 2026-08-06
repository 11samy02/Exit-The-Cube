class_name LevelSelect
extends Control

## The campaign to pick from. One level stands in the middle with its numbers,
## its neighbors wait to the left and the right, and the whole campaign runs
## along the bottom as a strip of pips: where the player is, how far it goes,
## and one click to anywhere in it

## Emitted after the panel closed itself, the screen underneath takes its focus
## back with it
signal closed

## Emitted with the level the player picked, the title screen opens the campaign
## at it
signal level_picked(index: int)

## How much of the campaign this panel is allowed to offer. -1 leaves it to the
## slot that is being played, which is what the title screen wants
var open_picks: int = -1
var open_levels: int = -1

## Size of one pip in the campaign strip
const PIP_SIZE := Vector2(20, 20)

## How wide the strip may get. A long campaign gets narrower pips instead of a
## panel that grows out of the screen
const STRIP_MAX_WIDTH := 900.0

## How far the shoulder buttons jump through the campaign at once
const PAGE_STEP := 5

## The middle card's border while the deck is what sideways steers, and while it
## is not. The panel has two rows to steer and only one of them listens to
## sideways at a time, so the one that does has to be the one that stands out
const CARD_BORDER_ACTIVE := 5
const CARD_BORDER_IDLE := 2

## How far the middle card's border falls back once the buttons have the focus
const CARD_IDLE_DIM := 0.5

@export_group("Input")

## How far a stick has to be pushed before it counts as a step. A single event
## per push reads badly on an analog stick: it fires on the way across the
## deadzone and never again while it is held, so the stick is read every frame
## here instead and repeats on its own
@export_range(0.2, 0.95) var stick_threshold: float = 0.55

## Seconds a direction has to be held before it starts repeating
@export var repeat_delay: float = 0.42

## Seconds between two steps while it stays held
@export var repeat_rate: float = 0.14

@export_group("Motion")

## How far off the panel the deck goes on its way out. Far enough that the
## cards are clear of the middle when they are swapped
@export var slide_distance: float = 260.0

## Seconds one swipe takes, out and back in together
@export var slide_duration: float = 0.3

## Every level gets its own hue so stepping through them reads as movement and
## not as the same card with another number on it
@export_range(0.0, 0.5) var hue_step: float = 0.09
@export_range(0.0, 1.0) var hue_start: float = 0.52
@export_range(0.0, 1.0) var hue_saturation: float = 0.45

## The level the campaign stands on, the one a continue would open
@export var next_color: Color = Color(0.35, 0.95, 1.0)

## A level of the campaign that is still locked away
@export var locked_color: Color = Color(0.28, 0.24, 0.4)

## Shown wherever a level was never finished and has no number to give
@export var no_record: String = "—"

@onready var _carousel: HBoxContainer = %Carousel
@onready var _main_card: PanelContainer = %MainCard
@onready var _number: Label = %Number
@onready var _level_name: Label = %LevelName
@onready var _state_value: Label = %StateValue
@onready var _previous_card: Button = %PreviousCard
@onready var _previous_number: Label = %PreviousNumber
@onready var _previous_name: Label = %PreviousName
@onready var _next_card: Button = %NextCard
@onready var _next_number: Label = %NextNumber
@onready var _next_name: Label = %NextName
@onready var _time_value: Label = %TimeValue
@onready var _death_value: Label = %DeathValue
@onready var _progress_value: Label = %ProgressValue
@onready var _strip: HBoxContainer = %Strip
@onready var _play_button: Button = %PlayButton
@onready var _back_button: Button = %BackButton

## The levels this panel lists, by their place in the campaign. The tutorials
## are not among them, so a slot in here and a level of the campaign are two
## different numbers and are kept apart everywhere below
var _picks: Array[int] = []

## Which of the listed levels is on screen right now, a slot in _picks
var _slot: int = 0

## One pip per listed level, in order
var _pips: Array[Button] = []

## Which way a stick or a key is being held, 0 while nothing is
var _held: int = 0

## Seconds until the held direction steps again
var _repeat_timer: float = 0.0

var _slide: Tween = null


func _ready() -> void:
	visible = false
	_carousel.offset_transform_enabled = true
	_carousel.offset_transform_visual_only = true
	_number.label_settings = _number.label_settings.duplicate()
	_state_value.label_settings = _state_value.label_settings.duplicate()
	_main_card.add_theme_stylebox_override("panel", _main_card.get_theme_stylebox("panel").duplicate())

	_previous_card.pressed.connect(_step.bind(-1))
	_next_card.pressed.connect(_step.bind(1))
	_play_button.pressed.connect(_on_play_pressed)
	_back_button.pressed.connect(close)
	_main_card.focus_entered.connect(_on_card_focused)
	_main_card.focus_exited.connect(_on_card_unfocused)
	_wire_focus()

	UiFeedback.attach_all(self)
	UiFeedback.use_back_sound(_back_button)


## The panel is two rows: the deck, and Play with Back below it. Up and down are
## what crosses between them, sideways stays inside the row that holds the focus
## — it steps through the campaign on the deck and walks from Play to Back on the
## buttons, which is where the two of them sit. The middle card takes the focus
## for the deck so that there is something to hold it, the two cards beside it
## are step buttons and not stops of their own and stay out of the walk
func _wire_focus() -> void:
	_previous_card.focus_mode = Control.FOCUS_NONE
	_next_card.focus_mode = Control.FOCUS_NONE
	_main_card.focus_mode = Control.FOCUS_ALL

	var to_card := _play_button.get_path_to(_main_card)
	var to_play := _main_card.get_path_to(_play_button)
	var to_back := _main_card.get_path_to(_back_button)

	_main_card.focus_neighbor_bottom = to_play
	_main_card.focus_neighbor_top = to_play
	_main_card.focus_next = to_play
	_main_card.focus_previous = to_back

	_play_button.focus_neighbor_right = _play_button.get_path_to(_back_button)
	_play_button.focus_neighbor_left = _play_button.get_path_to(_back_button)
	_play_button.focus_neighbor_top = to_card
	_play_button.focus_neighbor_bottom = to_card
	_play_button.focus_next = _play_button.get_path_to(_back_button)
	_play_button.focus_previous = to_card

	_back_button.focus_neighbor_left = _back_button.get_path_to(_play_button)
	_back_button.focus_neighbor_right = _back_button.get_path_to(_play_button)
	_back_button.focus_neighbor_top = _back_button.get_path_to(_main_card)
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(_main_card)
	_back_button.focus_next = _back_button.get_path_to(_main_card)
	_back_button.focus_previous = _back_button.get_path_to(_play_button)


## While the deck holds the focus sideways is swallowed here so the menu does not
## walk its focus with it, but it is not acted on: holding a direction has to
## repeat, and an event only fires once. That part is read off the input state in
## _process instead. On the buttons sideways is left alone and walks from Play to
## Back like it looks like it should.
##
## The wheel and the shoulder buttons are single events and are handled here
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action("ui_left") or event.is_action("ui_right"):
		if _main_card.has_focus():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept") and _main_card.has_focus():
		get_viewport().set_input_as_handled()
		UiFeedback.play_click()
		_on_play_pressed()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_page_up"):
		get_viewport().set_input_as_handled()
		_step(-PAGE_STEP)
	elif event.is_action_pressed("ui_page_down"):
		get_viewport().set_input_as_handled()
		_step(PAGE_STEP)
	elif event is InputEventMouseButton and event.pressed:
		_on_wheel(event as InputEventMouseButton)


func _on_wheel(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		get_viewport().set_input_as_handled()
		_step(-1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		get_viewport().set_input_as_handled()
		_step(1)


## The stick, the arrow keys and the cube's own left and right, all read the
## same way: one step when the direction is taken, then a repeat while it is
## held. A stick that only fired on its way over the deadzone would sometimes
## step twice on the same push and sometimes not at all.
##
## Only the deck steps, the buttons below it walk their own focus with sideways.
## A click anywhere on the panel that is not a control drops the focus, and a
## panel with no focus on it answers to no direction at all, so the deck takes it
## back whenever it went nowhere
func _process(delta: float) -> void:
	if not visible:
		return

	if not _main_card.has_focus():
		_held = 0
		_repeat_timer = 0.0
		if get_viewport().gui_get_focus_owner() == null:
			_main_card.grab_focus()
		return

	var direction := _pressed_direction()

	if direction == 0:
		_held = 0
		_repeat_timer = 0.0
		return

	if direction != _held:
		_held = direction
		_repeat_timer = repeat_delay
		_step(direction)
		return

	_repeat_timer -= delta
	if _repeat_timer <= 0.0:
		_repeat_timer = repeat_rate
		_step(direction)


## Whichever of the two ways to say sideways is pushed hardest
func _pressed_direction() -> int:
	var strength := Input.get_axis("ui_left", "ui_right")

	if InputMap.has_action("move_left") and InputMap.has_action("move_right"):
		var bound := Input.get_axis("move_left", "move_right")
		if absf(bound) > absf(strength):
			strength = bound

	if absf(strength) < stick_threshold:
		return 0

	return 1 if strength > 0.0 else -1


## Opens on the level the campaign stands at, that is the one being looked for
func open() -> void:
	_picks = Levels.selectable()
	_slot = clampi(_slot_of(SaveGame.level_index), 0, maxi(_open_count() - 1, 0))
	_held = 0
	_repeat_timer = 0.0
	_carousel.offset_transform_position = Vector2.ZERO
	_carousel.modulate = Color.WHITE

	_build_strip()
	_show_level()
	visible = true
	_main_card.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


## How many of the listed levels are open. They unlock from the front of the
## campaign, so the open ones are always the first slots
func _open_count() -> int:
	return mini(_picks_open(), _picks.size())


## How many of the listed levels this panel may open, and how far up the
## campaign that reaches. Left to the slot being played unless whoever opened
## the panel said otherwise — the seat select does, because a room is allowed
## everything either slot has already cleared
func _picks_open() -> int:
	return SaveGame.unlocked_picks() if open_picks < 0 else open_picks


func _levels_open() -> int:
	return SaveGame.unlocked_levels() if open_levels < 0 else open_levels


## The slot that level of the campaign is listed at. A campaign standing on a
## tutorial has no card of its own, the panel opens on the level after it
func _slot_of(level: int) -> int:
	for slot in range(_picks.size()):
		if _picks[slot] >= level:
			return slot

	return maxi(_picks.size() - 1, 0)


## Steps through the listed levels and wraps around at both ends, so a player at
## the far end is one press away from the first one again
func _step(direction: int) -> void:
	var open := _open_count()
	if open <= 1:
		return

	_slot = wrapi(_slot + direction, 0, open)
	_swipe(direction)
	UiFeedback.play_hover()


## The deck leaves the way the player is going, the cards are rebuilt while it
## is off the panel, and it comes back in from the other side. Moving the deck
## with the new cards already on it would only read as a shake, the swap has to
## happen where it cannot be seen
func _swipe(direction: int) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
		_carousel.offset_transform_position = Vector2.ZERO
		_carousel.modulate = Color.WHITE

	var leaving := Vector2(-signf(direction) * slide_distance, 0.0)
	var arriving := Vector2(signf(direction) * slide_distance, 0.0)
	var out_time := slide_duration * 0.4
	var in_time := slide_duration * 0.6

	_slide = create_tween()
	_slide.set_trans(Tween.TRANS_CUBIC)

	_slide.set_parallel(true)
	_slide.set_ease(Tween.EASE_IN)
	_slide.tween_property(_carousel, "offset_transform_position", leaving, out_time)
	_slide.tween_property(_carousel, "modulate:a", 0.0, out_time)

	_slide.chain().tween_callback(_show_level)

	_slide.set_parallel(true)
	_slide.set_ease(Tween.EASE_OUT)
	_slide.tween_property(_carousel, "offset_transform_position", Vector2.ZERO, in_time).from(arriving)
	_slide.tween_property(_carousel, "modulate:a", 1.0, in_time).from(0.0)


## One pip per listed level, not only the open ones: the locked ones are what is
## still ahead, and that is worth seeing
func _build_strip() -> void:
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()

	_pips.clear()
	var pip_size := _pip_size(_picks.size())

	for slot in range(_picks.size()):
		var level: int = _picks[slot]
		var pip := Button.new()
		pip.custom_minimum_size = pip_size
		pip.focus_mode = Control.FOCUS_NONE
		pip.tooltip_text = "%02d  %s" % [slot + 1, Levels.title_of(level)]
		pip.disabled = level >= _levels_open()
		pip.pressed.connect(_jump_to.bind(slot))
		_strip.add_child(pip)
		_pips.append(pip)


## How big one pip may be so that all of them together still fit the strip
func _pip_size(count: int) -> Vector2:
	if count < 2:
		return PIP_SIZE

	var separation := float(_strip.get_theme_constant(&"separation"))
	var room := (STRIP_MAX_WIDTH - (count - 1) * separation) / count
	return Vector2(clampf(room, 6.0, PIP_SIZE.x), PIP_SIZE.y)


func _jump_to(slot: int) -> void:
	var direction := signi(slot - _slot)
	if direction == 0:
		return

	_slot = slot
	_swipe(direction)


## Everything on the panel comes from one place, so a step only has to call this
func _show_level() -> void:
	var level := _level_on_screen()
	var accent := _accent_of(_slot)

	_number.text = "%02d" % (_slot + 1)
	_number.label_settings.font_color = accent
	_level_name.text = Levels.title_of(level)
	_paint_card(accent)

	_state_value.text = "NEXT UP" if _is_next(level) else "CLEARED"
	_state_value.label_settings.font_color = next_color if _is_next(level) else accent

	_show_neighbours(_open_count())
	_show_record(level)
	_paint_strip()

	_progress_value.text = "%d / %d" % [_open_count(), _picks.size()]


## The level of the campaign the middle card stands on
func _level_on_screen() -> int:
	if _picks.is_empty():
		return 0

	return _picks[clampi(_slot, 0, _picks.size() - 1)]


## The two cards beside the middle one are the step buttons as well, so what
## they do is written on them. With a single level open they have nowhere to go
func _show_neighbours(open: int) -> void:
	var enabled := open > 1
	_previous_card.disabled = not enabled
	_next_card.disabled = not enabled

	var behind := wrapi(_slot - 1, 0, maxi(open, 1))
	var ahead := wrapi(_slot + 1, 0, maxi(open, 1))

	_previous_number.text = "%02d" % (behind + 1) if enabled else ""
	_previous_name.text = Levels.title_of(_picks[behind]) if enabled else ""
	_next_number.text = "%02d" % (ahead + 1) if enabled else ""
	_next_name.text = Levels.title_of(_picks[ahead]) if enabled else ""


## A level that was cleared before the game started keeping records has none,
## and neither has the one the campaign stands on. Both say so instead of
## showing a zero that would read as a perfect run
func _show_record(level: int) -> void:
	var record := SaveGame.record_of(level)
	if record.is_empty():
		_time_value.text = no_record
		_death_value.text = no_record
		return

	_time_value.text = _format_time(float(record.get("time", 0.0)))
	_death_value.text = "%d" % int(record.get("deaths", 0))


## The strip says three things at a glance: what is done, where the player
## stands and how much of the campaign is still dark
func _paint_strip() -> void:
	for slot in range(_pips.size()):
		var level: int = _picks[slot]
		var color := locked_color

		if slot == _slot:
			color = Color.WHITE
		elif _is_next(level):
			color = next_color
		elif level < SaveGame.level_index:
			color = _accent_of(slot) * 0.75

		_style_pip(_pips[slot], color, slot == _slot)


func _style_pip(pip: Button, color: Color, is_current: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_right = 4
	box.corner_radius_bottom_left = 4

	if is_current:
		box.expand_margin_top = 5.0
		box.expand_margin_bottom = 5.0

	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		pip.add_theme_stylebox_override(state, box)


## The middle card carries the focus for the whole deck, and a card that is only
## ever bright says nothing about whether sideways would step it or walk the
## buttons. So it burns in its own hue while it is the row being steered and
## falls back to a thin dim border once the buttons have taken over
func _paint_card(accent: Color) -> void:
	var box := _main_card.get_theme_stylebox("panel") as StyleBoxFlat
	var active := _main_card.has_focus()
	var width := CARD_BORDER_ACTIVE if active else CARD_BORDER_IDLE

	box.border_color = accent if active else accent.darkened(CARD_IDLE_DIM)
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width


## The card is no button and gets none of the wiring the rest of the panel has,
## so the sound that answers a focus landing anywhere else is given here
func _on_card_focused() -> void:
	_paint_card(_accent_of(_slot))
	UiFeedback.play_hover()


func _on_card_unfocused() -> void:
	_paint_card(_accent_of(_slot))


## Its own hue per card, walked around the wheel so neighbours never share one
func _accent_of(slot: int) -> Color:
	return Color.from_hsv(fmod(hue_start + slot * hue_step, 1.0), hue_saturation, 1.0)


## True for the level a continue would open, the front of the campaign
func _is_next(index: int) -> bool:
	return index == SaveGame.level_index


func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%d:%05.2f" % [minutes, seconds - minutes * 60]


func _on_play_pressed() -> void:
	if _picks.is_empty():
		return

	visible = false
	level_picked.emit(_level_on_screen())
