extends Node
class_name ElevatorSpawner

## The elevator scene to instantiate in place of a wall
@export var elevator_scene: PackedScene

## Reference to the MapGenerator, used to get the replaceable wall cells
@export var map_generator: MapGenerator

## The Node where the elevator spawns in as a child
@export var holder: Node3D

## Reference to the KeySpawner, the key has to be spawned first
@export var key_spawner: KeySpawner

## Reference to the PlayerSpawner, the player has to be spawned first
@export var player_spawner: PlayerSpawner

## Minimum number of steps through the maze between the exit and the key
@export var min_distance_to_key: int = 8

## Minimum number of steps through the maze between the exit and the player
@export var min_distance_to_player: int = 10

## How many candidate walls to store, 0 = all of them
@export var spawn_point_count: int = 0

## What share of the walls the exit is drawn from, counted from the far end. The
## minimums above only say how close is too close, and a map where nearly every
## wall clears them lets the exit land next to the key anyway. Sorting by how
## much room they keep and cutting the front off makes the second half of the
## level a walk of its own, on every attempt
@export_range(0.05, 1.0) var far_share: float = 0.3

## How many GridMap layers above the floor the elevator occupies
@export var height_in_cells: int = 2

## Extra rotation for models that do not face -Z
@export_range(-180.0, 180.0) var facing_offset_degrees: float = 0.0

## -1 = a different exit on every map, otherwise a fixed seed
@export var spawn_seed: int = -1

var rng := RandomNumberGenerator.new()

## Steps through the maze from the key and from the player start to every cell,
## both rebuilt once per map
var key_field: Array = []
var player_field: Array = []

## The stored candidate wall cells (grid coordinates)
var spawn_points: Array[Vector2i] = []

## The currently spawned elevator instance, if any
var current_elevator_instance: Node3D = null

## The wall cell the elevator replaced, only valid after spawn_elevator()
var current_elevator_cell: Vector2i = Vector2i.ZERO


## Collects and shuffles the walls the elevator could replace. Only walls that
## keep their distance to key and player get stored, so trimming the list down
## to spawn_point_count cannot throw the good ones away.
## Call this once per generated map, not on every death/retry.
func generate_spawn_points() -> void:
	spawn_points.clear()
	rng.seed = spawn_seed if spawn_seed >= 0 else randi()

	key_field = _walk_from(key_spawner.current_key_cell if key_spawner != null else Vector2i.ZERO, key_spawner != null)
	player_field = _walk_from(player_spawner.current_player_cell if player_spawner != null else Vector2i.ZERO, player_spawner != null)

	var wall_cells := map_generator.get_wall_cells_next_to_path()
	var far_cells := wall_cells.filter(_keeps_distances)

	if far_cells.is_empty():
		push_warning("ElevatorSpawner: no wall keeps the minimum distances, using the farthest ones")
		far_cells = wall_cells

	var pool := _far_end_of(far_cells)
	_shuffle(pool)

	var count: int = pool.size()
	if spawn_point_count > 0:
		count = min(spawn_point_count, count)

	for i in range(count):
		spawn_points.append(pool[i])


## The walls that keep the most room to key and player, never fewer than there
## are candidates to store
func _far_end_of(cells: Array[Vector2i]) -> Array[Vector2i]:
	var sorted := _by_distance_surplus(cells)
	var keep := maxi(maxi(spawn_point_count, 1), ceili(sorted.size() * far_share))
	sorted.resize(mini(keep, sorted.size()))
	return sorted


## Clears a wall that keeps its distance to key and player and puts the
## elevator there, facing the corridor
func spawn_elevator() -> void:
	if spawn_points.is_empty():
		push_error("ElevatorSpawner: no spawn points generated yet!")
		return

	if elevator_scene == null:
		push_warning("ElevatorSpawner: no elevator scene assigned, nothing to spawn")
		return

	if current_elevator_instance != null and is_instance_valid(current_elevator_instance):
		current_elevator_instance.queue_free()

	var chosen := _pick_cell()
	current_elevator_cell = chosen
	_clear_wall(chosen)

	current_elevator_instance = elevator_scene.instantiate()
	holder.add_child(current_elevator_instance)
	current_elevator_instance.global_position = _cell_to_world(chosen)
	current_elevator_instance.global_rotation.y = _facing_angle(chosen)

	if current_elevator_instance is Elevator:
		current_elevator_instance.set_grid_cell(map_generator.grid_map, chosen)


## Any of the stored candidates, they all keep the minimum distances
func _pick_cell() -> Vector2i:
	return spawn_points[rng.randi_range(0, spawn_points.size() - 1)]


## True when the cell is far enough from both the key and the player
func _keeps_distances(cell: Vector2i) -> bool:
	return _distance_surplus(cell) >= 0


## The same cells, the ones breaking the distances the least first
func _by_distance_surplus(cells: Array[Vector2i]) -> Array[Vector2i]:
	var sorted: Array[Vector2i] = cells.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _distance_surplus(a) > _distance_surplus(b))
	return sorted


## Steps from that cell to everywhere, empty while nothing spawned it and the
## exit is free to stand anywhere as far as it is concerned
func _walk_from(cell: Vector2i, spawned: bool) -> Array:
	return map_generator.path_distance_field(cell) if spawned else []


## Cells of room left over, negative means a minimum distance is broken. A wall
## with no way to it at all is pushed below everything else: the exit standing
## behind a blocked off corner would end the level before it starts
func _distance_surplus(cell: Vector2i) -> int:
	var surplus := 0x7FFFFFFF

	surplus = mini(surplus, _surplus_in(key_field, cell, min_distance_to_key))
	surplus = mini(surplus, _surplus_in(player_field, cell, min_distance_to_player))

	return surplus


## How much further than asked that cell is in one field, counted in steps
## through the maze. An empty field is one nothing was spawned for
func _surplus_in(field: Array, cell: Vector2i, minimum: int) -> int:
	if field.is_empty():
		return 0x7FFFFFFF

	var steps := map_generator.distance_in_field(field, cell)
	if steps < 0:
		return -0x7FFFFFFF

	return steps - minimum


## Removes the wall cell and every cell above it
func _clear_wall(cell: Vector2i) -> void:
	for y in range(1, height_in_cells + 1):
		map_generator.grid_map.set_cell_item(
			Vector3i(cell.x, y, cell.y), GridMap.INVALID_CELL_ITEM
		)


## The angle that turns the elevator towards the corridor next to it
func _facing_angle(cell: Vector2i) -> float:
	var neighbors := map_generator.get_path_neighbors(cell)
	if neighbors.is_empty():
		return deg_to_rad(facing_offset_degrees)

	var direction: Vector2i = neighbors[0] - cell
	return atan2(-float(direction.x), -float(direction.y)) + deg_to_rad(facing_offset_degrees)


## Array.shuffle() ignores spawn_seed because it draws from the global rng
func _shuffle(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap


## Converts a grid cell into the world position of the wall layer
func _cell_to_world(cell: Vector2i) -> Vector3:
	var local_pos: Vector3 = map_generator.grid_map.map_to_local(Vector3i(cell.x, 1, cell.y))
	return map_generator.grid_map.to_global(local_pos)
