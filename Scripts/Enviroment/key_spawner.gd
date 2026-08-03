extends Node
class_name KeySpawner

## The key scene to instantiate at a chosen spawn point
@export var key: PackedScene

## Reference to the MapGenerator, used to get all walkable cells
@export var map_generator: MapGenerator

## How many possible spawn positions to store (only one is actually used per spawn)
@export var spawn_point_count: int = 5

## The Node where the key spawns in as a child
@export var holder: Node3D

## Reference to the PlayerSpawner, the player has to be spawned first
@export var player_spawner: PlayerSpawner

## Minimum number of steps through the maze between the key and the player start
@export var min_distance_to_player: int = 8

## What share of the map the key is drawn from, counted from the far end. A
## minimum that most of the map already clears puts the key anywhere, and a key
## that can turn up around the first corner makes the level a lucky draw. The
## candidates are sorted by how far they are and only the far end is kept, so
## the walk is real without the key sitting in the same dead end every time
@export_range(0.05, 1.0) var far_share: float = 0.34

## -1 = new candidate positions on every map, otherwise a fixed seed
@export var spawn_seed: int = -1

var rng := RandomNumberGenerator.new()

## Steps through the maze from where the player starts to every cell of it,
## rebuilt once per map. Read through the MapGenerator, never indexed here
var player_field: Array = []

## The stored candidate spawn positions (grid coordinates)
var spawn_points: Array[Vector2i] = []

## The currently spawned key instance, if any
var current_key_instance: Node3D = null

## The cell the current key stands in, only valid after spawn_key() has run
var current_key_cell: Vector2i = Vector2i.ZERO


## Picks spawn_point_count random walkable cells and stores them as candidates.
## Call this once per generated map, not on every death/retry.
func generate_spawn_points() -> void:
	spawn_points.clear()
	rng.seed = spawn_seed if spawn_seed >= 0 else randi()

	player_field = _walk_from_player()

	var path_cells := map_generator.get_path_cells()
	var far_cells := path_cells.filter(_is_far_from_player)

	if far_cells.is_empty():
		push_warning("KeySpawner: no cell is %d steps from the player, using the farthest ones" \
			% min_distance_to_player)
		far_cells = path_cells

	var pool := _far_end_of(far_cells)
	_shuffle(pool)

	var count: int = min(spawn_point_count, pool.size())
	for i in range(count):
		spawn_points.append(pool[i])


## The far end of those cells, never fewer than there are candidates to store
func _far_end_of(cells: Array[Vector2i]) -> Array[Vector2i]:
	var sorted := _by_distance(cells)
	var keep := maxi(spawn_point_count, ceili(sorted.size() * far_share))
	sorted.resize(mini(keep, sorted.size()))
	return sorted


## Steps from the player start to everywhere, empty while nothing spawns the
## player and the key may go anywhere
func _walk_from_player() -> Array:
	if player_spawner == null:
		return []

	return map_generator.path_distance_field(player_spawner.current_player_cell)


## How far that cell is to walk to from the player start, -1 for one there is no
## way to. A map without a player start reads as far enough from everywhere
func _steps_to_player(cell: Vector2i) -> int:
	if player_field.is_empty():
		return min_distance_to_player

	return map_generator.distance_in_field(player_field, cell)


## True when the cell is far enough from where the player starts, counted in
## steps through the corridors and not across the walls between them
func _is_far_from_player(cell: Vector2i) -> bool:
	return _steps_to_player(cell) >= min_distance_to_player


## The same cells, the farthest from the player start first. What the fallback
## reaches for when the map is too small for the distance the level asks
func _by_distance(cells: Array[Vector2i]) -> Array[Vector2i]:
	var sorted: Array[Vector2i] = cells.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _steps_to_player(a) > _steps_to_player(b))
	return sorted


## Array.shuffle() ignores spawn_seed because it draws from the global rng
func _shuffle(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap


## Removes the current key instance (if any) and spawns a new one at a
## random position picked from the stored spawn_points.
func spawn_key() -> void:
	if spawn_points.is_empty():
		push_error("KeySpawner: no spawn points generated yet!")
		return

	if current_key_instance != null and is_instance_valid(current_key_instance):
		current_key_instance.queue_free()

	var chosen: Vector2i = spawn_points[rng.randi_range(0, spawn_points.size() - 1)]
	current_key_cell = chosen
	var world_pos := _cell_to_world(chosen)

	current_key_instance = key.instantiate()
	holder.add_child(current_key_instance)
	current_key_instance.global_position = world_pos


## Converts a grid cell coordinate into a world position, using the
## GridMap's own cell size and transform instead of guessing them
func _cell_to_world(cell: Vector2i) -> Vector3:
	var local_pos: Vector3 = map_generator.grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
	local_pos.y += 2
	return map_generator.grid_map.to_global(local_pos)
