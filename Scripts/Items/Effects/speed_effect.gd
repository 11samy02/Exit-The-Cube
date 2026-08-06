extends ItemEffect
class_name SpeedEffect

## The cube runs harder while every blade in the level takes it easier. Nothing
## here protects the player, the level only stops being quite as fast as it was

## How much faster the cube runs while this is up
@export var player_multiplier: float = 1.3

## What the saws are left of their speed
@export_range(0.1, 1.0) var saw_multiplier: float = 0.85

## The colour of the air torn up behind the cube
@export var wind_color: Color = Color(0.6, 0.9, 1.0)

var movement: PlayerMovement = null

## The streaks blowing out behind the cube, taken down with the item
var wind: WindTrail = null

## The saws that were slowed, kept so exactly those are put back
var slowed: Array[SawMover] = []


func _start() -> void:
	movement = player.movement if player != null else null
	if movement != null:
		movement.set_boost(&"speed", player_multiplier)

	if player != null:
		wind = WindTrail.attach_to(player, wind_color)
		claim(wind)

	for node in get_tree().get_nodes_in_group("saw_mover"):
		var mover := node as SawMover
		if mover == null:
			continue

		mover.speed_multiplier = saw_multiplier
		slowed.append(mover)


func _stop(_cancelled: bool) -> void:
	if is_instance_valid(movement):
		movement.clear_boost(&"speed")

	for mover in slowed:
		if is_instance_valid(mover):
			mover.speed_multiplier = 1.0

	slowed.clear()

	if is_instance_valid(wind):
		wind.fade_out()
