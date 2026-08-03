extends Control

## The first thing the game does. Two beats — whose game this is, and what it
## was built in — then the screen goes down and hands over to the title screen.
## It runs for about four seconds and nobody watches a boot sequence twice, so
## any button drops it into the same blackout the last beat ends on

const TITLE_SCENE := "res://Scenes/Ui/title_screen.tscn"

## The beats in the order they play: the logo, the line written under it, and
## the color that line is written in
const BEATS := [
	{
		"logo": preload("res://Assets/Logos/logo.svg"),
		"line": "SAMY ABUAISHEH",
		"color": Color(0.72, 0.66, 0.9),
	},
	{
		"logo": preload("res://icon.svg"),
		"line": "MADE WITH GODOT",
		"color": Color(0.35, 0.65, 0.85),
	},
]

@export_group("Timing")

## Seconds the screen takes to come up out of black at the very start. The
## window is handed over black by the engine, and this is what turns that into
## the opening of the sequence instead of a frame that was there before it
@export var boot_fade: float = 0.35

## Seconds a logo takes to come up
@export var fade_in: float = 0.5

## Seconds it stands there once it is up
@export var hold: float = 0.9

## Seconds it takes to leave again
@export var fade_out: float = 0.4

## Seconds the screen takes to go black before the title screen is loaded. The
## menu is not a small scene, going black over the load is what keeps the last
## frame of the sequence from standing still while it builds
@export var blackout: float = 0.4

@export_group("Motion")

## How much bigger a logo starts out. It settles back to its size on the way in,
## so it arrives instead of simply being there
@export var pop_scale: float = 1.16

## How far the logo is thrown sideways by the glitch it leaves on
@export var glitch_throw: float = 13.0

## Seconds one frame of that glitch takes
@export var glitch_step: float = 0.04

@onready var _stack: VBoxContainer = %Stack
@onready var _logo: TextureRect = %Logo
@onready var _line: Label = %Line
@onready var _skip: Label = %Skip
@onready var _blackout: ColorRect = %Blackout

## The whole sequence, kept around so a button can cut it short
var _sequence: Tween = null

## True from the moment the title screen was asked for, a button pressed on the
## last frame must not load it a second time
var _leaving: bool = false


func _ready() -> void:
	_line.label_settings = _line.label_settings.duplicate()
	_logo.offset_transform_enabled = true
	_logo.offset_transform_visual_only = true
	_logo.offset_transform_pivot_ratio = Vector2(0.5, 0.5)

	_stack.modulate = Color(1, 1, 1, 0)
	_line.modulate = Color(1, 1, 1, 0)
	_skip.modulate = Color(1, 1, 1, 0)
	_blackout.color = Color(0, 0, 0, 1)

	_fade_in_skip()
	_play()


## Anything pressed drops the sequence. Held keys and released ones are ignored,
## a player who is already leaning on a button would otherwise never see a frame
func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return

	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		if event.is_pressed() and not event.is_echo():
			get_viewport().set_input_as_handled()
			_skip_sequence()


## One tween carries the whole thing: every beat comes up, stands, glitches once
## and leaves, and the screen goes black behind the last one
func _play() -> void:
	_sequence = create_tween()
	_sequence.tween_property(_blackout, "color:a", 0.0, boot_fade)

	for beat in BEATS:
		_queue_beat(beat)

	_sequence.tween_property(_blackout, "color:a", 1.0, blackout)
	_sequence.tween_callback(_open_title)


## The hint is worth nothing on the first frame, nobody is reaching for a button
## yet. It fades in once the first logo is up and stays for the rest of the run
func _fade_in_skip() -> void:
	var tween := create_tween()
	tween.tween_interval(boot_fade + fade_in + hold * 0.5)
	tween.tween_property(_skip, "modulate:a", 0.55, 0.7)


## Everything one beat is made of, appended to the sequence that is being built
func _queue_beat(beat: Dictionary) -> void:
	_sequence.tween_callback(_show_beat.bind(beat))
	_sequence.tween_property(_stack, "modulate:a", 1.0, fade_in)
	_sequence.parallel().tween_property(_logo, "offset_transform_scale", Vector2.ONE, fade_in) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence.parallel().tween_property(_line, "modulate:a", 1.0, fade_in) \
		.set_delay(fade_in * 0.3)

	_sequence.tween_interval(hold)

	_sequence.tween_property(_logo, "offset_transform_position", Vector2(-glitch_throw, 0), glitch_step)
	_sequence.tween_property(_logo, "offset_transform_position", Vector2(glitch_throw * 0.7, 0), glitch_step)
	_sequence.tween_property(_logo, "offset_transform_position", Vector2.ZERO, glitch_step)
	_sequence.tween_property(_stack, "modulate:a", 0.0, fade_out)


## Puts the beat on screen in its starting pose, run from inside the sequence
## while the stack is still faded out and none of this can be seen happening
func _show_beat(beat: Dictionary) -> void:
	_logo.texture = beat["logo"]
	_line.text = beat["line"]
	_line.label_settings.font_color = beat["color"]
	_line.modulate = Color(1, 1, 1, 0)
	_logo.offset_transform_scale = Vector2(pop_scale, pop_scale)
	_logo.offset_transform_position = Vector2.ZERO


## A skip does not cut straight to the menu. It runs the same blackout the last
## beat would have ended on, only faster, so the hand over looks the same either
## way and the scene still loads behind something
func _skip_sequence() -> void:
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()

	_sequence = create_tween()
	_sequence.tween_property(_stack, "modulate:a", 0.0, 0.12)
	_sequence.parallel().tween_property(_skip, "modulate:a", 0.0, 0.12)
	_sequence.tween_property(_blackout, "color:a", 1.0, 0.2)
	_sequence.tween_callback(_open_title)


func _open_title() -> void:
	if _leaving:
		return

	_leaving = true
	get_tree().change_scene_to_file(TITLE_SCENE)
