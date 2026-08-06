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

@export_group("Take off")

## How wide the ring the cube pushes off spreads, in meters
@export var ring_reach: float = 2.6

## Seconds that ring takes to run out and fade
@export var ring_time: float = 0.5

## How many rings go out, one after the other, so the ground reads as being
## shoved rather than flashed at
@export var ring_count: int = 2

## Seconds between them
@export var ring_delay: float = 0.09

## The colour the shove is drawn in
@export var ring_color: Color = Color(0.45, 0.95, 1.0)

var _movement: PlayerMovement = null
var _launched: bool = false
var _waited: float = 0.0


func _start() -> void:
	_movement = player.movement if player != null else null
	if _movement == null or _movement.body == null:
		stop(false)
		return

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
	_shove_the_ground()
	stop(false)


## Rings running out from under the cube as it goes up. They hang under the
## level rather than under this effect, which is gone the same frame the jump
## is spent — and they are handed to the owner's own layer, so a leap in a race
## read as your own is not a flash in somebody else's corridor
func _shove_the_ground() -> void:
	var holder := player.get_parent()
	if holder == null:
		return

	var floor_point := player.global_position - Vector3.UP * 0.45

	for at in range(maxi(ring_count, 1)):
		var ring := BurstRing.burst(holder, floor_point, ring_color,
			ring_reach * (1.0 + 0.35 * at), ring_time, false, ring_delay * at)
		claim(ring)


## What it takes to reach that height against the gravity the cube falls under.
## Worked out rather than tuned, so changing either number keeps the other true
func _take_off_speed() -> float:
	var grid := get_tree().get_first_node_in_group("map_generator") as MapGenerator
	var block := grid.grid_map.cell_size.y if grid != null and grid.grid_map != null else 2.0
	return sqrt(2.0 * _movement.gravity * blocks * block)
