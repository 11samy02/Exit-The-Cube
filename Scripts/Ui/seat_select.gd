extends Control
class_name SeatSelect

## Where the room is filled before anything is played on one screen.
##
## Four cards, one per seat, and every one of them is claimed by the device that
## claims it — press A on a pad and that pad has the seat, press Enter and the
## keyboard does. Nothing here can be done with the mouse on purpose: the whole
## point of the screen is to find out which hands are on which device, and a
## pointer would answer that for everybody at once.
##
## It runs before the seats are locked, so it cannot use the per seat actions
## either. Every press is read raw and sorted by the device it came from

## What comes after this screen, handed over by whoever opened it
enum Mode { CAMPAIGN, PARTY }

const CAMPAIGN_SCENE := "res://Scenes/Enviroment/map.tscn"
const PARTY_SCENE := "res://Scenes/Ui/party_setup.tscn"
const TITLE_SCENE := "res://Scenes/Ui/title_screen.tscn"
const LEVEL_SELECT_SCENE := "res://Scenes/Ui/level_select.tscn"

## How wide one seat card is. Four of them and the gaps between still fit a
## sixteen by nine window with room to spare
const CARD_WIDTH := 300.0
const CARD_HEIGHT := 330.0

## Seconds the pad buzzes when it takes a seat. Long enough to feel across the
## room, short enough not to be a rumble
const CLAIM_BUZZ := 0.25

## How big a button glyph is drawn in the prompt bar
const GLYPH_SIZE := 34.0

## What an empty seat is drawn in. Grey rather than the seat's own colour, so
## the four colours on screen are exactly the players who are actually there
const EMPTY_TINT := Color(0.35, 0.33, 0.42)

@onready var _layout: VBoxContainer = %Layout

## Which of the two things this screen is filling seats for
static var next_mode: int = Mode.CAMPAIGN

## Where the campaign should pick up, -1 for a fresh run
static var next_level: int = -1

var _cards: Array[PanelContainer] = []
var _start_note: Label = null
var _prompts: HBoxContainer = null
var _leaving: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Seats.clear()

	add_child(OnlineUi.background())
	move_child(get_child(get_child_count() - 1), 0)

	_build()
	Seats.seats_changed.connect(_refresh)
	InputIcons.device_changed.connect(_on_device_changed)
	Input.joy_connection_changed.connect(_on_joy_changed)
	_refresh()


## Raw device reading, because the per seat actions do not exist yet and the
## whole question this screen asks is which device a press came from
func _input(event: InputEvent) -> void:
	if _leaving:
		return

	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				_join_pad(event.device)
			JOY_BUTTON_B:
				_leave_device(event.device)
			JOY_BUTTON_START:
				_confirm()

		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_join_keyboard()
			KEY_ENTER, KEY_KP_ENTER:
				_confirm()
			KEY_ESCAPE:
				_leave_keyboard()

		get_viewport().set_input_as_handled()


func _join_pad(device: int) -> void:
	var at := Seats.claim_pad(device)
	if at < 0:
		return

	UiFeedback.play_click()
	Input.start_joy_vibration(device, 0.0, 0.6, CLAIM_BUZZ)


func _join_keyboard() -> void:
	if Seats.claim_keyboard() >= 0:
		UiFeedback.play_click()


## A pad that presses B gives up its own seat, and only its own. The player who
## wants out is the one holding the pad that says so
func _leave_device(device: int) -> void:
	var at := Seats.seat_of_device(device)

	if at < 0:
		_back()
		return

	UiFeedback.play_back()
	Seats.release(at)


func _leave_keyboard() -> void:
	var at := Seats.seat_of_keyboard()

	if at < 0:
		_back()
		return

	UiFeedback.play_back()
	Seats.release(at)


func _build() -> void:
	_layout.add_child(OnlineUi.screen_title("WHO IS PLAYING"))
	_layout.add_child(OnlineUi.body(
		"one seat each  ·  up to four  ·  one of them may be the keyboard", 22, OnlineUi.MUTED))
	_layout.add_child(OnlineUi.gap(28.0))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	_layout.add_child(row)

	for at in range(Seats.MAX_SEATS):
		var card := _build_card(at)
		_cards.append(card)
		row.add_child(card)

	_layout.add_child(OnlineUi.gap(30.0))

	_start_note = OnlineUi.body("", 24, OnlineUi.WAITING)
	_start_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout.add_child(_start_note)

	_layout.add_child(OnlineUi.gap(14.0))

	_prompts = HBoxContainer.new()
	_prompts.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompts.add_theme_constant_override("separation", 34)
	_layout.add_child(_prompts)


## One seat, empty until somebody takes it. Everything inside is rebuilt rather
## than juggled, four labels is nothing next to keeping two states in step
func _build_card(at: int) -> PanelContainer:
	var card := OnlineUi.panel(EMPTY_TINT, 0.35)
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)

	return card


## A taken seat is drawn in its own colour, thick bordered and lit from inside;
## an empty one is a grey outline. The two used to differ only by how dark the
## fill was, which on a bright screen is no difference at all
func _card_style(tint: Color, taken: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.14) if taken \
		else Color(0.055, 0.047, 0.09, 0.35)
	style.border_color = Color(tint.r, tint.g, tint.b, 1.0 if taken else 0.35)
	style.set_border_width_all(5 if taken else 2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)

	if taken:
		style.shadow_color = Color(tint.r, tint.g, tint.b, 0.35)
		style.shadow_size = 14

	return style


func _refresh() -> void:
	for at in range(_cards.size()):
		_fill_card(at)

	_start_note.text = _start_line()
	_show_prompts()


## The bar along the bottom, which is the only place that says how to get out of
## this screen. It is built out of the real glyphs rather than the words A and
## START, because what is printed on the button in somebody's hands depends on
## whose pad it is
func _show_prompts() -> void:
	for child in _prompts.get_children():
		child.queue_free()

	var ready := Seats.count() > 0

	if ready:
		_prompts.add_child(_prompt(JOY_BUTTON_START, KEY_ENTER, "START", OnlineUi.READY))

	_prompts.add_child(_prompt(JOY_BUTTON_A, KEY_SPACE, "JOIN", \
		OnlineUi.ACCENT if not ready else OnlineUi.MUTED))
	_prompts.add_child(_prompt(JOY_BUTTON_B, KEY_ESCAPE, \
		"LEAVE" if ready else "BACK", OnlineUi.MUTED))


## One prompt: the pad button, the key that does the same, and what it does
func _prompt(button: int, key: int, text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var press := InputEventJoypadButton.new()
	press.button_index = button
	_add_glyph(row, InputIcons.get_event_texture(press), _button_name(button))

	var typed := InputEventKey.new()
	typed.keycode = key
	_add_glyph(row, InputIcons.get_event_texture(typed), OS.get_keycode_string(key))

	var label := OnlineUi.heading(text, 22, color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	return row


## The glyph if there is one for this device, and the name of the button if
## there is not. A prompt nobody can read is worse than a plain word
func _add_glyph(row: HBoxContainer, texture: Texture2D, fallback: String) -> void:
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(GLYPH_SIZE, GLYPH_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		return

	var text := OnlineUi.body(fallback, 20, OnlineUi.TEXT)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text)


func _button_name(button: int) -> String:
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"

	return "START"


func _fill_card(at: int) -> void:
	var card := _cards[at]
	var column := card.get_node("Column") as VBoxContainer

	for child in column.get_children():
		child.queue_free()

	var seat := Seats.seat_at(at)
	var tint := Seats.color_of(at) if seat != null else EMPTY_TINT
	card.add_theme_stylebox_override("panel", _card_style(tint, seat != null))
	card.modulate = Color(1, 1, 1, 1) if seat != null else Color(1, 1, 1, 0.55)

	var number := OnlineUi.heading("P%d" % (at + 1), 46, tint)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(number)

	if seat == null:
		var press := InputEventJoypadButton.new()
		press.button_index = JOY_BUTTON_A
		var glyph := InputIcons.get_event_texture(press)

		if glyph != null:
			var icon := TextureRect.new()
			icon.texture = glyph
			icon.custom_minimum_size = Vector2(52, 52)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			column.add_child(icon)

		var empty := OnlineUi.body("EMPTY", 22, EMPTY_TINT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(empty)

		var how := OnlineUi.body("A on a pad\nSPACE on the keyboard", 18, OnlineUi.MUTED)
		how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(how)
		return

	var ready := OnlineUi.heading("READY", 22, OnlineUi.READY)
	ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(ready)

	var glyph := _glyph_for(seat)
	if glyph != null:
		var icon := TextureRect.new()
		icon.texture = glyph
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		column.add_child(icon)

	var device := OnlineUi.body(_device_line(seat), 20, OnlineUi.TEXT)
	device.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	device.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(device)

	var leave := OnlineUi.body("B to leave" if seat.source == Seats.Source.PAD \
		else "ESC to leave", 18, OnlineUi.MUTED)
	leave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(leave)


## The face button of that seat's own pad, in that pad's own brand. Two players
## on two different makes of controller see two different glyphs, which is the
## whole reason the brand is tracked per device
func _glyph_for(seat: SeatTable.Seat) -> Texture2D:
	if seat.source == Seats.Source.KEYBOARD:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		return InputIcons.get_event_texture(key)

	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	return InputIcons.get_event_texture(press, InputIcons.brand_of_device(seat.device))


func _device_line(seat: SeatTable.Seat) -> String:
	if seat.source == Seats.Source.KEYBOARD:
		return "Keyboard & Mouse"

	var reported := InputIcons.name_of_device(seat.device)
	return reported if not reported.is_empty() else "Pad %d" % seat.device


func _start_line() -> String:
	if Seats.count() == 0:
		return "nobody has sat down yet"

	if Seats.count() == 1:
		return "1 player ready"

	return "%d players ready" % Seats.count()


## Freezes the room, builds the per seat copies of every action, and hands over
## to whatever this screen was opened for
func _confirm() -> void:
	if _leaving or Seats.count() == 0:
		return

	_leaving = true
	Seats.lock()
	UiFeedback.play_click()

	if next_mode == Mode.PARTY:
		Transition.change_scene(PARTY_SCENE)
		return

	SaveGame.use_slot(SaveGame.Slot.COOP)
	Match.start_campaign(Seats.accounts())
	Levels.start(next_level if next_level >= 0 else 0)
	GameState.start_run()
	Transition.change_scene(CAMPAIGN_SCENE)


func _back() -> void:
	if _leaving:
		return

	_leaving = true
	Seats.clear()
	UiFeedback.play_back()
	Transition.change_scene(TITLE_SCENE)


func _on_device_changed(_device: int) -> void:
	_refresh()


func _on_joy_changed(_device: int, _connected: bool) -> void:
	_refresh()
