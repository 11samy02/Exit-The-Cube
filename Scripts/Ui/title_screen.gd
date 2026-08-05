extends Control

## The first thing the game shows. Start drops straight into the generated map,
## options opens the panel over the top of this screen

const LEVEL_SCENE := "res://Scenes/Enviroment/map.tscn"

const ONLINE_SCENE := "res://Scenes/Ui/online_menu.tscn"

const SEAT_SELECT_SCENE := "res://Scenes/Ui/seat_select.tscn"

const START_SOUND := preload("res://Assets/Sounds/UI & Menus/Start.wav")

## Seconds one breath of the title glow takes
@export var pulse_duration: float = 2.4

## Seconds the title needs to be typed out letter by letter
@export var type_duration: float = 0.75

## How far under their row the buttons start before they rise into it
@export var slide_distance: float = 26.0

## Seconds the screen takes to come up out of the black the splash handed over
## in. The splash goes down to black over its own load, this is the other half
## of that cut and it runs under the intro
@export var boot_fade: float = 0.45

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _continue_button: Button = %ContinueButton
@onready var _levels_button: Button = %LevelsButton
@onready var _level_select: LevelSelect = %LevelSelect
@onready var _start_button: Button = %StartButton
@onready var _coop_button: Button = %CoopButton
@onready var _party_button: Button = %PartyButton
@onready var _online_button: Button = %OnlineButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _credits_button: Button = %CreditsButton
@onready var _options_menu: OptionsMenu = %OptionsMenu
@onready var _credits: CreditsScreen = %Credits
@onready var _boot: ColorRect = %Boot
@onready var _content: Control = %Column
@onready var _modes_header: Control = %ModesHeader

var _sfx: AudioStreamPlayer

## The buttons that are actually on screen, in the order the intro slides them
## in. Continue is only in here while there is a campaign to pick up
var _buttons: Array[Control] = []

## The opening sequence, kept around so a keypress can cut it short
var _intro: Tween = null

## True from the moment start was pressed, a second press must not fire another
## scene change into the one that is already running
var _starting: bool = false


## Standing on the title screen means being in no lobby. A race left through the
## pause menu would otherwise leave this machine sitting in one, taking a seat
## the rest of the room can see and nobody is in
func _ready() -> void:
	if Online.in_lobby():
		Online.leave_lobby()

	Seats.clear()
	Match.stop()
	SaveGame.use_slot(SaveGame.Slot.SOLO)

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"sfx"
	add_child(_sfx)

	_build_menu()
	_continue_button.pressed.connect(_on_continue_pressed)
	_levels_button.pressed.connect(_on_levels_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_coop_button.pressed.connect(_on_coop_pressed)
	_party_button.pressed.connect(_on_party_pressed)
	_online_button.pressed.connect(_on_online_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_options_menu.closed.connect(_on_options_closed)
	_credits.closed.connect(_on_credits_closed)
	_level_select.closed.connect(_on_level_select_closed)
	_level_select.level_picked.connect(_on_level_picked)

	UiFeedback.attach_all(self)
	UiFeedback.use_back_sound(_quit_button)
	_play_intro()


## Continue only stands there while a campaign was left half played. With it up
## the first button is no longer the one that starts over, so that one says what
## it does instead of just Start, and the wide accented look moves up to it. On a
## fresh install Start is the top of the menu and wears that look itself
func _build_menu() -> void:
	_continue_button.visible = SaveGame.has_save()
	_levels_button.visible = SaveGame.unlocked_picks() > 0
	_start_button.text = "NEW GAME" if _continue_button.visible else "START"
	_start_button.theme_type_variation = &"" if _continue_button.visible else &"MenuPrimary"
	_start_button.custom_minimum_size.y = 56.0 if _continue_button.visible else 64.0

	_buttons = [_start_button]
	if _levels_button.visible:
		_buttons.append(_levels_button)
	if _continue_button.visible:
		_buttons.push_front(_continue_button)

	_buttons.append_array([
		_coop_button, _party_button, _online_button,
		_options_button, _credits_button, _quit_button,
	])


## Nobody wants to sit through the same opening on the third restart, so any
## input drops it on the last frame instead of skipping to a half built screen
func _unhandled_input(event: InputEvent) -> void:
	if _intro == null or not _intro.is_valid():
		return

	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		if event.is_pressed():
			_finish_intro()
			get_viewport().set_input_as_handled()


## The title switches itself on like an old tube: a flat line that snaps open,
## the letters typed into it, then one flash as it settles
func _play_intro() -> void:
	_prepare_intro()

	_intro = create_tween()
	_intro.set_parallel(true)

	_intro.tween_property(_boot, "color:a", 0.0, boot_fade)

	_intro.tween_property(_title, "offset_transform_scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_title, "visible_ratio", 1.0, type_duration) \
		.set_delay(0.22).set_trans(Tween.TRANS_LINEAR)

	var typed_at := 0.22 + type_duration
	_intro.tween_property(_title, "modulate", Color(2.4, 2.4, 2.6, 1), 0.08) \
		.set_delay(typed_at)
	_intro.tween_property(_title, "modulate", Color(1, 1, 1, 1), 0.4) \
		.set_delay(typed_at + 0.08)

	_intro.tween_property(_subtitle, "modulate", Color(1, 1, 1, 1), 0.4) \
		.set_delay(typed_at + 0.1)

	for i in _buttons.size():
		var button: Control = _buttons[i]
		var at := typed_at + 0.25 + i * 0.05
		_intro.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.25).set_delay(at)
		_intro.tween_property(button, "offset_transform_position", Vector2.ZERO, 0.35) \
			.set_delay(at).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var modes_at := typed_at + 0.25 + _buttons.find(_coop_button) * 0.05
	_intro.tween_property(_modes_header, "modulate", Color(1, 1, 1, 1), 0.25).set_delay(modes_at)

	_intro.chain().tween_callback(_finish_intro)


## Everything the intro animates starts from its hidden pose here, so the first
## drawn frame already looks right instead of flashing the finished screen
func _prepare_intro() -> void:
	_boot.color = Color(0, 0, 0, 1)
	_title.offset_transform_enabled = true
	_title.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_title.offset_transform_scale = Vector2(1.25, 0.04)
	_title.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_title.visible_ratio = 0.0
	_title.modulate = Color(1, 1, 1, 1)

	_subtitle.modulate = Color(1, 1, 1, 0)
	_modes_header.modulate = Color(1, 1, 1, 0)

	for button in _buttons:
		button.offset_transform_enabled = true
		button.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
		button.offset_transform_position = Vector2(0, slide_distance)
		button.modulate = Color(1, 1, 1, 0)


## Puts every animated node on its final pose and hands over to the idle pulse.
## Runs both at the end of the intro and when it is skipped
func _finish_intro() -> void:
	if _intro != null and _intro.is_valid():
		_intro.kill()

	_intro = null

	_boot.color = Color(0, 0, 0, 0)
	_title.offset_transform_scale = Vector2.ONE
	_title.offset_transform_position = Vector2.ZERO
	_title.visible_ratio = 1.0
	_title.modulate = Color(1, 1, 1, 1)
	_subtitle.modulate = Color(1, 1, 1, 1)
	_modes_header.modulate = Color(1, 1, 1, 1)

	for button in _buttons:
		button.offset_transform_position = Vector2.ZERO
		button.modulate = Color(1, 1, 1, 1)

	_buttons[0].grab_focus()
	_pulse_title()


## The map builds itself from scratch on load, so all that is opened here is the
## campaign at its first level and the run that counts the stats of it. Both
## wipe what the attempt before left behind
func _on_start_pressed() -> void:
	if _starting:
		return

	_starting = true
	_sfx.stream = START_SOUND
	_sfx.play()
	Match.start_campaign(_solo_seat())
	Levels.start()
	GameState.start_run()
	Transition.change_scene(LEVEL_SCENE)


## Picks the campaign up at the level the last clear was saved at. The run is
## opened first and the saved tally put back into it after, a campaign counts
## its deaths and its time over all of its levels
func _on_continue_pressed() -> void:
	if _starting:
		return

	_starting = true
	_sfx.stream = START_SOUND
	_sfx.play()
	Match.start_campaign(_solo_seat())
	Levels.start(SaveGame.level_index)
	GameState.start_run()
	SaveGame.restore()
	Transition.change_scene(LEVEL_SCENE)


## A level that was already cleared can be played again on its own. It opens a
## fresh run: the tally of the campaign belongs to the way through it, not to a
## single level picked out of the middle
func _on_level_picked(index: int) -> void:
	if _starting:
		return

	_starting = true
	_sfx.stream = START_SOUND
	_sfx.play()
	Match.start_campaign(_solo_seat())
	Levels.start(index)
	GameState.start_run()
	Transition.change_scene(LEVEL_SCENE)


## The online side of the game is a screen of its own, everything about it lives
## behind this one button
## One seat, on this machine, playing the campaign alone. Everything account
## keyed still has an account to file the run under
func _solo_seat() -> Array[int]:
	Seats.clear()
	Seats.claim_keyboard()
	Seats.lock()
	return Seats.accounts()


## The campaign played by everybody in the room, on one screen. Which level it
## picks up at is the co-op slot's own business, so the seat screen asks the save
## for it once the seats are known
func _on_coop_pressed() -> void:
	_open_seats(SeatSelect.Mode.CAMPAIGN)


func _on_party_pressed() -> void:
	_open_seats(SeatSelect.Mode.PARTY)


func _open_seats(mode: int) -> void:
	if _starting:
		return

	_starting = true
	SeatSelect.next_mode = mode
	SeatSelect.next_level = -1
	_sfx.stream = START_SOUND
	_sfx.play()
	Transition.change_scene(SEAT_SELECT_SCENE)


func _on_online_pressed() -> void:
	if _starting:
		return

	_starting = true
	_sfx.stream = START_SOUND
	_sfx.play()
	Transition.change_scene(ONLINE_SCENE)


func _on_levels_pressed() -> void:
	_content.visible = false
	_level_select.open()


func _on_level_select_closed() -> void:
	_content.visible = true
	_levels_button.grab_focus()


func _on_options_pressed() -> void:
	_content.visible = false
	_options_menu.open()


func _on_credits_pressed() -> void:
	_content.visible = false
	_credits.open()


func _on_credits_closed() -> void:
	_content.visible = true
	_credits_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_options_closed() -> void:
	_content.visible = true
	_options_button.grab_focus()


## Lets the title breathe, a menu that stands perfectly still reads as a frozen
## game while the level loads behind it
func _pulse_title() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title, "modulate", Color(1.25, 1.25, 1.35, 1), pulse_duration)
	tween.tween_property(_title, "modulate", Color(1, 1, 1, 1), pulse_duration)
