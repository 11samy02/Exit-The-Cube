class_name MatchSession
extends RefCounted

## One round of a rules driven mode, with nothing in it about how the players
## reached each other.
##
## This used to live in the online autoload, where every "who" was the one Steam
## account this machine signs in with. A splitscreen party has four of those on
## one machine, so every question here takes the account it is being asked about
## instead: which side is this one on, where does it come back, how many tiles
## does it owe. What carries an answer to another machine — if anything does at
## all — is somebody else's job

## How many cells at a team's end of the maze a player may come back at. Wide
## enough that a death does not put them back on the tile they just left, tight
## enough that they are still on their own side
const RESPAWN_SPREAD := 40

## Mode, size, shape and difficulty, by their place in the RaceRules lists
var settings: Dictionary = {}

## The number every maze in this round is built from
var race_seed: int = 0

## The level itself, built once and kept over every death, so the maze a player
## comes back into is the one they left
var level: MapData = null

## Every cube in the round by its account. The ranking is built off these, and
## online so are the ghosts
var runners: Dictionary = {}

## Who owns which tile of the floor. Empty outside the painting mode
var paint := PaintState.new()

## Which side each account is on, worked out from the seed rather than sent
var teams: Dictionary = {}

## What each side is drawn in, rolled per round
var team_colors: Array[Color] = []

## Where each account comes into the maze, one cell each and no two the same
var spawns: Dictionary = {}

## True once the clock ran out and the result is on screen
var round_ended: bool = false

## The cells each account may come back at, and the last one it used
var _respawn_pools: Dictionary = {}
var _last_respawn: Dictionary = {}

## Tiles each account has taken, oldest first, with the stamp each was taken
## under. A death gives the last few of them back, so the order matters
var _tiles: Dictionary = {}

## When each account is allowed back into the maze, in seconds since the game
## started. Missing while it is standing
var _back_at: Dictionary = {}


## One runner on zero. A ghost is only drawn once a position has arrived for it,
## so a player whose map takes longer to build does not flicker into the corner
## of the maze first
func add_runner(account: int, display_name: String) -> void:
	runners[account] = {
		"id": account,
		"name": display_name,
		"deaths": 0,
		"items": 0,
		"has_key": false,
		"finished": false,
		"time": 0.0,
		"dead": false,
		"placed": false,
		"position": Vector3.ZERO,
		"target": Vector3.ZERO,
		"yaw": 0.0,
		"target_yaw": 0.0,
		"item": "",
		"saws": [],
		"saws_at": 0.0,
		"seen_at": now(),
	}


## Splits the room into sides and clears the floor. Both the teams and the cells
## each player comes in on are worked out from the accounts and the seed, so
## every machine reaches the same answer without a word being sent about it.
##
## The spawn cells need the maze, which is not built yet at this point — they are
## filled in by the map once it has one, through spawn_cells_from
func draw_teams() -> void:
	paint.clear()
	teams.clear()
	team_colors.clear()
	spawns.clear()
	_respawn_pools.clear()
	_last_respawn.clear()
	_tiles.clear()
	_back_at.clear()
	round_ended = false

	if not is_paint():
		return

	var sides := RaceRules.team_count(settings)
	teams = TeamDraw.teams_of(runners.keys(), sides, race_seed)
	team_colors = RaceRules.roll_team_colors(race_seed, sides)


## Works the sides out again after somebody turned up late.
##
## The draw is a pure function of the accounts and the seed, so every machine
## reaches the same answer once it knows about everybody. A machine that was one
## callback short when the race opened drew without that player though, and had
## them on the wrong side for the rest of it — which is how one painted floor
## came out two different colours on two screens.
##
## Only the sides are worked out again. The colours come off the seed and have
## not moved, and the floor stays exactly where it is: the tiles are simply
## re-filed under whoever actually owns them
func redraw_teams() -> void:
	if not is_paint():
		return

	teams = TeamDraw.teams_of(runners.keys(), RaceRules.team_count(settings), race_seed)

	for cell: Vector2i in paint.claims:
		var claim: PaintState.Claim = paint.claims[cell]
		claim.team = team_of(claim.owner)


## Hands out the starting cells once the maze exists. Called by the map, which
## is the first thing that knows where the corridors are.
##
## The respawn region is worked out per side and shared by everybody on it, so a
## round of twelve does not walk the whole cell list twelve times over
func spawn_cells_from(cells: Array, size: int) -> void:
	if not is_paint() or not spawns.is_empty():
		return

	spawns = TeamDraw.spawns_of(teams, RaceRules.team_count(settings), cells, size)

	var by_team: Dictionary = {}

	for account: int in teams:
		var team := team_of(account)
		if not by_team.has(team):
			by_team[team] = TeamDraw.region_of(team, cells, size, RESPAWN_SPREAD)

		_respawn_pools[account] = by_team[team]


## Where that cube comes in, or a cell of -1 when the mode does not place people
func spawn_cell(account: int) -> Vector2i:
	return spawns.get(account, Vector2i(-1, -1))


## Where that cube comes back after a death: anywhere in its own end of the
## maze, and never twice in a row on the same tile. Coming back where you fell
## is coming back onto floor you had already painted, so the walk out is the
## whole of what the death cost
func respawn_cell(account: int) -> Vector2i:
	var pool: Array = _respawn_pools.get(account, [])
	if pool.size() < 2:
		return spawn_cell(account)

	var last: Vector2i = _last_respawn.get(account, Vector2i(-1, -1))
	var picked: Vector2i = last

	while picked == last:
		picked = pool[randi() % pool.size()]

	_last_respawn[account] = picked
	return picked


## True while this round paints the floor, whatever phase the game is in. The
## router adds the half about a round being on at all
func is_paint() -> bool:
	return RaceRules.is_paint(settings)


func mode() -> RaceMode:
	return RaceRules.mode_of(settings)


## Which side that account is on, 0 when the mode has no teams
func team_of(account: int) -> int:
	return int(teams.get(account, 0))


## What a side is drawn in this round. Rolled once when the teams are drawn, so
## every screen and every tile agrees without asking again
func team_color(team: int) -> Color:
	if team < 0 or team >= team_colors.size():
		return Color.WHITE

	return team_colors[team]


## Seconds left in the painting round, 0 once it is over
func round_left() -> float:
	return maxf(RaceRules.round_seconds(settings) - GameState.run_time, 0.0)


## True on the one frame the clock reaches zero. Every machine runs its own copy
## of the same clock, started at the same moment, so nobody has to be told
func tick_round() -> bool:
	if round_ended or not is_paint() or round_left() > 0.0:
		return false

	round_ended = true
	return true


## Takes a tile for that cube's side and remembers it was theirs, so a death can
## give it back again. False when the tile was already theirs or somebody has a
## better claim on it
func claim(account: int, cell: Vector2i, stamp: float) -> bool:
	if not claim_for(cell, team_of(account), account, stamp):
		return false

	var tiles: Array = _tiles.get(account, [])
	tiles.append([cell, stamp])
	_tiles[account] = tiles
	return true


## The same claim without the bookkeeping, for a tile taken on another machine.
## Their own ledger of it lives over there
func claim_for(cell: Vector2i, team: int, owner: int, stamp: float) -> bool:
	return paint.claim(cell, team, owner, stamp)


## Gives back the last few tiles that cube took, the price of dying. Only the
## ones still standing in its colour come off — anything painted over since
## belongs to whoever took it. The ones actually given back are handed to the
## caller, which is what has to go out over a wire if there is one
func release_tiles(account: int, count: int) -> Array:
	var tiles: Array = _tiles.get(account, [])
	var giving: Array = []

	while tiles.size() > 0 and giving.size() < count:
		var last: Array = tiles.pop_back()
		if paint.release(last[0] as Vector2i, account, float(last[1])):
			giving.append(last)

	return giving


## Puts one claimed tile back into somebody else's hands, for a release that
## arrived from another machine
func release_for(cell: Vector2i, owner: int, stamp: float) -> bool:
	return paint.release(cell, owner, stamp)


## Scrubs a tile bare whoever painted it. Unlike giving back your own tiles this
## takes anybody's, so it carries no owner to check — the roller that did it has
## already earned the right by getting there
func erase(cell: Vector2i) -> bool:
	if not paint.claims.has(cell):
		return false

	paint.claims.erase(cell)
	return true


## Starts the wait a death costs. Called by the cube that burst, so that the
## countdown on screen is the same one it is actually serving rather than a
## second timer running alongside it and drifting
func begin_penalty(account: int, seconds: float) -> void:
	_back_at[account] = now() + seconds


## Seconds until that cube is back on its feet, 0 while it is already standing
func penalty_left(account: int) -> float:
	return maxf(float(_back_at.get(account, 0.0)) - now(), 0.0)


func end_penalty(account: int) -> void:
	_back_at.erase(account)


## Writes values into one runner, whatever the round is being played over
func remember(account: int, values: Dictionary) -> void:
	var runner: Dictionary = runners.get(account, {})
	if runner.is_empty():
		return

	for key: String in values:
		runner[key] = values[key]

	runner["seen_at"] = now()


## The ranking. Fewest deaths first, then the fastest time, then the most
## spheres — and a cube that matches another on all three shares its place, so
## two identical runs are both first rather than one of them being second by the
## order they happened to be listed in.
##
## Whoever is still in the maze is listed under everybody who made it out and
## gets a place of their own down there, worked out from how the run is going
## rather than from a time nobody has yet. That is what makes the board worth
## looking at while the race is still on: a place that only appears at the end
## is a scoreboard nobody can race against
func standings() -> Array:
	var done: Array = []
	var running: Array = []

	for id: int in runners:
		var runner: Dictionary = runners[id].duplicate()
		if bool(runner["finished"]):
			done.append(runner)
		else:
			running.append(runner)

	done.sort_custom(_is_ahead)
	running.sort_custom(_is_leading)
	_rank(done, 0, _is_ahead)
	_rank(running, done.size(), _is_leading)

	return done + running


## Where that cube stands on the board right now, 0 while it is in no round
func rank_of(account: int) -> int:
	for runner in standings():
		if int(runner["id"]) == account:
			return int(runner["rank"])

	return 0


## How many cubes are out of the maze already
func finisher_count() -> int:
	var count := 0

	for id: int in runners:
		if bool(runners[id]["finished"]):
			count += 1

	return count


## True once that cube is out of the maze
func has_finished(account: int) -> bool:
	var runner: Dictionary = runners.get(account, {})
	return not runner.is_empty() and bool(runner["finished"])


## True once that cube has picked its own key up
func has_key(account: int) -> bool:
	var runner: Dictionary = runners.get(account, {})
	return not runner.is_empty() and bool(runner["has_key"])


func take_key(account: int) -> void:
	remember(account, {"has_key": true})


## Writes that cube out of the maze, with the run as it stands
func finish(account: int, time: float, deaths: int, items: int) -> void:
	if has_finished(account):
		return

	remember(account, {
		"finished": true,
		"time": time,
		"deaths": deaths,
		"items": items,
		"has_key": true,
		"dead": false,
	})


## True once nobody is left walking around, which is what ends a local race
func everyone_finished() -> bool:
	if runners.is_empty():
		return false

	for id: int in runners:
		if not bool(runners[id]["finished"]):
			return false

	return true


## True while somebody is still walking around in there, which is what makes
## spectating worth offering
func anyone_running() -> bool:
	for id: int in runners:
		if not bool(runners[id]["finished"]):
			return true

	return false


## The one comparison the finished ranking is built on
func _is_ahead(a: Dictionary, b: Dictionary) -> bool:
	if int(a["deaths"]) != int(b["deaths"]):
		return int(a["deaths"]) < int(b["deaths"])

	if not is_equal_approx(float(a["time"]), float(b["time"])):
		return float(a["time"]) < float(b["time"])

	return int(a["items"]) > int(b["items"])


## The same comparison for the cubes that are still in there, where the time is
## the one number nobody has yet: a run only has a time once the elevator is at
## the top. The key stands in for it — carrying it means the whole first half of
## the maze is behind you, which is the only progress the others can be told
## about without a packet on every corner
func _is_leading(a: Dictionary, b: Dictionary) -> bool:
	if bool(a["has_key"]) != bool(b["has_key"]):
		return bool(a["has_key"])

	if int(a["deaths"]) != int(b["deaths"]):
		return int(a["deaths"]) < int(b["deaths"])

	return int(a["items"]) > int(b["items"])


## Walks the sorted list and hands out places, counting on from wherever the
## group above it ended. Two runs that are level on every count the comparison
## looks at get the same number, and the one after them skips the places they
## took up, the way a podium with two golds has no silver
func _rank(sorted: Array, from: int, comparison: Callable) -> void:
	for at in range(sorted.size()):
		var runner: Dictionary = sorted[at]
		var above: Dictionary = sorted[at - 1] if at > 0 else {}
		var level: bool = not above.is_empty() and not comparison.call(above, runner) \
			and not comparison.call(runner, above)

		runner["rank"] = int(above["rank"]) if level else from + at + 1


func now() -> float:
	return float(Time.get_ticks_msec()) * 0.001
