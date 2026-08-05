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

const LOBBY_SCENE := "res://Scenes/Ui/lobby_screen.tscn"


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

## Where one of the host's CPUs is and how its run is going, in one message.
##
## It has to name the cube it is about, because the sender is the host and not
## the runner — which is also the only authority check there is on it: a packet
## about a bot that did not come from whoever owns the lobby is dropped. And it
## carries the whole runner rather than splitting position from progress, since
## a bot has no input lag to hide and nothing to gain from the finer rate
const MSG_BOT := 11

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

## What carries a local change out to the others. Handed to the router when the
## race starts, so the round itself never learns there is a wire under it
var wire := Wire.new()

## Seconds until the next ghost packet goes out
var _send_timer: float = 0.0

## Seconds until the counters go out again whether they moved or not
var _progress_timer: float = 0.0

## Seconds until the nearby blade positions go out again
var _saw_timer: float = 0.0

## Claims waiting to go out together on the next tick
var _pending_paint: Array = []

var _paint_timer: float = 0.0

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


## The wire under an online round.
##
## The router hands every change one of our cubes makes to a transport, and a
## round played on one screen simply has none — that is the whole of what makes
## the party mode the same code as this one. Everything in here is one line: the
## deciding already happened, this only carries it out
class Wire extends MatchTransport:
	var line: Node = null

	func send_paint(_account: int, cell: Vector2i, stamp: float) -> void:
		line.queue_paint(cell, stamp)

	func send_unpaint(_account: int, tiles: Array) -> void:
		line.push_unpaint(tiles)

	func send_erase(cell: Vector2i) -> void:
		line.push_erase(cell)

	func send_status(account: int, effect: String, seconds: float) -> void:
		line.push_status(account, effect, seconds)

	func send_hit(account: int) -> void:
		line.push_hit(account)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	wire.line = self
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

	if Match.is_painting():
		_tick_paint(delta)


## Opens a lobby with this machine as its host
func host_lobby() -> void:
	if not steam.running:
		return

	settings = default_rules()
	steam.create_lobby(MAX_PLAYERS)


## What a fresh lobby is set to. The rules of the round come out of the rulebook
## and the two about the CPUs are added here, because a lobby is the one place
## they may be changed while people are already in it
func default_rules() -> Dictionary:
	var rules := RaceRules.default_settings()
	rules[Bots.COUNT_KEY] = 0
	rules[Bots.SKILL_KEY] = Bots.default_skill()
	return rules


## Every setting a lobby carries, which is what is written to it and read back
func _rule_keys() -> Array:
	return default_rules().keys()


func join_lobby(lobby: int) -> void:
	if steam.running:
		steam.join_lobby(lobby)


## Steps out of the lobby and closes every session it opened. A host leaving
## hands the lobby to somebody else, Steam picks who
func leave_lobby() -> void:
	if lobby_id != 0:
		for member in members:
			steam.close_session(int(member["id"]))

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
	Match.stop()
	GameState.is_running = false
	set_ready(false)
	Transition.change_scene(LOBBY_SCENE)


## Which race the lobby is on, 0 before the first one
func _round() -> int:
	var value := steam.lobby_data(lobby_id, ROUND_KEY)
	return int(value) if not value.is_empty() else 0


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
	for key: String in _rule_keys():
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
	var runners := Match.runners()
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


## Hands the round over to the router and walks into the maze. Everything about
## the rules from here on is the router's — this node only carries the traffic
func _enter_race() -> void:
	if phase == Phase.RACING:
		return

	phase = Phase.RACING
	set_process(true)
	_send_timer = 0.0
	_paint_timer = 0.0
	_pending_paint.clear()
	_sent_progress.clear()
	_refresh_members()

	var accounts: Array[int] = []
	for member in members:
		accounts.append(int(member["id"]))

	var bots := Bots.count_in(settings, members.size())
	accounts.append_array(Bots.accounts_for(bots))

	Match.start_online(settings, race_seed, accounts, steam.id, wire,
		Bots.accounts_for(bots) if is_host else [] as Array[int])

	for member in members:
		Match.session.runners[member["id"]]["name"] = member["name"]

	set_ready(false)

	Levels.stop()
	GameState.is_running = false
	GameState.start_run()
	Quips.say_next(Quips.pick("online_race_start", OnlineQuips.RACE_START))

	race_launched.emit()
	Transition.change_scene(Match.MAP_SCENE)


## Where this cube is, sent to everybody else. The router keeps the local runner
## current every frame, so this only has to read it — and a map that is between
## two rebuilds has no cube to read, which is when nothing goes out
func _send_local_state() -> void:
	var me: Dictionary = Match.runners().get(steam.id, {})
	if me.is_empty() or not bool(me["placed"]):
		return

	_broadcast([MSG_STATE, me["position"], me["yaw"], me["dead"]], false)
	_send_bot_state()


## The host's own CPUs, sent alongside its cube. Nobody else runs them, so if
## this stops they stand still on every other screen in the race
func _send_bot_state() -> void:
	if not is_host:
		return

	for account in Match.local_accounts():
		var bot: Dictionary = Match.runners().get(account, {})
		if bot.is_empty() or not bool(bot["placed"]) or not Bots.is_bot_account(account):
			continue

		_broadcast([MSG_BOT, account, bot["position"], bot["yaw"], bot["dead"],
			int(bot["deaths"]), int(bot["items"]), bool(bot["has_key"]),
			bool(bot["finished"]), float(bot["time"])], false)


## The counters, sent whenever one of them moved and once a second regardless.
##
## The heartbeat is what makes the board self healing. Sending only on change is
## enough right up until one of those packets is the one that goes missing, and
## the counter it carried is then wrong on somebody else's screen for the rest
## of the race with nothing left to correct it
func _send_local_progress(delta: float) -> void:
	var me: Dictionary = Match.runners().get(steam.id, {})
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
	Match.standings_updated.emit()


## Where the blades around this cube are, by their place in the spawn order.
##
## The order is the same on every machine because the level was built from the
## same seed, so an index and a position is all a watcher needs to move its own
## copy of that blade to where this player sees it. Sending every blade would be
## two hundred positions on a gigantic map; the ones out of sight are the ones
## nobody watching this cube could see anyway
func _send_local_saws() -> void:
	var player := Player.at_seat(get_tree(), 0)
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


## One tile taken by our cube, held back until the next tick so that a run
## across a room is one packet rather than a dozen
func queue_paint(cell: Vector2i, stamp: float) -> void:
	_pending_paint.append([cell, stamp])


func push_unpaint(tiles: Array) -> void:
	_broadcast([MSG_UNPAINT, tiles], true)


func push_erase(cell: Vector2i) -> void:
	_broadcast([MSG_ERASE, cell], true)


func push_status(account: int, effect: String, seconds: float) -> void:
	_broadcast([MSG_STATUS, account, effect, seconds], true)


func push_hit(account: int) -> void:
	_broadcast([MSG_HIT, account], true)


## Somebody caught this cube with the cat. The kill happens here, on the machine
## that owns the cube, rather than being asserted from the other end
func _handle_hit(message: Array) -> void:
	if message.size() < 2 or not Match.is_local(int(message[1])):
		return

	Match.report_hit(int(message[1]))


func _handle_erase(message: Array) -> void:
	if message.size() < 2 or Match.session == null:
		return

	if Match.session.erase(message[1] as Vector2i):
		Match.paint_changed.emit()


func _handle_status(message: Array) -> void:
	if message.size() < 4 or not Match.is_local(int(message[1])):
		return

	Match.send_status(int(message[1]), String(message[2]), float(message[3]))


## Sends the tiles taken since the last tick, all in one message
func _tick_paint(delta: float) -> void:
	_paint_timer -= delta
	if _paint_timer > 0.0 or _pending_paint.is_empty():
		return

	_paint_timer = PAINT_RATE
	_broadcast([MSG_PAINT, Match.team_of(steam.id), _pending_paint.duplicate()], true)
	_pending_paint.clear()


func _handle_paint(runner: Dictionary, message: Array) -> void:
	if message.size() < 3 or not (message[2] is Array) or Match.session == null:
		return

	var team := int(message[1])
	var changed := false

	for entry: Variant in message[2] as Array:
		if entry is Array and (entry as Array).size() >= 2:
			var pair := entry as Array
			changed = Match.session.claim_for(pair[0] as Vector2i, team, int(runner["id"]), \
				float(pair[1])) or changed

	if changed:
		Match.paint_changed.emit()


func _handle_unpaint(runner: Dictionary, message: Array) -> void:
	if message.size() < 2 or not (message[1] is Array) or Match.session == null:
		return

	var changed := false

	for entry: Variant in message[1] as Array:
		if entry is Array and (entry as Array).size() >= 2:
			var pair := entry as Array
			changed = Match.session.release_for(pair[0] as Vector2i, int(runner["id"]), \
				float(pair[1])) or changed

	if changed:
		Match.paint_changed.emit()


## What this cube is carrying, by name, empty for an open hand. It goes out with
## the counters so that watching somebody shows what they have to play with,
## which is half of what makes watching them worth anything
func _held_item() -> String:
	var item: ItemData = ItemSystem.held_item
	return item.display_name if item != null else ""


## Writes something into this machine's own runner. The local cube is not drawn
## as a ghost, but it is ranked alongside every other one
func _remember_local(values: Dictionary) -> void:
	if Match.session != null:
		Match.session.remember(steam.id, values)


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
	if Match.session == null:
		return false

	if Match.session.runners.has(sender):
		return true

	if not is_racing():
		return false

	for member in members:
		if int(member["id"]) == sender:
			Match.session.add_runner(sender, String(member["name"]))
			return true

	return false


## Everything that decides whether this packet is ours to act on lives here
## rather than in the caller, so no route into it can reach the runner list with
## an account that is not in it
func _handle(sender: int, message: Array) -> void:
	if sender == steam.id or message.is_empty() or not _is_racer(sender):
		return

	var runner: Dictionary = Match.session.runners[sender]
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
		MSG_BOT:
			_handle_bot(sender, message)


## One of the host's CPUs, as the host last saw it.
##
## The packet names the cube instead of the sender being it, so this is the one
## handler that has to check who is talking: only the machine that owns the
## lobby runs the bots, and a packet about one from anybody else is somebody
## trying to drive a cube that is not theirs
func _handle_bot(sender: int, message: Array) -> void:
	if message.size() < 10 or lobby_id == 0 or sender != steam.lobby_owner(lobby_id):
		return

	var account := int(message[1])
	if not Bots.is_bot_account(account) or not Match.session.runners.has(account):
		return

	var bot: Dictionary = Match.session.runners[account]
	bot["target"] = message[2] as Vector3
	bot["target_yaw"] = float(message[3])
	bot["dead"] = bool(message[4])
	bot["deaths"] = int(message[5])
	bot["items"] = int(message[6])
	bot["has_key"] = bool(message[7])
	bot["seen_at"] = _now()

	if not bool(bot["placed"]):
		bot["placed"] = true
		bot["position"] = bot["target"]
		bot["yaw"] = bot["target_yaw"]

	if bool(message[8]) and not bool(bot["finished"]):
		bot["finished"] = true
		bot["time"] = float(message[9])
		bot["has_key"] = true


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

	Match.standings_updated.emit()


## A cube that has said nothing for a while is off the map. Its ranking stays,
## only the ghost goes: a player who alt tabbed into a crash should not keep
## sliding along the last corridor they were seen in
func _drop_stale_ghosts() -> void:
	var runners := Match.runners()
	var now := _now()

	for id: int in runners:
		if id == steam.id:
			continue

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
	Match.standings_updated.emit()


func _reset() -> void:
	phase = Phase.OFFLINE
	lobby_id = 0
	is_host = false
	race_seed = 0
	_acted_round = 0
	members.clear()
	Match.stop()
	_sent_progress.clear()
	_pending_paint.clear()
	_sent = 0
	_received = 0
	_hello_timer = 0.0
	_progress_timer = 0.0
	_saw_timer = 0.0
	_failed_links.clear()


func _now() -> float:
	return float(Time.get_ticks_msec()) * 0.001
