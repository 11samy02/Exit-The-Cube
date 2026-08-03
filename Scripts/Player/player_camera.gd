extends Node
class_name PlayerCamera

## Pivot the camera orbits around, gets the yaw and the pitch
@export var pivot: Node3D

## Arm that only probes for walls, its length is the furthest the camera may sit
@export var spring_arm: SpringArm3D

## Camera slid along the arm by hand instead of being parented to it
@export var camera: Camera3D

## The player body, excluded from the spring arm collision test
@export var body: CharacterBody3D

## Degrees per pixel of mouse movement, the options scale this
@export var mouse_sensitivity: float = 0.16

## Degrees per second at full right stick deflection, the options scale this
@export var stick_sensitivity: float = 220.0

## How far the camera may look down
@export var min_pitch: float = -70.0

## How far the camera may look up
@export var max_pitch: float = 55.0

## How many spots along the arm are tried before the camera gives up and slides
## in against the wall instead. More is a finer search and a shape test each
@export var probe_steps: int = 7

## The closest any of those spots may be, past this the camera is on top of the
## cube and the arm decides on its own
@export var min_probe_distance: float = 1.2

## Units per second the camera slides in while a wall pushes against it
@export var pull_in_speed: float = 12.0

## Units per second the camera slides back out once a wall let go of it
@export var return_speed: float = 5.0

## Directions tried when the camera looks for room around the player
@export var clearance_samples: int = 24

## How much more room another direction has to offer before the camera turns to
## it, keeps a view that is already fine from being nudged around
@export var clearance_tolerance: float = 0.4

## Distance the camera keeps when nothing is in the way, set by the perspective
var desired_distance: float = 0.0

var yaw: float = 0.0
var pitch: float = -12.0
var clearance: float = 0.0


func _ready() -> void:
	spring_arm.add_excluded_object(body.get_rid())
	yaw = rad_to_deg(pivot.global_rotation.y)
	desired_distance = spring_arm.spring_length
	clearance = spring_arm.spring_length
	process_physics_priority = 10
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_rotation()


func _process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look == Vector2.ZERO:
		return

	var speed := stick_sensitivity * Settings.controller_sensitivity
	yaw -= look.x * speed * delta
	pitch -= look.y * speed * delta
	_apply_rotation()


## Late priority so the wall probe of this frame is already done
func _physics_process(delta: float) -> void:
	_update_distance(delta)


## Turns the camera to whichever side of the player has the most room and puts
## it out there right away. A cube dropped into a corner would otherwise start
## the level with the view squeezed against a wall. Nearby directions are tried
## first, so a spot that is already open keeps the angle it had
func aim_at_clearest() -> void:
	var space := body.get_world_3d().direct_space_state
	var best_yaw := yaw
	var best_room := _room_behind(space, yaw)
	var step := 360.0 / float(maxi(clearance_samples, 2))

	for i in range(1, maxi(clearance_samples, 2)):
		var offset := ceilf(float(i) * 0.5) * step * (1.0 if i % 2 == 1 else -1.0)
		var candidate := wrapf(yaw + offset, -180.0, 180.0)
		var room := _room_behind(space, candidate)
		if room > best_room + clearance_tolerance:
			best_room = room
			best_yaw = candidate

	yaw = best_yaw
	clearance = best_room
	_apply_rotation()
	camera.position = Vector3(0.0, 0.0, minf(desired_distance, clearance))


## How far the camera could sit out on that yaw before a wall stops it. The arm
## only ever probes where it points right now, so this asks the space itself,
## and it does so with the arm's own sphere: a bare ray slips through the corner
## between two blocks the camera would never fit past
func _room_behind(space: PhysicsDirectSpaceState3D, candidate_yaw: float) -> float:
	var direction := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(candidate_yaw), 0.0)).z
	var reach := desired_distance + spring_arm.margin

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = spring_arm.shape
	query.transform = Transform3D(Basis(), pivot.global_position)
	query.motion = direction * reach
	query.exclude = [body.get_rid()]

	var travel: PackedFloat32Array = space.cast_motion(query)
	if travel.is_empty():
		return 0.0

	return maxf(reach * travel[0] - spring_arm.margin, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var step := mouse_sensitivity * Settings.mouse_sensitivity
		yaw -= event.relative.x * step
		pitch -= event.relative.y * step
		_apply_rotation()
	elif event is InputEventMouseButton and event.pressed and not Online.showing_results():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Eases in and out, going in stays the faster half so walls stay opaque
func _update_distance(delta: float) -> void:
	var wanted := _free_distance()
	var speed := pull_in_speed if wanted < clearance else return_speed

	clearance = move_toward(clearance, wanted, speed * delta)
	camera.position = Vector3(0.0, 0.0, minf(desired_distance, clearance))


## The furthest spot along the arm the camera itself still fits in. Only where
## it sits is tested, not what it looks through: a block standing between the
## camera and the cube is fine, the far side of it is culled away and the cube
## shows through. Being inside one is not, that is what the search avoids.
##
## Nothing fits at all only in a corner, and there the arm is asked instead,
## which slides the camera in until it is clear of the wall
func _free_distance() -> float:
	if desired_distance <= min_probe_distance:
		return desired_distance

	var space := body.get_world_3d().direct_space_state
	var direction := pivot.global_transform.basis.z
	var steps := maxi(probe_steps, 2)
	var ignore: Array[RID] = [body.get_rid()]

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = spring_arm.shape
	query.margin = spring_arm.margin
	query.exclude = ignore

	for i in range(steps):
		var distance := lerpf(desired_distance, min_probe_distance, float(i) / float(steps - 1))
		query.transform = Transform3D(Basis(), pivot.global_position + direction * distance)
		if space.intersect_shape(query, 1).is_empty():
			return distance

	return spring_arm.get_hit_length()


## Writes yaw and pitch onto the pivot, the spring arm follows as a child
func _apply_rotation() -> void:
	pitch = clampf(pitch, min_pitch, max_pitch)
	yaw = wrapf(yaw, -180.0, 180.0)
	pivot.rotation_degrees = Vector3(pitch, yaw, 0.0)
