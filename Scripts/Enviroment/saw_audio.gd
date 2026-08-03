extends Node
class_name SawAudio

## The looping blade sound, sits under the saw and travels with it
@export var player: AudioStreamPlayer3D

## Pitch range, every saw draws its own value once
@export var pitch_range: Vector2 = Vector2(0.92, 1.08)


## Each saw starts somewhere else in the loop. Identical loops running in step
## comb filter as soon as two saws come close, and a whole level of them would
## breathe in unison.
func _ready() -> void:
	if player.stream == null:
		return

	player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	player.play(randf() * player.stream.get_length())
