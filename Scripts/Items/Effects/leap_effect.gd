extends ItemEffect
class_name LeapEffect

## One jump, high enough to clear the walls. The only item that works the same
## in the campaign as it does online — nothing about it involves anybody else.
##
## The height is in blocks rather than metres so it stays right whatever the
## grid is set to: at 2.25 the cube tops out above a wall and can come down on
## the roof of the maze

## How many blocks high the leap goes
@export var blocks: float = 2.25

## Seconds the cube may still take off after leaving the floor, so a jump asked
## for a frame late is not silently dropped
@export var coyote_time: float = 0.12

var _movement: PlayerMovement = null
var _launched: bool = false
var _waited: float = 0.0


func _start() -> void:
	_movement = get_tree().get_first_node_in_group("player_movement") as PlayerMovement
	if _movement == null or _movement.body == null:
		stop(false)
		return

	show_vignette(0.6)
	_try_launch()


## Waits for the floor if the cube happens to be in the air when it is spent,
## then gives up rather than hanging on to a jump that never comes
func _tick(delta: float) -> void:
	if _launched:
		return

	_waited += delta
	if _waited > coyote_time:
		_try_launch()


func _try_launch() -> void:
	if not is_instance_valid(_movement) or _movement.body == null:
		stop(false)
		return

	_launched = true
	_movement.launch(_take_off_speed())
	stop(false)


## What it takes to reach that height against the gravity the cube falls under.
## Worked out rather than tuned, so changing either number keeps the other true
func _take_off_speed() -> float:
	var grid := get_tree().get_first_node_in_group("map_generator") as MapGenerator
	var block := grid.grid_map.cell_size.y if grid != null and grid.grid_map != null else 2.0
	return sqrt(2.0 * _movement.gravity * blocks * block)
