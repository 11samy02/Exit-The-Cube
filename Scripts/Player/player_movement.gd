extends Node
class_name PlayerMovement

## The body that actually gets moved
@export var body: CharacterBody3D

## Pivot the input is rotated by, so WASD always follows the camera
@export var camera_pivot: Node3D

## Top speed in world units per second
@export var max_speed: float = 6.0

## How fast the cube reaches max_speed
@export var acceleration: float = 40.0

## How fast the cube comes to a stop again
@export var friction: float = 55.0

## Downward acceleration while the cube is in the air
@export var gravity: float = 24.0

## Horizontal speed of this frame, read by the animation
var current_speed: float = 0.0

## Last direction the player actually moved in, read by the animation
var facing_direction: Vector3 = Vector3.FORWARD

## True while a movement input is held down
var is_moving: bool = false

## Scales speed and acceleration, everything the running items add up to. Read
## only, it is rebuilt whenever one of them comes or goes
var speed_multiplier: float = 1.0

## What each running item adds, by whoever set it. Two of them at once put their
## bonuses together instead of the later one wiping out the earlier: a cube on
## the cat's 1.4 that picks up a 1.3 off the speed item runs at 1.7, not at
## either of the two on its own
var _boosts: Dictionary = {}

## False while something else owns the cube, the spawn animation holds it here.
## Gravity and collision keep running, only the input is ignored
var input_enabled: bool = true


## Puts that item's boost up. The same source setting it again replaces its own
## share, so an item that is picked up twice does not count twice
func set_boost(source: StringName, multiplier: float) -> void:
	_boosts[source] = multiplier
	_rebuild_speed()


func clear_boost(source: StringName) -> void:
	_boosts.erase(source)
	_rebuild_speed()


## Only what an item adds over the plain cube is summed up, so two boosts of
## 1.4 and 1.3 land on 1.7 instead of the 1.82 a plain multiplication gives
func _rebuild_speed() -> void:
	var total := 1.0
	for multiplier in _boosts.values():
		total += float(multiplier) - 1.0

	speed_multiplier = maxf(total, 0.1)


## Freezes the cube where it stands, used when the elevator takes over
func disable() -> void:
	body.velocity = Vector3.ZERO
	current_speed = 0.0
	is_moving = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var direction := _get_input_direction()
	is_moving = direction != Vector3.ZERO

	if is_moving:
		facing_direction = direction
		var speed := max_speed * speed_multiplier
		var pickup := acceleration * speed_multiplier * delta
		body.velocity.x = move_toward(body.velocity.x, direction.x * speed, pickup)
		body.velocity.z = move_toward(body.velocity.z, direction.z * speed, pickup)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, friction * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, friction * delta)

	if body.is_on_floor():
		body.velocity.y = minf(body.velocity.y, 0.0)
	else:
		body.velocity.y -= gravity * delta

	current_speed = Vector2(body.velocity.x, body.velocity.z).length()
	body.move_and_slide()


## Reads WASD / left stick and turns it into a flat world direction
## that points where the camera is looking
func _get_input_direction() -> Vector3:
	if not input_enabled:
		return Vector3.ZERO

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input == Vector2.ZERO:
		return Vector3.ZERO

	var basis := camera_pivot.global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	return (right * input.x - forward * input.y).normalized()
