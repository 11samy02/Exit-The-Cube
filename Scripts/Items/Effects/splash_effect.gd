extends ItemEffect
class_name SplashEffect

## Throws paint outwards and takes every floor tile it can see.
##
## Line of sight rather than a plain circle: a splash that went through walls
## would paint the corridor on the other side of one, which reads as a bug
## whichever way it fell. What it takes is what you could have looked at

## How far the paint reaches, in cells. The one number worth balancing
@export var radius: int = 8

## How long the wave takes to travel out, in seconds. Only the look — the tiles
## are decided at once, they are simply handed over in rings
@export var sweep_duration: float = 0.45

var _rings: Array = []
var _swept: float = 0.0


func _start() -> void:
	if not Online.is_painting():
		stop(false)
		return

	show_vignette(0.7)
	_rings = _reachable_rings()


## Hands the rings over in order, so the paint reads as running outwards from
## the cube rather than appearing all at once
func _tick(delta: float) -> void:
	if _rings.is_empty():
		return

	_swept += delta
	var reached := int((_swept / maxf(sweep_duration, 0.01)) * _rings.size())

	while not _rings.is_empty() and reached > 0:
		for cell: Vector2i in _rings.pop_front() as Array:
			Online.paint_cell(cell)

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
			if not _can_see(generator, here, cell):
				continue

			(rings[away] as Array).append(cell)

	return rings


## Walks the straight line between two cells and gives up at the first wall.
## Grid stepping rather than a physics ray: the answer has to be about which
## cells the maze has, not about what a collision shape happens to catch
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
