extends CanvasLayer

## Sits in the game scene and does nothing until the pause button comes in. The
## whole layer runs on PROCESS_MODE_ALWAYS, otherwise it would freeze along
## with the tree it just paused

const TITLE_SCENE := "res://Scenes/Ui/title_screen.tscn"

@onready var _root: Control = %Root
@onready var _panel: Control = %Panel
@onready var _continue_button: Button = %ContinueButton
@onready var _options_button: Button = %OptionsButton
@onready var _title_button: Button = %TitleButton
@onready var _exit_button: Button = %ExitButton
@onready var _options_menu: OptionsMenu = %OptionsMenu

## True while the game is paused by this menu, the tree flag alone would also
## be true for a pause somebody else set
var _paused: bool = false

## Set when the player picked title screen or exit, from then on the menu stops
## reacting so the running transition cannot be interrupted
var _leaving: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false

	_continue_button.pressed.connect(close)
	_options_button.pressed.connect(_on_options_pressed)
	_title_button.pressed.connect(_on_title_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_options_menu.closed.connect(_on_options_closed)

	UiFeedback.attach_all(self)
	UiFeedback.use_back_sound(_continue_button)


## The options panel handles its own cancel, so while it is up nothing here may
## react, otherwise one press would close both at once
func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _options_menu.visible:
		return

	if event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()
		return

	if _paused and event.is_action_pressed("ui_cancel"):
		UiFeedback.play_back()
		close()
		get_viewport().set_input_as_handled()


## The tree is not frozen in a race. Eleven other cubes keep running whatever
## this one does, and a menu that stopped the clock would be the fastest route
## through every maze in the game
func open() -> void:
	if _paused:
		return

	_paused = true
	get_tree().paused = not Online.is_racing()
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UiFeedback.play_click()
	_slide_in()
	_continue_button.grab_focus()


func close() -> void:
	if not _paused:
		return

	_paused = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _toggle() -> void:
	if _paused:
		close()
	else:
		open()


## The panel drops in from slightly above and overshoots once, the same arcade
## motion the menu buttons use on hover
func _slide_in() -> void:
	_panel.offset_transform_enabled = true
	_panel.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_panel.offset_transform_position = Vector2(0, -60)
	_panel.offset_transform_scale = Vector2(1.06, 0.9)
	_panel.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "offset_transform_position", Vector2.ZERO, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "offset_transform_scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate", Color(1, 1, 1, 1), 0.18)


func _on_options_pressed() -> void:
	_panel.visible = false
	_options_menu.open()


func _on_options_closed() -> void:
	_panel.visible = true
	_options_button.grab_focus()


## The tree has to run again before the scene is swapped, a transition that
## starts on a paused tree never finishes its tween
func _on_title_pressed() -> void:
	if _leaving:
		return

	_leaving = true
	_root.visible = false
	get_tree().paused = false
	_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Transition.change_scene(TITLE_SCENE)


func _on_exit_pressed() -> void:
	if _leaving:
		return

	_leaving = true
	get_tree().paused = false
	get_tree().quit()
