extends Node
class_name SawAi

## Steers a saw that has no route of its own. A patrolling blade is a piece of
## the level: it is always in the same corridor and the player learns it once.
## This one picks where it wants to be and walks there, so it has to be read
## while it is happening instead of memorised.
##
## The AI only ever decides on a cell to reach. Walking there is the SawMover's
## job, and it is handed one leg at a time: a route through the corridors to the
## target, walked to its end, then this is asked again. That keeps the blade on
## the grid, so it can never cut a corner through a wall, and it means the route
## item draws exactly what the saw is about to do.

## What the saw wants
enum Mind {
	## Runs the player down while it can see them, holds on to where they went
	## when it loses them, and looks around there before giving up
	HUNTER,
	## Picks somewhere on the map, walks there, picks somewhere else
	WANDERER,
	## Aims at where the player is going rather than where they are, so it comes
	## down the corridor the player was about to take
	AMBUSHER,
	## Circles whatever the player needs next, the key first and the exit once
	## the key is taken. It does not chase, it sits on the way out
	WARDEN,
	## Walks the map down, always heading for whatever corner it has left alone
	## the longest. Nothing stays a safe spot for two visits
	SWEEPER,
}

## The saw this drives, it does the walking
@export var mover: SawMover

## What this one does. Rolled by the spawner when it is left on HUNTER there,
## set here to pin a single behaviour down while testing one of them
@export var mind: Mind = Mind.HUNTER

@export_group("Senses")

## How far the saw sees, in cells. Line of sight is taken through the corridors,
## a player behind a wall is not seen however close they are
@export var sight_range: int = 12

## Seconds a lost player is hunted at their last known cell before the saw gives
## up on them and falls back to what it does when it sees nothing
@export var memory_time: float = 4.0

@export_group("Routes")

## How many cells one leg of a route may be. Short legs mean the saw rethinks
## often and follows the player around corners, long ones make it commit
@export var route_length: int = 14

## Seconds between two rethinks while the saw has the player in sight. Without
## it a chasing saw would replan every frame for no gain
@export var chase_interval: float = 0.35

## Seconds between two rethinks while it does not
@export var idle_interval: float = 1.2

## Shortest gap between two rethinks when the saw ran out of route rather than
## out of time. The intervals above are for changing its mind on the way, and
## making a saw that has arrived sit through one of them is what left it
## standing in a corner for a second at a time. This is only here to keep a saw
## whose target is a step away from searching the map every frame
@export var min_think_gap: float = 0.15

@export_group("Guarding")

## How far around the key or the exit a WARDEN stays, in cells
@export var guard_radius: int = 6

## The map this saw reads, handed over by the spawner
var map_generator: MapGenerator = null

## Where the player has to be walked to from, handed over by the spawner. Both
## may stay empty, a saw without them simply has nothing to guard
var key_spawner: KeySpawner = null
var elevator_spawner: ElevatorSpawner = null

## Its own rng so a level with a seed builds the same saws every time
var rng := RandomNumberGenerator.new()

## The cell the player was last actually seen in, and how long that is still
## worth walking to
var _last_seen: Vector2i = Vector2i.ZERO
var _memory_left: float = 0.0

## Seconds until the saw thinks again, and how long since it last did
var _think_timer: float = 0.0
var _since_think: float = 0.0

## How long ago the SWEEPER was in a cell, by cell. A cell it has never been in
## is not in here at all and counts as the longest ago of them all
var _visited: Dictionary = {}

## Counts up so the SWEEPER has something to order its visits by
var _clock: float = 0.0


## Called by the spawner once the map and everything in it stands. Nothing works
## before this, the saw has no idea what it is walking on until then
func setup(generator: MapGenerator, start_cell: Vector2i, seed_value: int) -> void:
	map_generator = generator
	rng.seed = seed_value

	if mover == null:
		push_error("SawAi: no SawMover assigned, the saw has nobody to steer")
		return

	mover.behavior = SawMover.Behavior.ONCE
	mover.parent.global_position = _to_world(start_cell)
	_think()


func _process(delta: float) -> void:
	if map_generator == null:
		return

	_clock += delta
	_since_think += delta
	_memory_left = maxf(_memory_left - delta, 0.0)
	_visited[_cell_of_saw()] = _clock

	_think_timer -= delta

	if _think_timer <= 0.0 or (mover.route_done and _since_think >= min_think_gap):
		_think()


## Picks where to go and hands the way there to the saw.
##
## A target that is already reached, or one there is no way to, leaves the saw
## on a route it has finished with, and that route was very likely the one that
## walked it away from whatever it now wants. So it asks for somewhere else
## rather than keeping it: standing still would be better than running off, and
## going somewhere at all is better than either
func _think() -> void:
	_think_timer = chase_interval if _sees_player() else idle_interval
	_since_think = 0.0

	var route := _route_to(_target())
	if route.size() < 2:
		route = _route_to(_anywhere())
	if route.size() < 2:
		return

	var points: Array[Vector3] = []
	for cell in route:
		points.append(_to_world(cell))

	mover.set_waypoints(points, true)


## Where this saw wants to be, the one thing the five minds disagree on
func _target() -> Vector2i:
	match mind:
		Mind.HUNTER:
			return _hunt()
		Mind.WANDERER:
			return _anywhere()
		Mind.AMBUSHER:
			return _ahead_of_player()
		Mind.WARDEN:
			return _around_objective()
		Mind.SWEEPER:
			return _longest_untouched()

	return _anywhere()


## Straight at the player while they are in sight, at the corner they were last
## seen going around for a while after that, and searching that end of the map
## once even that has gone cold.
##
## The search is the point. Giving up on a lost player by picking a cell at
## random sends the blade off across the map, which from the player's side of it
## reads as the saw losing interest and walking away the moment it had them
func _hunt() -> Vector2i:
	if _sees_player():
		_last_seen = _cell_of_player()
		_memory_left = memory_time
		return _last_seen

	if _memory_left > 0.0:
		return _last_seen

	return _somewhere_around(_last_seen, sight_range)


## A corridor cell within that many steps of a place worth looking at, or
## anywhere at all when there is no such place yet
func _somewhere_around(middle: Vector2i, reach: int) -> Vector2i:
	if not map_generator.is_path_cell(middle):
		return _anywhere()

	var field := map_generator.path_distance_field(middle)
	var near: Array[Vector2i] = []

	for cell in map_generator.get_path_cells():
		var steps := map_generator.distance_in_field(field, cell)
		if steps > 0 and steps <= reach:
			near.append(cell)

	if near.is_empty():
		return _anywhere()

	return near[rng.randi_range(0, near.size() - 1)]


## Any corridor cell of the map, which is the whole of what a WANDERER wants
func _anywhere() -> Vector2i:
	var cells := map_generator.get_path_cells()
	if cells.is_empty():
		return _cell_of_saw()

	return cells[rng.randi_range(0, cells.size() - 1)]


## The cell the player is walking into rather than the one they are in. Running
## at where somebody is only ever arrives behind them, so this one reads the
## direction off their speed and aims a few cells down it. A player who is
## standing still is not going anywhere and is aimed at directly
func _ahead_of_player() -> Vector2i:
	var player := _player()
	if player == null:
		return _anywhere()

	var drift := Vector2(player.velocity.x, player.velocity.z)
	if drift.length() < 0.5:
		return _cell_of_player()

	var lead := route_length / 2
	var step := drift.normalized() * lead
	var guess := _cell_of_player() + Vector2i(roundi(step.x), roundi(step.y))

	return _nearest_corridor(guess)


## Whatever the player still has to reach: the key while they are without it,
## the exit once they carry it. The saw does not stand on it, it circles it, so
## the way to it is covered rather than the spot itself
func _around_objective() -> Vector2i:
	var objective := _objective_cell()
	if objective.x < 0:
		return _anywhere()

	return _somewhere_around(objective, guard_radius)


## The cell that has gone the longest without this saw in it, out of the ones
## close enough to be worth walking to. Without the reach the sweeper would
## spend its life crossing the map instead of sweeping it
func _longest_untouched() -> Vector2i:
	var here := _cell_of_saw()
	var field := map_generator.path_distance_field(here)
	var stalest: Array[Vector2i] = []
	var oldest := INF

	for cell in map_generator.get_path_cells():
		var steps := map_generator.distance_in_field(field, cell)
		if steps <= 0 or steps > route_length:
			continue

		var seen: float = _visited.get(cell, -INF)
		if seen < oldest:
			oldest = seen
			stalest = [cell]
		elif seen == oldest:
			stalest.append(cell)

	if stalest.is_empty():
		return _anywhere()

	return stalest[rng.randi_range(0, stalest.size() - 1)]


## The way from the cell the saw is walking into to that cell, cut off at
## route_length so one leg stays short enough to be rethought on the way. Walked
## down a distance field from the target, which is the shortest way there by
## construction
func _route_to(target: Vector2i) -> Array[Vector2i]:
	var here := _committed_cell()
	if target == here or not map_generator.is_path_cell(here):
		return []

	var field := map_generator.path_distance_field(target)
	if map_generator.distance_in_field(field, here) < 0:
		return []

	var route: Array[Vector2i] = [here]
	var cell := here

	while cell != target and route.size() <= route_length:
		var next := _downhill_from(cell, field)
		if next == cell:
			break

		route.append(next)
		cell = next

	return route


## The neighbour that is one step closer to whatever the field was built from
func _downhill_from(cell: Vector2i, field: Array) -> Vector2i:
	var here := map_generator.distance_in_field(field, cell)

	for neighbour in map_generator.get_path_neighbors(cell):
		if map_generator.distance_in_field(field, neighbour) == here - 1:
			return neighbour

	return cell


## True while nothing but open corridor stands between the saw and the player.
## The line is walked cell by cell instead of asked of the physics, the maze is
## a grid and a wall is a cell, so this is both cheaper and exact
func _sees_player() -> bool:
	var player := _player()
	if player == null:
		return false

	var from := _cell_of_saw()
	var to := _cell_of_player()

	if absi(from.x - to.x) + absi(from.y - to.y) > sight_range:
		return false

	return _clear_line(from, to)


## Steps along the line between two cells and stops at the first wall
func _clear_line(from: Vector2i, to: Vector2i) -> bool:
	var span := Vector2(to - from)
	var steps := int(maxf(absf(span.x), absf(span.y)))

	if steps == 0:
		return true

	for i in range(1, steps + 1):
		var point := Vector2(from) + span * (float(i) / steps)
		var cell := Vector2i(roundi(point.x), roundi(point.y))
		if not map_generator.is_path_cell(cell):
			return false

	return true


## The corridor cell closest to a guess that may well be inside a wall or off
## the map, which is what aiming ahead of a moving player produces
func _nearest_corridor(guess: Vector2i) -> Vector2i:
	if map_generator.is_path_cell(guess):
		return guess

	var nearest := _cell_of_player()
	var shortest := 0x7FFFFFFF

	for cell in map_generator.get_path_cells():
		var gap := absi(cell.x - guess.x) + absi(cell.y - guess.y)
		if gap < shortest:
			shortest = gap
			nearest = cell

	return nearest


## The cell the player still has to get to. The exit is a wall and cannot be
## stood in, so the corridor in front of it is what stands for it. Negative
## while the level has neither, which is what a map opened without them looks
## like
func _objective_cell() -> Vector2i:
	if not GameState.has_key and key_spawner != null:
		return key_spawner.current_key_cell

	if elevator_spawner == null:
		return Vector2i(-1, -1)

	var doors := map_generator.get_path_neighbors(elevator_spawner.current_elevator_cell)
	return doors[0] if not doors.is_empty() else Vector2i(-1, -1)


func _player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _cell_of_player() -> Vector2i:
	var player := _player()
	return _cell_of(player.global_position) if player != null else _cell_of_saw()


func _cell_of_saw() -> Vector2i:
	return _cell_of(mover.parent.global_position)


## The cell the saw is already walking into, which is where a new route has to
## start. Starting it from wherever the blade happens to be is what made it jerk
## about: a saw that has just left a cell is still nearest to it, so every
## rethink handed it a route beginning behind itself and it turned around on the
## spot to get there. From the cell it is committed to, a new plan is a change of
## mind at the next corner and never a step backwards in the middle of a corridor
func _committed_cell() -> Vector2i:
	if mover.target_index >= 0 and mover.target_index < mover.waypoints.size():
		return _cell_of(mover.waypoints[mover.target_index])

	return _cell_of_saw()


func _cell_of(world: Vector3) -> Vector2i:
	var grid := map_generator.grid_map
	var cell := grid.local_to_map(grid.to_local(world))
	return Vector2i(cell.x, cell.z)


func _to_world(cell: Vector2i) -> Vector3:
	var grid := map_generator.grid_map
	return grid.to_global(grid.map_to_local(Vector3i(cell.x, 1, cell.y)))
