extends CanvasLayer

## The panel that goes up once the player rode the elevator out. It reads the
## whole run off the GameState, which stopped counting the moment the cabin
## reached the top, so nothing has to be handed over to it

const TITLE_SCENE := "res://Scenes/Ui/title_screen.tscn"

const WIN_SOUND := preload("res://Assets/Sounds/UI & Menus/Achievement.wav")

## Seconds between one stat row lighting up and the next one
@export var row_delay: float = 0.1

## Seconds the comment takes to type itself out
@export var type_duration: float = 0.9

@onready var _root: Control = %Root
@onready var _panel: Control = %Panel
@onready var _title: Label = %Title
@onready var _level: Label = %Level
@onready var _comment: Label = %Comment
@onready var _time_value: Label = %TimeValue
@onready var _death_value: Label = %DeathValue
@onready var _item_value: Label = %ItemValue
@onready var _used_value: Label = %UsedValue
@onready var _rows: Array[Control] = [%TimeRow, %DeathRow, %ItemRow, %UsedRow]
@onready var _retry_button: Button = %RetryButton
@onready var _title_button: Button = %TitleButton

var _sfx: AudioStreamPlayer

## Set once a button was pressed, from then on nothing here reacts anymore so
## the running transition cannot be interrupted
var _leaving: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false

	_sfx = AudioStreamPlayer.new()
	_sfx.stream = WIN_SOUND
	_sfx.bus = &"sfx"
	_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx)

	_retry_button.pressed.connect(_on_retry_pressed)
	_title_button.pressed.connect(_on_title_pressed)
	GameState.run_finished.connect(open)

	UiFeedback.attach_all(self)
	UiFeedback.use_back_sound(_title_button)


## The run is over, so pause and cancel have nothing left to do. Swallowing them
## here keeps the pause menu from opening on top of the summary
func _input(event: InputEvent) -> void:
	if not _root.visible or _leaving:
		return

	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


## Freezes what is left of the map behind the panel and puts the numbers up
func open() -> void:
	if _root.visible:
		return

	_fill()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sfx.play()
	_play_intro()
	_retry_button.grab_focus()


## Every number of the run, plus the line that judges them
func _fill() -> void:
	_fill_heading()
	_time_value.text = _format_time(GameState.run_time)
	_death_value.text = str(GameState.deaths)
	_item_value.text = str(GameState.items_collected)
	_used_value.text = str(GameState.items_used)
	_comment.text = Quips.pick("run_summary", RunComments.matching_lines(GameState.deaths, \
		GameState.run_time, GameState.items_collected, GameState.items_used))


## Which level was cleared and what the button under it does next. The last
## level of the campaign ends it instead of moving on, and a map that was opened
## on its own has no campaign to move through at all
func _fill_heading() -> void:
	_level.text = _level_line()

	if Levels.has_next():
		_title.text = "LEVEL CLEAR"
		_retry_button.text = "NEXT LEVEL"
	elif Levels.is_running():
		_title.text = "CAMPAIGN CLEAR"
		_retry_button.text = "PLAY AGAIN"
	else:
		_title.text = "LEVEL CLEAR"
		_retry_button.text = "NEW RUN"


## The name of the level, with its place among the numbered levels behind it. A
## tutorial is not one of them and has nothing to count, it stands on its name
func _level_line() -> String:
	var level := GameState.level
	var name := level.display_name if level != null else ""

	if name.is_empty():
		name = Levels.title()

	var number := Levels.listed_number()
	if not Levels.is_running() or number <= 0:
		return name

	return "%s   ·   %d / %d" % [name, number, Levels.listed_count()] if not name.is_empty() \
		else "%d / %d" % [number, Levels.listed_count()]


## The panel drops in like the pause menu, then the rows light up one after the
## other and the comment is typed into the gap under the title
func _play_intro() -> void:
	_prepare_intro()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(_panel, "offset_transform_position", Vector2.ZERO, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "offset_transform_scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate", Color(1, 1, 1, 1), 0.2)

	for i in _rows.size():
		var row := _rows[i]
		var at := 0.28 + i * row_delay
		tween.tween_property(row, "modulate", Color(1, 1, 1, 1), 0.22).set_delay(at)
		tween.tween_property(row, "offset_transform_position", Vector2.ZERO, 0.3) \
			.set_delay(at).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var comment_at := 0.28 + _rows.size() * row_delay
	tween.tween_property(_comment, "visible_ratio", 1.0, type_duration) \
		.set_delay(comment_at).set_trans(Tween.TRANS_LINEAR)


## Puts everything the intro animates on its hidden pose, so the first drawn
## frame already looks right instead of flashing the finished panel
func _prepare_intro() -> void:
	_panel.offset_transform_enabled = true
	_panel.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_panel.offset_transform_position = Vector2(0, -60)
	_panel.offset_transform_scale = Vector2(1.06, 0.9)
	_panel.modulate = Color(1, 1, 1, 0)

	_comment.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_comment.visible_ratio = 0.0

	for row in _rows:
		row.offset_transform_enabled = true
		row.offset_transform_position = Vector2(-24, 0)
		row.modulate = Color(1, 1, 1, 0)


## Steps the campaign on and builds the map again, the scene is the same one for
## every level. A finished campaign starts over from its first level, a map
## without one is simply built again. The stats reset with the rebuild, the run
## this panel showed was closed when the elevator reached the top
func _on_retry_pressed() -> void:
	if _leaving:
		return

	_leaving = true

	if Levels.has_next():
		Levels.advance()
	elif Levels.is_running():
		Levels.start()

	_close()
	Transition.reload_scene()


## Leaving the campaign here means the title screen opens a fresh one on start
func _on_title_pressed() -> void:
	if _leaving:
		return

	_leaving = true
	Levels.stop()
	_close()
	Transition.change_scene(TITLE_SCENE)


## The tree has to run again before the scene is swapped, a transition that
## starts on a paused tree never finishes its tween. The camera of the next map
## takes the mouse back on its own
func _close() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%d:%05.2f" % [minutes, seconds - minutes * 60]
