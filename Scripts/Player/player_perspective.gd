extends Node
class_name PlayerPerspective

## Emitted whenever the player switches between the two views
signal perspective_changed(first_person: bool)

## Camera rig that gets told how far the camera should sit from the player
@export var camera_rig: PlayerCamera

## Camera at the end of the arm, its fov widens up close
@export var camera: Camera3D

## The cube mesh, only casts a shadow while in ego perspective
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


## The attempt picks the view up where the one before left it. A death builds a
## brand new player, so the view it comes up in is read back out of the run
## instead of starting over at third person every time. The camera is put
## straight onto its pose here rather than travelling there, the transition
## would read as the game snapping the view away on every reload
func _ready() -> void:
	is_first_person = GameState.is_first_person
	camera_rig.desired_distance = 0.0 if is_first_person else third_person_distance
	camera.fov = first_person_fov if is_first_person else third_person_fov

	if is_first_person:
		perspective_changed.emit(is_first_person)


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

	if event.is_action_pressed("toggle_perspective"):
		is_first_person = not is_first_person
		GameState.is_first_person = is_first_person
		perspective_changed.emit(is_first_person)


func _process(delta: float) -> void:
	var target_distance := 0.0 if is_first_person else third_person_distance
	var target_fov := first_person_fov if is_first_person else third_person_fov
	var weight := minf(transition_speed * delta, 1.0)

	camera_rig.desired_distance = lerpf(camera_rig.desired_distance, target_distance, weight)
	camera.fov = lerpf(camera.fov, target_fov, weight)
	_update_mesh_visibility()


## Keeps the cube out of the camera without losing its shadow, walls push the
## camera in as well so the real distance decides, not the wanted one. Once the
## view is locked the cube stays on, the elevator shaft would hide it otherwise.
func _update_mesh_visibility() -> void:
	if not is_locked and camera.position.z < hide_mesh_distance:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	else:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
