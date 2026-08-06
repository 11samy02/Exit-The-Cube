extends ItemEffect
class_name SawPathEffect

## Draws the routes of the blades around the cube while this runs, but only the
## ones close enough to be walked into. Every route in the level at once reads
## as a finished map of it and takes the reading of the level off the player, a
## circle that travels with the cube only ever answers what is coming up next

## How far the routes are read out, in meters. A blade whose whole route stays
## outside of this keeps it to itself
@export var reveal_radius: float = 14.0

## How much further a route that is already drawn may drift before it is dropped
## again. Without it a saw sitting right on the edge would flicker its route on
## and off from one step to the next
@export var release_margin: float = 3.0

## Only the saws this effect switched on, one that was already showing its route
## is left alone in both directions
var revealed: Array[SawMover] = []


func _start() -> void:
	_update_routes()


func _tick(_delta: float) -> void:
	_update_routes()


func _stop(_cancelled: bool) -> void:
	for mover in revealed:
		if is_instance_valid(mover):
			mover.show_path = false

	revealed.clear()


## Walks every blade in the level and switches its route on or off by how far it
## is. Writing show_path rebuilds the route mesh, so it is only written when the
## answer actually changed and not on every frame the saw stays in reach
func _update_routes() -> void:
	if not is_instance_valid(player):
		return

	var from := player.global_position

	for node in get_tree().get_nodes_in_group("saw_mover"):
		var mover := node as SawMover
		if mover == null or (mover.seat >= 0 and mover.seat != seat):
			continue

		var mine := revealed.has(mover)
		if not mine and mover.show_path:
			continue

		var reach := reveal_radius + release_margin if mine else reveal_radius
		var close := _route_distance(mover, from) <= reach

		if close and not mine:
			mover.show_path = true
			revealed.append(mover)
		elif not close and mine:
			mover.show_path = false
			revealed.erase(mover)


## How far the nearest point of that route is. What the player has to see coming
## is the corridor the blade sweeps and not the blade itself, so a saw at the
## far end of a route that runs past the cube is worth drawing
func _route_distance(mover: SawMover, from: Vector3) -> float:
	var nearest := INF

	if mover.parent != null:
		nearest = from.distance_to(mover.parent.global_position)

	for point in mover.waypoints:
		nearest = minf(nearest, from.distance_to(point))

	return nearest
