extends Node
class_name MapGenerator

## Reference to the GridMap node, which owns a MeshLibrary with the "ground" cube
@export var grid_map: GridMap

## Shape of the map
@export_enum("Square", "Round") var shape: int = 0

## Size for square maps (e.g. 16 = 16x16)
@export_range(8,256) var size: int = 16

## Radius for round maps
@export var radius: int = 8

## 0.0 = classic perfect maze (many dead ends)
## 1.0 = very open (few dead ends, many loops)
@export_range(0.0, 1.0) var openness: float = 0.2

## Covers the maze with a roof layer on top of the walls
@export var with_roof: bool = false

## Roughly the share of the roof that is left open. 0.0 = closed roof, the maze
## cannot be seen from above at all, 1.0 = no roof is built. The openings are
## cut as whole shapes, so the number is met about and not to the tile
@export_range(0.0, 1.0) var roof_openness: float = 0.0

## How wide one opening in the roof grows, in cells. Small values break the roof
## into many small holes, large ones leave a few wide ones
@export_range(2.0, 24.0) var roof_hole_size: float = 6.0

## Item index in the MeshLibrary (your "ground" cube, used for floor AND walls)
@export var ground_item_index: int = 0
@export var wall_item_index: int = 0
@export var roof_item_index: int = 0

## -1 = random seed on every call, otherwise a fixed seed for reproducible maps
@export var map_seed: int = -1

## The layer the roof is built on, one above the walls
const ROOF_LAYER := 2

## A roof tile with this many neighbours or more is filled back in, one with
## this many or fewer is taken away. What is left are round openings instead of
## the ragged edge a threshold on its own leaves behind
const ROOF_FILL_NEIGHBOURS := 6
const ROOF_ERODE_NEIGHBOURS := 2

var width: int
var height: int
var maze: Array = []
var rng := RandomNumberGenerator.new()


func generate_map() -> void:
	if grid_map == null:
		push_error("MapGenerator: grid_map is not set!")
		return

	grid_map.clear()
	rng.seed = map_seed if map_seed >= 0 else randi()

	if shape == 0:
		width = size
		height = size
	else:
		width = radius * 2 + 1
		height = radius * 2 + 1

	_init_grid()
	_carve_maze()

	if openness > 0.0:
		_add_extra_connections()

	_build_gridmap()


func _init_grid() -> void:
	maze.clear()
	for x in range(width):
		var col := []
		for z in range(height):
			col.append(false)
		maze.append(col)


func _in_shape_bounds(x: int, z: int) -> bool:
	if shape == 1:
		var center := Vector2(width / 2.0, height / 2.0)
		var dist := Vector2(x, z).distance_to(center)
		if dist > radius:
			return false
	return true


func _is_carvable(x: int, z: int) -> bool:
	if x <= 0 or x >= width - 1 or z <= 0 or z >= height - 1:
		return false

	if shape == 1:
		var center := Vector2(width / 2.0, height / 2.0)
		var dist := Vector2(x, z).distance_to(center)
		if dist > radius - 1:
			return false

	return true


func _find_start_cell() -> Vector2i:
	for x in range(1, width - 1, 2):
		for z in range(1, height - 1, 2):
			if _is_carvable(x, z):
				return Vector2i(x, z)
	return Vector2i(1, 1)


func _carve_maze() -> void:
	var visited := []
	for x in range(width):
		var col := []
		for z in range(height):
			col.append(false)
		visited.append(col)

	var start := _find_start_cell()
	var stack: Array[Vector2i] = [start]
	maze[start.x][start.y] = true
	visited[start.x][start.y] = true

	while stack.size() > 0:
		var current: Vector2i = stack[stack.size() - 1]
		var neighbors := _get_unvisited_neighbors(current, visited)

		if neighbors.size() > 0:
			var next: Vector2i = neighbors[rng.randi_range(0, neighbors.size() - 1)]
			var wall_x := (current.x + next.x) / 2
			var wall_z := (current.y + next.y) / 2

			maze[next.x][next.y] = true
			maze[wall_x][wall_z] = true
			visited[next.x][next.y] = true
			stack.append(next)
		else:
			stack.pop_back()


func _get_unvisited_neighbors(cell: Vector2i, visited: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs = [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]

	for d in dirs:
		var nx = cell.x + d.x
		var nz = cell.y + d.y
		if _is_carvable(nx, nz) and not visited[nx][nz]:
			result.append(Vector2i(nx, nz))

	return result


func _add_extra_connections() -> void:
	for x in range(1, width - 1):
		for z in range(1, height - 1):
			if not _is_carvable(x, z):
				continue
			if maze[x][z]:
				continue

			var horizontal_connector = maze[x - 1][z] and maze[x + 1][z] \
				and not maze[x][z - 1] and not maze[x][z + 1]
			var vertical_connector = maze[x][z - 1] and maze[x][z + 1] \
				and not maze[x - 1][z] and not maze[x + 1][z]

			if horizontal_connector or vertical_connector:
				if rng.randf() < openness:
					maze[x][z] = true


func _build_gridmap() -> void:
	for x in range(width):
		for z in range(height):
			if not _in_shape_bounds(x, z):
				continue

			grid_map.set_cell_item(Vector3i(x, 0, z), ground_item_index)

			if not maze[x][z]:
				grid_map.set_cell_item(Vector3i(x, 1, z), wall_item_index)

	_build_roof()


## The roof is not rolled tile by tile. That reads as static from below and it
## leaves single slabs over a corridor with no wall under them and none beside
## them, hanging in the air. It is built as a closed roof here, the openings are
## cut out of it as whole shapes, their edges are rounded off, and whatever ends
## up carried by nothing in the end is taken down again
func _build_roof() -> void:
	if not with_roof or roof_openness >= 1.0:
		return

	var roof := _cut_roof_openings()
	_round_roof_edges(roof)
	_drop_unsupported_roof(roof)

	for x in range(width):
		for z in range(height):
			if roof[x][z]:
				grid_map.set_cell_item(Vector3i(x, ROOF_LAYER, z), roof_item_index)


## A closed roof with the openings taken out of it where a noise field runs low.
## Noise is what makes them read as shapes instead of as speckles: it changes
## slowly from cell to cell, so the tiles that fall below the line lie together
func _cut_roof_openings() -> Array:
	var roof := _empty_mask()

	if roof_openness <= 0.0:
		for x in range(width):
			for z in range(height):
				roof[x][z] = _in_shape_bounds(x, z)
		return roof

	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / maxf(roof_hole_size, 1.0)
	noise.fractal_octaves = 2

	var cut := _roof_cut_level(noise)

	for x in range(width):
		for z in range(height):
			roof[x][z] = _in_shape_bounds(x, z) and noise.get_noise_2d(x, z) > cut

	return roof


## The noise value that leaves as much of the roof below it as roof_openness
## asks for. Cutting at a fixed value instead would let the size of the openings
## drift with whatever range the noise happened to land in on this map
func _roof_cut_level(noise: FastNoiseLite) -> float:
	var values := PackedFloat32Array()

	for x in range(width):
		for z in range(height):
			if _in_shape_bounds(x, z):
				values.append(noise.get_noise_2d(x, z))

	if values.is_empty():
		return 0.0

	values.sort()
	var at := int(floor(values.size() * roof_openness))
	return values[clampi(at, 0, values.size() - 1)]


## Fills in the tiles that are nearly surrounded by roof and takes away the ones
## that barely hang on. One pass over the whole grid, read from a copy so the
## tiles all decide from the same roof and not from the half changed one
func _round_roof_edges(roof: Array) -> void:
	var before := _copy_mask(roof)

	for x in range(width):
		for z in range(height):
			if not _in_shape_bounds(x, z):
				continue

			var neighbours := _roof_neighbour_count(before, x, z)

			if neighbours >= ROOF_FILL_NEIGHBOURS:
				roof[x][z] = true
			elif neighbours <= ROOF_ERODE_NEIGHBOURS:
				roof[x][z] = false


## How many of the eight cells around this one carry roof. Everything off the
## grid or outside the shape counts as roof: the maze is walled in there, and
## the rim of the roof should not be eaten away by its own border
func _roof_neighbour_count(roof: Array, x: int, z: int) -> int:
	var count := 0

	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue

			var nx := x + dx
			var nz := z + dz

			if nx < 0 or nx >= width or nz < 0 or nz >= height:
				count += 1
			elif not _in_shape_bounds(nx, nz) or roof[nx][nz]:
				count += 1

	return count


## Every roof tile has to be able to trace a line of roof back to one that sits
## on a wall. A tile that cannot is over a corridor with nothing under it and no
## roof to either side reaching a wall, which is what reads as floating
func _drop_unsupported_roof(roof: Array) -> void:
	var carried := _empty_mask()
	var pending: Array[Vector2i] = []

	for x in range(width):
		for z in range(height):
			if roof[x][z] and not maze[x][z]:
				carried[x][z] = true
				pending.append(Vector2i(x, z))

	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while pending.size() > 0:
		var cell: Vector2i = pending.pop_back()

		for d in dirs:
			var n: Vector2i = cell + d
			if n.x < 0 or n.x >= width or n.y < 0 or n.y >= height:
				continue
			if not roof[n.x][n.y] or carried[n.x][n.y]:
				continue

			carried[n.x][n.y] = true
			pending.append(n)

	for x in range(width):
		for z in range(height):
			roof[x][z] = carried[x][z]


func _empty_mask() -> Array:
	var mask := []

	for x in range(width):
		var col := []
		for z in range(height):
			col.append(false)
		mask.append(col)

	return mask


func _copy_mask(mask: Array) -> Array:
	var copy := []

	for col in mask:
		copy.append((col as Array).duplicate())

	return copy


## Returns all walkable cells (for the later spawn point generator)
func get_path_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(width):
		for z in range(height):
			if maze[x][z]:
				cells.append(Vector2i(x, z))
	return cells


## Returns every wall cell that has a walkable neighbor, so anything placed
## there can actually be reached
func get_wall_cells_next_to_path() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	for x in range(width):
		for z in range(height):
			if not _in_shape_bounds(x, z):
				continue
			if maze[x][z]:
				continue
			if get_path_neighbors(Vector2i(x, z)).is_empty():
				continue

			cells.append(Vector2i(x, z))

	return cells


## True when that cell is a corridor and not a block. Anything outside the map
## counts as a block, so a caller may ask about a neighbor without checking
func is_path_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return false

	return maze[cell.x][cell.y]


## How many steps through the corridors it takes from that cell to every other
## one, -1 wherever there is no way at all. The spawners used to measure across
## the grid, and that lies in a maze: two cells with a wall between them are
## neighbours on the grid and a long walk apart on foot, which is how the exit
## kept turning up right beside the key
func path_distance_field(from: Vector2i) -> Array:
	var field := []

	for x in range(width):
		var col := []
		for z in range(height):
			col.append(-1)
		field.append(col)

	if not is_path_cell(from):
		return field

	field[from.x][from.y] = 0
	var pending: Array[Vector2i] = [from]
	var head := 0

	while head < pending.size():
		var cell: Vector2i = pending[head]
		head += 1

		for n in get_path_neighbors(cell):
			if field[n.x][n.y] >= 0:
				continue

			field[n.x][n.y] = field[cell.x][cell.y] + 1
			pending.append(n)

	return field


## What a field says about one cell, -1 for a cell there is no way to. A wall is
## measured through the corridors beside it, which is where the exit stands and
## where anything else put into a wall is reached from
func distance_in_field(field: Array, cell: Vector2i) -> int:
	if field.is_empty():
		return -1
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return -1

	if maze[cell.x][cell.y]:
		return field[cell.x][cell.y]

	var nearest := -1

	for n in get_path_neighbors(cell):
		var steps: int = field[n.x][n.y]
		if steps < 0:
			continue
		if nearest < 0 or steps + 1 < nearest:
			nearest = steps + 1

	return nearest


## Returns the walkable neighbor cells directly adjacent to the given cell
func get_path_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for d in dirs:
		var n: Vector2i = cell + d
		if n.x >= 0 and n.x < width and n.y >= 0 and n.y < height:
			if maze[n.x][n.y]:
				neighbors.append(n)

	return neighbors
