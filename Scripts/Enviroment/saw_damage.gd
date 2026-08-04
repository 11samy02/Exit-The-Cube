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

## Seconds the blade takes to wind itself back up, once it is allowed to
@export var revive_duration: float = 0.6

## How close a player may be when it comes back, in meters
@export var revive_clearance: float = 6.0

## Seconds between two looks at whether the corridor is clear again
@export var revive_retry: float = 1.0


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

	var revive := Online.saw_revive_seconds()
	if revive <= 0.0:
		saw.queue_free()
		return

	_take_down(saw, revive)


## Puts the blade out of action for a while instead of taking it out of the
## level. A round that runs to a clock would otherwise be swept clean of blades
## by a team spending its hearts, and the last two minutes of it played in an
## empty maze
func _take_down(saw: Node3D, seconds: float) -> void:
	saw.visible = false
	saw.set_deferred("monitoring", false)
	_run_saw(saw, false)

	await get_tree().create_timer(seconds).timeout
	if not is_instance_valid(saw) or not saw.is_inside_tree():
		return

	await _wait_for_room(saw)
	if not is_instance_valid(saw) or not saw.is_inside_tree():
		return

	_wind_back_up(saw)


## A blade must not come back on top of somebody. It waits out of the way until
## the corridor it stopped in is clear rather than reappearing into a kill
func _wait_for_room(saw: Node3D) -> void:
	while _crowded(saw):
		await get_tree().create_timer(revive_retry).timeout
		if not is_instance_valid(saw) or not saw.is_inside_tree():
			return


func _crowded(saw: Node3D) -> bool:
	for node in get_tree().get_nodes_in_group("player"):
		if (node as Node3D).global_position.distance_to(saw.global_position) < revive_clearance:
			return true

	return false


## Winds it back up where it stopped, growing out of nothing so that it is seen
## coming rather than simply being there again
func _wind_back_up(saw: Node3D) -> void:
	saw.visible = true
	saw.scale = Vector3.ZERO
	_run_saw(saw, true)

	var arrival := create_tween()
	arrival.tween_property(saw, "scale", Vector3.ONE, revive_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await arrival.finished
	if is_instance_valid(saw) and saw.is_inside_tree():
		saw.set_deferred("monitoring", true)


## Switches the blade's own movement off or back on
func _run_saw(saw: Node3D, running: bool) -> void:
	for child in saw.get_children():
		if child is SawMover or child is SawAi:
			(child as Node).set_process(running)
			(child as Node).set_physics_process(running)


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
