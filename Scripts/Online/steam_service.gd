class_name SteamService
extends RefCounted

## The only place in the game that talks to Steamworks. Everything else goes
## through here, which buys two things.
##
## The first is that the game runs without Steam at all. The extension may be
## missing, the client may be shut, the build may be a copy somebody unzipped —
## in every one of those cases this object comes up unavailable and every call
## on it quietly does nothing. Nothing else has to check, and the campaign never
## learns that online exists.
##
## The second is that GodotSteam has changed the shape of a few of its calls
## between versions. Reaching for the singleton by name and asking whether it
## has a method keeps that in one file instead of spread over the lobby code

## The lobby is listed publicly, anybody may find it in the browser
const LOBBY_TYPE_PUBLIC := 2

## Filter comparison: the value has to match exactly
const COMPARE_EQUAL := 0

## Search the whole world rather than the same city
const DISTANCE_WORLDWIDE := 3

## Packets that may be dropped, used for the ghost positions. One lost frame of
## a cube twenty corridors away is worth less than the delay of resending it
const SEND_UNRELIABLE := 0

## Packets that have to arrive, used for everything that is counted
const SEND_RELIABLE := 2

## The channel all game traffic runs on
const CHANNEL := 0

## Everyone on the friends list, which is what Steam calls an immediate friend
const FRIEND_FLAG_IMMEDIATE := 4

## The persona state of somebody who is not signed in
const PERSONA_OFFLINE := 0

## The Steamworks singleton, null when the extension did not load
var api: Object = null

## True once the API came up and handed out an account. Everything below is a
## no-op while this is false
var running: bool = false

## The account this machine is signed in as, 0 while Steam is not running
var id: int = 0

## What went wrong, for the screen that has to tell the player about it
var error: String = ""


func _init() -> void:
	if Engine.has_singleton("Steam"):
		api = Engine.get_singleton("Steam")


## True when the extension loaded at all. A build without it is not broken, it
## simply has no online button that does anything
func available() -> bool:
	return api != null


## Brings Steamworks up. The app id is taken from steam_appid.txt beside the
## executable, or from the client when the game was launched through Steam,
## which is why nothing is passed in here: the older and the newer GodotSteam
## read the arguments of this call differently and the file works for both
func start() -> bool:
	if running:
		return true

	if api == null:
		error = "the Steam extension is not installed in this build"
		return false

	if api.has_method("isSteamRunning") and not bool(api.call("isSteamRunning")):
		error = "Steam is not running, start the client and try again"
		return false

	var report: Variant = null

	if api.has_method("steamInitEx"):
		report = api.call("steamInitEx")
	elif api.has_method("steamInit"):
		report = api.call("steamInit")

	id = int(api.call("getSteamID")) if api.has_method("getSteamID") else 0
	running = id != 0
	error = "" if running else _verbal(report)
	return running


## What Steamworks said about the failure, in its own words where it gave any.
## Whichever GodotSteam this is built against, the report comes back as a
## dictionary with a line in it meant to be read by a person
func _verbal(report: Variant) -> String:
	if typeof(report) == TYPE_DICTIONARY:
		var said := String((report as Dictionary).get("verbal", ""))
		if not said.is_empty():
			return said.to_lower()

	return "Steam would not start up, check that the client is signed in"


## Steamworks hands its answers back through callbacks that only fire while they
## are being pumped. Without this every signal below stays silent
func poll() -> void:
	if running and api.has_method("run_callbacks"):
		api.call("run_callbacks")


## Wires one Steamworks signal, quietly ignoring one this version does not have
func listen(signal_name: StringName, handler: Callable) -> void:
	if api == null or not api.has_signal(signal_name):
		return

	if not api.is_connected(signal_name, handler):
		api.connect(signal_name, handler)


## The name that account goes by. Falls back to the raw id so a player who has
## not been fetched yet still shows up as somebody rather than as nothing
func persona(account: int) -> String:
	if account == id:
		return String(_ask("getPersonaName", [], ""))

	var name := String(_ask("getFriendPersonaName", [account], ""))
	return name if not name.is_empty() else "CUBE %d" % (account % 10000)


func create_lobby(max_members: int) -> void:
	_do("createLobby", [LOBBY_TYPE_PUBLIC, max_members])


func join_lobby(lobby: int) -> void:
	_do("joinLobby", [lobby])


func leave_lobby(lobby: int) -> void:
	_do("leaveLobby", [lobby])


func lobby_owner(lobby: int) -> int:
	return int(_ask("getLobbyOwner", [lobby], 0))


func member_count(lobby: int) -> int:
	return int(_ask("getNumLobbyMembers", [lobby], 0))


func member_at(lobby: int, at: int) -> int:
	return int(_ask("getLobbyMemberByIndex", [lobby, at], 0))


func set_lobby_data(lobby: int, key: String, value: String) -> void:
	_do("setLobbyData", [lobby, key, value])


func lobby_data(lobby: int, key: String) -> String:
	return String(_ask("getLobbyData", [lobby, key], ""))


## Member data is written for this account only, every other machine in the
## lobby reads it back through member_data
func set_member_data(lobby: int, key: String, value: String) -> void:
	_do("setLobbyMemberData", [lobby, key, value])


func member_data(lobby: int, member: int, key: String) -> String:
	return String(_ask("getLobbyMemberData", [lobby, member, key], ""))


## Asks for every open lobby of this game. The answer arrives on the
## lobby_match_list signal rather than from this call
func request_lobbies(tag_key: String, tag_value: String) -> void:
	_do("addRequestLobbyListDistanceFilter", [DISTANCE_WORLDWIDE])
	_do("addRequestLobbyListStringFilter", [tag_key, tag_value, COMPARE_EQUAL])
	_do("requestLobbyList", [])


## Takes the lobby off the browser and turns invites away, used while a race is
## running. A cube that walked in halfway through a maze it never got the seed
## for would only stand in the start corridor
func set_joinable(lobby: int, joinable: bool) -> void:
	_do("setLobbyJoinable", [lobby, joinable])


## True while Steam's own overlay is loaded into this process. It only is when
## the game was started through Steam — a build run straight off the disk, or out
## of the editor, has no overlay at all, and every call that opens one quietly
## does nothing
func overlay_enabled() -> bool:
	return bool(_ask("isOverlayEnabled", [], false))


## Opens the Steam overlay on the invite dialog of that lobby
func invite_overlay(lobby: int) -> void:
	_do("activateGameOverlayInviteDialog", [lobby])


## Sends one friend an invite to that lobby without going through the overlay.
## This is the path that works whatever the game was started from
func invite_to_lobby(lobby: int, friend: int) -> void:
	_do("inviteUserToLobby", [lobby, friend])


## The whole friends list, the ones who are signed in first and each group by
## name. Steam sorts by nothing in particular, and a list of thirty names with
## the four that could actually be invited scattered through it is a list nobody
## reads to the end
func friends() -> Array:
	var found: Array = []
	var count := int(_ask("getFriendCount", [FRIEND_FLAG_IMMEDIATE], 0))

	for at in range(count):
		var id := int(_ask("getFriendByIndex", [at, FRIEND_FLAG_IMMEDIATE], 0))
		if id == 0:
			continue

		found.append({
			"id": id,
			"name": String(_ask("getFriendPersonaName", [id], "")),
			"online": int(_ask("getFriendPersonaState", [id], 0)) != PERSONA_OFFLINE,
		})

	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["online"]) != bool(b["online"]):
			return bool(a["online"])

		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)

	return found


func send(target: int, payload: PackedByteArray, reliable: bool) -> void:
	var kind := SEND_RELIABLE if reliable else SEND_UNRELIABLE
	_do("sendP2PPacket", [target, payload, kind, CHANNEL])


## Everything that arrived since the last call, oldest first. Each entry is
## whatever readP2PPacket handed back: the sender and the bytes
func receive() -> Array:
	var packets: Array = []
	if not running:
		return packets

	var size := int(_ask("getAvailableP2PPacketSize", [CHANNEL], 0))

	while size > 0:
		var packet: Dictionary = _ask("readP2PPacket", [size, CHANNEL], {})
		if packet.is_empty():
			break

		packets.append(packet)
		size = int(_ask("getAvailableP2PPacketSize", [CHANNEL], 0))

	return packets


func accept_session(account: int) -> void:
	_do("acceptP2PSessionWithUser", [account])


func close_session(account: int) -> void:
	_do("closeP2PSessionWithUser", [account])


## Calls a Steamworks method and throws the answer away
func _do(method: StringName, args: Array) -> void:
	if running and api.has_method(method):
		api.callv(method, args)


## Calls a Steamworks method that answers, with a fallback for the versions
## that never had it
func _ask(method: StringName, args: Array, fallback: Variant) -> Variant:
	if not running or not api.has_method(method):
		return fallback

	var answer: Variant = api.callv(method, args)
	return answer if answer != null else fallback
