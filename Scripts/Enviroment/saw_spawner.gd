extends Node
class_name SawSpawner

## The saw scene to instantiate, its root node must have SawMover attached
@export var saw_scene: PackedScene

## Reference to the MapGenerator, used to get walkable cells and neighbors
@export var map_generator: MapGenerator

## The Node where all saws spawn in as children
@export var holder: Node3D

## How many saws to spawn
@export var saw_count: int = 5

## How many waypoints a route has, rolled per saw between these two values
@export var min_patrol_length: int = 3
@export var max_patrol_length: int = 6

## Minimum and maximum random speed assigned per saw
@export var min_speed: float = 1.0
@export var max_speed: float = 3.0

## How many free cells stay between two routes, 0 = they may run side by side
@export var route_spacing: int = 1

## How often a saw goes looking for a closed route it can circle forever. This
## is the chance to try, not the share that comes out, a map without any rings
## left falls back to a normal patrol every time
@export_range(0.0, 1.0) var loop_chance: float = 0.5

## Reference to the PlayerSpawner, its cell is where the way has to start
@export var player_spawner: PlayerSpawner

## Reference to the KeySpawner, the key has to stay reachable
@export var key_spawner: KeySpawner

## Reference to the ElevatorSpawner, the exit has to stay reachable
@export var elevator_spawner: ElevatorSpawner

## -1 = a different saw layout on every call, otherwise a fixed seed
@export var spawn_seed: int = -1

@export_group("Hunters")

## The steered saw. It has no route of its own, it decides where to go while the
## level runs, so none of the tuning above applies to it
@export var ai_saw_scene: PackedScene

## How many of them to put into the level. Deliberately not part of a MapData:
## these are still being tried out, so they are switched on here on the node and
## no level can turn them on by itself
@export var ai_saw_count: int = 0

## Which mind they get. Empty rolls one per saw out of all of them, which is how
## they are meant to be watched next to each other
@export var ai_minds: Array[SawAi.Mind] = []

## How many steps through the corridors a steered saw has to start away from
## where the player comes in.
##
## Keeping it off the one spawn cell is not enough. It walks straight at the cube
## the moment the level opens, and the spawn animation still owns the cube for
## the first moment of it — so one that starts around the corner is not a hunter,
## it is a death the player was never in a position to do anything about
@export var ai_min_distance_to_player: int = 8

var rng := RandomNumberGenerator.new()

var spawned_saws: Array[Node3D] = []

## The routes that were rolled for this map, one entry per blade. A local race
## builds every one of them once per player, and rolling a second time would
## hand the second player a different maze
var _blueprints: Array[Dictionary] = []

## Grid cells taken by a route including its buffer, used as a set
var reserved_cells: Dictionary = {}

## Only the cells a saw actually sweeps, without the spacing buffer. A corridor
## is one cell wide, so a saw cannot be squeezed past and cannot be waited out
## either, its ping pong brings it straight back. Every cell in here counts as
## a wall when the level is checked for a way through.
var blocked_cells: Dictionary = {}


## Replaces all saws with fresh routes, behaviors and speeds. Routes never
## share a cell, so two saws can never overlap
func spawn_saws() -> void:
	_clear_saws()
	rng.seed = spawn_seed if spawn_seed >= 0 else randi()

	for i in range(saw_count):
		var path := _roll_route()
		if path.is_empty():
			push_warning("SawSpawner: no route left that is at least %d cells long and still leaves a way to key and exit, spawned %d of %d saws" \
				% [_patrol_minimum(), i, saw_count])
			break

		_reserve_route(path)

		var world_points: Array[Vector3] = []
		for cell in path:
			world_points.append(_cell_to_world(cell))

		_blueprints.append({
			"points": world_points,
			"behavior": _pick_behavior(path),
			"speed": rng.randf_range(min_speed, max_speed),
		})

	for at in range(_sets()):
		for plan: Dictionary in _blueprints:
			_build_saw(plan, at)

	_spawn_ai_saws()


## How many sets of blades the level gets. One everywhere but a local race,
## where every player runs their own — the routes are identical, so the maze is
## the same maze; what differs is whose item may touch which set
func _sets() -> int:
	return maxi(Seats.count(), 1) if Match.is_private_race() else 1


## One blade off a recorded plan. Nothing is rolled in here, so the second set
## walks exactly the corridors the first one does
func _build_saw(plan: Dictionary, seat: int) -> void:
	var saw: Node3D = saw_scene.instantiate()
	holder.add_child(saw)

	var mover: SawMover = _find_saw_mover(saw)
	if mover == null:
		push_error("SawSpawner: no SawMover found in saw scene!")
		saw.queue_free()
		return

	mover.behavior = int(plan["behavior"])
	mover.speed = float(plan["speed"])
	mover.set_waypoints(plan["points"])
	_hand_to_seat(saw, mover, seat)

	spawned_saws.append(saw)


## Ties a blade to one player: drawn on their layer, and deaf to every other
## cube. A saw is an area rather than a body, so being ignored is something the
## blade decides when somebody walks into it and not the physics server
func _hand_to_seat(saw: Node3D, mover: SawMover, seat: int) -> void:
	if not Match.is_private_race():
		return

	mover.seat = seat
	SeatView.mark(saw, SeatView.private_bit(seat))


## The steered saws go in after the patrolling ones and reserve nothing. They do
## not own a corridor, they walk the whole map, so there is nothing to keep the
## others out of and nothing about them that could shut the level off: they are
## never standing between the player and the key for longer than it takes them
## to move on
func _spawn_ai_saws() -> void:
	if ai_saw_scene == null or ai_saw_count <= 0:
		return

	var free_cells := _ai_start_cells()

	if free_cells.is_empty():
		push_warning("SawSpawner: no free cell left to put a steered saw in")
		return

	var plans: Array[Dictionary] = []

	for i in range(ai_saw_count):
		if free_cells.is_empty():
			free_cells = _ai_start_cells()

		var at := rng.randi_range(0, free_cells.size() - 1)

		plans.append({
			"mind": _roll_mind(i),
			"speed": rng.randf_range(min_speed, max_speed),
			"start": free_cells[at],
			"seed": rng.randi(),
		})

		free_cells.remove_at(at)

	for seat in range(_sets()):
		for plan in plans:
			_build_ai_saw(plan, seat)


## One steered blade off a recorded plan, so every player's set thinks the same
## thoughts from the same corner
func _build_ai_saw(plan: Dictionary, seat: int) -> void:
	var saw: Node3D = ai_saw_scene.instantiate()
	holder.add_child(saw)

	var brain: SawAi = _find_saw_ai(saw)
	if brain == null:
		push_error("SawSpawner: no SawAi found in the steered saw scene!")
		saw.queue_free()
		return

	brain.mind = int(plan["mind"])
	brain.key_spawner = key_spawner
	brain.elevator_spawner = elevator_spawner

	var mover: SawMover = _find_saw_mover(saw)
	if mover != null:
		mover.speed = float(plan["speed"])
		_hand_to_seat(saw, mover, seat)

	brain.setup(map_generator, plan["start"] as Vector2i, int(plan["seed"]))
	spawned_saws.append(saw)


## Where a steered saw may be dropped in: a free corridor cell a real walk away
## from where the player comes in.
##
## The distance is counted through the corridors and not across the grid. Two
## cells with a wall between them are neighbours on the grid and a long way apart
## on foot, and it is the walk that decides whether the player gets to react at
## all — measuring across the grid is how a saw ends up one corner away with a
## wall in between and still counted as far off.
##
## A map too small to keep that distance anywhere falls back to whatever cells
## are farthest off rather than giving up, the same way the key and the exit do
func _ai_start_cells() -> Array:
	var free_cells: Array = map_generator.get_path_cells().filter(
		func(c): return not blocked_cells.has(c)
	)

	if player_spawner == null or free_cells.is_empty():
		return free_cells

	var field := map_generator.path_distance_field(_player_cell())
	var far := free_cells.filter(
		func(c): return map_generator.distance_in_field(field, c) >= ai_min_distance_to_player
	)

	if not far.is_empty():
		return far

	push_warning("SawSpawner: no cell is %d steps from the player, starting the steered saws at the farthest ones" \
		% ai_min_distance_to_player)
	return _farthest_from_player(free_cells, field)


## The quarter of those cells that is farthest from the player, never fewer than
## one. Only reached on a map that cannot honour the distance at all
func _farthest_from_player(cells: Array, field: Array) -> Array:
	var sorted := cells.duplicate()

	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return map_generator.distance_in_field(field, a) > map_generator.distance_in_field(field, b))

	sorted.resize(maxi(1, sorted.size() / 4))
	return sorted


## Which mind the saw at that position gets. The list on the node wins when it
## is filled in. Otherwise they are dealt out one each while there are minds
## left, so a level with a handful of them shows different behaviour rather than
## three of the same drawn by chance, and only rolls freely once they run out
func _roll_mind(index: int) -> SawAi.Mind:
	if not ai_minds.is_empty():
		return ai_minds[index % ai_minds.size()]

	var minds := SawAi.Mind.values()
	if index < minds.size():
		return minds[index]

	return minds[rng.randi_range(0, minds.size() - 1)]


## Where the player starts, the cell every steered saw is kept a walk away from
func _player_cell() -> Vector2i:
	return player_spawner.current_player_cell if player_spawner != null else Vector2i(-1, -1)


func _find_saw_ai(node: Node) -> SawAi:
	if node is SawAi:
		return node

	for child in node.get_children():
		var found := _find_saw_ai(child)
		if found != null:
			return found

	return null


## Rolls what kind of route this saw gets. A ring is looked for on purpose, a
## random walk would only close by accident, so leaving it to chance means
## almost every saw ends up going back and forth
func _roll_route() -> Array[Vector2i]:
	if rng.randf() < loop_chance:
		var ring := _generate_loop_path()
		if not ring.is_empty():
			return ring

	return _generate_patrol_path()


## LOOP only works on a closed route, on an open one the way back from the
## last waypoint to the first would cut through the walls
func _pick_behavior(route: Array[Vector2i]) -> SawMover.Behavior:
	return SawMover.Behavior.LOOP if _is_closed_route(route) else SawMover.Behavior.PING_PONG


## True when the last cell of the route is directly adjacent to the first one
func _is_closed_route(route: Array[Vector2i]) -> bool:
	if route.size() < 3:
		return false

	return map_generator.get_path_neighbors(route[route.size() - 1]).has(route[0])


func _find_saw_mover(node: Node) -> SawMover:
	if node is SawMover:
		return node

	for child in node.get_children():
		var found := _find_saw_mover(child)
		if found != null:
			return found

	return null


func _clear_saws() -> void:
	for saw in spawned_saws:
		if is_instance_valid(saw):
			saw.queue_free()
	spawned_saws.clear()
	_blueprints.clear()
	reserved_cells.clear()
	blocked_cells.clear()


## Blocks the route and its buffer so the next saw cannot touch it
func _reserve_route(route: Array[Vector2i]) -> void:
	for cell in route:
		blocked_cells[cell] = true
		for dx in range(-route_spacing, route_spacing + 1):
			for dz in range(-route_spacing, route_spacing + 1):
				if abs(dx) + abs(dz) <= route_spacing:
					reserved_cells[cell + Vector2i(dx, dz)] = true


## Prefers a route past a junction, otherwise takes the longest one found.
## Anything below the minimum length is rejected
func _generate_patrol_path() -> Array[Vector2i]:
	var free_cells := map_generator.get_path_cells().filter(
		func(c): return not reserved_cells.has(c)
	)
	if free_cells.is_empty():
		return []

	var minimum := _patrol_minimum()
	var best_fallback: Array[Vector2i] = []
	var attempts := 120
	while attempts > 0:
		attempts -= 1
		var start: Vector2i = free_cells[rng.randi_range(0, free_cells.size() - 1)]
		var path := _walk_from(start, _roll_patrol_length())
		if path.size() < minimum:
			continue
		if not _keeps_level_solvable(path):
			continue
		if _has_branch_point(path):
			return path
		if path.size() > best_fallback.size():
			best_fallback = path

	return best_fallback


## Hunts for a route the saw can circle forever. Same rules as a patrol route,
## it just has to come back to where it started
func _generate_loop_path() -> Array[Vector2i]:
	var free_cells := map_generator.get_path_cells().filter(
		func(c): return not reserved_cells.has(c)
	)
	if free_cells.is_empty():
		return []

	var attempts := 120
	while attempts > 0:
		attempts -= 1
		var start: Vector2i = free_cells[rng.randi_range(0, free_cells.size() - 1)]
		var ring := _loop_through(start)
		if ring.is_empty():
			continue
		if not _keeps_level_solvable(ring):
			continue

		return ring

	return []


## Walks from one neighbor of the cell around to another one without ever
## touching the cell itself, that detour plus the cell is the ring. Every pair
## of neighbors gives the tightest ring between those two, of those the longest
## one that still fits the rolled length is taken
func _loop_through(cell: Vector2i) -> Array[Vector2i]:
	var doors := _free_neighbors(cell, {})
	if doors.size() < 2:
		return []

	var longest := _roll_patrol_length()
	var best: Array[Vector2i] = []

	for i in range(doors.size()):
		for j in range(i + 1, doors.size()):
			var door_in: Vector2i = doors[i]
			var door_out: Vector2i = doors[j]
			var detour := _walk_around(door_in, door_out, cell, longest - 1)
			if detour.is_empty():
				continue

			var ring: Array[Vector2i] = [cell]
			ring.append_array(detour)
			if ring.size() >= _patrol_minimum() and ring.size() > best.size():
				best = ring

	return best


## Shortest way between two cells that leaves the blocked one out, breadth
## first so the ring stays tight around the walls instead of wandering off.
## The cell limit is what keeps the search local, without it every failed
## attempt would sweep the whole map
func _walk_around(from: Vector2i, to: Vector2i, blocked: Vector2i, max_cells: int) -> Array[Vector2i]:
	if max_cells < 2:
		return []

	var forbidden := {blocked: true}
	var came_from := {from: from}
	var depth := {from: 1}
	var queue: Array[Vector2i] = [from]

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == to:
			return _trace_back(came_from, from, to)
		if depth[cell] >= max_cells:
			continue

		for neighbor in _free_neighbors(cell, forbidden):
			if came_from.has(neighbor):
				continue

			came_from[neighbor] = cell
			depth[neighbor] = depth[cell] + 1
			queue.append(neighbor)

	return []


## Unrolls the breadth first search back into a route, from first to last
func _trace_back(came_from: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = [to]

	while route[route.size() - 1] != from:
		route.append(came_from[route[route.size() - 1]])

	route.reverse()
	return route


## True when the player can still walk from the spawn to the key and on to the
## exit once this route and every route placed before it counts as a wall.
## The check is deliberately strict: it treats the whole patrol as blocked
## rather than the single cell the saw happens to sit on, because a saw sweeps
## its entire route and there is no moment where the corridor is clear.
func _keeps_level_solvable(route: Array[Vector2i]) -> bool:
	if player_spawner == null:
		return true

	var blocked := blocked_cells.duplicate()
	for cell in route:
		blocked[cell] = true

	var start: Vector2i = player_spawner.current_player_cell
	if blocked.has(start):
		return false

	var reached := _reachable_from(start, blocked)

	if key_spawner != null and not reached.has(key_spawner.current_key_cell):
		return false

	if elevator_spawner != null and not _reaches_elevator(reached):
		return false

	return true


## The elevator replaces a wall, so it is not walkable itself. Reaching any of
## the corridor cells in front of it is enough.
func _reaches_elevator(reached: Dictionary) -> bool:
	var doors := map_generator.get_path_neighbors(elevator_spawner.current_elevator_cell)
	if doors.is_empty():
		return true

	for cell in doors:
		if reached.has(cell):
			return true

	return false


## Flood fill over the walkable cells, every blocked cell counts as a wall
func _reachable_from(start: Vector2i, blocked: Dictionary) -> Dictionary:
	var reached := {start: true}
	var queue: Array[Vector2i] = [start]

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for neighbor in map_generator.get_path_neighbors(cell):
			if reached.has(neighbor) or blocked.has(neighbor):
				continue
			reached[neighbor] = true
			queue.append(neighbor)

	return reached


## The hard lower bound for a route, two cells is the absolute minimum
func _patrol_minimum() -> int:
	return maxi(2, min_patrol_length)


## The waypoint count for a single saw, safe against a flipped min/max
func _roll_patrol_length() -> int:
	var lowest := _patrol_minimum()
	var highest: int = maxi(lowest, max_patrol_length)
	return rng.randi_range(lowest, highest)


## Grows a route using depth first search, stepping back out of dead ends
## instead of giving up. Every route cell keeps its own list of untried branches
func _walk_from(start: Vector2i, target_length: int) -> Array[Vector2i]:
	var route: Array[Vector2i] = [start]
	var visited := {start: true}
	var branches: Array = [_free_neighbors(start, visited)]

	while route.size() < target_length:
		var options: Array = branches[branches.size() - 1]

		if options.is_empty():
			if route.size() == 1:
				break
			branches.pop_back()
			route.pop_back()
			continue

		var next: Vector2i = options.pop_at(rng.randi_range(0, options.size() - 1))
		if visited.has(next):
			continue

		route.append(next)
		visited[next] = true
		branches.append(_free_neighbors(next, visited))

	return route


## Walkable neighbors that are neither reserved nor already in the route
func _free_neighbors(cell: Vector2i, visited: Dictionary) -> Array:
	return map_generator.get_path_neighbors(cell).filter(
		func(n): return not visited.has(n) and not reserved_cells.has(n)
	)


func _has_branch_point(path: Array[Vector2i]) -> bool:
	for cell in path:
		if map_generator.get_path_neighbors(cell).size() >= 3:
			return true
	return false


## Converts a grid cell coordinate into a world position, using the
## GridMap's own cell size and transform instead of guessing them
func _cell_to_world(cell: Vector2i) -> Vector3:
	var local_pos: Vector3 = map_generator.grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
	local_pos.y += 2
	return map_generator.grid_map.to_global(local_pos)
