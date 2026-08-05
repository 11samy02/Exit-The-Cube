class_name CoopCoordinator
extends Node

## What a death costs when the level is being played by a room rather than by
## one person.
##
## On your own a death is the level: the map is torn down and put back up. That
## cannot be what happens in co-op, because it would take the level away from
## everybody still standing in it — so a cube that bursts sits out five seconds
## and is put back where the room came in, and the level is only rebuilt when
## nobody is left to play it.
##
## Whether a death costs five seconds or the whole level is not the dying cube's
## to decide. It depends on the other three, and only something that can see all
## of them can answer it, which is why the clock lives here rather than in the
## cube that burst

## Put in a group so a cube and the elevator can find it without a path
const GROUP := &"coop"

## Seconds a cube sits out before it is put back at the shared spawn
const RESPAWN_SECONDS := 5.0

## Seats that are down right now, to seconds left on each
var _down: Dictionary = {}

## True from the moment the level is being rebuilt, nothing reacts after that
var _wiping: bool = false


func _ready() -> void:
	add_to_group(GROUP)


static func find(tree: SceneTree) -> CoopCoordinator:
	return tree.get_first_node_in_group(GROUP) as CoopCoordinator


## A cube burst. Everybody being down at once is the level lost, and it needs no
## window of its own to notice: the last cube to burst is by definition inside
## everybody else's five seconds
func report_death(seat: int) -> void:
	if _wiping or _down.has(seat):
		return

	_down[seat] = RESPAWN_SECONDS

	if _down.size() >= Seats.count():
		_wipe()


## Seconds until that cube is back, 0 while it is standing
func down_for(seat: int) -> float:
	return float(_down.get(seat, 0.0))


func is_down(seat: int) -> bool:
	return _down.has(seat)


## True while every seat is on its feet. The elevator asks before it leaves, a
## cube four seconds from coming back would have the level ended without it.
##
## A wipe empties the list on its way out, so it has to be asked about as well —
## during one there is nobody standing at all, the level is being rebuilt
func everyone_alive() -> bool:
	return _down.is_empty() and not _wiping


## Counts every wait down and starts the entrance early enough that the number
## reaching zero and the player getting the cube back are the same moment. The
## spawn animation takes about a second, and without the lead the countdown is
## a lie by exactly that much
func _process(delta: float) -> void:
	if _wiping or _down.is_empty():
		return

	for seat: int in _down.keys():
		_down[seat] = float(_down[seat]) - delta

		var cube := Player.at_seat(get_tree(), seat)
		var lead := cube.spawn.entrance_lead() if cube != null else 0.0

		if float(_down[seat]) <= lead:
			_down.erase(seat)
			_revive(seat)


## Puts one cube back on its feet where the room came in.
##
## Whatever it was carrying goes with the death. An effect hangs on the player
## and used to be swept away by the rebuild the death caused; in here the cube
## survives its own death, so a shield spent on the saw that killed you would
## still be running when you came back
func _revive(seat: int) -> void:
	var cube := Player.at_seat(get_tree(), seat)
	if cube == null:
		return

	cube.inventory.stop_all(true)
	cube.inventory.grant(null)
	cube.death.is_dead = false
	cube.spawn.respawn()


## Nobody is left standing. This is the one death that still costs the level
func _wipe() -> void:
	_wiping = true
	_down.clear()
	Transition.reload_scene()
