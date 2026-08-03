extends Node
class_name PlayerAudio

## Animator the step timing is read from, its hop decides when the cube lands
@export var animator: PlayerAnimator

## Loops under everything, the room the level lives in
@export var ambient_player: AudioStreamPlayer

## Fires once per landing
@export var step_player: AudioStreamPlayer3D

## The step samples, one is picked at random per landing
@export var step_sounds: Array[AudioStream] = []

## Volume the ambient bed settles at, in decibels
@export var ambient_volume_db: float = -20.0

## Seconds the ambient bed takes to fade up from silence
@export var ambient_fade_in: float = 3.0

## Loudest a step can get, in decibels
@export var step_volume_db: float = -11.0

## Below this share of max_speed the cube is too slow to be heard
@export var step_speed_threshold: float = 0.2

## Lowest and highest pitch a single step is played back at
@export var step_pitch_range: Vector2 = Vector2(0.88, 1.14)

var last_hop_segment: int = 0

var step_bag: Array[int] = []


func _ready() -> void:
	_start_ambient()
	last_hop_segment = _current_hop_segment()


## The cube sits on the floor whenever its hop sine crosses zero, so every
## change of half period is exactly one landing
func _process(_delta: float) -> void:
	var segment := _current_hop_segment()
	if segment == last_hop_segment:
		return

	last_hop_segment = segment
	if animator.speed_ratio >= step_speed_threshold:
		_play_step()


## Which half of the hop the cube is in, 0 while it rises and 1 while it falls
func _current_hop_segment() -> int:
	return int(animator.run_time / PI)


## Picks the next sample and a fresh pitch so a long run never repeats itself
func _play_step() -> void:
	if step_sounds.is_empty():
		return

	step_player.stream = _next_step_sound()
	step_player.pitch_scale = randf_range(step_pitch_range.x, step_pitch_range.y)
	step_player.volume_db = step_volume_db + linear_to_db(animator.speed_ratio)
	step_player.play()


## Draws from a shuffled bag instead of at random, so every variant is heard
## once before any of them comes up again
func _next_step_sound() -> AudioStream:
	if step_bag.is_empty():
		step_bag.assign(range(step_sounds.size()))
		step_bag.shuffle()

	return step_sounds[step_bag.pop_back()]


## Creeps up from silence, an ambient bed that snaps on at full volume is
## instantly recognisable as a sound file
func _start_ambient() -> void:
	if ambient_player.stream == null:
		return

	ambient_player.volume_db = -80.0
	ambient_player.play()

	var fade := create_tween()
	fade.tween_property(ambient_player, "volume_db", ambient_volume_db, ambient_fade_in)
