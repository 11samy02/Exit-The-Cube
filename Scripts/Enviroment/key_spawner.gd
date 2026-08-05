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

## How far apart keys sharing one cell hang, in meters. Inside the cell, so none
## of them ends up inside a wall
const KEY_RING := 0.5

var rng := RandomNumberGenerator.new()

## Steps through the maze from where the player starts to every cell of it,
## rebuilt once per map. Read through the MapGenerator, never indexed here
var player_field: Array = []

## The stored candidate spawn positions (grid coordinates)
var spawn_points: Array[Vector2i] = []

## The currently spawned key instance, if any. With one key per cube this is the
## first of them, which is what the saws and the elevator place themselves by
var current_key_instance: Node3D = null

## Every key in the level, one per entry in the accounts it was given
var current_keys: Array[Key] = []

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
	spawn_keys([])


## One key per account, or a single unowned one when the list is empty, which is
## what the campaign and an online race both want.
##
## They all go into the one cell this spawner drew. A key each in a corner each
## would make the race a draw for who got the short walk — everybody starts on
## the same tile, so everybody's way out has to start on the same tile too. Only
## the last step is theirs alone: the keys sit in a small ring and each one is
## deaf to everybody but its owner
func spawn_keys(accounts: Array[int]) -> void:
	if spawn_points.is_empty():
		push_error("KeySpawner: no spawn points generated yet!")
		return

	for existing in current_keys:
		if is_instance_valid(existing):
			existing.queue_free()

	current_keys.clear()
	current_key_cell = spawn_points[rng.randi_range(0, spawn_points.size() - 1)]

	var count := maxi(accounts.size(), 1)

	for at in range(count):
		var owner: int = accounts[at] if at < accounts.size() else 0
		current_keys.append(_spawn_one(owner, current_key_cell, at, count))

	current_key_instance = current_keys[0]


func _spawn_one(owner: int, cell: Vector2i, at: int, total: int) -> Key:
	var made := key.instantiate() as Key
	made.owner_account = owner
	holder.add_child(made)
	made.global_position = _cell_to_world(cell) + _ring_offset(at, total)
	return made


## Where in the little ring that key hangs. Nothing at all for a single one, so
## a campaign key is exactly where it always was
func _ring_offset(at: int, total: int) -> Vector3:
	if total <= 1:
		return Vector3.ZERO

	var around := TAU * float(at) / float(total)
	return Vector3(cos(around), 0.0, sin(around)) * KEY_RING


## Converts a grid cell coordinate into a world position, using the
## GridMap's own cell size and transform instead of guessing them
func _cell_to_world(cell: Vector2i) -> Vector3:
	var local_pos: Vector3 = map_generator.grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
	local_pos.y += 2
	return map_generator.grid_map.to_global(local_pos)
