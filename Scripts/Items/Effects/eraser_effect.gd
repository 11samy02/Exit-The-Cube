extends ItemEffect
class_name EraserEffect

## Sends a roller out through the maze that washes enemy paint off the floor and
## soaks whoever it passes.
##
## It always goes somewhere. Enemy paint first, then whichever enemy is nearest,
## and failing both it simply patrols — an item that quietly did nothing because
## the other side had not painted yet would read as broken.
##
## It scrubs rather than paints: the tiles it takes are left bare, not turned to
## your colour. Whoever wants them has to walk them. Your own side's paint it
## rolls straight over

## The roller. Whatever mesh the scene carries is used, and a stand-in is built
## if it carries none
@export var roller_scene: PackedScene

## How many enemy tiles it washes off before it is spent
@export var tiles: int = 15

## How long it stays out when it cannot reach that many, in seconds
@export var life: float = 20.0

## Cells a second it travels
@export var speed: float = 7.0

## How far off a cell counts as reached
@export var reach: float = 0.6

## How close it has to pass somebody to soak them, in meters
@export var soak_range: float = 1.6

## The effect it leaves on whoever it catches, and for how long
@export var soak_effect: String = "slow"
@export var soak_seconds: float = 8.0

## How far off a patrol point is picked when there is nothing to hunt. It keeps
## the roller out in the maze instead of shuffling around the cube's own cell
@export var patrol_distance: int = 12

## Size of the stand-in roller, in meters. Only used until the scene has a mesh
@export var stand_in_size: Vector2 = Vector2(0.26, 0.85)

## Which surface of the model takes the team colour. The rest of it keeps what
## it was modelled with, so a frame stays a frame instead of going one flat
## colour. A model with no surface by this name is tinted whole
@export var tinted_surface: String = "color"

## The widest the roller may be, in meters. A model bigger than this is scaled
## down to it so it cannot poke through the corridor walls
@export var fit_width: float = 1.3

var _roller: Node3D = null
var _route: Array[Vector2i] = []
var _at: int = 0
var _washed: int = 0
var _soaked: Dictionary = {}
var _generator: MapGenerator = null
var _tint: Color = Color.WHITE

## Whose roller this is. Every question it asks about sides is asked on behalf
## of the cube that spent the item, not on behalf of the machine
var _owner: int = 0

## How high off the floor the roller's origin has to sit, worked out from the
## model rather than guessed
var _lift: float = 0.0


func _start() -> void:
	if not Match.is_painting():
		stop(false)
		return

	_generator = get_tree().get_first_node_in_group("map_generator") as MapGenerator
	if _generator == null or _generator.grid_map == null or player == null:
		stop(false)
		return

	_owner = player.account()
	_tint = Match.team_color(Match.team_of(_owner))
	_build_roller()

	if _roller == null:
		stop(false)
		return

	_retarget()
	time_left = maxf(time_left, life)
	show_vignette(0.5)


func _tick(delta: float) -> void:
	if _roller == null or not is_instance_valid(_roller):
		stop(false)
		return

	_roll(delta)
	_soak_anybody_near()

	if _washed >= tiles:
		stop(false)


## Walks the route and scrubs the enemy tiles it rolls over. Its own side's
## paint it leaves alone — the roller is a weapon, not a mess
func _roll(delta: float) -> void:
	if _at >= _route.size():
		_retarget()
		if _at >= _route.size():
			return

	var target := _cell_world(_route[_at])
	var step := speed * _generator.grid_map.cell_size.x * delta
	_roller.global_position = _roller.global_position.move_toward(target, step)
	_face(target)

	if _roller.global_position.distance_to(target) > reach:
		return

	_wash(_route[_at])
	_at += 1


func _wash(cell: Vector2i) -> void:
	if not _is_enemy_tile(cell, Match.team_of(_owner)):
		return

	Match.erase_cell(_owner, cell)
	_washed += 1


## Picks the next thing to drive at, in the order that makes the item feel like
## it is hunting: paint to wash, then somebody to soak, then anywhere at all
func _retarget() -> void:
	var mine := Match.team_of(_owner)
	var from := _current_cell()

	var route := _route_to(from, _is_enemy_tile.bind(mine))
	if route.is_empty():
		route = _route_to(from, _holds_enemy.bind(mine))
	if route.is_empty():
		route = _route_to(from, _far_enough.bind(from))

	if route.size() < 2:
		stop(false)
		return

	_route = route
	_at = 1


## Breadth first from a cell until something answers the question, which keeps
## the roller in the corridors rather than sending it straight through a wall
func _route_to(from: Vector2i, wanted: Callable) -> Array[Vector2i]:
	var came_from := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0

	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1

		if cell != from and wanted.call(cell):
			return _trace(came_from, from, cell)

		for step in _generator.get_path_neighbors(cell):
			if not came_from.has(step):
				came_from[step] = cell
				queue.append(step)

	return []


func _is_enemy_tile(cell: Vector2i, mine: int) -> bool:
	var claim: PaintState.Claim = Match.paint().claims.get(cell, null)
	return claim != null and claim.team != mine


## True where somebody from another side is standing
func _holds_enemy(cell: Vector2i, mine: int) -> bool:
	var runners := Match.runners()

	for id: int in runners:
		if id == _owner or Match.team_of(id) == mine:
			continue

		var runner: Dictionary = runners[id]
		if not bool(runner["placed"]) or bool(runner["dead"]):
			continue

		if _cell_of(runner["position"] as Vector3) == cell:
			return true

	return false


## The patrol fallback. Any cell a good way off will do, the point is only that
## the roller is seen working the maze instead of standing still
func _far_enough(cell: Vector2i, from: Vector2i) -> bool:
	return absi(cell.x - from.x) + absi(cell.y - from.y) >= patrol_distance


func _trace(came_from: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = [to]

	while route[route.size() - 1] != from:
		route.append(came_from[route[route.size() - 1]])

	route.reverse()
	return route


func _build_roller() -> void:
	_roller = roller_scene.instantiate() if roller_scene != null else Node3D.new()
	get_tree().current_scene.add_child(_roller)

	if _meshes_of(_roller).is_empty():
		_roller.add_child(_stand_in())

	_settle_size()
	_paint_roller()
	_roller.global_position = _cell_world(_cell_of(player.global_position))


## Sizes the model to the corridor and works out how high off the floor it has
## to sit for its underside to touch. Doing it from the mesh means the model can
## be remade at any scale, around any origin, without a number here changing
func _settle_size() -> void:
	var bounds := _bounds_of(_roller)
	if bounds.size == Vector3.ZERO:
		_lift = stand_in_size.x
		return

	var widest := maxf(bounds.size.x, bounds.size.z)
	if widest > fit_width:
		_roller.scale = Vector3.ONE * (fit_width / widest)

	_lift = -bounds.position.y * _roller.scale.y + 0.02


## Everything the roller's meshes cover, in the roller's own space
func _bounds_of(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true

	for mesh in _meshes_of(node):
		if mesh.mesh == null:
			continue

		var box := node.global_transform.affine_inverse() * (mesh.global_transform * mesh.mesh.get_aabb())
		bounds = box if first else bounds.merge(box)
		first = false

	return bounds


## A roller drawn from primitives, so the item is visible before the model is in
func _stand_in() -> Node3D:
	var barrel := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = stand_in_size.x
	cylinder.bottom_radius = stand_in_size.x
	cylinder.height = stand_in_size.y
	barrel.mesh = cylinder
	barrel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	barrel.position.y = stand_in_size.x
	return barrel


## The roller wears the colour of whoever sent it, mesh and light both, so a
## stretch of floor going bare has something visibly doing it
func _paint_roller() -> void:
	var meshes := _meshes_of(_roller)
	var painted := false

	for mesh in meshes:
		painted = _tint_surfaces(mesh) or painted

	if not painted:
		for mesh in meshes:
			mesh.material_override = _team_material()

	var glow := OmniLight3D.new()
	glow.light_color = _tint
	glow.light_energy = 1.6
	glow.omni_range = 4.0
	_roller.add_child(glow)


## Paints only the surfaces the model named for it, and says whether it found
## any. The stand-in has none, so it falls through to being tinted whole
func _tint_surfaces(mesh: MeshInstance3D) -> bool:
	if mesh.mesh == null:
		return false

	var found := false

	for surface in range(mesh.mesh.get_surface_count()):
		if mesh.mesh.surface_get_name(surface).to_lower() != tinted_surface.to_lower():
			continue

		mesh.set_surface_override_material(surface, _team_material())
		found = true

	return found


func _team_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _tint
	material.emission_enabled = true
	material.emission = _tint
	material.emission_energy_multiplier = 1.4
	return material


func _meshes_of(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		found.append(node)

	for child in node.get_children():
		found.append_array(_meshes_of(child))

	return found


## Turns the barrel across the way it is going, which is the way a roller rolls
func _face(target: Vector3) -> void:
	var along := target - _roller.global_position
	along.y = 0.0

	if along.length_squared() > 0.001:
		_roller.rotation.y = atan2(along.x, along.z)


## Anybody on another side who is close enough gets soaked, once each
func _soak_anybody_near() -> void:
	var runners := Match.runners()
	var mine := Match.team_of(_owner)

	for id: int in runners:
		if id == _owner or Match.team_of(id) == mine or _soaked.has(id):
			continue

		var runner: Dictionary = runners[id]
		if not bool(runner["placed"]) or bool(runner["dead"]):
			continue

		if _roller.global_position.distance_to(runner["position"] as Vector3) <= soak_range:
			_soaked[id] = true
			Match.send_status(id, soak_effect, soak_seconds)


func _current_cell() -> Vector2i:
	return _cell_of(_roller.global_position)


func _current_cell_of_player() -> Vector2i:
	return _cell_of(player.global_position)


func _cell_of(where: Vector3) -> Vector2i:
	var grid := _generator.grid_map
	var at := grid.local_to_map(grid.to_local(where))
	return Vector2i(at.x, at.z)


func _cell_world(cell: Vector2i) -> Vector3:
	var grid := _generator.grid_map
	var local := grid.map_to_local(Vector3i(cell.x, 0, cell.y))
	local.y += grid.cell_size.y * 0.5 + _lift
	return grid.to_global(local)


func _stop(_cancelled: bool) -> void:
	if is_instance_valid(_roller):
		_roller.queue_free()
