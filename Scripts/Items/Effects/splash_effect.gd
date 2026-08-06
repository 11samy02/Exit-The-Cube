extends ItemEffect
class_name SplashEffect

## Throws paint outwards and takes the floor around the cube.
##
## It goes through the walls of the maze. A splash held to what the cube could
## see is a splash that mostly hits the corridor it is already standing in, and
## the item is meant to be the one that takes a junction in one go

## How far the paint reaches, in cells. The one number worth balancing
@export var radius: int = 8

## How long the wave takes to travel out, in seconds. Only the look — the tiles
## are decided at once, they are simply handed over in rings
@export var sweep_duration: float = 0.45

## Whether the paint stops at a wall. Off, the splash soaks whatever is within
## reach of the cube, the corridor on the other side of a wall included
@export var walled_in: bool = false

@export_group("Burst")

## How many rings the wave is drawn as
@export var ring_count: int = 3

## Seconds between them
@export var ring_delay: float = 0.08

var _rings: Array = []
var _swept: float = 0.0


func _start() -> void:
	if not Match.is_painting():
		stop(false)
		return

	_rings = _reachable_rings()
	_throw_the_paint()


## The wave the paint arrives on, in the colour of the side that threw it. The
## tiles are already decided by the time this runs, this is only what it looks
## like from the outside
func _throw_the_paint() -> void:
	var holder := player.get_parent()
	if holder == null:
		return

	var color := Match.team_color(Match.team_of(player.account()))
	var reach := float(radius) * _cell_size()

	for at in range(maxi(ring_count, 1)):
		var ring := BurstRing.burst(holder, player.global_position, color,
			reach, sweep_duration + 0.2, false, ring_delay * at)
		claim(ring)


## How wide one cell of the maze is, so the burst covers the tiles it painted
func _cell_size() -> float:
	var generator := get_tree().get_first_node_in_group("map_generator") as MapGenerator
	if generator == null or generator.grid_map == null:
		return 2.0

	return generator.grid_map.cell_size.x


## Hands the rings over in order, so the paint reads as running outwards from
## the cube rather than appearing all at once
func _tick(delta: float) -> void:
	if _rings.is_empty():
		return

	_swept += delta
	var reached := int((_swept / maxf(sweep_duration, 0.01)) * _rings.size())

	while not _rings.is_empty() and reached > 0:
		for cell: Vector2i in _rings.pop_front() as Array:
			Match.paint_cell(player.account(), cell)

		reached -= 1

	if _rings.is_empty():
		stop(false)


## Every floor cell within reach that the cube could draw a straight line to,
## bundled by how far out it is
func _reachable_rings() -> Array:
	var generator := get_tree().get_first_node_in_group("map_generator") as MapGenerator
	var grid := generator.grid_map if generator != null else null

	if generator == null or grid == null or player == null:
		return []

	var at := grid.local_to_map(grid.to_local(player.global_position))
	var here := Vector2i(at.x, at.z)
	var rings: Array = []

	for step in range(radius + 1):
		rings.append([])

	for x in range(here.x - radius, here.x + radius + 1):
		for z in range(here.y - radius, here.y + radius + 1):
			var cell := Vector2i(x, z)
			var away := int(round(Vector2(cell - here).length()))

			if away > radius or not generator.is_path_cell(cell):
				continue
			if walled_in and not _can_see(generator, here, cell):
				continue

			(rings[away] as Array).append(cell)

	return rings


## Walks the straight line between two cells and gives up at the first wall.
## Only read while the splash is set to stop at them
func _can_see(generator: MapGenerator, from: Vector2i, to: Vector2i) -> bool:
	var span := Vector2(to - from)
	var steps := int(ceil(maxf(absf(span.x), absf(span.y))))

	if steps <= 0:
		return true

	for step in range(1, steps + 1):
		var along := Vector2(from) + span * (float(step) / float(steps))
		var cell := Vector2i(roundi(along.x), roundi(along.y))

		if not generator.is_path_cell(cell):
			return false

	return true
