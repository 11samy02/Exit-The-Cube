extends Area3D
class_name Key

## Seconds the burst keeps playing after the key itself has vanished
@export var burst_linger: float = 0.8

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var glitter: GPUParticles3D = $Glitter
@onready var sparks: GPUParticles3D = $Sparks
@onready var pickup_sound: AudioStreamPlayer3D = $PickupSound

var collected: bool = false


## Bursts on the first touch, every later contact is ignored
func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player"):
		return

	collected = true
	set_deferred("monitoring", false)
	glitter.emitting = false
	sparks.restart()
	_play_pickup_sound()
	animation_player.play("collect")
	GameState.collect_key()


## Varies the pitch a little so a retry never sounds exactly the same
func _play_pickup_sound() -> void:
	if pickup_sound.stream == null:
		return

	pickup_sound.pitch_scale = randf_range(0.97, 1.06)
	pickup_sound.play()


## Called by the collect animation, keeps the node alive until the burst fades
func _collect() -> void:
	await get_tree().create_timer(burst_linger).timeout
	queue_free()
