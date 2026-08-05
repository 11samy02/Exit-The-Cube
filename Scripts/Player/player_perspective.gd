extends Node
class_name PlayerPerspective

## Emitted whenever the player switches between the two views
signal perspective_changed(first_person: bool)

## Camera rig that gets told how far the camera should sit from the player
@export var camera_rig: PlayerCamera

## Camera at the end of the arm, its fov widens up close
@export var camera: Camera3D

## The cube mesh. It is put on a layer of its own so its owner's camera can drop
## it in ego perspective while every other camera keeps drawing it
@export var mesh: MeshInstance3D

## Camera distance in third person
@export var third_person_distance: float = 4.5

## Field of view in third person
@export var third_person_fov: float = 75.0

## Field of view in ego perspective
@export var first_person_fov: float = 85.0

## How fast the camera travels between both views
@export var transition_speed: float = 14.0

## Below this distance the cube would block the view, so it is hidden
@export var hide_mesh_distance: float = 2.0

## Which view the player is currently in
var is_first_person: bool = false

## True once the view is fixed, the toggle is dead from then on
var is_locked: bool = false


## Which seat drives this cube. Cached rather than looked up every frame, and it
## is the base action again as soon as there is only one seat in the room
var _seat: int = 0

## The one visual layer this cube's mesh is drawn on, so its own camera can stop
## looking at it without taking it off anybody else's
var _own_layer: int = 0


## The attempt picks the view up where the one before left it. A death builds a
## brand new player, so the view it comes up in is read back out of the run
## instead of starting over at third person every time. The camera is put
## straight onto its pose here rather than travelling there, the transition
## would read as the game snapping the view away on every reload
func _ready() -> void:
	var cube := Player.of(self)
	_seat = cube.seat
	_own_layer = SeatView.body_bit(_seat)
	mesh.layers = _own_layer

	if cube.is_bot:
		_stand_down()
		return

	if Match.is_private_race():
		camera.cull_mask = SeatView.mask_for(_seat)

	is_first_person = GameState.is_first_person
	camera_rig.desired_distance = 0.0 if is_first_person else third_person_distance
	camera.fov = first_person_fov if is_first_person else third_person_fov

	if is_first_person:
		perspective_changed.emit(is_first_person)


## A bot has no view of its own to keep the cube out of. In a race everybody
## reads as running their own maze, so its body goes where the ghost will be
## drawn instead and the solid cube is taken off every camera at once
func _stand_down() -> void:
	is_locked = true
	set_process(false)
	set_process_unhandled_input(false)

	if Player.of(self).is_ghosted():
		SeatView.mark(Player.of(self), 0)
	else:
		mesh.layers = SeatView.SHARED


## Pulls the camera out and takes the toggle away for good, the elevator ride
## is meant to be watched from the outside. What the player picked is left
## alone, being carried out of the level is not a change of mind about the view
func lock_to_third_person() -> void:
	is_locked = true

	if is_first_person:
		is_first_person = false
		perspective_changed.emit(is_first_person)


## Takes the cube out of sight for good. The elevator calls this once the doors
## are shut, from the outside the player is simply gone with the cabin
func hide_mesh() -> void:
	mesh.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_locked:
		return

	if event.is_action_pressed(Seats.action(_seat, &"toggle_perspective")):
		is_first_person = not is_first_person
		GameState.is_first_person = is_first_person
		perspective_changed.emit(is_first_person)


func _process(delta: float) -> void:
	var target_distance := 0.0 if is_first_person else third_person_distance
	var target_fov := first_person_fov if is_first_person else third_person_fov
	var weight := minf(transition_speed * delta, 1.0)

	camera_rig.desired_distance = lerpf(camera_rig.desired_distance, target_distance, weight)
	camera.fov = lerpf(camera.fov, target_fov, weight)
	_update_own_view()


## Keeps the cube out of its own camera without taking it off anybody else's.
##
## Hiding the mesh, or dropping it to shadows only, is a property of the node and
## therefore true in every viewport at once. On a split screen that made a player
## in ego view vanish out of their friend's half of the window as well. So the
## cube is drawn on a layer of its own and its own camera simply stops looking at
## that layer, which is a per camera thing and leaves every other view alone.
##
## The shadow survives it either way: a light reads its own cull mask, not the
## camera's. Walls push the camera in as well, so the real distance decides and
## not the wanted one — and once the view is locked the cube stays on, the
## elevator shaft would hide it otherwise
func _update_own_view() -> void:
	if not is_locked and camera.position.z < hide_mesh_distance:
		camera.cull_mask &= ~_own_layer
	else:
		camera.cull_mask |= _own_layer
