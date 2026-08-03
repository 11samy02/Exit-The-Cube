extends Area3D
class_name ItemSphere

## Seconds the burst keeps playing after the shell has fully shattered
@export var burst_linger: float = 0.6

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var shards: GPUParticles3D = $Shards
@onready var sparks: GPUParticles3D = $Sparks
@onready var pickup_sound: AudioStreamPlayer3D = $PickupSound

var collected: bool = false


## Bursts on the first touch, every later contact is ignored. The item that
## comes out is rolled here, an item the player still carries is overwritten
## by a different one. Only a project without any items leaves the sphere
## standing, it would burst for nothing otherwise
func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player"):
		return

	if ItemSystem.grant_random_item() == null:
		return

	collected = true
	GameState.count_item_collected()
	set_deferred("monitoring", false)
	shards.restart()
	sparks.restart()
	_play_pickup_sound()
	animation_player.play("collect")


## Varies the pitch so a row of pickups never sounds identical
func _play_pickup_sound() -> void:
	if pickup_sound.stream == null:
		return

	pickup_sound.pitch_scale = randf_range(0.94, 1.12)
	pickup_sound.play()


## Called by the collect animation, keeps the node alive until the burst fades
func _collect() -> void:
	await get_tree().create_timer(burst_linger).timeout
	queue_free()
