extends Node
class_name SawDamage

## The saw this blade belongs to, brought to a stop by a cube that cannot be cut
@export var mover: SawMover

## Seconds the blade stands still after a shielded cube walked into it. It
## glides out and back in on its own, this is only the time in between
@export var stall_duration: float = 2.2

## How much of its glow the blade keeps while it lies there knocked out. Low
## enough that a saw the cube has already dealt with reads as harmless
@export_range(0.0, 1.0) var stall_dim: float = 0.12

## What is left where a blade was broken: debris, sparks and a cloud of smoke
@export var explosion_scene: PackedScene


## The blade only ever hurts the player, everything else may pass through.
##
## What a touch does depends on what the cube is carrying. A shield that breaks
## blades takes the saw out of the level, one that only holds them off knocks it
## out for a moment, and a bare cube is cut in half
func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var death := get_tree().get_first_node_in_group("player_death") as PlayerDeath
	if death == null:
		return

	if death.breaks_saws:
		_shatter(body, death)
		return

	if death.is_invulnerable:
		if mover != null:
			mover.stall(stall_duration, stall_dim)
		return

	death.kill()


## The blade loses. It is taken out of the level for the rest of the attempt and
## the cube leaves its own color on the spot, so the wreck is still marked on
## the next run past it
func _shatter(cube: Node3D, death: PlayerDeath) -> void:
	var saw: Node3D = mover.parent if mover != null else null
	if saw == null:
		return

	_explode(saw)
	death.break_saw(cube.global_position.lerp(saw.global_position, 0.5))
	saw.queue_free()


## The wreck is handed to whatever the saw hung under, so it keeps burning where
## the blade stood instead of being taken down with it
func _explode(saw: Node3D) -> void:
	if explosion_scene == null:
		return

	var holder := saw.get_parent()
	if holder == null:
		return

	var explosion := explosion_scene.instantiate() as Node3D
	holder.add_child(explosion)
	explosion.global_position = saw.global_position
