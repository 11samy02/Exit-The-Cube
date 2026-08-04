extends Node
class_name ItemSpawner

## The item scene to instantiate
@export var item_scene: PackedScene

## Reference to the MapGenerator, used to get the walkable cells
@export var map_generator: MapGenerator

## The Node where all items spawn in as children
@export var holder: Node3D

## Reference to the KeySpawner, the key has to be spawned first
@export var key_spawner: KeySpawner

## Reference to the PlayerSpawner, the player has to be spawned first
@export var player_spawner: PlayerSpawner

## Minimum number of steps through the maze between an item and the player
## start. 1 only keeps items out of the cell the player appears in, higher
## values push them away.
@export var min_distance_to_player: int = 1

## How many items to spawn. Fewer are placed when the map runs out of room that
## still keeps min_distance, so this is a ceiling and not a promise
@export var item_count: int = 10

## Minimum number of steps through the maze between two items, never less than
## 1. Spheres are placed as far apart as the map allows, this is only the line
## under which another one is not worth placing at all
@export var min_distance: int = 3

## How much closer than the roomiest cell on the map a sphere may still be
## dropped. 1.0 always takes the single roomiest cell and lays the same lattice
## on every map, lower values leave the pick some room to breathe
@export_range(0.1, 1.0) var spread_slack: float = 0.75

## -1 = a different item layout on every call, otherwise a fixed seed
@export var spawn_seed: int = -1

## Stands in for "no sphere anywhere near", any real distance beats it
const NO_NEIGHBOUR := 0x7FFFFFFF

## True while the level keeps putting spheres back as they are taken. Off for
## the campaign, where a level is laid out once and then played
@export var restock: bool = false

## Seconds between one sphere being taken and the next appearing
@export var restock_delay: float = 6.0

## How far a fresh sphere has to stay from anybody standing about, in meters.
## Without it they would appear under whoever just emptied the map
@export var restock_clearance: float = 12.0

var rng := RandomNumberGenerator.new()

## Seconds until the next sphere is put back
var _restock_timer: float = 0.0

var spawned_items: Array[Node3D] = []

## The cells the current items stand in
var used_cells: Array[Vector2i] = []


## Replaces all items with a fresh spread. Every sphere goes where the most room
## is left, so a big map is covered instead of clustered and a small one hands
## out fewer rather than dropping three of them into the same corner
func spawn_items() -> void:
	_clear_items()
	rng.seed = spawn_seed if spawn_seed >= 0 else randi()

	if item_scene == null:
		push_warning("ItemSpawner: no item scene assigned, nothing to spawn")
		return

	var candidates := _open_cells()
	if candidates.is_empty():
		push_warning("ItemSpawner: no cell is %d steps from the player, nothing spawned" \
			% min_distance_to_player)
		return

	var room := PackedInt32Array()
	room.resize(candidates.size())
	room.fill(NO_NEIGHBOUR)

	while used_cells.size() < item_count and not candidates.is_empty():
		var index := _pick_roomiest(room)
		if index < 0:
			break

		var cell: Vector2i = candidates[index]
		_place_item(cell)

		candidates.remove_at(index)
		room.remove_at(index)
		_close_in_on(candidates, room, cell)

	if used_cells.size() < item_count:
		push_warning("ItemSpawner: the map has room for %d of %d items at %d steps apart" \
			% [used_cells.size(), item_count, maxi(1, min_distance)])


## Every cell a sphere may stand in: walkable, not the one the key is in, and
## far enough from the player that it is not collected before the first step
func _open_cells() -> Array[Vector2i]:
	var player_field := _walk_from_player()
	var cells: Array[Vector2i] = []

	for cell in map_generator.get_path_cells():
		if _is_key_cell(cell):
			continue
		if not _is_far_from_player(player_field, cell):
			continue

		cells.append(cell)

	_shuffle(cells)
	return cells


## The cell with the most room around it, meaning the one whose nearest sphere
## is furthest away. Picking at random and throwing away whatever landed too
## close is what used to leave two or three of them within sight of each other
func _pick_roomiest(room: PackedInt32Array) -> int:
	var widest := 0

	for i in range(room.size()):
		widest = maxi(widest, room[i])

	if widest < maxi(1, min_distance):
		return -1

	var line := maxi(maxi(1, min_distance), int(widest * spread_slack))
	var picks := PackedInt32Array()

	for i in range(room.size()):
		if room[i] >= line:
			picks.append(i)

	return picks[rng.randi_range(0, picks.size() - 1)]


## Pulls every candidate in to the sphere that was just placed, so the next pick
## reads how much room is left over and not how much there was to begin with
func _close_in_on(candidates: Array[Vector2i], room: PackedInt32Array, placed: Vector2i) -> void:
	var field := map_generator.path_distance_field(placed)

	for i in range(candidates.size()):
		var steps := map_generator.distance_in_field(field, candidates[i])
		if steps >= 0:
			room[i] = mini(room[i], steps)


func _place_item(cell: Vector2i) -> void:
	var item: Node3D = item_scene.instantiate()
	holder.add_child(item)
	item.global_position = _cell_to_world(cell)

	spawned_items.append(item)
	used_cells.append(cell)


## Puts spheres back while the level runs, one at a time.
##
## A mode that ends on a clock rather than at an exit is picked clean inside the
## first minute otherwise, and spends the rest of the round with nothing to find.
## They come back somewhere else rather than where they were taken, so the map
## does not turn into a set of fixed pickup points people camp
func _process(delta: float) -> void:
	if not restock:
		return

	_prune_taken()

	if spawned_items.size() >= item_count:
		_restock_timer = restock_delay
		return

	_restock_timer -= delta
	if _restock_timer > 0.0:
		return

	_restock_timer = restock_delay
	_restock_one()


## Forgets the spheres that have been taken, so their cells are free again
func _prune_taken() -> void:
	for at in range(spawned_items.size() - 1, -1, -1):
		if not is_instance_valid(spawned_items[at]):
			spawned_items.remove_at(at)
			used_cells.remove_at(at)


## One fresh sphere, somewhere with nothing else on it and nobody standing there
func _restock_one() -> void:
	var free_cells := map_generator.get_path_cells().filter(
		func(c: Vector2i) -> bool: return not used_cells.has(c) and not _crowded(c)
	)

	if free_cells.is_empty():
		return

	var cell: Vector2i = free_cells[randi() % free_cells.size()]
	_place_item(cell)

	var sphere := spawned_items[spawned_items.size() - 1] as ItemSphere
	if sphere != null:
		sphere.appear()


## True when somebody is close enough that a sphere appearing there would be
## picked up by standing still rather than by going and getting it
func _crowded(cell: Vector2i) -> bool:
	var at := _cell_to_world(cell)

	for node in get_tree().get_nodes_in_group("player"):
		if (node as Node3D).global_position.distance_to(at) < restock_clearance:
			return true

	return false


func _clear_items() -> void:
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	spawned_items.clear()
	used_cells.clear()


## True when the key already stands in this cell
func _is_key_cell(cell: Vector2i) -> bool:
	return key_spawner != null and cell == key_spawner.current_key_cell


## Steps from the player start to everywhere, empty while nothing spawns the
## player and a sphere may go wherever it likes
func _walk_from_player() -> Array:
	if player_spawner == null:
		return []

	return map_generator.path_distance_field(player_spawner.current_player_cell)


## True when the cell keeps its distance to where the player starts, an item in
## that cell would be collected before the player has even moved
func _is_far_from_player(player_field: Array, cell: Vector2i) -> bool:
	if player_field.is_empty():
		return true

	return map_generator.distance_in_field(player_field, cell) >= maxi(1, min_distance_to_player)


## Array.shuffle() ignores spawn_seed because it draws from the global rng
func _shuffle(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap


## Converts a grid cell into a world position at wall height
func _cell_to_world(cell: Vector2i) -> Vector3:
	var local_pos: Vector3 = map_generator.grid_map.map_to_local(Vector3i(cell.x, 1, cell.y))
	return map_generator.grid_map.to_global(local_pos)
