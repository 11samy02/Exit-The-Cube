extends CanvasLayer

## The panel that asks whether the game should play the level out, the badge that
## says it is doing so, and the two things the player may still do while it does.
##
## It sits in the map scene next to the pause menu and does nothing at all in a
## level that is going fine. The question is asked when an attempt starts on a
## level that has already cost more than it is worth, and asked again as that
## number gets worse — a level that took ten lives and a level that took a hundred
## are not the same conversation

## The death counts one level may make the offer at, each of them once.
##
## Three of them because a level costs more than once. The first is the game
## noticing, the last is it not letting one room be the reason somebody stops
## playing. Exported as a list so the marks themselves can be moved, and so a
## short one can be dropped in while something is being tried out — a hundred
## deaths is a long way to walk to find out whether a dialog appears
@export var offer_at_deaths: Array[int] = [10, 50, 100]

## Seconds between the level being back on screen and the question. Long enough
## that the answer is given to a maze the player can see rather than to a cover
## that is still coming down
@export var ask_delay: float = 1.4

## Seconds the panel takes to drop in, the same motion the pause menu uses
@export var slide_duration: float = 0.28

## How fast the level runs while the watch button is held down. Watching a CPU
## walk a maze it is in no danger in is the one place in this game where time
## could stand to move faster
@export_range(1.0, 8.0) var fast_forward_scale: float = 2.0

## Which of the two questions the panel is up for, and there are only two: the
## game asking for the level, and the player asking for it back
enum Asking { NOTHING, HAND_OVER, TAKE_BACK }

@onready var _root: Control = %Root
@onready var _panel: Control = %Panel
@onready var _title: Label = %Title
@onready var _question: Label = %Question
@onready var _badge: Control = %Badge
@onready var _take_icon: TextureRect = %TakeIcon
@onready var _take_text: Label = %TakeText
@onready var _fast_icon: TextureRect = %FastIcon
@onready var _fast_text: Label = %FastText
@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton

var _asking: int = Asking.NOTHING


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_badge.visible = false

	_yes_button.pressed.connect(_on_yes_pressed)
	_no_button.pressed.connect(_on_no_pressed)
	Autopilot.changed.connect(_show_badge)
	Settings.bindings_changed.connect(_write_hints)
	InputIcons.device_changed.connect(_on_device_changed)

	UiFeedback.attach_all(self)
	UiFeedback.use_back_sound(_no_button)

	_write_hints()
	_pick_the_level_back_up()


## The clock is only ever wound back up here. Leaving a level while the button is
## held down would otherwise hand the next one a world running at double speed
func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Neither button may be pressed by accident. The choice is a level being taken
## away from somebody or an offer being put away for the rest of the game, and
## both of them are worth an actual press — so the two keys that dismiss every
## other panel in the game are swallowed here
func _input(event: InputEvent) -> void:
	if _root.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()

		return

	if Autopilot.is_running() and event.is_action_pressed("take_over"):
		get_viewport().set_input_as_handled()
		_ask_to_take_back()


## Runs the world faster while the button is held and only while a CPU is the one
## playing. A player holding it down in their own level would be handing
## themselves a maze with the blades on double time
func _process(_delta: float) -> void:
	var fast := Autopilot.is_running() and not _root.visible \
		and Input.is_action_pressed("fast_forward")

	Engine.time_scale = fast_forward_scale if fast else 1.0


## Either the CPU is already meant to be playing this level and simply lost the
## cube it was driving to a death, or the level has cost enough to be worth
## asking about. Nothing at all in a level that is going fine
func _pick_the_level_back_up() -> void:
	if Autopilot.should_resume():
		_resume()
	elif Autopilot.due_offer(offer_at_deaths) > 0:
		_ask()


## Puts the CPU straight back on the cube after a death of its own. No question
## is asked a second time: it was answered when the level was handed over, and a
## dialog on top of every burst would be the game asking permission to keep the
## promise it already made
func _resume() -> void:
	if Transition.is_running:
		await Transition.finished

	if is_inside_tree() and Autopilot.should_resume():
		Autopilot.take_over()


## Waits out the transition, the banner and anything else already holding the
## screen, then asks. The deaths are counted over every attempt of the level and
## survive the rebuild, so this is the first frame of the attempt after the one
## that took the tally past a mark
func _ask() -> void:
	if Transition.is_running:
		await Transition.finished

	await get_tree().create_timer(ask_delay, true, false, true).timeout

	while is_inside_tree() and get_tree().paused:
		await get_tree().create_timer(0.25, true, false, true).timeout

	if not is_inside_tree() or not GameState.is_running:
		return

	var mark := Autopilot.due_offer(offer_at_deaths)
	if mark > 0:
		Autopilot.mark_offered(mark)
		open(Asking.HAND_OVER)


## The player reached for the cube. Asked about rather than simply done, because
## the button that does it is one press away at all times and taking a level back
## by accident is losing the run you were sitting there watching
func _ask_to_take_back() -> void:
	open(Asking.TAKE_BACK)


## Freezes the level behind the panel. The campaign is one player and one maze,
## so there is nothing running in there that a stopped clock would be unfair to
func open(asking: int) -> void:
	if _root.visible:
		return

	_asking = asking
	_word_the_question()
	_root.visible = true
	get_tree().paused = true
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UiFeedback.play_click()
	_slide_in()
	_yes_button.grab_focus()


func close() -> void:
	_asking = Asking.NOTHING
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## One panel, two questions. They are opposites and the wording has to say so —
## a yes that hands the level over and a yes that takes it back sitting on
## identically labelled buttons is exactly how somebody presses the wrong one
func _word_the_question() -> void:
	if _asking == Asking.TAKE_BACK:
		_title.text = "YOUR TURN?"
		_question.text = "DO YOU WANT TO TAKE THE LEVEL BACK?"
		_yes_button.text = "YES, I'LL PLAY"
		_no_button.text = "NO, KEEP WATCHING"
		return

	_title.text = "STUCK?"
	_question.text = "DO YOU WANT ME TO FINISH THE LEVEL?"
	_yes_button.text = "YES, TAKE OVER"
	_no_button.text = "NO, I'LL DO IT"


## The panel drops in from slightly above and overshoots once, the same arcade
## motion the rest of the menus use
func _slide_in() -> void:
	_panel.offset_transform_enabled = true
	_panel.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_panel.offset_transform_position = Vector2(0, -60)
	_panel.offset_transform_scale = Vector2(1.06, 0.9)
	_panel.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "offset_transform_position", Vector2.ZERO, slide_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "offset_transform_scale", Vector2.ONE, slide_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate", Color(1, 1, 1, 1), slide_duration * 0.65)


## Yes to whichever question was on the panel. The tree has to be running again
## before the CPU is put on the cube, its brain is driven by the physics frames
## it would otherwise never get
func _on_yes_pressed() -> void:
	var asking := _asking
	close()

	if asking == Asking.TAKE_BACK:
		Autopilot.give_back()
	else:
		Autopilot.take_over()


## No to the offer puts it away for good; no to taking the level back is only
## this once, and the CPU carries on with what it was doing
func _on_no_pressed() -> void:
	if _asking != Asking.TAKE_BACK:
		Autopilot.decline()

	close()


## The badge is the whole of what says the cube is not the player's anymore. It
## goes up with the takeover and comes down when the doors close on it, or when
## the player takes the level back
func _show_badge() -> void:
	_badge.visible = Autopilot.is_running()


func _on_device_changed(_device: int) -> void:
	_write_hints()


## Spells out the two things the player may do while watching, in whatever they
## are actually holding. The glyph is looked up the same way every other prompt
## in the game is, so a pad plugged in halfway through shows pad buttons and a
## rebind never turns the hint into a lie
func _write_hints() -> void:
	_write_hint(_take_icon, _take_text, &"take_over", "TAKE BACK OVER")
	_write_hint(_fast_icon, _fast_text, &"fast_forward", "HOLD FOR FAST")


## One prompt. Where there is a picture of the button it is shown on its own;
## where there is not, the name of the key goes in front of the words instead —
## a gap where the button should be tells nobody anything
func _write_hint(glyph: TextureRect, label: Label, action: StringName, says: String) -> void:
	glyph.texture = InputIcons.get_action_texture(action, InputIcons.prompt_slot())
	glyph.visible = glyph.texture != null
	label.text = says if glyph.visible else "%s  %s" % [_key_of(action), says]


## What that action reads as on a keyboard, and nothing at all when it is only on
## a pad — a glyph nobody can name is worse in a line of text than a gap
func _key_of(action: StringName) -> String:
	var event := Settings.get_binding(action, Settings.SLOT_KEYBOARD)
	return "[%s]" % event.as_text().replace(" (Physical)", "") if event != null else ""
