extends Area3D
class_name ItemSphere

## Seconds the burst keeps playing after the shell has fully shattered
@export var burst_linger: float = 0.6

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var shards: GPUParticles3D = $Shards
@onready var sparks: GPUParticles3D = $Sparks
@onready var pickup_sound: AudioStreamPlayer3D = $PickupSound

## Seconds the sphere takes to wind itself into existence
@export var appear_duration: float = 0.5

## How far past its own size it swells on the way in, before settling
@export var appear_overshoot: float = 1.25

## Turns it spins while it forms
@export var appear_spins: float = 1.5

## Whose sphere this is, -1 for the one sphere a shared maze has.
##
## A race everybody reads as their own needs a set each: one shell in one cell
## that the first cube through takes is a race for pickups rather than a race,
## and the other players are left walking corridors that have already been
## stripped. They stand in the same cells and each one is deaf and invisible to
## everybody but its owner
@export var owner_seat: int = -1

var collected: bool = false


func _ready() -> void:
	if owner_seat < 0 or not Match.is_private_race():
		return

	SeatView.mark(self, SeatView.private_bit(owner_seat))


## Winds the sphere into the level rather than letting it blink into a corridor
## somebody is looking at. Used by a mode that puts spheres back while it runs —
## a level that lays them all out before anybody is there has nobody to hide the
## pop from, and does not need this
func appear() -> void:
	monitoring = false
	scale = Vector3.ZERO
	sparks.restart()

	var turn := rotation
	turn.y += TAU * appear_spins

	var arrival := create_tween()
	arrival.set_parallel(true)
	arrival.tween_property(self, "scale", Vector3.ONE, appear_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).from(Vector3.ONE * 0.01)
	arrival.tween_property(self, "rotation", turn, appear_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await arrival.finished
	if is_inside_tree() and not collected:
		set_deferred("monitoring", true)


## Bursts on the first touch, every later contact is ignored. The item that
## comes out is rolled here, an item the player still carries is overwritten
## by a different one. Only a project without any items leaves the sphere
## standing, it would burst for nothing otherwise
func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player"):
		return

	var cube := Player.of(body)
	if cube != null and cube.is_ghosted():
		return

	if owner_seat >= 0 and (cube == null or cube.seat != owner_seat):
		return

	if ItemSystem.grant_random_item(body) == null:
		return

	collected = true

	if cube == null or not cube.is_bot:
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
