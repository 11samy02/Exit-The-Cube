extends ItemEffect
class_name EchoEffect

## Returned when a spot has no corridor anywhere near it, which leaves the
## burst with nowhere to run
const INVALID_CELL := Vector2i(-1, -1)

## The cube calls out and the level answers. Every few seconds a burst of wave
## fronts leaves it and runs the corridors to whatever is being looked for, the
## key while it is still out there and the exit once it is carried.
##
## The waves take the shortest way through the maze, not the straight line, so
## what they draw on their way is the route itself. That is the difference to
## the arrow, which only ever says which direction the target lies in

## Seconds between two bursts
@export var interval: float = 3.0

## Wave fronts per burst
@export var rings_per_burst: int = 3

## Seconds between the fronts of one burst
@export var ring_delay: float = 0.09

## How fast a front travels in meters per second, well over the cube's own pace
@export var ring_speed: float = 14.0

## Radius of a front, a little under half a corridor
@export var ring_size: float = 0.55

## Meters a front fades out over before it reaches the target
@export var fade_distance: float = 3.0

@export var ring_color: Color = Color(0.4, 0.95, 1.0)

## How hard a front burns, the corridors are dark
@export var ring_glow: float = 3.0

## How high over the floor the fronts run, the cube is about half a cell tall
@export var ring_height: float = 0.9

var map_generator: MapGenerator = null

## Seconds until the next burst leaves the cube
var _next_burst: float = 0.0

## The route of the burst that is going out, and how many fronts of it are
## still waiting to leave
var _route: PackedVector3Array = PackedVector3Array()
var _rings_left: int = 0
var _next_ring: float = 0.0


func _start() -> void:
	map_generator = get_tree().get_first_node_in_group("map_generator") as MapGenerator
	if map_generator == null:
		push_warning("EchoEffect: no map generator in the level, the waves have no corridors to run")


## The route is looked up once per burst and every front of it runs the same
## one, so they read as a single wave rolling down the corridor. The fronts
## leave one after the other, counted down here instead of waited on, an item
## that ends mid burst simply stops sending
func _tick(delta: float) -> void:
	_next_burst -= delta
	if _next_burst <= 0.0:
		_next_burst = interval
		_route = _route_to_target()
		_rings_left = maxi(rings_per_burst, 1) if _route.size() >= 2 else 0
		_next_ring = 0.0

	if _rings_left <= 0:
		return

	_next_ring -= delta
	if _next_ring > 0.0:
		return

	_next_ring = ring_delay
	_rings_left -= 1
	_send_ring()


## The front is handed to the level and not kept as a child of the item. The
## last burst leaves shortly before the item runs out and would otherwise be
## taken off the screen halfway down the corridor
func _send_ring() -> void:
	var holder: Node = player.get_parent() if is_instance_valid(player) else self
	if holder == null:
		holder = self

	var ring := EchoRing.new()
	ring.fade_distance = fade_distance
	ring.top_level = true
	holder.add_child(ring)
	ring.launch(_route, ring_speed, ring_color, ring_size, ring_glow)


## The corners of the shortest way from the cube to what it is looking for,
## as world positions at wave height
func _route_to_target() -> PackedVector3Array:
	var points := PackedVector3Array()
	var target := _current_target()
	if map_generator == null or target == null or not is_instance_valid(player):
		return points

	var from := _corridor_cell(_cell_of(player.global_position))
	var to := _corridor_cell(_cell_of(target.global_position))
	if from == INVALID_CELL or to == INVALID_CELL:
		return points

	for cell in _walk(from, to):
		points.append(_world_of(cell))

	if not points.is_empty():
		points.append(Vector3(target.global_position.x, points[points.size() - 1].y, target.global_position.z))

	return points


## The cell the wave can actually travel through. The exit is built into a wall,
## so its own cell is never a corridor: the wave is sent to the corridor in
## front of it instead and only covers the last step over on its own
func _corridor_cell(cell: Vector2i) -> Vector2i:
	if map_generator.is_path_cell(cell):
		return cell

	var neighbors := map_generator.get_path_neighbors(cell)
	if neighbors.is_empty():
		return INVALID_CELL

	return neighbors[0]


## Breadth first over the walkable cells, which on an unweighted grid is the
## shortest way. The map is small enough that this is cheaper than keeping a
## navigation mesh in sync with it
func _walk(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	if from == to:
		return route

	var came_from := {from: from}
	var queue: Array[Vector2i] = [from]
	var found := false

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == to:
			found = true
			break

		for next in map_generator.get_path_neighbors(cell):
			if came_from.has(next):
				continue

			came_from[next] = cell
			queue.append(next)

	if not found:
		return route

	var step := to
	while step != from:
		route.push_front(step)
		step = came_from[step]

	route.push_front(from)
	return route


## The key while it is still out there, the exit once the cube carries it
func _current_target() -> Node3D:
	if not GameState.has_key:
		var key := get_tree().get_first_node_in_group("key") as Node3D
		if key != null:
			return key

	return get_tree().get_first_node_in_group("elevator") as Node3D


func _cell_of(position: Vector3) -> Vector2i:
	var grid := map_generator.grid_map
	var cell := grid.local_to_map(grid.to_local(position))
	return Vector2i(cell.x, cell.z)


func _world_of(cell: Vector2i) -> Vector3:
	var grid := map_generator.grid_map
	var point := grid.to_global(grid.map_to_local(Vector3i(cell.x, 0, cell.y)))
	point.y += grid.cell_size.y * 0.5 + ring_height
	return point
