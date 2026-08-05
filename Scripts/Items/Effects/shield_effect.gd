extends ItemEffect
class_name ShieldEffect

## The cube stops being the softer of the two. A blade it runs into is taken out
## of the level for the rest of the attempt, and the cube leaves its color on
## the spot, so the wrecks read as a tally of what this run has already cleared

var death: PlayerDeath = null

## True once a blade has been broken, the shield is spent with it
var _used: bool = false


func _start() -> void:
	show_vignette(0.85)
	death = player.death if player != null else null
	if death == null:
		return

	death.set_guard(&"shield", true)
	death.saw_broken.connect(_on_saw_broken)


## One blade per heart. The item does not run out on a timer if it is used, it
## ends the moment it was needed
func _on_saw_broken() -> void:
	_used = true
	stop(false)


## A cube standing in a blade when the shield runs out is cut like any other,
## the saw has already reported its touch and will not report it a second time.
## A shield that was spent on a blade is exempt: that saw is gone, and being cut
## in the same instant it broke would read as the item having failed
func _stop(cancelled: bool) -> void:
	if not is_instance_valid(death):
		return

	death.clear_guard(&"shield")

	if not cancelled and not _used:
		_kill_if_still_inside_a_saw()


func _kill_if_still_inside_a_saw() -> void:
	if not is_instance_valid(player):
		return

	for node in get_tree().get_nodes_in_group("saw"):
		var saw := node as Area3D
		if saw == null or not saw.monitoring:
			continue

		if saw.get_overlapping_bodies().has(player):
			death.kill()
			return
