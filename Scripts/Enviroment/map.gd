extends GridMap


@export var map_generator : MapGenerator
@export var key_spawner : KeySpawner
@export var saw_spawner : SawSpawner
@export var elevator_spawner : ElevatorSpawner
@export var item_spawner : ItemSpawner
@export var player_spawner : PlayerSpawner
@export var blood_spawner : BloodSpawner
@export var glass_wall_spawner : GlassWallSpawner

## The level that gets built. Everything in it is pushed onto the spawners
## before they run, so swapping this one file swaps the level. Without it the
## values set on the spawner nodes themselves are used.
##
## While a campaign is running this is overwritten with the level the player is
## on, so the one set here is what the scene builds when it is opened on its own
@export var map_data : MapData

## -1 = every component keeps its own seed, otherwise this one seed rebuilds
## the exact same level. A MapData carries its own and overrules this one
@export var world_seed : int = -1


## The campaign decides which level is built, the resource on this node is only
## what the scene falls back to when it is opened on its own. A round with rules
## of its own brings its level along and comes first, it is the one thing that is
## not picked out of a list but generated from the seed everybody shares.
##
## The UI reads the run state in its own _ready, and a child is ready before its
## parent. Handing the level over here instead of in _ready keeps the UI from
## showing the key of the attempt before across a scene reload.
func _enter_tree() -> void:
	var level := Match.level() if Match.is_racing() else Levels.current()
	if level != null:
		map_data = level

	GameState.begin_level(map_data)
	DeathMarks.begin_level(map_data)
	ItemSystem.reset()


## A level that fails to load leaves map_data empty and the map quietly builds
## from the values on the spawner nodes instead, which reads as the resource
## being ignored. Worth a line in the output
func _ready() -> void:
	if map_data == null:
		push_warning("Map: no MapData assigned, building from the values on the spawner nodes")
	else:
		_apply_map_data()

	var run_seed := map_data.world_seed if map_data != null else world_seed
	if run_seed >= 0:
		_apply_world_seed(run_seed)

	map_generator.generate_map()

	if player_spawner != null:
		player_spawner.generate_spawn_points()
		Match.spawn_cells_from(map_generator.get_path_cells(), map_generator.width)

		player_spawner.spawn_seats(Match.seat_cells())

	var with_exit := map_data == null or map_data.with_exit

	if with_exit:
		key_spawner.generate_spawn_points()
		key_spawner.spawn_keys(Match.key_owners())

		if elevator_spawner != null:
			elevator_spawner.generate_spawn_points()
			elevator_spawner.spawn_elevator()
	else:
		saw_spawner.key_spawner = null
		saw_spawner.elevator_spawner = null

	if glass_wall_spawner != null:
		glass_wall_spawner.spawn_walls()

	saw_spawner.spawn_saws()

	if item_spawner != null:
		item_spawner.spawn_items()

	if blood_spawner != null:
		blood_spawner.spawn_marks()

	Match.attach_to_map(self)


## Hands the level over to the spawners, one section per spawner
func _apply_map_data() -> void:
	_apply_maze()
	_apply_player()
	_apply_key()
	_apply_elevator()
	_apply_saws()
	_apply_items()
	_apply_glass_walls()


func _apply_maze() -> void:
	map_generator.shape = map_data.shape
	map_generator.size = map_data.size
	map_generator.radius = map_data.radius
	map_generator.openness = map_data.openness
	map_generator.with_roof = map_data.with_roof
	map_generator.roof_openness = map_data.roof_openness
	map_generator.roof_hole_size = map_data.roof_hole_size
	map_generator.ground_item_index = map_data.ground_item_index
	map_generator.wall_item_index = map_data.wall_item_index
	map_generator.roof_item_index = map_data.roof_item_index
	map_generator.map_seed = map_data.map_seed


## Only the tuning is pushed over, the scenes a spawner builds from stay on
## its own node. Every spawner here is optional, the map runs without them
func _apply_player() -> void:
	if player_spawner == null:
		return

	player_spawner.spawn_point_count = map_data.player_spawn_point_count
	player_spawner.spawn_height = map_data.player_spawn_height
	player_spawner.spawn_seed = map_data.player_spawn_seed


func _apply_key() -> void:
	if key_spawner == null:
		return

	key_spawner.spawn_point_count = map_data.key_spawn_point_count
	key_spawner.min_distance_to_player = map_data.key_min_distance_to_player
	key_spawner.spawn_seed = map_data.key_spawn_seed


func _apply_elevator() -> void:
	if elevator_spawner == null:
		return

	elevator_spawner.min_distance_to_key = map_data.elevator_min_distance_to_key
	elevator_spawner.min_distance_to_player = map_data.elevator_min_distance_to_player
	elevator_spawner.spawn_point_count = map_data.elevator_spawn_point_count
	elevator_spawner.height_in_cells = map_data.elevator_height_in_cells
	elevator_spawner.facing_offset_degrees = map_data.elevator_facing_offset_degrees
	elevator_spawner.spawn_seed = map_data.elevator_spawn_seed


func _apply_saws() -> void:
	if saw_spawner == null:
		return

	saw_spawner.saw_count = map_data.saw_count
	saw_spawner.ai_saw_count = map_data.ai_saw_count
	saw_spawner.min_patrol_length = map_data.saw_min_patrol_length
	saw_spawner.max_patrol_length = map_data.saw_max_patrol_length
	saw_spawner.min_speed = map_data.saw_min_speed
	saw_spawner.max_speed = map_data.saw_max_speed
	saw_spawner.route_spacing = map_data.saw_route_spacing
	saw_spawner.spawn_seed = map_data.saw_spawn_seed


## The pool goes over even without an item spawner, a level can hand out items
## through something other than the spheres
func _apply_items() -> void:
	ItemSystem.set_item_pool(map_data.item_pool)

	if item_spawner == null:
		return

	item_spawner.item_count = map_data.item_count
	item_spawner.min_distance = map_data.item_min_distance
	item_spawner.min_distance_to_player = map_data.item_min_distance_to_player
	item_spawner.spawn_seed = map_data.item_spawn_seed
	item_spawner.restock = map_data.restock_items


## A level that says it has no glass walls gets none, whatever count it carries.
## The switch is what a level is read by, the count is only how many
func _apply_glass_walls() -> void:
	if glass_wall_spawner == null:
		return

	glass_wall_spawner.wall_count = map_data.glass_wall_count if map_data.with_glass_walls else 0
	glass_wall_spawner.item_index = map_data.glass_wall_item_index
	glass_wall_spawner.min_distance = map_data.glass_wall_min_distance
	glass_wall_spawner.spawn_seed = map_data.glass_wall_seed


## Every component gets its own offset, the same number everywhere would make
## them all draw the identical sequence of values
func _apply_world_seed(run_seed: int) -> void:
	map_generator.map_seed = run_seed
	key_spawner.spawn_seed = run_seed + 1
	saw_spawner.spawn_seed = run_seed + 2

	if elevator_spawner != null:
		elevator_spawner.spawn_seed = run_seed + 3

	if item_spawner != null:
		item_spawner.spawn_seed = run_seed + 4

	if player_spawner != null:
		player_spawner.spawn_seed = run_seed + 5

	if glass_wall_spawner != null:
		glass_wall_spawner.spawn_seed = run_seed + 6
