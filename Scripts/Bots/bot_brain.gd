class_name BotBrain
extends Node

## What sits where a player would. It drives one cube: it decides where that cube
## wants to be, walks it there through the corridors, keeps it off the blades and
## spends what it is carrying.
##
## The cube itself is a cube like any other. It has a seat, an account, a key of
## its own, a slot and a place on the board, and everything in the game that
## touches a player touches this one the same way — so nothing about the round had
## to learn that some of the runners are not people. All this does is write a
## direction where the input would have been.
##
## The three rungs of the ladder are one resource and no branches: the difference
## between a bot that blunders into a saw and one that reads the maze is how far
## ahead it looks, how many cells it weighs up, how long it takes to react and
## whether it is simply told where the key is

## What one cell of bare floor is worth to a painter, and what one of the other
## side's is. Taking a tile off somebody counts double, it moves the score twice
const BARE_TILE := 1.0
const ENEMY_TILE := 1.5

## What a tile that is already this side's is worth, which is less than nothing:
## walking back over your own paint is the one thing a round is lost by
const OWN_TILE := -0.6

## How much of a neighbouring tile's worth rubs off on the cell itself, so a bot
## heads for a patch of floor rather than for the one best tile in the maze
const PATCH_SHARE := 0.35

## What one step of the walk there costs, weighed against those tile values
const STEP_COST := 0.06

## How hard a corner of the map that a team mate has already claimed pushes
const SPREAD_WEIGHT := 2.5

## How far a roaming bot is willing to walk to somewhere it has not been, in
## steps. Without a limit it spends the round crossing the map
const ROAM_REACH := 40

## How far off the cell its walk was measured from a bot may get before the
## measuring is worth doing again, in cells
const FIELD_DRIFT := 4.0

## How close to the middle of a cell counts as having reached it
const CELL_REACH := 0.62

## Under this speed, while it is asking to move, a bot counts as stuck
const STUCK_SPEED := 0.6

## Seconds of that before it gives up on where it was going
const STUCK_PATIENCE := 1.1

## Seconds it will stand and wait out a blade before deciding the corridor is
## not going to clear and taking another one
const BLOCK_PATIENCE := 1.5

## How much faster that patience is won back than it is spent. A blade sweeping
## a junction leaves the way clear every second pass, and a counter that started
## over on each of those frames never reached the end of anything — the bot stood
## in the same corridor for the whole round
const WAIT_FORGIVENESS := 2.0

## Shortest gap between two thinks when a bot ran out of route rather than out of
## time. Only here to keep one that has arrived, or one in a maze it cannot find
## a way through at all, from sweeping the whole map every frame
const MIN_THINK_GAP := 0.12

## How hard the blades pull the cube off its route, against the route itself
const DODGE_WEIGHT := 1.8

## Share of the danger range at which a blade in the way stops being something
## to wait out and becomes something to run from
const FLEE_FORCE := 0.45

## How many cells of fresh floor a run has to promise before it beats simply
## walking off to a better part of the map
const PAINT_RUN_FLOOR := 4

## What a cell with a sphere on it is worth on top of its floor, while the slot
## is empty. Well over a bare tile, so a sphere one step off the run is taken
const SPHERE_WORTH := 2.0

## The longest a route may get. A walk that steps around a blade is no longer
## guaranteed to be getting closer with every cell, so it needs an end
const ROUTE_CAP := 512

## How many cells of detour a blade in the way is worth going around. Under it
## the bot walks through and takes its chances, over it there is no corner of the
## maze it will not walk to rather than wait
const BLADE_COST := 5.0

## How long a bot may go without covering ground before it stops being careful,
## how far it has to have got in that time to count, and how long it stays
## reckless once it has given up
const DESPERATE_AFTER := 2.2
const DESPERATE_STEP := 2.5
const DESPERATE_FOR := 2.5

## Meters at which another cube is close enough to be walked around. They pass
## straight through each other, so nothing else keeps a side apart
const MATE_ROOM := 3.0

## How hard that nudge is against everything else the cube is being asked to do.
## Small on purpose: it spreads a crowd out, it does not steer
const MATE_WEIGHT := 0.35

## Meters at which a blade is worth spending a shield or a rush on
const SAW_PANIC := 8.0

## Meters at which somebody on another side is worth a jolt
const SHOCK_REACH := 11.0

## Cells of floor that are not this side's, around the cube, before a splash is
## worth throwing
const SPLASH_WORTH := 10

## How far the splash count looks, in cells
const SPLASH_RADIUS := 7

## Tiles the other sides have to hold before the roller is worth sending out
const ERASER_WORTH := 12

## The cube this brain drives
var cube: Player = null

var _skill: BotSkill = null
var _squad: BotSquad = null
var _movement: PlayerMovement = null
var _account: int = 0

var _rng := RandomNumberGenerator.new()

## Where it is walking, cell by cell, and how far along that it is
var _route: Array[Vector2i] = []
var _step: int = 0

## The cell it settled on last time it thought
var _goal := Vector2i(-1, -1)

## Seconds until it thinks again, and how long since it last did
var _think_left: float = 0.0
var _since_think: float = 0.0

## Steps from one cell to everywhere, and the cell that was measured from
var _field: Array = []
var _field_from := Vector2i(-9999, -9999)

## Where its feet have got to, which trails what it wants by the reaction time
var _drive := Vector3.ZERO

## The blades near this cube, and where each of them will be a moment from now.
## Culled once a frame: walking the waypoints of every saw in the maze over and
## over for a dozen bots is the frame gone
var _near: Array[SawMover] = []
var _threats: Array[Vector3] = []

## The order this bot tries the four ways out of a cell in. Two shortest routes
## of one length are common in an open maze, and a fixed order had every bot
## picking the identical one — which is what put them in single file
var _turn_order: Array[Vector2i] = []

## How long ago this bot was in a cell, by cell, and the clock that orders them
var _visited: Dictionary = {}
var _clock: float = 0.0

## Seconds it has been asking to move without getting anywhere, waiting on a
## blade included — a corridor a patrol never leaves is as blocked as a wall
var _stuck: float = 0.0

## True while this frame's plan was to stand and let a blade go by, and how long
## it has been doing that
var _blocked: bool = false
var _waited: float = 0.0

## True for the one think after waiting too long, which sends the bot down some
## other corridor instead of back at the one it could not get past
var _detour: bool = false

## Where it stood when its progress was last looked at, how long until the next
## look, and how long it has left of not caring about blades
var _progress_from := Vector3.ZERO
var _progress_left: float = DESPERATE_AFTER
var _desperate_left: float = 0.0

## Seconds the thing in its slot has been sitting there
var _item_held: float = 0.0

## True once it has been close enough to the key or the way out to have found
## them. A bot that has to search for something does not unfind it
var _found_key: bool = false
var _found_exit: bool = false


## Built by the spawner rather than living in the player scene, the same way the
## ghost is: a cube nobody drives is the exception and not the rule
static func attach_to(player: Player, skill: BotSkill) -> BotBrain:
	var made := BotBrain.new()
	made.name = "Brain"
	made.cube = player
	made._skill = skill
	player.add_child(made)
	return made


func _ready() -> void:
	if _skill == null:
		_skill = Bots.skill_of(Bots.default_skill())

	_movement = cube.movement
	_account = cube.account()
	_rng.seed = _account * 7919 + 13
	_think_left = _rng.randf() * _skill.think_interval
	_draw_turn_order()


## Shuffles the four ways out of a cell once, so this bot has a leaning of its
## own where two routes are the same length
func _draw_turn_order() -> void:
	_turn_order = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for at in range(_turn_order.size() - 1, 0, -1):
		var to := _rng.randi_range(0, at)
		var swap := _turn_order[at]
		_turn_order[at] = _turn_order[to]
		_turn_order[to] = swap


## Nothing is left behind on a cube this stops driving, the round may still put
## somebody else's claim on the corner it was heading for
func _exit_tree() -> void:
	if _squad != null:
		_squad.drop_claim(_account)


func _physics_process(delta: float) -> void:
	if not _awake():
		_drive = Vector3.ZERO
		_movement.drive = Vector3.ZERO
		return

	_clock += delta
	_visited[_here()] = _clock
	_watch_for_stuck(delta)
	_watch_for_progress(delta)

	_think_left -= delta
	_since_think += delta

	if _think_left <= 0.0 or (_since_think >= MIN_THINK_GAP and _at_a_loss()):
		_think()

	_drive = _drive.move_toward(_aim(), delta / maxf(_skill.reaction_time, 0.01))
	_movement.drive = _drive

	_spend_item(delta)


## True while there is a cube on its feet in a level this can be read from
func _awake() -> bool:
	if _squad == null:
		_squad = BotSquad.find(get_tree())

	if _squad == null or not _squad.is_ready() or cube == null:
		return false

	if cube.death.is_dead or cube.spawn.is_spawning:
		return false

	return not Match.round_ended() and not Match.showing_results(_account)


## True while it has walked its route out or walked into something the route did
## not know about, which are the two reasons to think early
func _at_a_loss() -> bool:
	return _step >= _route.size() or _stuck > STUCK_PATIENCE or _waited > BLOCK_PATIENCE


## Picks somewhere to be and lays out the way there. A goal there is no route to
## is dropped for anywhere at all, standing still is the one thing worse than
## walking off in the wrong direction
func _think() -> void:
	_think_left = _skill.think_interval
	_since_think = 0.0
	_detour = _detour or _stuck > STUCK_PATIENCE or _waited > BLOCK_PATIENCE
	_stuck = 0.0
	_waited = 0.0

	if Match.is_painting() and not _detour and _lay_paint_route():
		return

	_goal = _pick_goal()
	_lay_route(_goal)

	if _route.size() < 2:
		_goal = _anywhere()
		_lay_route(_goal)


## Lays out the run of fresh floor in front of the cube, and says whether it
## found one long enough to be worth walking. A neighbourhood already in this
## side's colour has nothing to offer and hands the round back to the goal
## picker, which is what moves the bot to the next part of the map
func _lay_paint_route() -> bool:
	var found := _paint_route()
	if found.size() < PAINT_RUN_FLOOR or _fresh_in(found) < PAINT_RUN_FLOOR:
		return false

	_route = found
	_step = 1
	_goal = found[found.size() - 1]
	_squad.claim(_account, _goal)
	return true


## How many cells of that run are not already this side's. A greedy walk always
## finds somewhere to go, so without this a bot in a corner it had already
## painted shuffled around inside it for the rest of the round instead of
## walking off to floor that was still worth something
func _fresh_in(route: Array[Vector2i]) -> int:
	var mine := Match.team_of(_account)
	var claims: Dictionary = Match.paint().claims
	var fresh := 0

	for cell in route:
		var claim: PaintState.Claim = claims.get(cell, null)
		if claim == null or claim.team != mine:
			fresh += 1

	return fresh


## The way a painter actually wants to walk: fresh floor, one cell at a time.
##
## Not the shortest way to somewhere good. The shortest way anywhere runs over
## the paint you already own, and a round is won on how much floor you cover a
## second rather than on which corner you reach — so the run is grown a cell at a
## time onto whichever neighbour is worth the most, and doubling back is worth
## nothing at all. How far it is grown is the rung
func _paint_route() -> Array[Vector2i]:
	var walker := _squad.map_generator
	var mine := Match.team_of(_account)
	var claims: Dictionary = Match.paint().claims
	var spheres := _sphere_cells()
	var here := _here()

	var route: Array[Vector2i] = [here]
	var seen: Dictionary = {here: true}
	var cell := here

	while route.size() < maxi(_skill.paint_route, 2):
		var best := cell
		var best_worth := -INF

		for step in _turn_order:
			var neighbour: Vector2i = cell + step
			if seen.has(neighbour) or not walker.is_path_cell(neighbour):
				continue

			var worth := _tile_worth(neighbour, mine, claims) \
				+ _beyond(neighbour, cell, mine, claims) * PATCH_SHARE

			if spheres.has(neighbour):
				worth += SPHERE_WORTH

			if worth > best_worth:
				best_worth = worth
				best = neighbour

		if best == cell:
			break

		seen[best] = true
		route.append(best)
		cell = best

	return route


## The cells with a sphere standing on them, or nothing while the slot is full.
##
## A painter that only ever weighed floor walked straight past the spheres, and
## a round of items nobody spends is half the mode missing. Folding them into the
## same walk is what makes a bot pick one up on its way rather than going to
## fetch it
func _sphere_cells() -> Dictionary:
	var found: Dictionary = {}

	if cube.inventory == null or cube.inventory.held_item != null:
		return found

	for sphere in _squad.spheres():
		found[_cell_of(sphere.global_position)] = true

	return found


## What the floor past that cell is worth, not counting the way the cube came
## in. It is what keeps a run from turning down a corridor this side has already
## taken just because the one cell at the mouth of it happens to be bare
func _beyond(cell: Vector2i, from: Vector2i, mine: int, claims: Dictionary) -> float:
	var worth := 0.0

	for step in _turn_order:
		var neighbour: Vector2i = cell + step
		if neighbour == from or not _squad.map_generator.is_path_cell(neighbour):
			continue

		worth += _tile_worth(neighbour, mine, claims)

	return worth


## Where this bot is going, and a sphere on the way there if one is worth it
func _pick_goal() -> Vector2i:
	if _detour:
		_detour = false
		return _roam_goal()

	if _rng.randf() < _skill.mistake_chance:
		return _anywhere()

	var goal := _mode_goal()
	var sphere := _sphere_goal(goal)
	return sphere if sphere.x >= 0 else goal


## What this bot is actually trying to do, which is the one thing the three
## modes disagree on
func _mode_goal() -> Vector2i:
	if Match.is_painting():
		return _paint_goal()

	if Match.mode().with_exit:
		return _race_goal()

	return _roam_goal()


## The key while it is without one, the way out once it carries it — but only
## once it knows where either of them is. A bot that has to find them first
## searches the maze, which is what makes the lower rungs lose a race
func _race_goal() -> Vector2i:
	var carrying := Match.has_key(_account)
	var target := _squad.exit_cell() if carrying else _squad.key_cell()

	if target.x < 0 or not _knows(target, carrying):
		return _roam_goal()

	return target


## True once this bot has been close enough to that place to have found it, and
## it stays found. The top rung is simply told where both of them are
func _knows(target: Vector2i, carrying: bool) -> bool:
	if _skill.knows_objectives:
		return true

	if carrying:
		_found_exit = _found_exit or _within_sight(target)
		return _found_exit

	_found_key = _found_key or _within_sight(target)
	return _found_key


## The best patch of floor that is not already this side's, weighed against the
## walk there and against wherever the rest of the side is heading.
##
## The cells are sampled rather than all of them walked, and how many of them are
## sampled is the rung: a bot that looks at fourteen cells finds somewhere to
## paint, one that looks at a hundred and thirty finds the right somewhere
func _paint_goal() -> Vector2i:
	var field := _own_field()
	var cells := _squad.cells()
	if cells.is_empty():
		return _here()

	var mine := Match.team_of(_account)
	var claims: Dictionary = Match.paint().claims
	var best := _here()
	var best_score := -INF

	for _try in range(maxi(_skill.foresight, 1)):
		var cell: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		var steps := _squad.map_generator.distance_in_field(field, cell)
		if steps <= 0:
			continue

		var score := _patch_worth(cell, mine, claims) - float(steps) * STEP_COST
		score -= _squad.crowding(_account, mine, cell, _skill.spread_radius) \
			* _skill.spread * SPREAD_WEIGHT

		if score > best_score:
			best_score = score
			best = cell

	_squad.claim(_account, best)
	return best


## What that cell and the floor around it are worth to this side
func _patch_worth(cell: Vector2i, mine: int, claims: Dictionary) -> float:
	var worth := _tile_worth(cell, mine, claims)

	for neighbour in _squad.map_generator.get_path_neighbors(cell):
		worth += _tile_worth(neighbour, mine, claims) * PATCH_SHARE

	return worth


func _tile_worth(cell: Vector2i, mine: int, claims: Dictionary) -> float:
	if not claims.has(cell):
		return BARE_TILE

	var claim: PaintState.Claim = claims[cell]
	return OWN_TILE if claim.team == mine else ENEMY_TILE


## Whatever corner of the maze this bot has left alone the longest, which is how
## it searches for something it has not found and how it fills a mode that gives
## it nothing else to do
func _roam_goal() -> Vector2i:
	var field := _own_field()
	var cells := _squad.cells()
	if cells.is_empty():
		return _here()

	var best := _here()
	var best_score := -INF

	for _try in range(maxi(_skill.foresight, 1)):
		var cell: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		var steps := _squad.map_generator.distance_in_field(field, cell)
		if steps <= 0 or steps > ROAM_REACH:
			continue

		var score := _clock - float(_visited.get(cell, -100000.0)) - float(steps) * 0.2
		score -= _squad.crowding(_account, Match.team_of(_account), cell,
			_skill.spread_radius) * _skill.spread * SPREAD_WEIGHT

		if score > best_score:
			best_score = score
			best = cell

	_squad.claim(_account, best)
	return best


## A sphere worth stepping aside for, or a cell of -1 when the slot is full or
## the nearest one costs more of the way than the rung is willing to give up.
##
## What is measured is what the detour adds to the walk, not how far the sphere
## is. A sphere down the corridor the bot is already in is free and always worth
## taking; one behind it is the whole way back. Measuring the distance alone is
## what had the bots chaining spheres around the maze forever with the key in
## their pocket and the way out ignored.
##
## A ghost is sent away empty handed. It cannot take a sphere out of somebody
## else's maze, so its slot never fills — and a bot walking to a sphere it will
## never pick up walks to it again the moment it arrives, forever
func _sphere_goal(objective: Vector2i) -> Vector2i:
	if _skill.item_detour <= 0 or cube.inventory == null or cube.inventory.held_item != null:
		return Vector2i(-1, -1)

	if cube.is_ghosted():
		return Vector2i(-1, -1)

	var walker := _squad.map_generator
	var mine := _own_field()
	var ahead: Array = _squad.field_from(objective) if _is_landmark(objective) else []
	var straight := walker.distance_in_field(ahead, _here()) if not ahead.is_empty() else 0

	var best := Vector2i(-1, -1)
	var cheapest := _skill.item_detour + 1

	for sphere in _squad.spheres():
		var cell := _cell_of(sphere.global_position)
		var there := walker.distance_in_field(mine, cell)
		if there <= 0:
			continue

		var onwards := walker.distance_in_field(ahead, cell) if not ahead.is_empty() else 0
		if onwards < 0:
			continue

		var cost := there + onwards - straight
		if cost < cheapest:
			cheapest = cost
			best = cell

	return best


## True while that cell is close enough to count as somewhere this bot has seen.
## Measured through the corridors from the cell itself, which the level walked
## once and every bot in it reads out of the same cache
func _within_sight(cell: Vector2i) -> bool:
	var steps := _squad.map_generator.distance_in_field(_squad.field_from(cell), _here())
	return steps >= 0 and steps <= _skill.sight_range


## Any corridor cell at all, which is where a bot ends up when nothing else has
## anything to say
func _anywhere() -> Vector2i:
	var cells := _squad.cells()
	if cells.is_empty():
		return _here()

	return cells[_rng.randi_range(0, cells.size() - 1)]


## Steps from where this bot stands to everywhere else, kept until it has walked
## far enough off that cell for the numbers to be worth measuring again
func _own_field() -> Array:
	var here := _here()

	if not _field.is_empty() and Vector2(here - _field_from).length() < FIELD_DRIFT:
		return _field

	_field_from = here
	_field = _squad.map_generator.path_distance_field(here)
	return _field


## Walks the corridors out to that cell and takes it up at whichever point of the
## way is nearest, so a fresh plan is a change of mind at the next corner rather
## than a walk back to where the thinking started
func _lay_route(target: Vector2i) -> void:
	_route = _find_route(target)
	_step = 0

	if _route.is_empty():
		return

	var closest := 0
	var shortest := INF
	var at := cube.global_position

	for index in range(_route.size()):
		var gap := _flat(_world_of(_route[index]) - at).length_squared()
		if gap < shortest:
			shortest = gap
			closest = index

	_step = mini(closest + 1, _route.size() - 1)


## The way from here to there, cell by cell. Whichever of the two ends the level
## already measured from is the one the walk goes down: the key and the exit
## stand still all round and every bot reads the same cached sweep of them, so a
## race costs no thinking at all
func _find_route(target: Vector2i) -> Array[Vector2i]:
	if target.x < 0 or target == _here():
		return [] as Array[Vector2i]

	if _is_landmark(target):
		return _downhill(_squad.field_from(target), _here())

	var back := _downhill(_own_field(), target)
	back.reverse()
	return back


## True for a cell the whole level walks to, which is worth a cache of its own
func _is_landmark(cell: Vector2i) -> bool:
	return cell == _squad.key_cell() or cell == _squad.exit_cell()


## Steps from that cell down to whatever the field was measured from, one cell
## closer each time
func _downhill(field: Array, from: Vector2i) -> Array[Vector2i]:
	var walker := _squad.map_generator
	var route: Array[Vector2i] = []

	if field.is_empty() or walker.distance_in_field(field, from) < 0:
		return route

	var cell := from
	var seen: Dictionary = {cell: true}
	route.append(cell)

	while walker.distance_in_field(field, cell) > 0 and route.size() < ROUTE_CAP:
		var next := _step_down(field, cell, route.size(), seen)

		if next == cell:
			break

		seen[next] = true
		route.append(next)
		cell = next

	return route


## The next cell of the route: the one that costs least, counting both how much
## closer it gets and what is going to be standing on it.
##
## Weighed rather than ruled on. The old version looked for a neighbour the same
## distance from the goal and stepped onto that instead — but on a grid every
## neighbour is exactly one step nearer or one step further, never the same, so
## that branch could not fire and the bot had no way round anything. It stood in
## the corridor jittering at a blade it was perfectly able to walk around.
##
## As a cost it works: a step away from the goal costs one more cell, a step onto
## a blade costs several, so the detour wins on its own — and where every way is
## blocked all of them are penalised alike and the bot goes through and deals
## with it on the way
func _step_down(field: Array, cell: Vector2i, walked: int, seen: Dictionary) -> Vector2i:
	var walker := _squad.map_generator
	var best := cell
	var cheapest := INF

	for step in _turn_order:
		var neighbour: Vector2i = cell + step
		if seen.has(neighbour) or not walker.is_path_cell(neighbour):
			continue

		var gap := walker.distance_in_field(field, neighbour)
		if gap < 0:
			continue

		var cost := float(gap)
		if _skill.routes_around_blades and not _desperate() and _blade_on(neighbour, walked):
			cost += BLADE_COST

		if cost < cheapest:
			cheapest = cost
			best = neighbour

	return best


## Everything the cube is being asked to do this frame, added up
func _aim() -> Vector3:
	_read_blades()
	return (_dodge_or_go() + _room_from_mates()).limit_length(1.0)


## The route, against the blades.
##
## A blade off to the side is leaned away from and walked past. One the route
## runs straight into is not weighed against the route at all — the way out and
## the way through are opposite directions, and the average of them is still the
## way through, only slower. Close, the bot runs; further off it eases back.
##
## And a corridor with a blade about to cross it is not walked into at all. The
## push can only ever move a cube away from a blade it is already beside, which
## is one step too late: this is the bot stopping at the corner and letting the
## thing go by, and how far down its own route it looks is the rung
func _dodge_or_go() -> Vector3:
	var wanted := _route_direction()
	var push := _dodge()
	var force := minf(push.length(), 1.0)
	var escape := push.normalized() if force > 0.01 else Vector3.ZERO
	var into := force > 0.01 and wanted.dot(escape) < 0.0

	_blocked = false

	if into and force >= FLEE_FORCE:
		return escape * _skill.pace

	if into or _blocked_ahead():
		_blocked = true
		return escape * force * _skill.pace

	if force > 0.01:
		return (wanted + escape * force * DODGE_WEIGHT).limit_length(1.0) * _skill.pace

	return wanted.limit_length(1.0) * _skill.pace


## Where every blade near this cube is going to be. Culled by plain distance
## first, so a maze full of saws costs one length check each
func _read_blades() -> void:
	_near.clear()
	_threats.clear()

	var at := cube.global_position
	var reach := _skill.danger_range + float(_skill.look_ahead_cells) * 2.0 + 6.0

	for node in get_tree().get_nodes_in_group("saw_mover"):
		var mover := node as SawMover
		if mover == null or mover.parent == null or not mover.parent.visible:
			continue

		if not _skill.sees_all_blades \
				and _flat(at - mover.parent.global_position).length() > reach:
			continue

		_near.append(mover)
		_threats.append(_threat_after(mover, _skill.danger_lookahead))


## True while a blade will be standing on a cell of the route at about the
## moment this cube would be walking onto it.
##
## Both sides are played forward. Asking where a blade will be in a second, and
## then holding still for a cell the cube does not reach for three, is what had
## the bots waiting out corridors that were never going to be in their way
func _blocked_ahead() -> bool:
	if _skill.look_ahead_cells <= 0 or _near.is_empty() or _desperate():
		return false

	var pace := maxf(_movement.max_speed * _skill.pace, 0.1)
	var last := mini(_step + _skill.look_ahead_cells, _route.size())

	for at in range(_step, last):
		var point := _world_of(_route[at])
		var when := _flat(point - cube.global_position).length() / pace

		for mover in _near:
			if _flat(_threat_after(mover, when) - point).length() < _skill.blade_room:
				return true

	return false


## True while a blade will be sitting on that cell at about the moment the cube
## could be walking onto it. The one question the route builder asks of the
## level, so a rung that plans around blades never lays a way through one
func _blade_on(cell: Vector2i, steps: int) -> bool:
	if _near.is_empty():
		return false

	var point := _world_of(cell)
	var when := float(steps) * _cell_span() / maxf(_movement.max_speed * _skill.pace, 0.1)

	for mover in _near:
		if _flat(_threat_after(mover, when) - point).length() < _skill.blade_room:
			return true

	return false


func _cell_span() -> float:
	var grid := _squad.map_generator.grid_map
	return grid.cell_size.x if grid != null else 2.0


## A nudge away from the other cubes standing in this one. They walk straight
## through each other, so nothing else keeps a side apart, and four bots that
## picked the same corner arrive as one cube with four names
func _room_from_mates() -> Vector3:
	var push := Vector3.ZERO
	var at := cube.global_position

	for node in get_tree().get_nodes_in_group("player"):
		var other := node as Player
		if other == null or other == cube:
			continue

		var away := _flat(at - other.global_position)
		var gap := away.length()

		if gap >= MATE_ROOM or gap < 0.001:
			continue

		push += away / gap * (1.0 - gap / MATE_ROOM) * MATE_WEIGHT

	return push


## Which way the next cell of the route lies, and the doorway of the lift once
## the cube is standing in front of it with a key
func _route_direction() -> Vector3:
	var at := cube.global_position

	if _boarding():
		return _flat(_world_of(_squad.elevator_spawner.current_elevator_cell) - at).normalized()

	while _step < _route.size() \
			and _flat(_world_of(_route[_step]) - at).length() < CELL_REACH:
		_step += 1

	if _step >= _route.size():
		return Vector3.ZERO

	return _flat(_world_of(_route[_step]) - at).normalized()


## True once this bot is at the way out with what the doors ask for, and the last
## thing left to do is walk into the cabin
func _boarding() -> bool:
	if _squad.elevator_spawner == null or not Match.has_key(_account):
		return false

	var door := _squad.exit_cell()
	return door.x >= 0 and Vector2(_here() - door).length() <= 1.5


## What every blade close enough to matter adds up to, as a push away from where
## it is going to be. What "close enough" and "going to be" mean is the rung
func _dodge() -> Vector3:
	var push := Vector3.ZERO
	var at := cube.global_position
	var reach := _skill.danger_range

	for threat in _threats:
		var away := _flat(at - threat)
		var gap := away.length()

		if gap >= reach or gap < 0.001:
			continue

		if _skill.danger == BotSkill.Danger.SIGHT and not _can_see(threat):
			continue

		push += away / gap * (1.0 - gap / reach)

	return push


## Where that blade will be in that many seconds. The lowest rung is never given
## a lookahead at all and reads a saw where it stands, which is why it keeps
## walking into the one that was about to arrive
func _threat_after(mover: SawMover, seconds: float) -> Vector3:
	var at: Vector3 = mover.parent.global_position
	var travel := mover.speed * mover.speed_multiplier * seconds

	if travel <= 0.0 or mover.waypoints.size() < 2:
		return at

	var index := clampi(mover.target_index, 0, mover.waypoints.size() - 1)
	var walked := 0.0
	var point := at

	while walked < travel and index >= 0 and index < mover.waypoints.size():
		var leg: Vector3 = mover.waypoints[index] - point
		var length := leg.length()

		if length < 0.001:
			index += mover.direction
			continue

		if walked + length >= travel:
			return point + leg.normalized() * (travel - walked)

		walked += length
		point = mover.waypoints[index]
		index += mover.direction

		if _skill.danger != BotSkill.Danger.AHEAD:
			break

	return point


## True while nothing but open corridor stands between the cube and that point.
## Walked cell by cell rather than asked of the physics, the maze is a grid and a
## wall is a cell
func _can_see(point: Vector3) -> bool:
	var from := _here()
	var to := _cell_of(point)
	var span := Vector2(to - from)
	var steps := int(maxf(absf(span.x), absf(span.y)))

	if steps == 0:
		return true

	for i in range(1, steps + 1):
		var along := Vector2(from) + span * (float(i) / float(steps))
		if not _squad.map_generator.is_path_cell(Vector2i(roundi(along.x), roundi(along.y))):
			return false

	return true


## A bot that is asking to move and is not moving has walked into something the
## route did not know about, and the only way out of it is a different plan
func _watch_for_stuck(delta: float) -> void:
	if _drive.length() > 0.3 and _movement.current_speed < STUCK_SPEED:
		_stuck += delta
	else:
		_stuck = 0.0

	_waited = _waited + delta if _blocked else maxf(_waited - delta * WAIT_FORGIVENESS, 0.0)


## True while it has stopped weighing blades and is simply moving
func _desperate() -> bool:
	return _desperate_left > 0.0


## A bot that has not got anywhere in a while stops being careful.
##
## Every reason a cube can end up planted in one corridor reads the same way from
## the outside — it stands there. Rather than trying to name them all, anything
## that has not covered ground in four seconds drops the blade costs and the look
## ahead for a moment and simply goes. It may die doing it, and that is still a
## better race than a CPU rooted to a corner for the whole round
func _watch_for_progress(delta: float) -> void:
	if _desperate_left > 0.0:
		_desperate_left -= delta
		return

	_progress_left -= delta
	if _progress_left > 0.0:
		return

	_progress_left = DESPERATE_AFTER
	var moved := cube.global_position.distance_to(_progress_from)
	_progress_from = cube.global_position

	if moved >= DESPERATE_STEP:
		return

	_desperate_left = DESPERATE_FOR
	_detour = true
	_think()


## Spends what the cube is carrying once it has held it long enough and the
## moment is worth it. The delay is what keeps the middle rung from reading as a
## machine: an item used the very frame it was picked up is not a decision
func _spend_item(delta: float) -> void:
	var slot := cube.inventory
	if slot == null or slot.held_item == null:
		_item_held = 0.0
		return

	_item_held += delta

	if _skill.items == BotSkill.Items.NEVER or _item_held < _skill.item_delay:
		return

	if _skill.items == BotSkill.Items.WHENEVER or _item_pays(ItemSystem.id_of(slot.held_item)):
		slot.use()
		_item_held = 0.0


## Whether that item buys this bot anything where it is standing. What it cannot
## use at all is spent rather than kept — a slot held by something useless is a
## slot the next sphere cannot fill
func _item_pays(id: String) -> bool:
	match id:
		"shield", "rush", "freeze":
			return _nearest_saw() < SAW_PANIC
		"leap":
			return _stuck > 0.7 or _nearest_saw() < 3.2
		"shock":
			return not Match.is_painting() or _nearest_rival() < SHOCK_REACH
		"splash":
			return not Match.is_painting() or _loose_tiles_around() >= SPLASH_WORTH
		"eraser":
			return not Match.is_painting() or _enemy_tiles() >= ERASER_WORTH

	return true


## Meters to the nearest blade still in the level
func _nearest_saw() -> float:
	var at := cube.global_position
	var shortest := INF

	for node in get_tree().get_nodes_in_group("saw_mover"):
		var mover := node as SawMover
		if mover == null or mover.parent == null or not mover.parent.visible:
			continue

		shortest = minf(shortest, _flat(at - mover.parent.global_position).length())

	return shortest


## Meters to the nearest runner on another side, out of everybody the round has
## a position for
func _nearest_rival() -> float:
	var at := cube.global_position
	var mine := Match.team_of(_account)
	var shortest := INF

	for id: int in Match.runners():
		var runner: Dictionary = Match.runners()[id]
		if id == _account or Match.team_of(id) == mine or not bool(runner["placed"]):
			continue

		if bool(runner["dead"]) or bool(runner["finished"]):
			continue

		shortest = minf(shortest, _flat(at - (runner["position"] as Vector3)).length())

	return shortest


## Cells of floor around the cube that are not this side's, which is what a
## splash would actually take
func _loose_tiles_around() -> int:
	var here := _here()
	var mine := Match.team_of(_account)
	var claims: Dictionary = Match.paint().claims
	var loose := 0

	for x in range(-SPLASH_RADIUS, SPLASH_RADIUS + 1):
		for z in range(-SPLASH_RADIUS, SPLASH_RADIUS + 1):
			var cell := here + Vector2i(x, z)
			if not _squad.map_generator.is_path_cell(cell):
				continue

			var claim: PaintState.Claim = claims.get(cell, null)
			if claim == null or claim.team != mine:
				loose += 1

	return loose


## How much floor the other sides are holding, anywhere on the map
func _enemy_tiles() -> int:
	var mine := Match.team_of(_account)
	var theirs := 0

	for cell: Vector2i in Match.paint().claims:
		var claim: PaintState.Claim = Match.paint().claims[cell]
		if claim.team != mine:
			theirs += 1

	return theirs


func _here() -> Vector2i:
	return _cell_of(cube.global_position)


func _cell_of(world: Vector3) -> Vector2i:
	var grid := _squad.map_generator.grid_map
	var at := grid.local_to_map(grid.to_local(world))
	return Vector2i(at.x, at.z)


func _world_of(cell: Vector2i) -> Vector3:
	var grid := _squad.map_generator.grid_map
	return grid.to_global(grid.map_to_local(Vector3i(cell.x, 0, cell.y)))


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
