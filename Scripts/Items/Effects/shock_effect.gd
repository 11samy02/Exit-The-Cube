extends ItemEffect
class_name ShockEffect

## A jolt that goes out in a ring and leaves everybody else in it unsteady.
##
## Only players on other sides, and only once each: it is a burst, not a field
## to stand in. What it does to them is decided by the status it sends, not here

## How far the ring reaches, in meters
@export var radius: float = 12.0

## What it leaves on whoever it catches, and for how long
@export var effect: String = "woozy"
@export var seconds: float = 6.0


func _start() -> void:
	show_vignette(0.8)

	if not Online.is_painting() or player == null:
		stop(false)
		return

	var mine := Online.team_of(Online.steam.id)

	for id: int in Online.runners:
		if id == Online.steam.id or Online.team_of(id) == mine:
			continue

		var runner: Dictionary = Online.runners[id]
		if not bool(runner["placed"]) or bool(runner["dead"]):
			continue

		if player.global_position.distance_to(runner["position"] as Vector3) <= radius:
			Online.send_status(id, effect, seconds)

	stop(false)
