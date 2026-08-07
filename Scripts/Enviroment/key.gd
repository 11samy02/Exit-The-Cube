extends Area3D
class_name Key

## Seconds the burst keeps playing after the key itself has vanished
@export var burst_linger: float = 0.8

## Whose key this is, 0 for the one key a campaign level has.
##
## A local race puts one in the maze per cube, because everybody sharing a single
## key would make the race a sprint for one pickup rather than a way out each.
## They are told apart by colour and none of them opens for anybody else
@export var owner_account: int = 0

## Which surface of the key carries its glow. The other one is the dark body it
## is set in and stays as it was authored
const TINTED_SURFACE := 0

@onready var mesh: MeshInstance3D = $key
@onready var flash: OmniLight3D = $Flash

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var glitter: GPUParticles3D = $Glitter
@onready var sparks: GPUParticles3D = $Sparks
@onready var pickup_sound: AudioStreamPlayer3D = $PickupSound

var collected: bool = false


func _ready() -> void:
	if owner_account == 0:
		return

	_tint(Match.color_of(owner_account))

	var seat := Match.seat_of_account(owner_account)

	if Match.is_bot_seat(seat):
		visible = false
		return

	if Match.is_private_race():
		SeatView.mark(self, SeatView.private_bit(seat))


## Bursts on the first touch, every later contact is ignored — and a key that
## belongs to somebody is not touched by anybody else at all
func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player"):
		return

	var cube := Player.of(body)

	if owner_account != 0 and (cube == null or cube.account() != owner_account):
		return

	if owner_account == 0 and cube != null and cube.is_ghosted():
		return

	collected = true
	set_deferred("monitoring", false)
	glitter.emitting = false
	sparks.restart()
	_play_pickup_sound()
	animation_player.play("collect")

	if owner_account != 0:
		Match.take_key(owner_account)
	else:
		GameState.collect_key()


## Puts the owner's colour on the key without repainting it.
##
## The key is two surfaces: the part that glows and the dark body it is set in.
## An override covers both and leaves a single flat block of colour that no
## longer reads as a key at all — so only the glowing surface is recoloured, and
## every key in the maze is still the same key. Its own material is copied first,
## the one in the scene is shared by all of them
func _tint(color: Color) -> void:
	flash.light_color = color

	var lit := mesh.get_active_material(TINTED_SURFACE)
	if lit == null:
		return

	var copy := lit.duplicate() as StandardMaterial3D
	if copy == null:
		return

	copy.albedo_color = color
	copy.emission_enabled = true
	copy.emission = color
	mesh.set_surface_override_material(TINTED_SURFACE, copy)


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
