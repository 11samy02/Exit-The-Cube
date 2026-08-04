extends ItemEffect
class_name EraserEffect

## Sends a roller off towards the nearest enemy paint and washes a stretch of it
## away. Anybody it runs into on the way is left soaked and slow.
##
## It scrubs rather than paints: the tiles it takes are left bare, not turned to
## your colour. Whoever wants them has to walk them

## The roller. Its mesh is swapped for the model in the scene
@export var roller_scene: PackedScene

## How many enemy tiles it washes off before it is spent
@export var tiles: int = 20

## Cells a second it travels
@export var speed: float = 9.0

## How far off a cell counts as reached
@export var reach: float = 0.6

## How close it has to pass somebody to soak them, in meters
@export var soak_range: float = 1.6

## The effect it leaves on whoever it catches, and for how long
@export var soak_effect: String = "slow"
@export var soak_seconds: float = 8.0

## Given up on after this long, so a roller that cannot find a way stops
@export var life: float = 12.0

var _roller: Node3D = null
var _route: Array[Vector2i] = []
var _at: int = 0
var _washed: int = 0
var _soaked: Dictionary = {}
var _generator: MapGenerator = null


func _start() -> void:
	if not Online.is_painting():
		stop(false)
		return

	_generator = get_tree().get_first_node_in_group("map_generator") as MapGenerator
	if _generator == null or player == null:
		stop(false)
		return

	_route = _route_to_enemy_paint()
	if _route.is_empty():
		stop(false)
		return

	_build_roller()
	time_left = minf(time_left, life)


## The way from here to the nearest cell somebody else has painted, walked
## through the corridors rather than measured across the walls
func _route_to_enemy_paint() -> Array[Vector2i]:
	var grid := _generator.grid_map
	var at := grid.local_to_map(grid.to_local(player.global_position))
	var here := Vector2i(at.x, at.z)
	var mine := Online.team_of(Online.steam.id)

	var came_from := {here: here}
	var queue: Array[Vector2i] = [here]
	var head := 0

	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1

		if _is_enemy_tile(cell, mine):
			return _trace(came_from, here, cell)

		for step in _generator.get_path_neighbors(cell):
			if not came_from.has(step):
				came_from[step] = cell
				queue.append(step)

	return []


func _is_enemy_tile(cell: Vector2i, mine: int) -> bool:
	var claim: PaintState.Claim = Online.paint.claims.get(cell, null)
	return claim != null and claim.team != mine


func _trace(came_from: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = [to]

	while route[route.size() - 1] != from:
		route.append(came_from[route[route.size() - 1]])

	route.reverse()
	return route


func _build_roller() -> void:
	if roller_scene == null:
		return

	_roller = roller_scene.instantiate()
	get_tree().current_scene.add_child(_roller)
	_roller.global_position = _cell_world(_route[0])
	_paint_roller()


## The roller wears the colour of whoever sent it, so a stretch of floor going
## bare has something visibly doing it
func _paint_roller() -> void:
	var tint := Online.team_color(Online.team_of(Online.steam.id))

	for mesh in _meshes_of(_roller):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 0.8
		mesh.material_override = material


func _meshes_of(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		found.append(node)

	for child in node.get_children():
		found.append_array(_meshes_of(child))

	return found


func _tick(delta: float) -> void:
	if _roller == null or not is_instance_valid(_roller):
		stop(false)
		return

	_roll(delta)
	_soak_anybody_near()

	if _washed >= tiles or _at >= _route.size():
		stop(false)


## Walks the route, scrubbing whatever it rolls over that is not ours
func _roll(delta: float) -> void:
	if _at >= _route.size():
		return

	var target := _cell_world(_route[_at])
	var step := speed * _generator.grid_map.cell_size.x * delta
	_roller.global_position = _roller.global_position.move_toward(target, step)

	if _roller.global_position.distance_to(target) > reach:
		return

	Online.erase_cell(_route[_at])
	_washed += 1
	_at += 1

	if _at >= _route.size() and _washed < tiles:
		_extend_route()


## Once it has reached the paint it came for, it keeps going to whatever enemy
## tile is next, so one roller washes a stretch rather than a single cell
func _extend_route() -> void:
	var mine := Online.team_of(Online.steam.id)
	var from := _route[_route.size() - 1]

	for step in _generator.get_path_neighbors(from):
		if _is_enemy_tile(step, mine):
			_route.append(step)
			return

	var onward := _route_from(from, mine)
	if not onward.is_empty():
		_route.append_array(onward.slice(1))


func _route_from(from: Vector2i, mine: int) -> Array[Vector2i]:
	var came_from := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0

	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1

		if cell != from and _is_enemy_tile(cell, mine):
			return _trace(came_from, from, cell)

		for step in _generator.get_path_neighbors(cell):
			if not came_from.has(step):
				came_from[step] = cell
				queue.append(step)

	return []


## Anybody on another side who is close enough gets soaked, once each
func _soak_anybody_near() -> void:
	var mine := Online.team_of(Online.steam.id)

	for id: int in Online.runners:
		if id == Online.steam.id or Online.team_of(id) == mine or _soaked.has(id):
			continue

		var runner: Dictionary = Online.runners[id]
		if not bool(runner["placed"]) or bool(runner["dead"]):
			continue

		if _roller.global_position.distance_to(runner["position"] as Vector3) <= soak_range:
			_soaked[id] = true
			Online.send_status(id, soak_effect, soak_seconds)


func _cell_world(cell: Vector2i) -> Vector3:
	var grid := _generator.grid_map
	var local := grid.map_to_local(Vector3i(cell.x, 0, cell.y))
	local.y += grid.cell_size.y * 0.5 + 0.3
	return grid.to_global(local)


func _stop(_cancelled: bool) -> void:
	if is_instance_valid(_roller):
		_roller.queue_free()
