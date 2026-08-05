extends Node
class_name PlayerSpawner

## The player scene to instantiate at a chosen spawn point
@export var player_scene: PackedScene

## Reference to the MapGenerator, used to get all walkable cells
@export var map_generator: MapGenerator

## How many possible spawn positions to store (only one is actually used per spawn)
@export var spawn_point_count: int = 5

## The Node where the player spawns in as a child
@export var holder: Node3D

## Height the player is dropped in at, from there it falls onto the floor
@export var spawn_height: float = 3.0

## -1 = new candidate positions on every map, otherwise a fixed seed
@export var spawn_seed: int = -1

## How far apart cubes sharing one spawn cell are placed, in meters. Inside a
## single cell, so nobody is pushed into a wall
const SEAT_RING := 0.55

var rng := RandomNumberGenerator.new()

## The stored candidate spawn positions (grid coordinates)
var spawn_points: Array[Vector2i] = []

## The currently spawned player instance, if any. With more than one seat this
## is the first of them — the key, the elevator and the item spawners all place
## themselves relative to where the players came in, and in co-op that is one
## cell for everybody
var current_player_instance: Node3D = null

## Every cube in the level, in seat order
var current_players: Array[Player] = []

## The cell the current player started in, only valid after spawn_player()
var current_player_cell: Vector2i = Vector2i.ZERO


## Picks spawn_point_count random walkable cells and stores them as candidates.
## Call this once per generated map, not on every death/retry.
func generate_spawn_points() -> void:
	spawn_points.clear()
	rng.seed = spawn_seed if spawn_seed >= 0 else randi()

	var path_cells := map_generator.get_path_cells()
	_shuffle(path_cells)
	var count: int = min(spawn_point_count, path_cells.size())
	for i in range(count):
		spawn_points.append(path_cells[i])


## Removes the current player (if any) and spawns a new one at a random
## position picked from the stored spawn_points
func spawn_player() -> void:
	spawn_seats([])


## One cube per seat.
##
## An empty `cells` means every seat comes in at the one cell this spawner drew
## for itself, which is what the campaign wants: a room is walked into together
## and a wipe puts everybody back together. A cell per seat is what a mode that
## places people itself hands over.
##
## The draw out of the candidate list stays exactly one call into the rng
## whatever the seat count is. Every campaign level carries a fixed spawn seed,
## and a second draw here would move every starting point in the game
func spawn_seats(cells: Array[Vector2i]) -> void:
	if spawn_points.is_empty():
		push_error("PlayerSpawner: no spawn points generated yet!")
		return

	if player_scene == null:
		push_warning("PlayerSpawner: no player scene assigned, nothing to spawn")
		return

	for existing in current_players:
		if is_instance_valid(existing):
			existing.queue_free()

	current_players.clear()
	current_player_cell = spawn_points[rng.randi_range(0, spawn_points.size() - 1)]

	var count := maxi(Match.cube_count(), 1)

	for seat in range(count):
		var cell := cells[seat] if seat < cells.size() else current_player_cell
		current_players.append(_spawn_one(seat, cell, count))

	current_player_instance = current_players[0]
	_let_them_pass()
	_hand_the_window_over()


## Cubes walk through each other, and neither pushes the other's camera around.
##
## A corridor in this maze is one cell wide. Two players meeting in one would
## simply plug it, and the level is something the room is doing together rather
## than an obstacle course made of each other. The exceptions are put on the
## bodies themselves rather than moved onto a layer of their own, because the
## key, the elevator, the blades and the spheres all watch for players on the
## layer they are already on
func _let_them_pass() -> void:
	for cube in current_players:
		for other in current_players:
			if cube == other:
				continue

			cube.add_collision_exception_with(other)
			cube.camera_rig.ignore(other)

	for cube in current_players:
		if cube.is_ghosted():
			PlayerGhost.attach_to(cube)
		elif Match.is_private_race():
			PlayerGhost.attach_to(cube)
		elif Seats.count() > 1:
			PlayerTag.attach_to(cube)

	for cube in current_players:
		if cube.is_bot:
			BotBrain.attach_to(cube, Match.bot_skill())


## The first seat keeps the window. Every cube carries a camera of its own and
## the last one into the tree would otherwise be holding it, which with bots in
## the round is a view of a cube nobody is playing
func _hand_the_window_over() -> void:
	if Match.is_split() or current_players.is_empty():
		return

	var first := current_players[0]
	if is_instance_valid(first.view):
		first.view.make_current()


## Builds one cube and puts it down. The seat and whether anybody is driving it
## are written before the node is in the tree, so every script under it reads
## the right ones in its own _ready
func _spawn_one(seat: int, cell: Vector2i, total: int) -> Player:
	var cube := player_scene.instantiate() as Player
	cube.seat = seat
	cube.is_bot = Match.is_bot_seat(seat)
	holder.add_child(cube)
	cube.global_position = cell_to_world(cell) + seat_offset(seat, total)
	return cube


## How far off the shared cell that seat stands. Nothing at all for a single
## cube, so a solo spawn is the world position it always was, and a small ring
## for the rest — four bodies dropped onto one tile spend the first second of the
## level shoving each other down a corridor.
##
## A race is the exception and takes the exact same tile for everybody. Nobody
## may start half a step ahead of anybody else, and it costs nothing to read:
## each player sees their own cube and the rest as ghosts standing in it
func seat_offset(seat: int, total: int) -> Vector3:
	if total <= 1 or Match.is_private_race():
		return Vector3.ZERO

	var around := TAU * float(seat) / float(total)
	return Vector3(cos(around), 0.0, sin(around)) * SEAT_RING


## Array.shuffle() ignores spawn_seed because it draws from the global rng
func _shuffle(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap


## Converts a grid cell into a world position above the floor, the player
## drops down from there on its own
func cell_to_world(cell: Vector2i) -> Vector3:
	var local_pos: Vector3 = map_generator.grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
	local_pos.y = spawn_height
	return map_generator.grid_map.to_global(local_pos)
