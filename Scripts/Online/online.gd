extends Node

## Everything multiplayer. One lobby over Steam, up to twelve cubes in it, and
## a race through a maze every one of them builds for themselves out of the same
## seed.
##
## Nothing here runs unless the player pressed ONLINE. The campaign never asks
## this node anything, and the two calls the map scene makes into it both fall
## straight back out again while no race is on, so a build with no Steam client,
## no extension and no network plays exactly as it did before.
##
## The maze is not sent over the wire. Every machine builds the identical level
## from the settings and the one seed the host rolled, which is what makes a
## ninety six cell maze possible at all: the only traffic is a position per cube
## per frame and a handful of counters

## Steam came up, or did not. The online screen waits on this before it lets
## anybody host
signal steam_ready(ok: bool)

## This machine is now in a lobby, whether it opened one or walked into one
signal lobby_entered

## The lobby is gone, with the line to show the player about why
signal lobby_closed(reason: String)

## Somebody joined, left, readied up, or the host moved a setting
signal lobby_updated

## The answer to a browser refresh, one dictionary per open lobby
signal lobby_list_ready(lobbies: Array)

## The host started the race, the map is being swapped in
signal race_launched

## A runner died, took a sphere, or made it out
signal standings_updated

## A tile changed hands, anywhere on the map
signal paint_changed

## The painting round ran out of time
signal round_over

const MAP_SCENE := "res://Scenes/Enviroment/map.tscn"
const LOBBY_SCENE := "res://Scenes/Ui/lobby_screen.tscn"
const TITLE_SCENE := "res://Scenes/Ui/title_screen.tscn"

## The two nodes a race puts into the map. They are loaded by path when they are
## needed rather than preloaded by name: both of them talk back to this autoload,
## and naming them up here would be a circle neither script could compile out of
const GHOST_FIELD := "res://Scripts/Online/ghost_field.gd"
const RACE_OVERLAY := "res://Scripts/Ui/race_overlay.gd"
const PAINT_FIELD := "res://Scripts/Online/paint_field.gd"


## How many cubes fit in one maze
const MAX_PLAYERS := 12

## How few it can be run with. One is allowed on purpose: a lobby of one is how
## the whole thing gets tested, and a mode that refuses to open until somebody
## else turns up cannot be looked at alone
const MIN_PLAYERS := 1

## What the lobby browser filters on, so the list is this game and not every
## lobby the app id ever opened
const TAG_KEY := "game"
const TAG_VALUE := "exit_the_cube"

## Which race the lobby is on, counted up by the host and read by everybody.
##
## It used to be a single word saying whether a race was on, and that is exactly
## why stepping back to the lobby dragged the whole room out of the maze with it:
## there was one flag for everyone, so one player changing it changed it for all.
## A number that only ever goes up says "a new race has started" without saying
## anything about who is still in the old one, and leaving becomes a thing a
## player does to themselves
const ROUND_KEY := "round"

## Where this machine stands. RACING is the only one the map scene cares about
enum Phase { OFFLINE, LOBBY, RACING }

## A ghost position, sent unreliably and often
const MSG_STATE := 1

## Everything a ranking is built from, the finish included. It is one message
## rather than two on purpose: a separate "I am out" sent once and only once is
## a single packet the whole board depends on, and a line that hiccups at that
## moment leaves a cube standing in the maze forever on every other screen. This
## one repeats, so a lost one costs a second rather than the race
const MSG_PROGRESS := 2

## Sent to everybody on arrival so the other machines can open a session back
const MSG_HELLO := 4

## Where the blades nearest this cube are standing, so that watching somebody
## shows the maze they are actually in.
##
## Only the ones close enough to matter go out, by their place in the spawn
## order. Every machine built the same level from the same seed, so blade number
## nine is the same blade on every screen — which means a position and an index
## is enough to put a watcher's own copy of it exactly where the watched player
## sees it, without sending anything about the route it runs
const MSG_SAWS := 5

## How many blades around a cube are worth telling the others about. Beyond a
## dozen they are around a corner and behind a wall
const SAWS_TRACKED := 12

## How far a blade may be and still be sent, in meters
const SAW_RANGE := 26.0

## How often the blade positions go out. Slower than the ghosts: a watcher is
## looking at a whole corridor rather than reading one cube's footwork
const SAW_RATE := 1.0 / 10.0

## Tiles this cube has just taken, and tiles a death has just cost it. Both are
## sent reliably: a lost position is one frame of a ghost, a lost tile is a hole
## in the floor that nothing ever fills in
const MSG_PAINT := 6
const MSG_UNPAINT := 7

## How often claimed tiles go out. A cube crossing a cell every few frames does
## not need a packet each time, and a handful in one message is the same packet
const PAINT_RATE := 1.0 / 6.0

## One cube caught another while the cat was up.
##
## It has to be a message rather than a collision because the other players are
## drawings here — a position arrives, a cube is put there, and nothing about it
## is a body anything can run into. So the one who caught somebody says so, and
## the machine that owns that cube is the one that kills it. Which is also the
## honest way round: nobody else gets to decide when your cube dies
const MSG_HIT := 8

## How close a rainbow cube has to get to count as having caught somebody, in
## meters. A little over one cell, so a pass down the same corridor lands it
const HIT_RANGE := 2.4

## A tile scrubbed bare by a roller, whoever it belonged to
const MSG_ERASE := 9

## Something done to another cube — a soaking, a jolt. Like the cat's kill it
## has to be a message: the machine that owns a cube is the one that may change
## what it can do
const MSG_STATUS := 10

## How many cells at a team's end of the maze a player may come back at. Wide
## enough that a death does not put them back on the tile they just left, tight
## enough that they are still on their own side
const RESPAWN_SPREAD := 40

## How often a cube tells the others where it is. Fifteen a second is enough for
## a ghost the interpolation smooths anyway, and it keeps twelve players inside
## a couple of kilobytes a second
const STATE_RATE := 1.0 / 15.0

## Seconds without a packet before a ghost is taken off the map. Long enough to
## sit through a map rebuild after a death, which sends nothing at all
const GHOST_TIMEOUT := 8.0

## Seconds between two knocks at the other cubes while the lobby is open
const HELLO_INTERVAL := 2.0

## Seconds between two counter packets when nothing about them has changed. One
## a second per cube is nothing next to the ghost positions, and it is what puts
## a board that drifted back in step on its own
const PROGRESS_HEARTBEAT := 1.0

var steam := SteamService.new()

var phase: int = Phase.OFFLINE

## The lobby this machine is in, 0 while it is in none
var lobby_id: int = 0

## True while this machine owns the lobby and decides the rules
var is_host: bool = false

## Mode, size, shape and difficulty, by their place in the RaceRules lists. The
## host owns these, everybody else reads them off the lobby
var settings: Dictionary = RaceRules.default_settings()

## The number the whole lobby builds its maze from
var race_seed: int = 0

## Everybody in the lobby, in the order Steam lists them:
## { "id": int, "name": String, "ready": bool, "host": bool }
var members: Array[Dictionary] = []

## Every cube in the race by its account, whether it is still on this machine's
## screen or not. The ghosts are drawn off these and so is the ranking
var runners: Dictionary = {}

## The level the race is run on, built once when the race starts and kept over
## every death, so the maze a player comes back into is the one they left
var _level: MapData = null

## True once the clock was put back to zero for this race. A death rebuilds the
## map and would otherwise hand the runner a fresh start on the timer as well
var _clock_zeroed: bool = false

## Seconds until the next ghost packet goes out
var _send_timer: float = 0.0

## Seconds until the counters go out again whether they moved or not
var _progress_timer: float = 0.0

## Seconds until the nearby blade positions go out again
var _saw_timer: float = 0.0

## Who owns which tile of the floor. Empty outside the painting mode
var paint := PaintState.new()

## Which side each account is on, worked out from the seed rather than sent
var teams: Dictionary = {}

## What each side is drawn in, rolled per round
var team_colors: Array[Color] = []

## Where each account comes into the maze, one cell each and no two the same
var spawns: Dictionary = {}

## The cells this cube may come back at, and the last one it used
var _respawn_pool: Array = []
var _last_respawn: Vector2i = Vector2i(-1, -1)

## Tiles this cube has taken, oldest first, with the stamp each was taken under.
## A death gives the last few of them back, so the order matters
var _my_tiles: Array = []

## Claims waiting to go out together on the next tick
var _pending_paint: Array = []

var _paint_timer: float = 0.0

## True once the clock ran out and the result is on screen
var _round_ended: bool = false

## When this cube is allowed back into the maze, in seconds since the game
## started. Zero while it is standing. The panel counts down against it, so the
## number on screen and the wait the cube is actually serving are the same one
var _back_at: float = 0.0

## Accounts Steam could not open a line to, by what it said about it. Shown on
## the race panel, because a player who cannot be reached at all is not a bug in
## the ranking and should not be read as one
var _failed_links: Dictionary = {}

## What was last sent about this cube, so a counter that has not moved does not
## cost a reliable packet every tick
var _sent_progress: Dictionary = {}

## The lobby state this machine last acted on. Steam repeats a data update for
## every key that changed, and the race must only be entered once
var _acted_round: int = 0

## Packets out and in since this lobby was joined. The race panel puts them on
## screen, and they are the difference between "nothing is syncing" and knowing
## which half of it went quiet: traffic out with none coming back is a line that
## was never opened, traffic both ways is something further up
var _sent: int = 0
var _received: int = 0

## Seconds until the next knock goes out to everybody in the lobby. A Steam
## session has to be agreed to by both ends before anything crosses it, and the
## first packets sent over an unopened one are thrown away — so the knocking is
## done while people are still readying up rather than with the race already on
var _hello_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	GameState.run_finished.connect(_on_run_finished)


## Brings Steam up. This is deliberately not done at startup and it is worth
## saying why, because doing it there is the obvious thing and it costs the
## campaign.
##
## Bringing the API up loads Steam's overlay into the process, and the overlay
## hooks the input APIs on its way in. On a build that was started outside Steam
## that hook has been seen to swallow controller input entirely — the pad is
## still enumerated and still reports its name, and nothing that is pressed on
## it ever arrives. A player who never touches the online button should never be
## anywhere near that, so the whole of Steam stays switched off until the online
## screen asks for it.
##
## What it costs is an invite accepted while sitting on the title screen: there
## is nothing listening for the callback yet. Pressing ONLINE first is a small
## price for a campaign that plays the way it always did
func connect_to_steam() -> bool:
	if steam.running:
		return true

	var ok := steam.start()
	if ok:
		_listen()
		set_process(true)

	steam_ready.emit(ok)
	return ok


## Why online is not available, empty while it is
func steam_error() -> String:
	if not steam.available():
		return "this build has no Steam support compiled in"

	return steam.error


func _listen() -> void:
	steam.listen(&"lobby_created", _on_lobby_created)
	steam.listen(&"lobby_joined", _on_lobby_joined)
	steam.listen(&"lobby_chat_update", _on_lobby_chat_update)
	steam.listen(&"lobby_data_update", _on_lobby_data_update)
	steam.listen(&"lobby_match_list", _on_lobby_match_list)
	steam.listen(&"join_requested", _on_join_requested)
	steam.listen(&"p2p_session_request", _on_session_request)
	steam.listen(&"network_messages_session_request", _on_session_request)
	steam.listen(&"network_messages_session_failed", _on_session_failed)


## Steamworks answers through callbacks and the packets pile up in a queue, both
## of which have to be emptied by hand. The race traffic goes out on the same
## beat, which is why this runs even while the tree is paused
func _process(delta: float) -> void:
	steam.poll()
	_receive()

	if phase == Phase.LOBBY:
		_keep_sessions_warm(delta)
		return

	if phase != Phase.RACING:
		return

	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = STATE_RATE
		_send_local_state()

	_saw_timer -= delta
	if _saw_timer <= 0.0:
		_saw_timer = SAW_RATE
		_send_local_saws()

	_send_local_progress(delta)
	_drop_stale_ghosts()

	if is_painting():
		_tick_paint(delta)
		_tick_hunt()
		_tick_round()


## Opens a lobby with this machine as its host
func host_lobby() -> void:
	if not steam.running:
		return

	settings = RaceRules.default_settings()
	steam.create_lobby(MAX_PLAYERS)


func join_lobby(lobby: int) -> void:
	if steam.running:
		steam.join_lobby(lobby)


## Steps out of the lobby and closes every session it opened. A host leaving
## hands the lobby to somebody else, Steam picks who
func leave_lobby() -> void:
	if lobby_id != 0:
		for runner: int in runners:
			steam.close_session(runner)

		steam.leave_lobby(lobby_id)

	_reset()
	lobby_closed.emit("")


## Asks Steam for every open lobby of this game, the answer comes back on
## lobby_list_ready
func refresh_lobbies() -> void:
	if steam.running:
		steam.request_lobbies(TAG_KEY, TAG_VALUE)


## Opens the Steam overlay on this lobby's invite dialog, and says whether that
## was possible at all.
##
## It only is when the game was started through Steam. Off the disk or out of the
## editor there is no overlay in the process, and asking for one is a call that
## returns quietly having done nothing — which is exactly what a button that
## looks like it works and does not feels like. False means the caller has to
## offer the list itself
func invite_friends() -> bool:
	if lobby_id == 0 or not steam.overlay_enabled():
		return false

	steam.invite_overlay(lobby_id)
	return true


## The friends list, for the panel the game puts up when there is no overlay to
## hand the job to
func friend_list() -> Array:
	return steam.friends()


## Sends that friend an invite to this lobby. It arrives as a Steam notification
## and joins them straight in, the same as one sent from the overlay would
func invite_friend(friend: int) -> void:
	if lobby_id != 0:
		steam.invite_to_lobby(lobby_id, friend)


func in_lobby() -> bool:
	return phase != Phase.OFFLINE and lobby_id != 0


func is_racing() -> bool:
	return phase == Phase.RACING


## True while a painting round is on. Every part of the paint mode asks this
## rather than the mode setting, so nothing of it can run in a lobby or a race
func is_painting() -> bool:
	return phase == Phase.RACING and RaceRules.is_paint(settings)


## Which side that account is on, 0 when the mode has no teams
func team_of(account: int) -> int:
	return int(teams.get(account, 0))


## The colour that account is drawn in. In a team mode everybody on a side is
## the same colour on purpose — a round is read by where the colours are, and
## twelve separate hues would say nothing about who is winning
func color_of(account: int) -> Color:
	if RaceRules.is_paint(settings):
		return team_color(team_of(account))

	return GhostField.ghost_color(account)


## What a side is drawn in this round. Rolled once when the teams are drawn, so
## every screen and every tile agrees without asking again
func team_color(team: int) -> Color:
	if team < 0 or team >= team_colors.size():
		return Color.WHITE

	return team_colors[team]


## The mode this round is being played under
func mode() -> RaceMode:
	return RaceRules.mode_of(settings)


## Seconds a broken blade stays down, 0 outside a race or in a mode that keeps
## them broken
func saw_revive_seconds() -> float:
	return mode().saw_revive_seconds if is_racing() else 0.0


## Seconds left in the painting round, 0 once it is over
func round_left() -> float:
	return maxf(RaceRules.round_seconds(settings) - GameState.run_time, 0.0)


func round_ended() -> bool:
	return _round_ended


## The level the race is run on. The map scene builds from this instead of from
## the campaign while a race is on
func level() -> MapData:
	return _level


## Marks this machine ready or not. The host has a start button instead and is
## always counted as ready
func set_ready(ready: bool) -> void:
	if lobby_id == 0:
		return

	steam.set_member_data(lobby_id, "ready", "1" if ready else "0")
	_refresh_members()


func is_ready() -> bool:
	for member in members:
		if member["id"] == steam.id:
			return bool(member["ready"])

	return false


## True once every cube in the lobby has readied up, the host included. Nobody
## presses start any more — the room being green is what starts the race, so the
## host is a player in it rather than the one holding everybody up.
##
## The host used to be counted as ready no matter what, left over from when the
## start button was theirs. It meant they could never take their own readiness
## back, and that a host sitting alone in a fresh lobby was already a full room
func everyone_ready() -> bool:
	if members.is_empty():
		return false

	for member in members:
		if not bool(member["ready"]):
			return false

	return true


## Whether the countdown may run. A race wants somebody to race against, so one
## cube readying up on its own waits for company rather than opening a maze
## nobody else is in
func race_can_start() -> bool:
	return members.size() >= MIN_PLAYERS and everyone_ready()


## Moves one of the four settings. Only the host may, everybody else reads them
## back off the lobby a moment later
func set_setting(key: String, value: int) -> void:
	if not is_host or lobby_id == 0:
		return

	settings[key] = value
	steam.set_lobby_data(lobby_id, key, str(value))
	steam.set_lobby_data(lobby_id, "title", RaceRules.short_title_of(settings))
	lobby_updated.emit()


## Rolls the seed the whole lobby builds from and puts the lobby into the race.
## Nothing is sent to anybody here: the state lands in the lobby data and every
## machine, this one included, walks into the race off the update it gets back
func start_race() -> void:
	if not is_host or lobby_id == 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	steam.set_lobby_data(lobby_id, "seed", str(rng.randi_range(0, 0x7FFFFFF)))
	steam.set_lobby_data(lobby_id, ROUND_KEY, str(_round() + 1))
	_read_lobby_data()
	_follow_round()


## Steps this machine out of the race and back to the lobby screen, and only this
## machine. The others keep running: somebody who is done watching should not be
## able to end everybody else's maze by walking away from their own
func leave_race() -> void:
	if phase != Phase.RACING:
		return

	phase = Phase.LOBBY
	_level = null
	runners.clear()
	GameState.is_running = false
	set_ready(false)
	Transition.change_scene(LOBBY_SCENE)


## Which race the lobby is on, 0 before the first one
func _round() -> int:
	var value := steam.lobby_data(lobby_id, ROUND_KEY)
	return int(value) if not value.is_empty() else 0


## Called by the map once it has finished building itself. This is where the
## ghosts and the race panel are put into the scene, so the map scene itself
## carries nothing online at all and still works opened on its own
func attach_to_map(map: Node) -> void:
	if not is_racing() or map == null:
		return

	map.add_child(_build(GHOST_FIELD))
	map.add_child(_build(RACE_OVERLAY))

	if RaceRules.is_paint(settings):
		map.add_child(_build(PAINT_FIELD))

	_zero_clock()


## One of the two race nodes, built from its script. Every one of them knows
## what it extends, so nothing here has to
func _build(script_path: String) -> Node:
	var script: GDScript = load(script_path)
	var node: Node = script.new()
	node.name = script_path.get_file().get_basename().to_pascal_case()
	return node


## The clock is put back to zero on the first frame after the maze was built,
## not when the race was started. A gigantic map takes a moment to generate and
## the machine that took longest must not start the race already behind.
##
## Only the first map of the race is timed from zero. The ones a death rebuilds
## carry the time that has already been spent, that is what a death costs
func _zero_clock() -> void:
	if _clock_zeroed:
		return

	_clock_zeroed = true
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.run_time = 0.0
	GameState.level_start_time = 0.0


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


## How many cubes are out of the maze already
func finisher_count() -> int:
	var count := 0

	for id: int in runners:
		if bool(runners[id]["finished"]):
			count += 1

	return count


## Where this machine stands on the board right now, 0 while it is in no race
func local_rank() -> int:
	for runner in standings():
		if int(runner["id"]) == steam.id:
			return int(runner["rank"])

	return 0


## True once this cube is out of the maze and the race panel has the screen. The
## map is still running underneath it, so whatever would normally take the mouse
## back off a menu has to ask first
func showing_results() -> bool:
	if not is_racing():
		return false

	var me: Dictionary = runners.get(steam.id, {})
	return not me.is_empty() and bool(me["finished"])


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


func _on_lobby_created(result: int, lobby: int) -> void:
	if result != 1:
		lobby_closed.emit("the lobby would not open, Steam said no")
		return

	lobby_id = lobby
	is_host = true
	phase = Phase.LOBBY
	_acted_round = 0

	steam.set_lobby_data(lobby, TAG_KEY, TAG_VALUE)
	steam.set_lobby_data(lobby, "host", steam.persona(steam.id))
	steam.set_lobby_data(lobby, ROUND_KEY, "0")
	steam.set_lobby_data(lobby, "title", RaceRules.short_title_of(settings))
	steam.set_joinable(lobby, true)

	for key: String in settings:
		steam.set_lobby_data(lobby, key, str(settings[key]))

	set_ready(false)
	_refresh_members()
	lobby_entered.emit()
	_open_lobby_screen()


func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		lobby_closed.emit("that lobby would not let you in")
		return

	lobby_id = lobby
	phase = Phase.LOBBY
	is_host = steam.lobby_owner(lobby) == steam.id

	set_ready(false)
	_read_lobby_data()
	_acted_round = _round()
	_refresh_members()
	_greet_everyone()
	lobby_entered.emit()
	_open_lobby_screen()


## Puts the lobby on screen from wherever the game happened to be. Being in a
## lobby and looking at something else is not a state worth having, and it is
## exactly what an invite accepted off the title screen would leave behind
func _open_lobby_screen() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != LOBBY_SCENE:
		Transition.change_scene(LOBBY_SCENE)


## Somebody came or went. Steam has already updated the member list by the time
## this arrives, so it is simply read again
func _on_lobby_chat_update(lobby: int, changed: int, _by: int, _state: int) -> void:
	if lobby != lobby_id:
		return

	steam.close_session(changed)
	is_host = steam.lobby_owner(lobby) == steam.id
	_refresh_members()
	lobby_updated.emit()


func _on_lobby_data_update(_success: int, lobby: int, _member: int) -> void:
	if lobby != lobby_id:
		return

	_read_lobby_data()
	_refresh_members()
	lobby_updated.emit()
	_follow_round()


## The host counted the lobby on to a new race and every machine, the host
## included, walks into it off the update it gets back rather than off the button
## that caused it. Only going up ever means anything — there is no number that
## means "stop", because stopping is something each player does for themselves
func _follow_round() -> void:
	var now := _round()
	if now <= _acted_round:
		return

	_acted_round = now
	_enter_race()


func _on_lobby_match_list(lobbies: Array) -> void:
	var found: Array = []

	for lobby: int in lobbies:
		found.append({
			"id": lobby,
			"host": steam.lobby_data(lobby, "host"),
			"title": steam.lobby_data(lobby, "title"),
			"players": steam.member_count(lobby),
		})

	lobby_list_ready.emit(found)


## A friend invited this machine through the Steam overlay
func _on_join_requested(lobby: int, _friend: int) -> void:
	if lobby_id != 0:
		leave_lobby()

	join_lobby(lobby)


## Every session has to be agreed to by both sides, and this is the one chance
## to agree. Steam asks once per attempt — turn it down and the packets that
## follow are dropped without another word, which is a race that silently never
## syncs at all.
##
## It used to be turned down whenever the sender was not in the member list yet,
## and that list arrives over the network like everything else: a cube that
## started sending the moment it joined got refused by a host whose list was one
## callback behind. Being in a lobby at all is enough of a reason to say yes
func _on_session_request(remote: int) -> void:
	if lobby_id == 0 or remote == 0:
		return

	steam.accept_session(remote)
	_refresh_members()


## Steam gave up on a line to somebody. Worth saying out loud rather than
## leaving a race that quietly never syncs: this is the one message that names
## the reason, and it is the difference between a firewall and a bug in here
func _on_session_failed(reason: int, remote: int, state: int, message: String) -> void:
	push_warning("Online: no line to %d (reason %d, state %d) %s" % [remote, reason, state, message])
	_failed_links[remote] = message if not message.is_empty() else "reason %d" % reason


## The four settings, read back off the lobby. The host wrote them, so this is
## also how the host's own copy is kept honest after a reconnect
func _read_lobby_data() -> void:
	for key: String in RaceRules.default_settings():
		var value := steam.lobby_data(lobby_id, key)
		if not value.is_empty():
			settings[key] = int(value)

	var seed_value := steam.lobby_data(lobby_id, "seed")
	if not seed_value.is_empty():
		race_seed = int(seed_value)


## Rebuilds the member list off Steam. Names and ready flags both live there, so
## nothing has to be sent between the machines while the lobby is open
func _refresh_members() -> void:
	members.clear()

	if lobby_id == 0:
		return

	var owner := steam.lobby_owner(lobby_id)

	for at in range(steam.member_count(lobby_id)):
		var id := steam.member_at(lobby_id, at)
		if id == 0:
			continue

		members.append({
			"id": id,
			"name": steam.persona(id),
			"ready": steam.member_data(lobby_id, id, "ready") == "1",
			"host": id == owner,
		})


## One packet to everybody the moment this machine arrives, so the sessions are
## open before the first ghost position needs one
func _greet_everyone() -> void:
	_broadcast([MSG_HELLO], true)


## Keeps knocking while the lobby fills up. Opening a Steam session takes a
## round trip both ends have to agree to, and whatever is sent before that is
## gone — so a race that starts on a cold line loses its first second of ghosts,
## and one where a knock went missing never opens the line at all
func _keep_sessions_warm(delta: float) -> void:
	if members.size() < 2:
		return

	_hello_timer -= delta
	if _hello_timer > 0.0:
		return

	_hello_timer = HELLO_INTERVAL
	_greet_everyone()


## How the lines to the other cubes are doing, for the race panel to show. This
## is the one thing worth putting on screen when a race will not sync: packets
## going out with nothing coming back is a line that never opened, and both
## numbers climbing means the trouble is somewhere else entirely
func link_report() -> Dictionary:
	var open := 0

	for id: int in runners:
		if id != steam.id and steam.session_is_open(id):
			open += 1

	return {
		"sent": _sent,
		"received": _received,
		"open": open,
		"peers": maxi(runners.size() - 1, 0),
		"failed": _failed_links.size(),
	}


func _enter_race() -> void:
	if phase == Phase.RACING:
		return

	phase = Phase.RACING
	set_process(true)
	_level = RaceRules.build_level(settings, race_seed)
	_clock_zeroed = false
	_send_timer = 0.0
	_sent_progress.clear()
	_build_runners()
	_draw_teams()
	set_ready(false)

	Levels.stop()
	GameState.is_running = false
	GameState.start_run()
	Quips.say_next(Quips.pick("online_race_start", OnlineQuips.RACE_START))

	race_launched.emit()
	Transition.change_scene(MAP_SCENE)


## Splits the room into sides and clears the floor. Both the teams and the cells
## each player comes in on are worked out from the accounts and the seed, so
## every machine reaches the same answer without a word being sent about it.
##
## The spawn cells need the maze, which is not built yet at this point — they are
## filled in by the map once it has one, through spawn_cells_from
func _draw_teams() -> void:
	paint.clear()
	teams.clear()
	team_colors.clear()
	spawns.clear()
	_respawn_pool.clear()
	_last_respawn = Vector2i(-1, -1)
	_my_tiles.clear()
	_pending_paint.clear()
	_paint_timer = 0.0
	_round_ended = false

	if not RaceRules.is_paint(settings):
		return

	var sides := RaceRules.team_count(settings)
	teams = TeamDraw.teams_of(runners.keys(), sides, race_seed)
	team_colors = RaceRules.roll_team_colors(race_seed, sides)


## Hands out the starting cells once the maze exists. Called by the map, which
## is the first thing that knows where the corridors are
func spawn_cells_from(cells: Array, size: int) -> void:
	if not RaceRules.is_paint(settings) or not spawns.is_empty():
		return

	spawns = TeamDraw.spawns_of(teams, RaceRules.team_count(settings), cells, size)
	_respawn_pool = TeamDraw.region_of(team_of(steam.id), cells, size, RESPAWN_SPREAD)


## Where this cube comes in, or a cell of -1 when the mode does not place people
func spawn_cell() -> Vector2i:
	return spawns.get(steam.id, Vector2i(-1, -1))


## Where this cube comes back after a death: anywhere in its own end of the
## maze, and never twice in a row on the same tile. Coming back where you fell
## is coming back onto floor you had already painted, so the walk out is the
## whole of what the death cost
func respawn_cell() -> Vector2i:
	if _respawn_pool.size() < 2:
		return spawn_cell()

	var picked: Vector2i = _last_respawn

	while picked == _last_respawn:
		picked = _respawn_pool[randi() % _respawn_pool.size()]

	_last_respawn = picked
	return picked


## One runner per cube in the lobby, all of them on zero. A ghost is only drawn
## once a position has arrived for it, so a player whose map takes longer to
## build does not flicker into the corner of the maze first
func _build_runners() -> void:
	runners.clear()
	_refresh_members()

	for member in members:
		_add_runner(member)


func _add_runner(member: Dictionary) -> void:
	runners[member["id"]] = {
		"id": member["id"],
		"name": member["name"],
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
		"seen_at": _now(),
	}


## Where this cube is, sent to everybody else. The player is looked up rather
## than handed in, so a map that is between two rebuilds simply sends nothing
func _send_local_state() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var death := get_tree().get_first_node_in_group("player_death") as PlayerDeath
	var dead := death != null and death.is_dead
	var yaw := 0.0

	var mesh := player.get_node_or_null("mesh") as Node3D
	if mesh != null:
		yaw = mesh.global_rotation.y

	_remember_local({"position": player.global_position, "yaw": yaw, "dead": dead})
	_broadcast([MSG_STATE, player.global_position, yaw, dead], false)


## The counters, sent whenever one of them moved and once a second regardless.
##
## The heartbeat is what makes the board self healing. Sending only on change is
## enough right up until one of those packets is the one that goes missing, and
## the counter it carried is then wrong on somebody else's screen for the rest
## of the race with nothing left to correct it
func _send_local_progress(delta: float) -> void:
	var me: Dictionary = runners.get(steam.id, {})
	var progress := {
		"deaths": GameState.deaths,
		"items": GameState.items_collected,
		"has_key": GameState.has_key,
		"finished": not me.is_empty() and bool(me["finished"]),
		"time": float(me.get("time", 0.0)),
		"item": _held_item(),
	}

	_remember_local(progress)
	_progress_timer -= delta

	if progress == _sent_progress and _progress_timer > 0.0:
		return

	_progress_timer = PROGRESS_HEARTBEAT
	_sent_progress = progress.duplicate()
	_broadcast([MSG_PROGRESS, progress["deaths"], progress["items"], progress["has_key"], \
		progress["finished"], progress["time"], progress["item"]], true)
	standings_updated.emit()


## Where the blades around this cube are, by their place in the spawn order.
##
## The order is the same on every machine because the level was built from the
## same seed, so an index and a position is all a watcher needs to move its own
## copy of that blade to where this player sees it. Sending every blade would be
## two hundred positions on a gigantic map; the ones out of sight are the ones
## nobody watching this cube could see anyway
func _send_local_saws() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var spawner := get_tree().get_first_node_in_group(&"saw_spawner") as SawSpawner

	if player == null or spawner == null:
		return

	var here := player.global_position
	var near: Array = []

	for at in range(spawner.spawned_saws.size()):
		var saw: Node3D = spawner.spawned_saws[at]
		if not is_instance_valid(saw):
			continue

		var away := here.distance_to(saw.global_position)
		if away <= SAW_RANGE:
			near.append({"at": at, "away": away, "position": saw.global_position})

	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["away"]) < float(b["away"]))

	var payload: Array = []
	for entry: Dictionary in near.slice(0, SAWS_TRACKED):
		payload.append(int(entry["at"]))
		payload.append(entry["position"])

	_broadcast([MSG_SAWS, payload], false)


## Starts the wait a death costs. Called by the cube that burst, so that the
## countdown on screen is the same one it is actually serving rather than a
## second timer running alongside it and drifting
func begin_penalty() -> void:
	_back_at = _now() + mode().death_penalty_seconds


## Seconds until this cube is back on its feet, 0 while it is already standing
func penalty_left() -> float:
	return maxf(_back_at - _now(), 0.0) if _back_at > 0.0 else 0.0


## Called by the cube once it is back, so nothing keeps counting down at it
func end_penalty() -> void:
	_back_at = 0.0


## Takes a tile for this cube's side, if it is not already ours. Called by the
## paint field whenever the player steps onto a new cell
func paint_cell(cell: Vector2i) -> void:
	if not is_painting() or _round_ended:
		return

	var stamp := GameState.run_time

	if not paint.claim(cell, team_of(steam.id), steam.id, stamp):
		return

	_my_tiles.append([cell, stamp])
	_pending_paint.append([cell, stamp])
	paint_changed.emit()


## Gives back the last few tiles this cube took, the price of dying. Only the
## ones still standing in our colour come off — anything painted over since
## belongs to whoever took it
func lose_tiles(count: int) -> void:
	if not is_painting():
		return

	var giving: Array = []

	while _my_tiles.size() > 0 and giving.size() < count:
		var last: Array = _my_tiles.pop_back()
		if paint.release(last[0] as Vector2i, steam.id, float(last[1])):
			giving.append(last)

	if giving.is_empty():
		return

	_broadcast([MSG_UNPAINT, giving], true)
	paint_changed.emit()


## While the cat is up, anybody on another side who comes within reach is told
## they have been caught.
##
## Only players on other teams. Running through your own side at speed is how a
## team covers ground, and a rainbow cube that took its own people out with it
## would make the item something you hope nobody on your team picks up
func _tick_hunt() -> void:
	if not _cat_is_up():
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var mine := team_of(steam.id)

	for id: int in runners:
		if id == steam.id or team_of(id) == mine:
			continue

		var runner: Dictionary = runners[id]
		if not bool(runner["placed"]) or bool(runner["dead"]):
			continue

		if player.global_position.distance_to(runner["position"] as Vector3) <= HIT_RANGE:
			_broadcast([MSG_HIT, id], true)


## True while the rainbow is running on this cube. Read off the item system
## rather than kept as a flag here, so it cannot say yes a moment after the
## effect has already let go
func _cat_is_up() -> bool:
	for effect: ItemEffect in ItemSystem.active_effects:
		if effect is RushEffect:
			return true

	return false


## Somebody caught this cube with the cat. The kill happens here, on the machine
## that owns the cube, rather than being asserted from the other end
func _handle_hit(message: Array) -> void:
	if message.size() < 2 or int(message[1]) != steam.id:
		return

	var death := get_tree().get_first_node_in_group("player_death") as PlayerDeath
	if death != null and not death.is_dead:
		death.kill(true)


## Scrubs a tile bare whoever painted it, and tells the others. Unlike giving
## back your own tiles this takes anybody's, so it carries no owner to check —
## the roller that did it has already earned the right by getting there
func erase_cell(cell: Vector2i) -> void:
	if not is_painting() or not paint.claims.has(cell):
		return

	paint.claims.erase(cell)
	_broadcast([MSG_ERASE, cell], true)
	paint_changed.emit()


func _handle_erase(message: Array) -> void:
	if message.size() < 2 or not paint.claims.has(message[1] as Vector2i):
		return

	paint.claims.erase(message[1] as Vector2i)
	paint_changed.emit()


## Puts a status on somebody else's cube. Their machine decides what it means
func send_status(account: int, effect: String, seconds: float) -> void:
	if is_racing():
		_broadcast([MSG_STATUS, account, effect, seconds], true)


func _handle_status(message: Array) -> void:
	if message.size() < 4 or int(message[1]) != steam.id:
		return

	Status.apply(String(message[2]), float(message[3]))


## Sends the tiles taken since the last tick, all in one message
func _tick_paint(delta: float) -> void:
	_paint_timer -= delta
	if _paint_timer > 0.0 or _pending_paint.is_empty():
		return

	_paint_timer = PAINT_RATE
	_broadcast([MSG_PAINT, team_of(steam.id), _pending_paint.duplicate()], true)
	_pending_paint.clear()


## Ends the round when the clock runs out. Every machine has its own copy of the
## same clock, started at the same moment, so nobody has to be told
func _tick_round() -> void:
	if _round_ended or round_left() > 0.0:
		return

	_round_ended = true
	GameState.is_running = false
	round_over.emit()


func _handle_paint(runner: Dictionary, message: Array) -> void:
	if message.size() < 3 or not (message[2] is Array):
		return

	var team := int(message[1])
	var changed := false

	for entry: Variant in message[2] as Array:
		if entry is Array and (entry as Array).size() >= 2:
			var pair := entry as Array
			changed = paint.claim(pair[0] as Vector2i, team, int(runner["id"]), \
				float(pair[1])) or changed

	if changed:
		paint_changed.emit()


func _handle_unpaint(runner: Dictionary, message: Array) -> void:
	if message.size() < 2 or not (message[1] is Array):
		return

	var changed := false

	for entry: Variant in message[1] as Array:
		if entry is Array and (entry as Array).size() >= 2:
			var pair := entry as Array
			changed = paint.release(pair[0] as Vector2i, int(runner["id"]), \
				float(pair[1])) or changed

	if changed:
		paint_changed.emit()


## What this cube is carrying, by name, empty for an open hand. It goes out with
## the counters so that watching somebody shows what they have to play with,
## which is half of what makes watching them worth anything
func _held_item() -> String:
	var item: ItemData = ItemSystem.held_item
	return item.display_name if item != null else ""


## Writes something into this machine's own runner. The local cube is not drawn
## as a ghost, but it is ranked alongside every other one
func _remember_local(values: Dictionary) -> void:
	var runner: Dictionary = runners.get(steam.id, {})
	if runner.is_empty():
		return

	for key: String in values:
		runner[key] = values[key]

	runner["seen_at"] = _now()


## Every message carries the account that sent it as its first value. Steam
## reports the sender alongside the packet as well, but under a key whose name
## has moved between versions — and reading the wrong one hands back a zero that
## matches nobody, so every packet is dropped and the race silently never syncs.
## Writing it into the payload costs eight bytes and cannot be got wrong
func _broadcast(message: Array, reliable: bool) -> void:
	var stamped: Array = [steam.id]
	stamped.append_array(message)
	var payload := var_to_bytes(stamped)

	for member in members:
		if member["id"] != steam.id:
			steam.send(member["id"], payload, reliable)
			_sent += 1


## Empties the packet queue. Anything malformed, or from an account this machine
## is not racing against, is dropped
func _receive() -> void:
	for payload: PackedByteArray in steam.receive():
		_received += 1

		var message: Variant = bytes_to_var(payload)
		if typeof(message) != TYPE_ARRAY or (message as Array).size() < 2:
			continue

		var parts := message as Array
		_handle(int(parts[0]), parts.slice(1))


## True for an account this machine should be listening to, taking it on board
## if it was missed.
##
## The runner list is built from the member list the moment the race starts, and
## that member list arrives over the network like everything else. A machine
## whose copy was one callback short at that exact moment would spend the whole
## race throwing away everything one player sent, and nothing would ever put it
## right — so a packet from somebody the lobby knows is reason enough
func _is_racer(sender: int) -> bool:
	if runners.has(sender):
		return true

	if not is_racing():
		return false

	for member in members:
		if int(member["id"]) == sender:
			_add_runner(member)
			return true

	return false


## Everything that decides whether this packet is ours to act on lives here
## rather than in the caller, so no route into it can reach the runner list with
## an account that is not in it
func _handle(sender: int, message: Array) -> void:
	if sender == steam.id or message.is_empty() or not _is_racer(sender):
		return

	var runner: Dictionary = runners[sender]
	runner["seen_at"] = _now()
	_failed_links.erase(sender)

	match int(message[0]):
		MSG_STATE:
			_handle_state(runner, message)
		MSG_PROGRESS:
			_handle_progress(runner, message)
		MSG_SAWS:
			_handle_saws(runner, message)
		MSG_PAINT:
			_handle_paint(runner, message)
		MSG_UNPAINT:
			_handle_unpaint(runner, message)
		MSG_HIT:
			_handle_hit(message)
		MSG_ERASE:
			_handle_erase(message)
		MSG_STATUS:
			_handle_status(message)


## Keeps the blade positions of every cube, so that whoever is watched can have
## their maze put on screen the moment somebody switches to them
func _handle_saws(runner: Dictionary, message: Array) -> void:
	if message.size() < 2 or not (message[1] is Array):
		return

	runner["saws"] = message[1]
	runner["saws_at"] = _now()


## A ghost is moved to where the packet says over the next frames rather than
## snapped there. The first packet is the exception, there is nothing to come
## from yet and the cube would otherwise slide in from the middle of the map
func _handle_state(runner: Dictionary, message: Array) -> void:
	if message.size() < 4:
		return

	runner["target"] = message[1] as Vector3
	runner["target_yaw"] = float(message[2])
	runner["dead"] = bool(message[3])

	if not bool(runner["placed"]):
		runner["placed"] = true
		runner["position"] = runner["target"]
		runner["yaw"] = runner["target_yaw"]


## A cube that has reported itself out stays out. The heartbeat repeats the
## finish for the rest of the race, so this arrives over and over — and a
## finished runner must never be walked backwards by a packet that overtook it
func _handle_progress(runner: Dictionary, message: Array) -> void:
	if message.size() < 6:
		return

	runner["deaths"] = int(message[1])
	runner["items"] = int(message[2])
	runner["has_key"] = bool(message[3])

	if message.size() > 6:
		runner["item"] = String(message[6])

	if bool(message[4]) and not bool(runner["finished"]):
		runner["finished"] = true
		runner["time"] = float(message[5])
		runner["has_key"] = true
		runner["dead"] = false

	standings_updated.emit()


## A cube that has said nothing for a while is off the map. Its ranking stays,
## only the ghost goes: a player who alt tabbed into a crash should not keep
## sliding along the last corridor they were seen in
func _drop_stale_ghosts() -> void:
	var now := _now()

	for id: int in runners:
		var runner: Dictionary = runners[id]
		if bool(runner["placed"]) and now - float(runner["seen_at"]) > GHOST_TIMEOUT:
			runner["placed"] = false


## The elevator carried this cube out. The summary panel stays down in a race,
## the standings take its place.
##
## Nothing is sent from here. The finish is written into this machine's own
## runner and the heartbeat carries it out on the next tick and every tick after
## that, which is what makes it survive a line that stuttered at the wrong moment
func _on_run_finished() -> void:
	if not is_racing():
		return

	_remember_local({
		"finished": true,
		"time": GameState.run_time,
		"deaths": GameState.deaths,
		"items": GameState.items_collected,
	})

	_progress_timer = 0.0
	standings_updated.emit()


func _reset() -> void:
	phase = Phase.OFFLINE
	lobby_id = 0
	is_host = false
	race_seed = 0
	_level = null
	_acted_round = 0
	members.clear()
	runners.clear()
	_sent_progress.clear()
	paint.clear()
	teams.clear()
	team_colors.clear()
	spawns.clear()
	_respawn_pool.clear()
	_last_respawn = Vector2i(-1, -1)
	_my_tiles.clear()
	_pending_paint.clear()
	_round_ended = false
	_sent = 0
	_received = 0
	_hello_timer = 0.0
	_progress_timer = 0.0
	_saw_timer = 0.0
	_failed_links.clear()


func _now() -> float:
	return float(Time.get_ticks_msec()) * 0.001
