extends ItemEffect
class_name FreezeEffect

## Every blade in the level winds down and stands still for as long as this
## runs. It does not make them safe: a saw that is not moving still cuts, so the
## level turns from a timing puzzle into a maze of standing knives

## How much of its glow a frozen blade keeps. It is still deadly, so it may not
## go as dark as one the cube has knocked out for good
@export_range(0.0, 1.0) var frozen_dim: float = 0.5

## The saws that were told to stand, kept so the hold can be topped up
var held: Array[SawMover] = []


func _start() -> void:
	for node in get_tree().get_nodes_in_group("saw_mover"):
		var mover := node as SawMover
		if mover != null and (mover.seat < 0 or mover.seat == seat):
			held.append(mover)

	_hold()


## The hold is renewed every frame with exactly the time that is left, so the
## saws come back up on their own the moment the item runs out. A blade that was
## knocked out for longer by something else keeps its own longer stop
func _tick(_delta: float) -> void:
	_hold()


func _hold() -> void:
	for mover in held:
		if is_instance_valid(mover):
			mover.stall(time_left, frozen_dim)


func _stop(_cancelled: bool) -> void:
	held.clear()
