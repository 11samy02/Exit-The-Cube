extends ItemEffect
class_name SpeedEffect

## The cube runs harder while every blade in the level takes it easier. Nothing
## here protects the player, the level only stops being quite as fast as it was

## How much faster the cube runs while this is up
@export var player_multiplier: float = 1.3

## What the saws are left of their speed
@export_range(0.1, 1.0) var saw_multiplier: float = 0.85

var movement: PlayerMovement = null

## The saws that were slowed, kept so exactly those are put back
var slowed: Array[SawMover] = []


func _start() -> void:
	movement = get_tree().get_first_node_in_group("player_movement") as PlayerMovement
	if movement != null:
		movement.set_boost(&"speed", player_multiplier)

	for node in get_tree().get_nodes_in_group("saw_mover"):
		var mover := node as SawMover
		if mover == null:
			continue

		mover.speed_multiplier = saw_multiplier
		slowed.append(mover)


func _stop(_cancelled: bool) -> void:
	if is_instance_valid(movement):
		movement.clear_boost(&"speed")

	for mover in slowed:
		if is_instance_valid(mover):
			mover.speed_multiplier = 1.0

	slowed.clear()
