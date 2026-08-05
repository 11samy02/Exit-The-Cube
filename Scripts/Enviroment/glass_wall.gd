extends AnimatableBody3D
class_name GlassWall

## Which seat this pane belongs to, -1 while it is everybody's.
##
## In a local race the maze is shared but the item that drops the panes must not
## be: one player spending it would open the wall for the three running against
## them. So a race sets one pane per seat into the same cell, and each of them
## only exists for its own player — nobody else sees it, walks into it, or is
## carried up by it
var seat: int = -1

## A pane set into a straight run of wall. It is wall like any other until the
## opener drops it into the floor, and it comes back up on its own once the item
## runs out. Standing in its cell when it comes back means riding it up, which
## is the only way onto the top of the maze: from up there the walls are a floor
## and the level can be walked over instead of through.
##
## The way up is not free. There is nothing to catch a cube that walks off the
## edge, and a pane rising into a roof block has nowhere to put whatever is
## standing on it.

## Emitted when the pane pressed the player into the ceiling above it
signal crushed

## Seconds the pane takes to drop out of the way
@export var open_duration: float = 0.55

## Seconds it takes to come back up. Slower than it goes down, the ride up is
## meant to be noticed and stepped off if the player wants nothing to do with it
@export var close_duration: float = 1.3

@export_group("Motion")

## Share of the move spent gathering itself in the other direction before it
## goes. A pane that simply starts moving reads as a value being changed, one
## that winds up first reads as a thing with weight behind it
@export_range(0.0, 0.4) var wind_up_share: float = 0.16

## How far that wind up travels, in shares of the whole move
@export_range(0.0, 0.3) var wind_up_depth: float = 0.09

## How hard the move runs out at the far end. 1 is a straight line, higher
## values launch harder and settle longer
@export_range(1.0, 8.0) var settle_power: float = 4.0

## How much deeper than a full cell the pane sinks, in meters. Left exactly one
## cell down its top face lands in the same plane as the floor, and two faces in
## one plane is what the flicker was
@export var sink_overshoot: float = 0.08

@export_group("Glass")

## The pane itself. Glass out of the MeshLibrary is drawn by whatever material
## was saved with it, and a see through material that does not write depth
## flickers against everything behind it
@export var glass_color: Color = Color(0.86, 0.92, 1.0, 0.32)

## What it throws back off the corridor lights, this is most of what reads as
## glass rather than as a tinted hole in the wall
@export var glass_glow: Color = Color(0.72, 0.86, 1.0)
@export var glass_glow_strength: float = 0.35

## How far off the middle of the cell the player may stand and still be counted
## as riding, in shares of a cell. Anything under one leaves the player room to
## step off the pane on the way up
@export_range(0.1, 1.0) var ride_footprint: float = 0.85

## How far above the top of the pane the underside of the player may be and
## still count as standing on it, in meters
@export var ride_tolerance: float = 0.35

## Left between the top of the pane and a roof block before the cube on it
## counts as crushed. Anything under the height of the cube is a death
@export var crush_clearance: float = 1.3

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _shape: CollisionShape3D = $Shape

## The pane's own box, kept as itself so its size can be read. The collision
## shape only ever hands out a Shape3D, which has no size to speak of
var _box: BoxShape3D = null

## True while the pane is down and the cell can be walked through
var is_open: bool = false

## Where the pane sits shut and where it sits dropped, both in world space
var _shut_y: float = 0.0
var _open_y: float = 0.0

## The move that is running: where it started, where it ends, how long it takes
## and how far into it we are. Stepped by hand rather than tweened, the carry has
## to read how far the pane rose this frame and a tween runs on its own clock
var _from_y: float = 0.0
var _target_y: float = 0.0
var _duration: float = 0.0
var _elapsed: float = 0.0

## How far this move winds up before it goes, 0 when there is no room for it
var _wind_up: float = 0.0

## Underside of the roof block over this cell, INF while the sky is open
var _ceiling_y: float = INF

## How tall the thing riding the pane is, taken off its own collision box
var _rider_height: float = 1.2


## Hands this pane to one seat: drawn on that seat's layer only, and solid to
## that player alone. Every other cube walks straight through where it stands
func claim(owner_seat: int, players: Array[Player]) -> void:
	seat = owner_seat
	SeatView.mark(self, SeatView.private_bit(owner_seat))

	for cube in players:
		if cube.seat != owner_seat:
			add_collision_exception_with(cube)


## Everybody this pane is allowed to carry or crush. Its own player in a race,
## the whole room everywhere else
func _mine() -> Array[Player]:
	var players := Player.all(get_tree())

	if seat < 0:
		return players

	return players.filter(func(cube: Player) -> bool: return cube.seat == seat)


## Called by the spawner once the pane stands in its cell. It builds itself off
## the same MeshLibrary the maze is drawn from, so a pane is the glass cube that
## was put in the library and not a second copy of it that could drift from it
func setup(grid_map: GridMap, cell: Vector2i, item_index: int) -> void:
	var library := grid_map.mesh_library
	if library == null:
		push_error("GlassWall: the GridMap has no MeshLibrary to take the glass cube out of")
		return

	var size := grid_map.cell_size

	_mesh.mesh = library.get_item_mesh(item_index)
	_mesh.transform = library.get_item_mesh_transform(item_index)
	_mesh.material_override = _glass_material()

	_box = BoxShape3D.new()
	_box.size = size
	_shape.shape = _box

	global_position = grid_map.to_global(grid_map.map_to_local(Vector3i(cell.x, 1, cell.y)))
	_shut_y = global_position.y
	_open_y = _shut_y - size.y - sink_overshoot
	_from_y = _shut_y
	_target_y = _shut_y
	_elapsed = 0.0
	_duration = 0.0

	if grid_map.get_cell_item(Vector3i(cell.x, 2, cell.y)) != GridMap.INVALID_CELL_ITEM:
		_ceiling_y = grid_map.to_global(grid_map.map_to_local(Vector3i(cell.x, 2, cell.y))).y - size.y * 0.5


## Drops the pane into the floor, the cell can be walked through from here on
func open() -> void:
	if is_open:
		return

	is_open = true
	_start_move(_open_y, open_duration)


## Brings it back up, carrying whatever is standing on it
func close() -> void:
	if not is_open:
		return

	is_open = false
	_start_move(_shut_y, close_duration)


## Sets a move going from wherever the pane happens to be. Starting from the
## position rather than from the end it was last at means a pane caught halfway
## carries on out of that spot instead of jumping to one end first.
##
## Dropping away winds up upwards, and under a roof block there is nothing up
## there to wind up into, so that pane simply goes. Rising winds up down into the
## floor, which is solid either way and always has the room
func _start_move(to_y: float, seconds: float) -> void:
	_from_y = global_position.y
	_target_y = to_y
	_duration = maxf(seconds, 0.01)
	_elapsed = 0.0
	_wind_up = 0.0 if to_y < _from_y and _ceiling_y != INF else wind_up_depth


## Where the pane is through its move, from 0 at the start to 1 at the end.
##
## It gathers itself backwards first and then runs out long into the far end.
## Straight line motion is what reads as a value being animated rather than a
## slab of glass being moved, and the wind up is what gives it the weight
func _travel(t: float) -> float:
	if _wind_up > 0.0 and t < wind_up_share:
		return -_wind_up * sin(t / wind_up_share * PI)

	var start := wind_up_share if _wind_up > 0.0 else 0.0
	var run := (t - start) / (1.0 - start)
	return 1.0 - pow(1.0 - run, settle_power)


## Glass the MeshLibrary hands over is drawn with whatever material was saved
## into it, and a see through one that writes no depth sorts differently from
## frame to frame against the corridor behind it, which is the flicker. This
## one writes depth, is only drawn from the front, and is mostly white
func _glass_material() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()

	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	glass.cull_mode = BaseMaterial3D.CULL_BACK
	glass.albedo_color = glass_color
	glass.metallic = 0.2
	glass.metallic_specular = 0.85
	glass.roughness = 0.08
	glass.emission_enabled = true
	glass.emission = glass_glow
	glass.emission_energy_multiplier = glass_glow_strength
	glass.rim_enabled = true
	glass.rim = 0.9
	glass.rim_tint = 0.1

	return glass


## The pane lifts its rider itself rather than leaving it to be pushed. The
## player is a body that moves under its own steam, and a wall driving into one
## from below comes out differently depending on which of the two the physics
## stepped first: sometimes a ride up, sometimes the cube dropped through the
## pane and out of the level. Lifting it by exactly what the pane rose by is the
## same thing every time
func _physics_process(delta: float) -> void:
	if _box == null or _elapsed >= _duration:
		return

	_elapsed = minf(_elapsed + delta, _duration)

	var was := global_position.y
	global_position.y = _from_y + (_target_y - _from_y) * _travel(_elapsed / _duration)

	var lift := global_position.y - was
	if lift <= 0.0:
		return

	for rider in _riders():
		rider.global_position.y += lift

	_crush_if_no_room()


## Every cube standing on top of this pane. Anything further off the middle of
## the cell than the footprint is on its way off and is left behind, which is
## what makes stepping off the pane possible
func _riders() -> Array[Player]:
	var riding: Array[Player] = []
	var here := global_position
	var reach := maxf(_box.size.x, _box.size.z) * 0.5 * ride_footprint
	var top := here.y + _box.size.y * 0.5

	for player in _mine():
		var there := player.global_position
		if absf(there.x - here.x) > reach or absf(there.z - here.z) > reach:
			continue

		var feet := there.y - _rider_height * 0.5
		if feet >= top - ride_tolerance and feet <= top + ride_tolerance:
			riding.append(player)

	return riding


## A pane coming up under a roof block runs out of room, and whatever is in the
## gap is what runs out of it first
func _crush_if_no_room() -> void:
	if _ceiling_y == INF:
		return

	var top := global_position.y + _box.size.y * 0.5
	if _ceiling_y - top >= crush_clearance:
		return

	var caught := _squeezed()
	if caught.is_empty():
		return

	crushed.emit()

	for player in caught:
		player.death.kill()


## Every cube in the gap this pane is closing up. Riding the pane is not part of
## it: a cube the pane shoved up ahead of itself instead of carrying is in
## exactly the same gap, and the ceiling does not care which of the two put it
## there
func _squeezed() -> Array[Player]:
	var caught: Array[Player] = []
	var here := global_position
	var reach := maxf(_box.size.x, _box.size.z) * 0.5
	var top := here.y + _box.size.y * 0.5

	for player in _mine():
		var there := player.global_position
		if absf(there.x - here.x) > reach or absf(there.z - here.z) > reach:
			continue

		var feet := there.y - _rider_height * 0.5
		var head := there.y + _rider_height * 0.5

		if head > top and feet < _ceiling_y:
			caught.append(player)

	return caught
