extends Node

## What is being played right now, and the one thing the game asks about it.
##
## There are three ways into a round and the rules of two of them are identical:
## an online race, the same modes played on one screen in splitscreen, and the
## campaign, which has no round rules at all. Everything in the game used to ask
## the online node instead — which meant the party mode would have had to be a
## second copy of the same scoring, and the campaign would have gone on asking a
## Steam autoload whether it was painting a floor.
##
## So the round itself is a MatchSession with no network in it, whatever it is
## being played over. This node holds the one that is running, says which cubes
## on this machine are ours, and hands anything that has to reach another machine
## to a transport — of which a local round simply has none

## A runner died, took a sphere, or made it out
signal standings_updated

## A tile changed hands, anywhere on the map
signal paint_changed

## The painting round ran out of time
signal round_over

const MAP_SCENE := "res://Scenes/Enviroment/map.tscn"

## The nodes a round puts into the map. Loaded by path rather than preloaded by
## name: every one of them talks back to this autoload, and naming them up here
## would be a circle neither script could compile out of
const GHOST_FIELD := "res://Scripts/Online/ghost_field.gd"
const RACE_OVERLAY := "res://Scripts/Ui/race_overlay.gd"
const PAINT_FIELD := "res://Scripts/Online/paint_field.gd"
const SPLIT_RIG := "res://Scripts/Ui/split_rig.gd"
const COOP_COORDINATOR := "res://Scripts/Match/coop_coordinator.gd"
const BOT_SQUAD := "res://Scripts/Bots/bot_squad.gd"

## How close a rainbow cube has to get to count as having caught somebody, in
## meters. A little over one cell, so a pass down the same corridor lands it
const HIT_RANGE := 2.4

## What kind of round is on. CAMPAIGN has no session at all — the levels come
## out of the campaign list and nothing here scores them
enum Kind { NONE, CAMPAIGN, ONLINE, PARTY }

var kind: int = Kind.NONE

var session: MatchSession = null

## Where a local change has to be carried to reach the other players, null when
## there is nowhere for it to go
var transport: MatchTransport = null

## The accounts of the cubes on this machine, by seat. Online that is one entry
## and it is the Steam account; locally it is one per seat, and in a party the
## bots are counted on behind the people
var _seat_accounts: Array[int] = []

## How many of those seats somebody in the room is actually holding a pad for.
## Everything past this one is a bot, which is the only difference between them
var _human_count: int = 0

## What the bots of this round are like, null while there are none
var _bot_skill: BotSkill = null

## The same accounts as a set, for the "is this one of mine" question that every
## write path asks
var _local: Dictionary = {}

## True once the clock was put back to zero for this round. A death rebuilds the
## map and would otherwise hand the runner a fresh start on the timer as well
var _clock_zeroed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## Keeps the local cubes' entries in the ranking current and runs the clock.
##
## Nothing sends a position in a local round, so without this the items that
## look for somebody to jolt or to soak would find every cube standing at the
## origin, having never moved since the round was built
func _process(_delta: float) -> void:
	if session == null:
		return

	refresh_local_runners()

	if is_painting():
		_tick_hunt()

		if session.tick_round():
			GameState.is_running = false
			put_the_cubes_down()
			round_over.emit()


## Takes the room's hands off its cubes.
##
## A round that is over puts a result on the screen with the maze still standing
## behind it. Everything that scores stops on its own — no tile can be claimed,
## no bot is driven — but nothing was telling the players themselves, so from
## their side of it the round simply carried on
func put_the_cubes_down() -> void:
	for cube in local_players():
		cube.movement.input_enabled = false
		cube.movement.drive = Vector3.ZERO


## While a cat is up, anybody on another side who comes within reach of it is
## caught.
##
## This is a rule of the painting mode and not of playing it over a wire, so the
## round runs it rather than the network node — which is where it used to live,
## and why a party round on one screen had a rainbow cube that could not catch
## anybody at all. Every cube on this machine is checked, not just the first
## seat: the second player's cat is as real as the first one's, and so is a bot's
func _tick_hunt() -> void:
	for cube in local_players():
		if not cube.death.is_dead and _carries_cat(cube):
			_catch_around(cube)


## True while the rainbow is running on that cube. Read off its own slot rather
## than kept as a flag, so it cannot say yes a moment after the effect let go
func _carries_cat(cube: Player) -> bool:
	for effect in cube.inventory.active_effects:
		if effect is RushEffect:
			return true

	return false


## Everybody on another side within reach of that cube, told they were caught.
##
## Only other teams. Running through your own side at speed is how a team covers
## ground, and a rainbow that took its own people out would make the item one you
## hope nobody on your team picks up
func _catch_around(cube: Player) -> void:
	var me := cube.account()
	var mine := team_of(me)

	for id: int in session.runners:
		if id == me or team_of(id) == mine:
			continue

		var runner: Dictionary = session.runners[id]
		if not bool(runner["placed"]) or bool(runner["dead"]) or bool(runner["finished"]):
			continue

		if cube.global_position.distance_to(runner["position"] as Vector3) <= HIT_RANGE:
			report_hit(id)


## The campaign, alone or in splitscreen. No session, so nothing here scores it
func start_campaign(accounts: Array[int]) -> void:
	kind = Kind.CAMPAIGN
	session = null
	transport = null
	set_process(false)
	_remember_accounts(accounts)


## A round played by everybody on this one machine, and by however many cubes
## the room asked the game to bring along.
##
## A bot is a seat like any other from here on. It gets an account off the seat
## after the last person in the room, which puts it in the ranking, on a side, on
## its own spawn cell and behind a key of its own without a line of this having
## to know that nobody is holding a pad for it
func start_party(rules: Dictionary, seed_value: int, accounts: Array[int]) -> void:
	var humans := maxi(accounts.size(), 1)
	var bots := Bots.count_in(rules, humans)
	var everyone := accounts.duplicate()

	for at in range(bots):
		everyone.append(Player.account_for(humans + at))

	_start_round(Kind.PARTY, rules, seed_value, everyone, null)
	_human_count = humans
	_bot_skill = Bots.skill_in(rules) if bots > 0 else null

	for at in range(everyone.size()):
		session.add_runner(everyone[at], _name_of_seat(at))

	session.draw_teams()


## What the cube in that seat is called on the board
func _name_of_seat(seat: int) -> String:
	return Bots.name_of(seat - _human_count) if is_bot_seat(seat) else "P%d" % (seat + 1)


## A round played over a wire. The caller owns the names and fills them in, it is
## the only one that knows them.
##
## The bots belong to whoever is hosting: only that machine is handed them as
## cubes of its own to run and to report, everybody else is given the same names
## on the board and draws them from what arrives. One machine deciding where a
## CPU is, is the same rule the rest of the round already runs on
func start_online(rules: Dictionary, seed_value: int, accounts: Array[int], \
		mine: int, line: MatchTransport, driven_bots: Array[int] = [] as Array[int]) -> void:
	var ours: Array[int] = [mine]
	ours.append_array(driven_bots)

	_start_round(Kind.ONLINE, rules, seed_value, ours, line)
	_human_count = 1
	_bot_skill = Bots.skill_in(rules) if not driven_bots.is_empty() else null

	for account in accounts:
		session.add_runner(account, _online_name(account))

	session.draw_teams()


## What that account is called before anybody has said. A Steam name arrives
## with the member list a moment later; a bot's is the only name it will ever
## have, and every machine works out the same one
func _online_name(account: int) -> String:
	if not Bots.is_bot_account(account):
		return ""

	return Bots.name_of((account - Bots.ACCOUNT_BASE) / Bots.ACCOUNT_STEP)


func _start_round(new_kind: int, rules: Dictionary, seed_value: int, \
		accounts: Array[int], line: MatchTransport) -> void:
	kind = new_kind
	transport = line
	session = MatchSession.new()
	session.settings = rules.duplicate()
	session.race_seed = seed_value
	session.level = RaceRules.build_level(rules, seed_value)
	_clock_zeroed = false
	_remember_accounts(accounts)
	set_process(true)


func _remember_accounts(accounts: Array[int]) -> void:
	_seat_accounts = accounts.duplicate()
	_human_count = accounts.size()
	_bot_skill = null
	_local.clear()

	for account in accounts:
		_local[account] = true


## Puts the round away. The campaign is not one, so this leaves nothing behind
## that could make the next level think it is being scored
func stop() -> void:
	kind = Kind.NONE
	session = null
	transport = null
	_bot_skill = null
	set_process(false)


## True while a rules driven round is on, whatever it is being played over. The
## campaign is not one of them
func is_racing() -> bool:
	return session != null and (kind == Kind.ONLINE or kind == Kind.PARTY)


## True while a painting round is on. Every part of the paint mode asks this
## rather than the mode setting, so nothing of it can run in a lobby or a race
func is_painting() -> bool:
	return is_racing() and session.is_paint()


## True while more than one cube is being played on this machine, which is the
## one thing that decides whether the window is cut up
func is_split() -> bool:
	return Seats.count() > 1


## How many cubes this machine puts into the level, people and bots together.
## The one number the spawner counts to, and one outside a round
func cube_count() -> int:
	return maxi(_seat_accounts.size(), maxi(Seats.count(), 1))


## How many of those somebody in the room is actually driving
func human_count() -> int:
	return maxi(_human_count, 1)


## True for a seat the game drives itself. Everything past the last person in
## the room is one, which is the whole of what makes a cube a bot
func is_bot_seat(seat: int) -> bool:
	return seat >= _human_count and seat < _seat_accounts.size()


## True while this round has any bots in it at all
func has_bots() -> bool:
	return _bot_skill != null


## True while a bot may not touch anything the players share.
##
## Any race, over a wire or on one screen. Everybody is running the same maze as
## their own, so a CPU is a shape going past in it and nothing more — it takes no
## sphere off the floor, opens nobody's doors and leaves no blood on the walls.
## A painting round is the opposite: there the floor is the point and a bot that
## could not paint would not be playing
func bots_are_ghosts() -> bool:
	return is_racing() and session.mode().with_exit


## What the bots of this round are like, null while there are none
func bot_skill() -> BotSkill:
	return _bot_skill


## True while everybody is racing through the one maze but is meant to read it as
## their own.
##
## The players see each other as ghosts and nothing else of each other — no
## second key lying about, no item somebody else threw up. It is the online race
## put on one screen: the maze is shared because building four of them costs four
## of everything, and what makes it a race of your own is what your camera draws.
##
## A bot counts for this as much as a second person does. One player racing ten
## CPUs through a shared maze is the same problem — ten keys on the floor, ten
## sets of items going off in the corridors — and the same answer
func is_private_race() -> bool:
	return kind == Kind.PARTY and session != null and session.mode().with_exit \
		and (is_split() or has_bots())


func settings() -> Dictionary:
	return session.settings if session != null else {}


func mode() -> RaceMode:
	return session.mode() if session != null else RaceRules.mode_of(RaceRules.default_settings())


## The level the round is run on. The map scene builds from this instead of from
## the campaign while a round is on
func level() -> MapData:
	return session.level if session != null else null


func paint() -> PaintState:
	return session.paint if session != null else null


func runners() -> Dictionary:
	return session.runners if session != null else {}


func round_ended() -> bool:
	return session != null and session.round_ended


func round_left() -> float:
	return session.round_left() if session != null else 0.0


## Seconds a broken blade stays down, 0 outside a round or in a mode that keeps
## them broken
func saw_revive_seconds() -> float:
	return session.mode().saw_revive_seconds if is_racing() else 0.0


## True for a cube this machine is playing. Everything that may be decided here
## rather than asked of somebody else hangs off this one question
func is_local(account: int) -> bool:
	return _local.has(account)


## True for a cube somebody in this room is actually playing. is_local is the
## wider question and the one every write path asks — a bot is decided on this
## machine as well, it is simply not anybody's
func is_mine(account: int) -> bool:
	return is_local(account) and not is_bot_seat(seat_of_account(account))


func local_accounts() -> Array[int]:
	return _seat_accounts.duplicate()


func account_of_seat(seat: int) -> int:
	return _seat_accounts[seat] if seat >= 0 and seat < _seat_accounts.size() else 0


func seat_of_account(account: int) -> int:
	return _seat_accounts.find(account)


## Whose keys the level should put down, empty when one unowned key is enough.
##
## Online every machine builds its own maze and the one key in it is that
## player's, so nothing has to be split. On one screen there is a single maze,
## and a race through it needs a way out each
func key_owners() -> Array[int]:
	if session == null or not session.mode().with_exit:
		return [] as Array[int]

	var owners: Array[int] = []

	if kind == Kind.PARTY:
		for id: int in session.runners:
			owners.append(id)

		return owners

	if not has_bots():
		return owners

	owners.append(0)

	for account in _seat_accounts:
		if is_bot_seat(seat_of_account(account)):
			owners.append(account)

	return owners


## True once that cube may use the exit
func has_key(account: int) -> bool:
	if session == null:
		return GameState.has_key

	if kind == Kind.PARTY or not is_mine(account):
		return session.has_key(account)

	return GameState.has_key


## That cube picked its own key up. Only a person's own key is worth telling the
## run about — the banner and the tally belong to whoever is watching, and a bot
## finding its key is somebody else's half of the race
func take_key(account: int) -> void:
	if session == null:
		GameState.collect_key()
		return

	session.take_key(account)

	if not is_bot_seat(seat_of_account(account)):
		GameState.collect_key()

	standings_updated.emit()


## Counts a death against that runner, so the board reads what is happening in
## the maze rather than only what the finished runs came to
func count_death(account: int) -> void:
	if session == null:
		return

	var runner: Dictionary = session.runners.get(account, {})
	if not runner.is_empty():
		runner["deaths"] = int(runner["deaths"]) + 1


## That cube rode the cabin out. Only a local race ends this way — online the
## elevator finishes the whole run and the heartbeat carries it
## That cube rode the cabin out. Only a local race ends this way — online the
## elevator finishes the whole run and the heartbeat carries it.
##
## The time is handed in rather than read here, because the moment a run ends is
## the moment the runner reached the way out and not the moment the doors, the
## snap, the flight and the summary delay have all finished playing. A player who
## got there first was being timed through four seconds of ceremony that the CPUs
## behind them never had to sit through
func finish(account: int, at: float = -1.0) -> void:
	if session == null:
		return

	var runner: Dictionary = session.runners.get(account, {})
	var mine := not is_bot_seat(seat_of_account(account))
	var deaths := GameState.deaths if mine else int(runner.get("deaths", 0))
	var items := GameState.items_collected if mine else int(runner.get("items", 0))

	session.finish(account, at if at >= 0.0 else GameState.run_time, deaths, items)
	standings_updated.emit()

	if _everyone_done():
		GameState.is_running = false
		round_over.emit()


## True once everybody the round is actually waiting for is out of the maze.
##
## A bot still walking around is nobody to wait for. The room has finished, the
## board is what it is, and holding the result screen back until the last CPU
## has found its way out is the game refusing to end a race it has already lost
func _everyone_done() -> bool:
	if session == null:
		return false

	for id: int in session.runners:
		if is_bot_seat(seat_of_account(id)):
			continue

		if not session.has_finished(id):
			return false

	return true


func team_of(account: int) -> int:
	return session.team_of(account) if session != null else 0


func team_color(team: int) -> Color:
	return session.team_color(team) if session != null else Color.WHITE


## The colour that account is drawn in. In a team mode everybody on a side is
## the same colour on purpose — a round is read by where the colours are, and
## twelve separate hues would say nothing about who is winning
func color_of(account: int) -> Color:
	if is_painting():
		return team_color(team_of(account))

	var seat := seat_of_account(account)
	if seat >= 0 and kind != Kind.ONLINE and not is_bot_seat(seat):
		return Seats.color_of(seat)

	return GhostField.ghost_color(account)


## Takes a tile for that cube's side. The claim is settled here whatever the
## round is being played over, and only then does anybody else hear about it
func paint_cell(account: int, cell: Vector2i) -> void:
	if not is_painting() or session.round_ended:
		return

	var stamp := GameState.run_time
	if not session.claim(account, cell, stamp):
		return

	if transport != null and is_local(account):
		transport.send_paint(account, cell, stamp)

	paint_changed.emit()


## Gives back the last few tiles that cube took, the price of dying
func lose_tiles(account: int, count: int) -> void:
	if not is_painting():
		return

	var given := session.release_tiles(account, count)
	if given.is_empty():
		return

	if transport != null and is_local(account):
		transport.send_unpaint(account, given)

	paint_changed.emit()


func erase_cell(account: int, cell: Vector2i) -> void:
	if not is_painting() or not session.erase(cell):
		return

	if transport != null and is_local(account):
		transport.send_erase(cell)

	paint_changed.emit()


## Puts a status on a cube. One of ours is simply told; anybody else's machine
## is the one that decides what it means for them
func send_status(account: int, effect: String, seconds: float) -> void:
	if is_local(account):
		Status.apply_to(maxi(seat_of_account(account), 0), effect, seconds)
	elif transport != null:
		transport.send_status(account, effect, seconds)


## One cube caught another. Same rule as a status: the machine that owns a cube
## is the one that kills it
func report_hit(account: int) -> void:
	if is_local(account):
		var cube := Player.at_seat(get_tree(), seat_of_account(account))
		if cube != null and not cube.death.is_dead:
			cube.death.kill(true)
	elif transport != null:
		transport.send_hit(account)


func begin_penalty(account: int) -> void:
	if session != null:
		session.begin_penalty(account, death_penalty_seconds())


## Seconds a death costs before the cube is put back, 0 when a death rebuilds
## the level instead.
##
## A round played on one screen can never rebuild it: the maze belongs to the
## whole room and tearing it down would take the level away from the three
## players still walking around in it. So a mode with no wait of its own — the
## race, which online simply reloads — gets the co-op one when it is local
func death_penalty_seconds() -> float:
	if not is_racing():
		return 0.0

	var own := session.mode().death_penalty_seconds
	if own > 0.0:
		return own

	return CoopCoordinator.RESPAWN_SECONDS if kind == Kind.PARTY else 0.0


## True while a death is sat out rather than rebuilding the level
func serves_penalty() -> bool:
	return death_penalty_seconds() > 0.0


func penalty_left(account: int) -> float:
	return session.penalty_left(account) if session != null else 0.0


func end_penalty(account: int) -> void:
	if session != null:
		session.end_penalty(account)


func spawn_cells_from(cells: Array, width: int) -> void:
	if session != null:
		session.spawn_cells_from(cells, width)


## Where the cubes on this machine come into the maze, in seat order. Empty when
## the mode places nobody, which is what the campaign wants: the level's own
## spawner drew a cell and everybody starts on it
func seat_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	if session == null:
		return cells

	for account in _seat_accounts:
		var cell := session.spawn_cell(account)
		if cell.x < 0:
			return [] as Array[Vector2i]

		cells.append(cell)

	return cells


func respawn_cell(account: int) -> Vector2i:
	return session.respawn_cell(account) if session != null else Vector2i(-1, -1)


func standings() -> Array:
	return session.standings() if session != null else []


func rank_of(account: int) -> int:
	return session.rank_of(account) if session != null else 0


func finisher_count() -> int:
	return session.finisher_count() if session != null else 0


func anyone_running() -> bool:
	return session != null and session.anyone_running()


## True once that cube is out of the maze and the result panel has the screen.
## The map is still running underneath it, so whatever would normally take the
## mouse back off a menu has to ask first
func showing_results(account: int) -> bool:
	return is_racing() and session.has_finished(account)


## The cubes on this machine that are actually in the level right now
func local_players() -> Array[Player]:
	var found: Array[Player] = []

	for seat in range(_seat_accounts.size()):
		var cube := Player.at_seat(get_tree(), seat)
		if cube != null:
			found.append(cube)

	return found


## Writes where each of our cubes is into the ranking, so that everything which
## reads a runner's position — the jolt, the roller, the online packets — has one
## place to read it from whether it arrived over a wire or not
func refresh_local_runners() -> void:
	if session == null:
		return

	for seat in range(_seat_accounts.size()):
		var account: int = _seat_accounts[seat]
		var cube := Player.at_seat(get_tree(), seat)

		if cube == null:
			session.remember(account, {"placed": false})
			continue

		var mesh := cube.get_node_or_null("mesh") as Node3D

		session.remember(account, {
			"placed": true,
			"position": cube.global_position,
			"yaw": mesh.global_rotation.y if mesh != null else 0.0,
			"dead": cube.death.is_dead,
		})


## Counts a sphere against that cube, so the ranking reads what it picked up
func count_item(account: int) -> void:
	if session == null:
		return

	var runner: Dictionary = session.runners.get(account, {})
	if not runner.is_empty():
		runner["items"] = int(runner["items"]) + 1


## Called by the map once it has finished building itself. This is where the
## round's own nodes are put into the scene, so the map scene itself carries
## nothing about any of the modes and still works opened on its own
func attach_to_map(map: Node) -> void:
	if map == null:
		return

	match kind:
		Kind.ONLINE:
			map.add_child(build_node(GHOST_FIELD))
			map.add_child(build_node(RACE_OVERLAY))
			if is_painting():
				map.add_child(build_node(PAINT_FIELD))
		Kind.PARTY:
			map.add_child(build_node(RACE_OVERLAY))
			if is_private_race():
				map.add_child(build_node(GHOST_FIELD))
			if is_painting():
				map.add_child(build_node(PAINT_FIELD))
		Kind.CAMPAIGN:
			if is_split():
				map.add_child(build_node(COOP_COORDINATOR))

	if has_bots():
		map.add_child(build_node(BOT_SQUAD))

	if is_split():
		map.add_child(build_node(SPLIT_RIG))

	if is_racing():
		zero_clock()


## One node built from its script. Every one of them knows what it extends, so
## nothing here has to
func build_node(script_path: String) -> Node:
	var script: GDScript = load(script_path)
	var node: Node = script.new()
	node.name = script_path.get_file().get_basename().to_pascal_case()
	return node


## The clock is put back to zero on the first frame after the maze was built,
## not when the round was started. A gigantic map takes a moment to generate and
## the machine that took longest must not start the round already behind.
##
## Only the first map of the round is timed from zero. The ones a death rebuilds
## carry the time that has already been spent, that is what a death costs
func zero_clock() -> void:
	if _clock_zeroed:
		return

	_clock_zeroed = true
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.run_time = 0.0
	GameState.level_start_time = 0.0
