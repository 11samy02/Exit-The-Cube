extends Node
class_name PlayerSpawner

## The player scene to instantiate at a chosen spawn point
@export var player_scene: PackedScene

## Reference to the MapGenerator, used to get all walkable cells
@export var map_generator: MapGenerator

## How many possible spawn positions to store (only one is actually used per spawn)
@export var spawn_point_count: int = 5

## The Node where the player spawns in as a child
@export var holder: Node3D

## Height the player is dropped in at, from there it falls onto the floor
@export var spawn_height: float = 3.0

## -1 = new candidate positions on every map, otherwise a fixed seed
@export var spawn_seed: int = -1

var rng := RandomNumberGenerator.new()

## The stored candidate spawn positions (grid coordinates)
var spawn_points: Array[Vector2i] = []

## The currently spawned player instance, if any
var current_player_instance: Node3D = null

## The cell the current player started in, only valid after spawn_player()
var current_player_cell: Vector2i = Vector2i.ZERO


## Picks spawn_point_count random walkable cells and stores them as candidates.
## Call this once per generated map, not on every death/retry.
func generate_spawn_points() -> void:
	spawn_points.clear()
	rng.seed = spawn_seed if spawn_seed >= 0 else randi()

	var path_cells := map_generator.get_path_cells()
	_shuffle(path_cells)
	var count: int = min(spawn_point_count, path_cells.size())
	for i in range(count):
		spawn_points.append(path_cells[i])


## Removes the current player (if any) and spawns a new one at a random
## position picked from the stored spawn_points
func spawn_player() -> void:
	if spawn_points.is_empty():
		push_error("PlayerSpawner: no spawn points generated yet!")
		return

	if player_scene == null:
		push_warning("PlayerSpawner: no player scene assigned, nothing to spawn")
		return

	if current_player_instance != null and is_instance_valid(current_player_instance):
		current_player_instance.queue_free()

	current_player_cell = spawn_points[rng.randi_range(0, spawn_points.size() - 1)]

	current_player_instance = player_scene.instantiate()
	holder.add_child(current_player_instance)
	current_player_instance.global_position = cell_to_world(current_player_cell)


## Array.shuffle() ignores spawn_seed because it draws from the global rng
func _shuffle(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap


## Converts a grid cell into a world position above the floor, the player
## drops down from there on its own
func cell_to_world(cell: Vector2i) -> Vector3:
	var local_pos: Vector3 = map_generator.grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
	local_pos.y = spawn_height
	return map_generator.grid_map.to_global(local_pos)
