extends CanvasLayer
class_name GameUi

## Seconds the key icon takes to pop into the corner
@export var pop_duration: float = 0.5

## Seconds the level banner takes to fade in and back out
@export var banner_fade: float = 0.5

## Seconds a subtitle stays readable once it has typed itself out, the length of
## the line is added on top of it
@export var subtitle_hold: float = 2.6

## Seconds a subtitle takes to fade in and back out
@export var subtitle_fade: float = 0.3

## How many lines may wait behind the one on screen. Anything over that is the
## commentary talking over itself, so the oldest one is dropped
const SUBTITLE_QUEUE_MAX := 2

@onready var key_icon: TextureRect = $Control/MarginContainer/key_icon
@onready var death_count: Label = $Control/MarginContainer/death_icon/death_count
@onready var banner: Control = %banner
@onready var level_name: Label = %level_name
@onready var lesson: Control = %lesson
@onready var lesson_icon: TextureRect = %lesson_icon
@onready var lesson_text: Label = %lesson_text
@onready var subtitle: Label = %subtitle

## The action the hint waits for, empty while the banner fades on a timer
var _lesson_action: StringName = &""

## Lines waiting for the one on screen to be done with
var _subtitle_queue: Array[String] = []

## The tween that runs the line on screen, null while nothing is being said
var _subtitle_tween: Tween = null


func _ready() -> void:
	GameState.key_collected.connect(_on_key_collected)
	GameState.death_count_changed.connect(_show_deaths)
	InputIcons.device_changed.connect(_on_device_changed)
	Settings.bindings_changed.connect(_refresh_lesson_icon)
	Quips.line_requested.connect(_say)
	Settings.commentary_changed.connect(_on_commentary_changed)
	_reset_key_icon()
	_show_deaths(GameState.deaths)
	_show_banner(GameState.level)
	_say(Quips.take_pending())


## A hint that waits for its action stays up until the player has actually used
## the control once, pressing it is what takes the banner down
func _unhandled_input(event: InputEvent) -> void:
	if _lesson_action.is_empty() or not event.is_action_pressed(_lesson_action):
		return

	_lesson_action = &""
	_fade_banner_out(0.4)


## The tally carries over from the earlier attempts, so it is filled in on start
## as well, not only when a death comes in
func _show_deaths(deaths: int) -> void:
	death_count.text = str(deaths)


## The icon is the indicator for the key, so it starts off screen empty
func _reset_key_icon() -> void:
	key_icon.pivot_offset = key_icon.custom_minimum_size * 0.5
	key_icon.visible = GameState.has_key
	key_icon.scale = Vector2.ONE if GameState.has_key else Vector2(0.2, 0.2)
	key_icon.modulate = Color(1, 1, 1, 1.0 if GameState.has_key else 0.0)


## Pops the icon in overbright and lets the flash settle back to normal
func _on_key_collected() -> void:
	key_icon.visible = true
	key_icon.scale = Vector2(0.2, 0.2)
	key_icon.modulate = Color(4, 4, 4, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(key_icon, "scale", Vector2.ONE, pop_duration).set_trans(Tween.TRANS_BACK)
	tween.tween_property(key_icon, "modulate", Color(1, 1, 1, 1), pop_duration).set_trans(Tween.TRANS_EXPO)


## Names the level the player just dropped into and spells out whatever it wants
## to teach. A level without a name and without a hint shows nothing at all
func _show_banner(level: MapData) -> void:
	_lesson_action = &""
	banner.modulate = Color(1, 1, 1, 0)
	banner.visible = false

	var title := _banner_title(level)
	var text := level.hint_text if level != null else ""
	if title.is_empty() and text.is_empty():
		return

	level_name.text = title
	level_name.visible = not title.is_empty()
	lesson_text.text = text
	lesson.visible = not text.is_empty()

	if level != null and not level.hint_action.is_empty() and InputMap.has_action(level.hint_action):
		_lesson_action = StringName(level.hint_action)

	_refresh_lesson_icon()
	banner.visible = true
	_fade_banner_in(level)


## The name of the level, its position in the campaign when it carries none
func _banner_title(level: MapData) -> String:
	if level != null and not level.display_name.is_empty():
		return level.display_name

	return Levels.title()


## Fades in, and back out again on its own unless it is waiting for a control to
## be pressed
func _fade_banner_in(level: MapData) -> void:
	var hold: float = level.hint_duration if level != null else 6.0

	var tween := create_tween()
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 1), banner_fade)

	if _lesson_action.is_empty():
		tween.tween_interval(maxf(hold, 0.0))
		tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), banner_fade)
		tween.tween_callback(banner.hide)


## Takes the banner down early, the lesson it spelled out has just been used
func _fade_banner_out(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), duration)
	tween.tween_callback(banner.hide)


## Queues a line of commentary. Two of them can land in the same moment, an item
## picked up right next to the key does exactly that, so they are shown one after
## the other instead of overwriting each other. Anything past the queue is the
## game babbling and gets dropped
func _say(text: String) -> void:
	if text.is_empty():
		return

	_subtitle_queue.append(text)
	while _subtitle_queue.size() > SUBTITLE_QUEUE_MAX:
		_subtitle_queue.pop_front()

	if _subtitle_tween == null or not _subtitle_tween.is_valid():
		_show_next_line()


## Types the next line out, holds it and takes it away again, then comes back
## here for whatever came in while it was up
func _show_next_line() -> void:
	if _subtitle_queue.is_empty():
		_subtitle_tween = null
		return

	var text: String = _subtitle_queue.pop_front()
	subtitle.text = text
	subtitle.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	subtitle.visible_ratio = 0.0
	subtitle.modulate = Color(1, 1, 1, 0)

	var type_time := clampf(text.length() * 0.018, 0.4, 1.4)

	_subtitle_tween = create_tween()
	_subtitle_tween.tween_property(subtitle, "modulate", Color(1, 1, 1, 1), subtitle_fade)
	_subtitle_tween.parallel().tween_property(subtitle, "visible_ratio", 1.0, type_time)
	_subtitle_tween.tween_interval(subtitle_hold + text.length() * 0.02)
	_subtitle_tween.tween_property(subtitle, "modulate", Color(1, 1, 1, 0), subtitle_fade)
	_subtitle_tween.tween_callback(_show_next_line)


## Turned all the way down from the pause menu, whatever is still hanging on
## screen goes with it instead of waiting out its own fade
func _on_commentary_changed() -> void:
	if Settings.commentary != Settings.COMMENTARY_OFF:
		return

	_subtitle_queue.clear()
	if _subtitle_tween != null and _subtitle_tween.is_valid():
		_subtitle_tween.kill()

	_subtitle_tween = null
	subtitle.text = ""


func _on_device_changed(_device: int) -> void:
	_refresh_lesson_icon()


## The prompt is read out of the InputMap every time, so a rebound key and a pad
## plugged in halfway through the level both show the right glyph
func _refresh_lesson_icon() -> void:
	if _lesson_action.is_empty():
		lesson_icon.visible = false
		return

	lesson_icon.texture = InputIcons.get_action_texture(_lesson_action, InputIcons.prompt_slot())
	lesson_icon.visible = lesson_icon.texture != null
