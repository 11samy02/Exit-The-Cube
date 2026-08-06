extends ItemEffect
class_name ShockEffect

## A jolt that goes through the whole floor and leaves every other side unsteady.
##
## It does not travel and it is not a field to stand in. The maze is one floor
## and this is a shock through it: everybody on another side gets it at once,
## wherever they are standing. A jolt that only reached the corridor it was let
## off in was an item you had to be lucky to be able to use at all

## How far the jolt carries, in meters. 0 or under is the whole floor, which is
## what it is set to — the number is here for tuning it back down
@export var reach: float = 0.0

## What it leaves on whoever it catches, and for how long
@export var effect: String = "woozy"
@export var seconds: float = 4.0

@export_group("Going off")

## How wide the shock is drawn around the cube that let it off, in meters
@export var burst_reach: float = 16.0

## How many rings it goes out as, and the gap between them
@export var burst_rings: int = 4
@export var burst_delay: float = 0.07

## Seconds one of those rings takes to run out
@export var burst_time: float = 0.7

## Colour of the shock itself
@export var burst_color: Color = Color(0.65, 0.45, 1.0)


func _start() -> void:
	if not Match.is_painting() or player == null:
		stop(false)
		return

	_go_off()
	_jolt_the_others()
	stop(false)


## What it looks like from the outside. The rings are thrown wide and left
## behind: the effect itself is spent the same frame it is used, so nothing that
## has to still be on screen a moment later may hang off it
func _go_off() -> void:
	var holder := player.get_parent()
	if holder == null:
		return

	for at in range(maxi(burst_rings, 1)):
		var ring := BurstRing.burst(holder, player.global_position, burst_color,
			burst_reach * (0.45 + 0.55 * float(at) / float(maxi(burst_rings - 1, 1))),
			burst_time, at % 2 == 1, burst_delay * at)
		claim(ring)


## Everybody on another side, told they have been caught. Only other teams: a
## jolt that took your own people out with it would be an item you hope nobody
## on your side picks up
func _jolt_the_others() -> void:
	var me := player.account()
	var mine := Match.team_of(me)
	var runners := Match.runners()

	for id: int in runners:
		if id == me or Match.team_of(id) == mine:
			continue

		var runner: Dictionary = runners[id]
		if not bool(runner["placed"]) or bool(runner["dead"]) or bool(runner["finished"]):
			continue

		if reach > 0.0 \
				and player.global_position.distance_to(runner["position"] as Vector3) > reach:
			continue

		Match.send_status(id, effect, seconds)
