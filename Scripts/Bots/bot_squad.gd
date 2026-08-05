class_name BotSquad
extends Node

## What every bot in the level shares, and the one thing they have to agree on.
##
## Three jobs that belong together because they all hang off the finished map:
## handing the brains the spawners they read the level from, keeping the walks
## through the corridors in one cache instead of one per bot, and making sure two
## bots on a side do not set off for the same corner of the maze.
##
## It is added by the round once the map stands, which is the first moment the
## key and the exit actually exist — a brain built with the cubes is older than
## both of them and would have found neither

## Put in a group so a brain can look it up without a path
const GROUP := &"bot_squad"

## How many walks through the corridors are kept. Every one of them is a full
## sweep of the map, and the handful of cells worth keeping — the key, the exit,
## each side's corner — is far under this
const CACHE_SIZE := 16

## Seconds a claimed target stands before the bot that took it has to say again
## that it still wants it. Without it a bot that died would hold its corner of
## the maze for the rest of the round
const CLAIM_LIFE := 4.0

var map_generator: MapGenerator = null
var key_spawner: KeySpawner = null
var elevator_spawner: ElevatorSpawner = null
var item_spawner: ItemSpawner = null

## Steps from one cell to every other, by the cell it was walked from
var _fields: Dictionary = {}

## The order they were asked for in, oldest first, so the cache can drop one
var _field_order: Array[Vector2i] = []

## Where each bot is heading and when it last said so, by account
var _claims: Dictionary = {}
var _claimed_at: Dictionary = {}

## Every corridor cell of the maze, built once. The generator walks the whole
## grid to answer this, and a dozen bots asking it twice a second each would
## spend more of the round listing the map than walking it
var _cells: Array[Vector2i] = []


## The squad of this level, null in one that has no bots in it
static func find(tree: SceneTree) -> BotSquad:
	return tree.get_first_node_in_group(GROUP) as BotSquad


func _ready() -> void:
	add_to_group(GROUP)
	_read_map()


## The spawners hang on the map this was added to, which is the only node that
## knows all of them
func _read_map() -> void:
	var map := get_parent()
	if map == null:
		return

	map_generator = map.get("map_generator") as MapGenerator
	key_spawner = map.get("key_spawner") as KeySpawner
	elevator_spawner = map.get("elevator_spawner") as ElevatorSpawner
	item_spawner = map.get("item_spawner") as ItemSpawner


## True once the level can actually be read, which is what a brain waits for
func is_ready() -> bool:
	return not cells().is_empty()


## Every cell of the maze a cube may stand on
func cells() -> Array[Vector2i]:
	if _cells.is_empty() and map_generator != null:
		_cells = map_generator.get_path_cells()

	return _cells


## Steps through the corridors from that cell to every other one. Kept, because
## the cells worth walking from are the same ones for every bot in the round
func field_from(cell: Vector2i) -> Array:
	if _fields.has(cell):
		return _fields[cell]

	if map_generator == null:
		return []

	var field := map_generator.path_distance_field(cell)
	_fields[cell] = field
	_field_order.append(cell)

	if _field_order.size() > CACHE_SIZE:
		_fields.erase(_field_order.pop_front())

	return field


## Where the keys were put down, which is one cell for the whole round
func key_cell() -> Vector2i:
	return key_spawner.current_key_cell if key_spawner != null else Vector2i(-1, -1)


## The corridor in front of the way out. The exit itself is carved into a wall
## and cannot be walked to, only up to
func exit_cell() -> Vector2i:
	if elevator_spawner == null or map_generator == null:
		return Vector2i(-1, -1)

	var doors := map_generator.get_path_neighbors(elevator_spawner.current_elevator_cell)
	return doors[0] if not doors.is_empty() else Vector2i(-1, -1)


## Every sphere still lying in the maze
func spheres() -> Array[Node3D]:
	var found: Array[Node3D] = []

	if item_spawner == null:
		return found

	for node in item_spawner.spawned_items:
		if is_instance_valid(node):
			found.append(node)

	return found


## That bot says where it is heading, so the rest of its side can stay off it
func claim(account: int, cell: Vector2i) -> void:
	_claims[account] = cell
	_claimed_at[account] = _now()


func drop_claim(account: int) -> void:
	_claims.erase(account)
	_claimed_at.erase(account)


## How badly that cell is already spoken for by the rest of that side, 0 for one
## nobody is walking to and 1 for one somebody is standing on.
##
## This is the whole of the splitting up: a bot scores every cell it might head
## for and takes this off the score, so four bots on a side settle on four
## corners of the maze without any of them being told which one is theirs
func crowding(account: int, team: int, cell: Vector2i, reach: int) -> float:
	var worst := 0.0
	var span := float(maxi(reach, 1))

	for id: int in _claims:
		if id == account or Match.team_of(id) != team:
			continue

		if _now() - float(_claimed_at.get(id, 0.0)) > CLAIM_LIFE:
			continue

		var gap := Vector2(cell - (_claims[id] as Vector2i)).length()
		worst = maxf(worst, 1.0 - minf(gap / span, 1.0))

	return worst


func _now() -> float:
	return float(Time.get_ticks_msec()) * 0.001
