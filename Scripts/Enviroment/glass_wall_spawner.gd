extends Node
class_name GlassWallSpawner

## Swaps a handful of the maze walls for panes of glass. A pane is only ever set
## into a straight run of wall with corridor on both sides of it: two walls
## holding it up and no more than those two, so opening one always opens a way
## from one corridor into the next and never into the middle of a block.
##
## The maze itself is not told about any of this. A pane is a wall until it is
## opened, so the routes the saws take and the way through to the key and the
## exit are the same level they would have been without them.

## The pane to put in
@export var glass_wall_scene: PackedScene

## Reference to the MapGenerator, the maze is read off it
@export var map_generator: MapGenerator

## The Node the panes spawn in as children of
@export var holder: Node3D

## Reference to the ElevatorSpawner, the exit wall is not up for glazing
@export var elevator_spawner: ElevatorSpawner

## How many panes to set in. Fewer are placed when the maze has no more room
## that keeps them apart, a maze of short walls has very few windows in it
@export var wall_count: int = 0

## Item index of the glass cube in the MeshLibrary
@export var item_index: int = 2

## Minimum number of steps through the maze between two panes
@export var min_distance: int = 6

## -1 = different panes on every build, otherwise a fixed seed
@export var spawn_seed: int = -1

var rng := RandomNumberGenerator.new()

var spawned_walls: Array[GlassWall] = []

## The cells the panes were set into
var used_cells: Array[Vector2i] = []


## Replaces the walls with panes. Every pane goes where the most room is left,
## the same way the item spheres are spread: a row of them in one corridor would
## be one wide door rather than several ways through
func spawn_walls() -> void:
	_clear_walls()
	rng.seed = spawn_seed if spawn_seed >= 0 else randi()

	if glass_wall_scene == null or wall_count <= 0:
		return

	var candidates := _windows()
	if candidates.is_empty():
		push_warning("GlassWallSpawner: this maze has no straight run of wall to set a pane into")
		return

	var room := PackedInt32Array()
	room.resize(candidates.size())
	room.fill(0x7FFFFFFF)

	while used_cells.size() < wall_count and not candidates.is_empty():
		var index := _pick_roomiest(room)
		if index < 0:
			break

		var cell: Vector2i = candidates[index]
		_place_wall(cell)

		candidates.remove_at(index)
		room.remove_at(index)
		_close_in_on(candidates, room, cell)

	_hand_out()


## In a local race every pane is set once per seat, into the same cells.
##
## Where they go was decided above, so nothing is rolled again — the extra sets
## are placed straight on top of the first one. It costs a handful of bodies per
## player, and it is the only way an item that drops the glass can drop it for
## the one player who actually spent it
func _hand_out() -> void:
	if not Match.is_private_race() or spawned_walls.is_empty():
		return

	var players := Player.all(get_tree())
	var cells := used_cells.duplicate()
	var sets: Array = [spawned_walls.duplicate()]

	for seat in range(1, players.size()):
		var copies: Array[GlassWall] = []

		for cell in cells:
			copies.append(_place_wall(cell, false))

		sets.append(copies)

	for seat in range(sets.size()):
		for wall: GlassWall in sets[seat]:
			wall.claim(seat, players)


## Every wall cell a pane may be set into: wall on two opposite sides of it and
## open corridor on the other two. That is the whole rule, and it is what keeps
## a pane between two walls with no more neighbours than those
func _windows() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var exit_cell := _elevator_cell()

	for cell in map_generator.get_wall_cells_next_to_path():
		if cell == exit_cell:
			continue
		if _is_window(cell):
			cells.append(cell)

	_shuffle(cells)
	return cells


## Whether that wall cell is a window: the walls beside it have to run straight
## through it, and the two sides it opens onto have to be corridor. Anything off
## the map counts as wall, so the rim of the maze is never glazed
func _is_window(cell: Vector2i) -> bool:
	if map_generator.is_path_cell(cell):
		return false

	var west := not map_generator.is_path_cell(cell + Vector2i(-1, 0))
	var east := not map_generator.is_path_cell(cell + Vector2i(1, 0))
	var north := not map_generator.is_path_cell(cell + Vector2i(0, -1))
	var south := not map_generator.is_path_cell(cell + Vector2i(0, 1))

	var runs_east_west := west and east and not north and not south
	var runs_north_south := north and south and not west and not east

	return runs_east_west or runs_north_south


## The cell with the most room around it, the same pick the item spheres use.
## Below the minimum there is no room left worth placing a pane in
func _pick_roomiest(room: PackedInt32Array) -> int:
	var widest := 0

	for i in range(room.size()):
		widest = maxi(widest, room[i])

	if widest < maxi(1, min_distance):
		return -1

	var picks := PackedInt32Array()

	for i in range(room.size()):
		if room[i] >= widest:
			picks.append(i)

	return picks[rng.randi_range(0, picks.size() - 1)]


## Pulls every candidate in to the pane that was just set, so the next pick
## reads how much room is left rather than how much there was.
##
## Both corridors the pane opens onto are measured from, not just one. A pane
## has a side each way, and the walk from one of them can be right around the
## maze while the other one is three steps: measuring from a single side would
## call two panes far apart that are back to back through one corner
func _close_in_on(candidates: Array[Vector2i], room: PackedInt32Array, placed: Vector2i) -> void:
	for door in map_generator.get_path_neighbors(placed):
		var field := map_generator.path_distance_field(door)

		for i in range(candidates.size()):
			var steps := map_generator.distance_in_field(field, candidates[i])
			if steps >= 0:
				room[i] = mini(room[i], steps)


## Takes the wall cube out of the GridMap and puts a pane in its place. The cell
## stays a wall as far as the maze is concerned, it is only no longer drawn by
## the GridMap because the pane has to be able to move and a grid cell cannot
## Sets one pane into that cell. A repeat pass for another seat goes into a cell
## that is already spoken for, so it does not claim it a second time — the list
## of taken cells is what the spread is worked out from
func _place_wall(cell: Vector2i, remember: bool = true) -> GlassWall:
	var grid_map := map_generator.grid_map
	grid_map.set_cell_item(Vector3i(cell.x, 1, cell.y), GridMap.INVALID_CELL_ITEM)

	var wall: GlassWall = glass_wall_scene.instantiate()
	holder.add_child(wall)
	wall.setup(grid_map, cell, item_index)

	spawned_walls.append(wall)

	if remember:
		used_cells.append(cell)

	return wall


func _clear_walls() -> void:
	for wall in spawned_walls:
		if is_instance_valid(wall):
			wall.queue_free()

	spawned_walls.clear()
	used_cells.clear()


func _elevator_cell() -> Vector2i:
	return elevator_spawner.current_elevator_cell if elevator_spawner != null else Vector2i(-1, -1)


## Array.shuffle() ignores spawn_seed because it draws from the global rng
func _shuffle(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap
