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

## How much further the top rung reads the blades than the rest. Far enough that
## nothing it could walk into inside its own lookahead is missed
const ALL_SEEING_REACH := 2.5

## How many cells of detour a blade in the way is worth going around. Under it
## the bot walks through and takes its chances, over it there is no corner of the
## maze it will not walk to rather than wait
const BLADE_COST := 5.0

## The most cells a timed plan may open up before it is settled with whatever it
## has found. A maze is narrow and a plan reaches a few dozen cells across a
## couple of dozen beats, so this is a ceiling and not a budget — it is only here
## so that an open room cannot turn one think into a frame
const PLAN_STATES := 6000

## How far a blade may travel between two samples of it while a plan is laid, as
## a share of a cell.
##
## The whole of what makes a plan trustworthy. A blade doing twelve covers two
## cells in the time the cube covers one, so asking where it is once a beat hands
## back two clear samples with a whole corridor swept in between — and a cube sent
## through that gap walks into a saw the plan never knew was there. Well under
## half a cell, so nothing can cross a corridor unrecorded
const BLADE_SAMPLE := 0.4

## How much further than the plan itself reaches a blade is still worth knowing
## about, in meters. A patrol is a dozen cells at most, so a blade this far out
## cannot have arrived anywhere the cube will be
const PLAN_BLADE_MARGIN := 30.0

## How near something that is chasing the cube counts as too near, in cells, and
## how many cells of detour each of those is worth going out of the way for.
##
## A lean and not a wall, and the difference is the whole of how a hunter has to
## be handled. Its own route is laid and gets shut off like any other blade's, but
## where it will be after that is a question about where the cube goes next — so
## the honest answer is a preference: everything else being equal, be further from
## it than nearer. Shutting off everywhere it could reach instead was worse than
## useless. A hunter is chasing the cube, so that circle is drawn around the cube
## as often as not, and a plan that finds nowhere at all to stand answers with a
## cube standing still — which is exactly what being chased must not produce
const HUNTER_SHY := 6.0
const HUNTER_DREAD := 3.0

## The least of its own margin a plan may ever be squeezed down to.
##
## Worked back from the two colliders and nothing else: a blade reaches 0.93 and
## the cube 0.56, so the two are touching at 1.49 between their middles. This is
## a little over that against a blade_room of 2.2 — the last of the room a plan
## may give up to get moving, and never a route laid through its own death.
##
## It used to sit at a metre and four fifths, which was right while the cube was
## a box and read a whole corner width across. Rounding the collider off took
## thirty centimetres out of what actually kills it and left this behind, too shy
## by exactly that much. Thirty centimetres is nothing in a corridor and it is
## the whole thing on a loop that circles a single block: the cells of a ring like
## that are two metres apart, so a cube that insists on one metre eight can never
## be anywhere on it while the blade is, and the plan simply has no way through
const MIN_ROOM_SHARE := 0.72

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

## What tells this brain apart from the same brain on the same cube in an earlier
## attempt at the level. 0 in a round, where there are no earlier attempts
var _salt: int = 0

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

## Seconds left of a run somebody asked this brain to make. Nothing in the ladder
## ever sets it — see dash()
var _barge_left: float = 0.0

## The timed plan: which cell the cube means to be standing in on each beat from
## the moment it was laid, and the clock it was laid at. Empty on every rung but
## the legend one
var _plan: Array[Vector2i] = []
var _plan_at: float = 0.0

## Where cell zero sits in the world and how wide a cell is, read once per plan.
## The blade marking asks for a cell centre thousands of times over, and every one
## of those used to be two calls into the grid
var _grid_origin := Vector3.ZERO
var _grid_span := 2.0

## How much of the room it likes to keep around a blade this plan is insisting
## on. 1 is the whole of it — see squeeze()
var _room_share: float = 1.0

## Where the blades that are chasing the cube stand, in cells, collected once per
## plan. What the search leans away from rather than refusing to enter
var _hunted: Array[Vector2] = []

## Seconds the thing in its slot has been sitting there
var _item_held: float = 0.0

## True once it has been close enough to the key or the way out to have found
## them. A bot that has to search for something does not unfind it
var _found_key: bool = false
var _found_exit: bool = false


## Built by the spawner rather than living in the player scene, the same way the
## ghost is: a cube nobody drives is the exception and not the rule.
##
## The salt is what makes one attempt at a level differ from the next. A brain
## draws everything it is ever unsure about out of one generator seeded off the
## account, which is right for a round — the CPUs in it lean differently and each
## of them keeps its lean. It is exactly wrong for a level that is played again
## after a death though: the maze is built from a fixed seed, so a brain given
## the same numbers walks the identical route into the identical blade forever.
## Whoever retries a level hands in something that has moved
static func attach_to(player: Player, skill: BotSkill, salt: int = 0) -> BotBrain:
	var made := BotBrain.new()
	made.name = "Brain"
	made.cube = player
	made._skill = skill
	made._salt = salt
	player.add_child(made)
	return made


func _ready() -> void:
	if _skill == null:
		_skill = Bots.skill_of(Bots.default_skill())

	_movement = cube.movement
	_account = cube.account()
	_rng.seed = _account * 7919 + 13 + _salt * 104729
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
	_barge_left = maxf(_barge_left - delta, 0.0)
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
## not know about, which are the two reasons to think early.
##
## A plan is laid to the end of its horizon and then laid again, so running out
## of it is not a surprise and neither is standing still — that is a beat it meant
## to spend. Only a cube that is asking to move and is not moving has met
## something none of it knew about
func _at_a_loss() -> bool:
	if _skill.plans_in_time:
		return _stuck > STUCK_PATIENCE

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

	if _skill.plans_in_time:
		_lay_timed_plan()


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
## True while a step of the route is close enough for a blade to be worth
## weighing.
##
## Only the first few cells. A route across a map is hundreds of cells, and
## checking every neighbour of every one of them against every blade is what
## brought a medium map to one frame a second — the cost grew with the length of
## the walk and the size of the level at the same time. It bought nothing either:
## the prediction only reaches about a second ahead, so a cell forty steps out
## was being judged against where a blade happens to be standing now, which says
## nothing about where it will be when the cube arrives
func _weighs_blades(walked: int) -> bool:
	return _skill.routes_around_blades and not _desperate() and not _untouchable() \
		and walked <= _skill.look_ahead_cells


## Lays out where the cube means to stand on each beat from now, and falls back
## to walking the plain route when there is nothing to plan against.
##
## The cell it plans to is the objective itself and never the goal the rest of
## the thinking settled on.
##
## Those two part company at the worst possible moment. A route to a cell the cube
## is already standing on comes back empty, and an empty route makes the goal a
## cell picked at random — which is not a landmark, which the search will not plan
## to, which left the plan empty. And an empty plan is not a cube that waits: every
## reader of it falls straight through to the plain route and the reflex, so the
## rung quietly stopped being the rung and walked into the first blade it met. It
## did that standing on the doorstep of the lift, with the key, at full margin,
## which is exactly where it was dying
##
## This is the whole of the legend rung. Everything else in here reads the blades
## as things to be near or not near right now; this reads them as things that are
## somewhere else in two seconds, which is the difference between a corridor being
## shut and a corridor being shut *at the moment you would be in it*. A maze whose
## blades outrun the cube cannot be walked any other way — there is nowhere to
## dodge to at a wall, and waiting one beat at the corner is the answer the rest
## of the ladder has no way of even asking about
func _lay_timed_plan() -> void:
	_grid_span = _cell_span()
	_grid_origin = _world_of(Vector2i.ZERO)
	_plan_at = _clock

	var aim := _squad.exit_cell() if Match.has_key(_account) else _squad.key_cell()

	if aim.x < 0:
		_plan = [] as Array[Vector2i]
		return

	var found := _search_in_time(aim)
	_plan = found if not found.is_empty() else ([_here(), _here()] as Array[Vector2i])

	if _plan.size() < 2:
		_plan = _route.slice(maxi(_step - 1, 0))


## Seconds one beat of a plan lasts, which is what crossing one cell costs the
## cube at the pace this rung walks at.
##
## It has to be the true crossing time and not a careful one. The follower drives
## the cube at whatever speed it has, so a beat written down as longer than the
## crossing really takes does not slow the cube — it only moves the whole plan
## later than the cube actually arrives, which puts it in the gap before the gap
## is open. Where the margin belongs is in what counts as a cell being free
func _plan_beat() -> float:
	return _cell_span() / maxf(_movement.max_speed * _skill.pace, 0.1)


## Walks the maze out in cells and beats together, and hands back the best line
## through it that was found.
##
## A plain flood fill and not a weighted search, because every move a cube can
## make costs exactly one beat — a step to a neighbour and standing still are the
## same beat, and standing still is a move like any other. That is the one thing
## this has that a route through cells alone cannot express.
##
## A step has to keep both of its cells, the one being left as much as the one
## being entered. A beat is the time the cube needs to cross a cell, so for the
## whole of it the cube is somewhere between the two middles and in neither — and
## checking only the destination is how it was cut in half at a metre and a
## quarter by a blade that swept the cell it was still halfway out of, on a plan
## that had promised it a metre and a half of room.
##
## A search that never once found a cell to step onto is a cube with a blade
## coming and nowhere to be, and that is the one case the plan is not allowed to
## answer with "stay where you are" — see _least_bad_step.
##
## Only a landmark is planned to. The key and the way out are the two cells the
## level already measured itself from and keeps the sweep of, so the score of a
## cell is a lookup; anywhere else would put a fresh sweep of the whole map into
## the cache several times a second and push the two that matter back out of it
func _search_in_time(target: Vector2i) -> Array[Vector2i]:
	var nothing: Array[Vector2i] = []
	if not _is_landmark(target):
		return nothing

	var walker := _squad.map_generator
	var field := _squad.field_from(target)
	if field.is_empty():
		return nothing

	var horizon := maxi(_skill.plan_horizon, 4)
	var calendar := _blade_calendar(horizon)
	var here := _here()

	var start := Vector3i(here.x, here.y, 0)
	var came_from: Dictionary = {}
	var seen: Dictionary = {start: true}
	var frontier: Array[Vector2i] = [here]
	var opened := 0

	var best := start
	var best_score := walker.distance_in_field(field, here) + _hunter_cost(here)
	var moved := false

	for beat in range(horizon):
		var next: Array[Vector2i] = []

		for cell in frontier:
			for step in _plan_moves():
				var to: Vector2i = cell + step
				if step != Vector2i.ZERO and not walker.is_path_cell(to):
					continue

				var key := Vector3i(to.x, to.y, beat + 1)
				if seen.has(key) or _blade_due(calendar, to, beat + 1) \
						or _blade_due(calendar, cell, beat + 1):
					continue

				seen[key] = true
				came_from[key] = Vector3i(cell.x, cell.y, beat)
				next.append(to)
				opened += 1

				if to != here:
					moved = true

				var score := walker.distance_in_field(field, to)
				if score < 0:
					continue

				score += _hunter_cost(to)

				if best_score < 0 or score < best_score:
					best_score = score
					best = key

		if next.is_empty() or opened >= PLAN_STATES:
			break

		frontier = next

	if not moved:
		return [here, _least_bad_step(calendar, here)] as Array[Vector2i]

	return _walk_back(came_from, best, here)


## Which way to go when the search found nowhere safe at all.
##
## Standing still is the one answer that must not be given here. The search has
## just said that every way out of this cell is spoken for, and the cell the cube
## is standing in is very often one of them — a blade is on its way and this is
## what being caught looks like from the inside. So the cube is sent to whichever
## neighbour the blades reach last, which is the difference between a chance and
## none. It stays put only where staying really is the last thing to be swept
func _least_bad_step(calendar: Array, here: Vector2i) -> Vector2i:
	var walker := _squad.map_generator
	var best := here
	var latest := _beats_until(calendar, here)

	for step in _turn_order:
		var to: Vector2i = here + step
		if not walker.is_path_cell(to):
			continue

		var due := _beats_until(calendar, to)
		if due > latest:
			latest = due
			best = to

	return best


## How many beats there are before a blade is due in that cell, counting from
## then. The whole plan when none is
func _beats_until(calendar: Array, cell: Vector2i, from: int = 0) -> int:
	for beat in range(maxi(from, 0), calendar.size()):
		if (calendar[beat] as Dictionary).has(cell):
			return beat - from

	return calendar.size()




## The plan read back out of the search, oldest beat first. A search that found
## nowhere better than where the cube already stands hands back the cube's own
## cell twice, which the follower reads as standing still — and standing still is
## an answer, it is what lets the blade in the corridor go by
func _walk_back(came_from: Dictionary, last: Vector3i, here: Vector2i) -> Array[Vector2i]:
	var plan: Array[Vector2i] = []
	var key := last

	while came_from.has(key):
		plan.append(Vector2i(key.x, key.y))
		key = came_from[key]

	plan.append(Vector2i(key.x, key.y))
	plan.reverse()

	if plan.size() < 2:
		return [here, here] as Array[Vector2i]

	return plan


## The five things a cube may do with one beat, walking before waiting.
##
## The order is the whole of it, and it used to be the other way round. A flood
## fill hands each cell-and-beat to whichever move reached it first, so with
## standing still tried first every state that could be reached either way was
## filed under the waiting one — and the route read back out of that begins with a
## wait almost every time. On its own that would cost a beat. What made it cost
## the level is that a plan is laid again every seventh of a second and a beat
## lasts a third of one: the cube waited, was handed the same answer before the
## beat was out, waited again, and stood in an empty corridor with the nearest
## blade three cells away doing that for a quarter of the level.
##
## Waiting still wins where it is the only thing that is safe, which is the only
## place it was ever meant to win
func _plan_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = _turn_order.duplicate()
	moves.append(Vector2i.ZERO)
	return moves


## Where every blade near the cube will be on each beat of the plan, as the cells
## that are not worth being in at that moment.
##
## Worked out once per plan rather than per cell looked at. The search asks about
## a few thousand cell-and-beat pairs and there can be forty blades in a level;
## asking each of them where it will be, every time, is the same question answered
## a hundred thousand times a second
func _blade_calendar(horizon: int) -> Array:
	var calendar: Array = []
	var beat := _plan_beat()
	var covered := _beats_of_cover(beat)

	_hunted.clear()

	for at in range(horizon + 1):
		calendar.append({})

	if _barge_left > 0.0 or covered > horizon:
		return calendar

	for mover in _plan_blades(horizon):
		_mark_blade_route(calendar, mover, horizon, beat, covered)

	return calendar


## How many beats of the plan the cube cannot be hurt for.
##
## A shield or the rainbow makes a blade something to walk through rather than
## around, and a plan that went on treating the maze as lethal spent the whole of
## it standing at corners waiting for corridors it could have run straight down.
## What is asked is how long the cover actually has left, not merely whether it
## is up — the beats past the end of it are laid out against a maze that can kill
## again, so the run does not end with the cube halfway down a swept corridor
## with nothing left on it
func _beats_of_cover(beat: float) -> int:
	if cube.inventory == null or not cube.death.is_invulnerable or beat <= 0.0:
		return 0

	var longest := 0.0

	for effect in cube.inventory.active_effects:
		longest = maxf(longest, effect.time_left)

	return int(floor(longest / beat))


## Every blade worth planning around. Its own cull and not the rung's eyes: those
## are set for reading a blade beside the cube right now, and a plan reaching ten
## seconds out has to know about the one two corridors away that will have arrived
## by the time the cube is there
func _plan_blades(horizon: int) -> Array[SawMover]:
	var found: Array[SawMover] = []
	var at := cube.global_position
	var reach := float(horizon) * _grid_span + PLAN_BLADE_MARGIN

	for node in get_tree().get_nodes_in_group("saw_mover"):
		var mover := node as SawMover
		if mover == null or mover.parent == null or not mover.parent.visible:
			continue

		if _flat(at - mover.parent.global_position).length() <= reach:
			found.append(mover)

	return found


## True for a blade that is being steered at the player rather than walking a
## patrol of its own.
##
## It is worth planning around exactly as far as the route it is holding: those
## cells are laid and it will walk them. What comes after is not a question about
## the blade at all — it is a question about where the cube goes next, which is
## the very thing the plan is still deciding — so the walk stops at the end of the
## route and leaves it standing there, and the reflex covers what the plan cannot
func _is_hunter(mover: SawMover) -> bool:
	return mover.behavior == SawMover.Behavior.ONCE


## Walks one blade forward through the whole plan and writes every cell it passes
## through into the page of the beat it passes through it on.
##
## The walking itself is the blade's own — it is asked where it will be rather
## than told. A prediction that lived here was a second copy of how a saw moves,
## and it was missing the three things that most often put a cube into one: the
## rest a patrol takes at each end, the way it eases off going into that turn and
## back out of it, and the glide out of being frozen. Every one of those is a
## corridor the plan called clear while the blade was still standing in it.
##
## And it is sampled far finer than a beat, because what is being written down is
## the path the blade takes and not the places it happens to be looked at.
##
## The room is the rung's own and does not grow with the blade's speed. Widening
## it by how far a fast blade travels between two thinks was tried, on the theory
## that a plan goes stale while it is being walked: it cost a metre and a quarter
## of clearance around every quick saw, which shuts corridors a person can see are
## open and leaves the cube standing in them — and it did not save a single death.
## Whatever is walking cubes into blades is not the width of this circle
func _mark_blade_route(calendar: Array, mover: SawMover, horizon: int, beat: float,
		covered: int) -> void:
	var at: Vector3 = mover.parent.global_position

	if _is_hunter(mover):
		_hunted.append(_cell_point(at))

	var pace := mover.speed * mover.speed_multiplier
	var room := _planner_room()

	if covered <= 0:
		_mark_blade(calendar[0], at, room)

	var slices := _slices_per_beat(pace, beat)
	var walk := mover.forecast(beat / float(slices), horizon * slices)

	for sample in range(walk.size()):
		var page := (sample + 1) / slices

		if page >= covered and page < calendar.size():
			_mark_blade(calendar[page], walk[sample], room)


## What a cell costs on top of the walk, for being near something that is chasing
## the cube. Nothing at all once the hunters are far enough off, which is most of
## the maze most of the time
func _hunter_cost(cell: Vector2i) -> int:
	if _hunted.is_empty():
		return 0

	var cost := 0.0

	for spot in _hunted:
		var gap := Vector2(float(cell.x) - spot.x, float(cell.y) - spot.y).length()
		if gap < HUNTER_SHY:
			cost += (HUNTER_SHY - gap) * HUNTER_DREAD

	return int(round(cost))


## That spot in cells, fractions and all. The middle of a cell is a whole number
func _cell_point(at: Vector3) -> Vector2:
	return Vector2((at.x - _grid_origin.x) / _grid_span, (at.z - _grid_origin.z) / _grid_span)


## How many times a blade has to be looked at inside one beat for its path to be
## written down without gaps in it
func _slices_per_beat(pace: float, beat: float) -> int:
	return clampi(int(ceil(pace * beat / (_grid_span * BLADE_SAMPLE))), 1, 8)


## Writes one blade's reach at one moment into that beat's page.
##
## All arithmetic and no grid. Which cell a spot is in and where a cell's middle
## sits are both a division and a rounding once the corner of the grid and the
## width of a cell are known, and this is called thousands of times per plan
func _mark_blade(page: Dictionary, at: Vector3, room: float) -> void:
	var spot := _cell_point(at)
	var middle := Vector2i(roundi(spot.x), roundi(spot.y))
	var reach := room / _grid_span
	var around := int(floor(reach + 0.5))

	for x in range(-around, around + 1):
		for z in range(-around, around + 1):
			var cell := middle + Vector2i(x, z)
			if Vector2(float(cell.x) - spot.x, float(cell.y) - spot.y).length() <= reach:
				page[cell] = true


## True while a blade is due in that cell on that beat.
##
## One page and not two. A page already holds every cell its blades pass through
## during that whole beat rather than the handful they happen to be sitting on at
## the end of it, so asking the next one as well was the same margin counted
## twice — and a maze with forty blades in it came out shut in both directions,
## which is a cube that stands at a corner for half a minute rather than one that
## is being careful
func _blade_due(calendar: Array, cell: Vector2i, beat: int) -> bool:
	if beat < 0 or beat >= calendar.size():
		return false

	return (calendar[beat] as Dictionary).has(cell)


## Which way the plan wants the cube to be going right now, and nothing at all on
## a beat it means to spend standing where it is.
##
## The cell after the next one is deliberately not looked at. Reaching a cell
## early and carrying straight on into the following one is the cube arriving in
## a corridor before the beat the plan cleared it for — which is the one thing
## this whole rung exists to stop
func _plan_direction() -> Vector3:
	var beat := _plan_beat()
	var at := int((_clock - _plan_at) / beat) if beat > 0.0 else 0
	var want: Vector2i = _plan[clampi(at + 1, 0, _plan.size() - 1)]
	var to := _flat(_world_of(want) - cube.global_position)

	if to.length() < CELL_REACH * 0.5:
		return Vector3.ZERO

	return to.normalized()


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
		if _weighs_blades(walked) and _blade_on(neighbour, walked):
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

	if _skill.plans_in_time and not _plan.is_empty():
		_blocked = false
		var hunted := _dodge_hunters()
		var chased := minf(hunted.length(), 1.0)

		if chased >= FLEE_FORCE:
			return hunted.normalized() * _skill.pace

		if chased > 0.01:
			return (wanted + hunted * DODGE_WEIGHT).limit_length(1.0) * _skill.pace

		return wanted.limit_length(1.0) * _skill.pace

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


## How far out blades are read. The top rung sees far further than the rest, but
## not the whole map: a blade across a maze cannot reach this cube inside the
## second the prediction covers, and reading two hundred of them every frame for
## every bot is a level that runs at walking pace
func _blade_reach(reach: float) -> float:
	return reach * ALL_SEEING_REACH if _skill.sees_all_blades else reach


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

		if _flat(at - mover.parent.global_position).length() > _blade_reach(reach):
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
	if _skill.look_ahead_cells <= 0 or _near.is_empty() or _desperate() or _untouchable():
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

	if _skill.plans_in_time and not _plan.is_empty():
		return _plan_direction()


	while _step < _route.size() \
			and _flat(_world_of(_route[_step]) - at).length() < CELL_REACH:
		_step += 1

	if _step >= _route.size():
		return Vector3.ZERO

	return _flat(_world_of(_route[_step]) - at).normalized()


## True once this bot is at the way out with what the doors ask for, and the last
## thing left to do is walk into the cabin.
##
## The cabin is carved into a wall, so it is not a cell any route may be laid
## through and this last step is walked straight at it with nothing weighed. That
## is fine for a rung that was reacting to the blades anyway — but it was the one
## place a timed plan was thrown away and the cube sent off blind, with the key,
## a step from the door, and a patrol sweeping the doorstep. So on a rung that
## plans, the plan has to have cleared where the cube is standing first: it says
## so by naming that cell again for the beat ahead, and only then is the last step
## taken
func _boarding() -> bool:
	if _squad.elevator_spawner == null or not Match.has_key(_account):
		return false

	var door := _squad.exit_cell()
	if door.x < 0 or Vector2(_here() - door).length() > 1.5:
		return false

	return not _skill.plans_in_time or (_plan.size() >= 2 and _plan[1] == _here())


## Cuts it that much finer around the blades from here on, 1 being the room the
## rung would rather have.
##
## The margin a plan keeps is not one number that is right everywhere. Wide is
## flawless in an early maze with four blades in it and shuts a late one solid —
## forty patrols, every corridor spoken for on every beat, and a cube that stands
## at a corner because there is no line through the maze that clears the bar it
## set itself. So the bar is what gives first: whoever is driving watches whether
## the cube is getting anywhere and pulls this down a notch when it is not, well
## before the last resort of walking through the blades. It is still never pulled
## under what actually kills a cube
func squeeze(share: float) -> void:
	_room_share = clampf(share, MIN_ROOM_SHARE, 1.0)


## The room this plan keeps around a blade, which is the rung's own less whatever
## has been given up to get moving again
func _planner_room() -> float:
	return _skill.blade_room * _room_share


## Takes the corridor rather than waiting at the mouth of it, for that long.
##
## A brain on its own never does this. Its answer to a blade in the way is to
## stand and let it go by, which is right in a race — but a maze corridor is one
## cell wide, and where the only way on is past a patrol that never clears, "wait"
## and "go round" are both nothing and the cube spends the level shuffling between
## the two. Whoever is driving this brain can see that from the outside, and this
## is what it says about it: stop backing away, walk the route, take the chance.
##
## It really is a chance. The cube can be cut in half doing this and regularly is
func dash(seconds: float) -> void:
	_barge_left = maxf(_barge_left, seconds)
	_desperate_left = maxf(_desperate_left, seconds)
	_detour = false
	_think()


## The same push, but only from the blades that are chasing the cube.
##
## What a plan cannot hold. Everything else in the maze walks a line that was laid
## before the cube got there and is written into the plan beat by beat; a hunter
## is aimed at wherever the cube is going, so the only thing that answers it is
## the reflex — lean away, and keep walking the plan while doing it
## True while nothing in the maze can cut this cube in half.
##
## A shield or the rainbow is a moment to spend running down the corridors that
## were shut a second ago, and a bot that went on stepping around them politely
## has paid for an item it then did not use. Walking through is a play the game
## already expects, too: both effects check whether the cube is still standing
## inside a blade when they run out and finish the job if it is
func _untouchable() -> bool:
	return cube.death.is_invulnerable


func _dodge_hunters() -> Vector3:
	if _untouchable():
		return Vector3.ZERO

	var push := Vector3.ZERO
	var at := cube.global_position
	var reach := _skill.danger_range

	for index in range(mini(_near.size(), _threats.size())):
		if not _is_hunter(_near[index]):
			continue

		var away := _flat(at - _threats[index])
		var gap := away.length()

		if gap >= reach or gap < 0.001:
			continue

		push += away / gap * (1.0 - gap / reach)

	return push


## What every blade close enough to matter adds up to, as a push away from where
## it is going to be. What "close enough" and "going to be" mean is the rung.
##
## None of it during a run somebody asked for: the push and the route are opposite
## directions in a corridor, and a run that is still being leaned out of is the
## same shuffle it was called to end
func _dodge() -> Vector3:
	if _barge_left > 0.0 or _untouchable():
		return Vector3.ZERO

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
