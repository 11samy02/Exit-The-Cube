extends ItemEffect
class_name ArrowEffect

## The arrow model that is spawned
@export var arrow_scene: PackedScene

## Turns the model around its own axis. The effect aims the +X axis at the
## target, the model in arrow.tscn has its tip on -X, so it is turned around
@export_range(-180.0, 180.0) var yaw_offset_degrees: float = 180.0

## How far above the player the arrow floats in third person
@export var third_person_height: float = 2.4

## How big the arrow is drawn in third person
@export var third_person_scale: float = 1.0

## How far in front of the camera the arrow sits in first person
@export var first_person_distance: float = 1.4

## How far under the view center it hangs there, so it stays out of the way
@export var first_person_drop: float = 0.55

## How big it is drawn in first person, at its own size it sits close enough
## to the camera to swallow the whole corridor
@export var first_person_scale: float = 0.22

## Color the arrow is painted and lit in
@export var arrow_color: Color = Color(1, 0.85, 0.2)

## How brightly it glows in that color, the corridors are dark
@export var arrow_glow: float = 1.8

## Draws the arrow over the level instead of into it. A wall right in front of
## the camera would cut the first person arrow in half otherwise
@export var draw_over_level: bool = true

## How far the arrow is tipped up towards the camera in first person, the flat
## model would be edge on and unreadable otherwise
@export_range(0.0, 90.0) var first_person_tilt: float = 55.0

## Height of the idle bobbing in third person
@export var bob_height: float = 0.12

## Bobs per second
@export var bob_speed: float = 2.4

## Seconds before the end at which the arrow starts blinking, so the timer
## running out can be seen on the arrow itself and not only in the UI
@export var warning_time: float = 5.0

## Blinks per second while the arrow runs out
@export var warning_blink_speed: float = 4.0

var arrow: Node3D = null
var perspective: PlayerPerspective = null
var camera: Camera3D = null
var bob_time: float = 0.0


## The arrow is placed by hand every frame, so it hangs outside of the player
## transform instead of being dragged around by it
func _start() -> void:
	perspective = get_tree().get_first_node_in_group("player_perspective") as PlayerPerspective
	if perspective != null:
		camera = perspective.camera

	if arrow_scene == null:
		push_warning("ArrowEffect: no arrow scene assigned, there is nothing to show")
		return

	arrow = arrow_scene.instantiate()
	arrow.top_level = true
	add_child(arrow)
	_paint_arrow()


## The model comes in with a plain material that goes muddy under the purple
## ambient light, so it gets its own glowing one
func _paint_arrow() -> void:
	var mesh_instance := _find_mesh(arrow)
	if mesh_instance == null:
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = arrow_color
	material.emission_enabled = true
	material.emission = arrow_color
	material.emission_energy_multiplier = arrow_glow
	material.no_depth_test = draw_over_level
	material.render_priority = 1 if draw_over_level else 0
	mesh_instance.material_override = material


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found

	return null


func _tick(delta: float) -> void:
	if not is_instance_valid(arrow) or not is_instance_valid(player):
		return

	bob_time += delta

	var target := _current_target()
	arrow.visible = target != null and warning_blink(warning_time, warning_blink_speed)
	if target != null:
		_point_at(target.global_position)


func _stop(_cancelled: bool) -> void:
	if is_instance_valid(arrow):
		arrow.queue_free()

	arrow = null


## The key while it is still out there, the exit once the player carries it
func _current_target() -> Node3D:
	if not GameState.has_key:
		var key := get_tree().get_first_node_in_group("key") as Node3D
		if key != null:
			return key

	return get_tree().get_first_node_in_group("elevator") as Node3D


## Only the yaw is taken from the target, an arrow that tips down towards a
## key one floor below would be a lot harder to read
func _point_at(target_position: Vector3) -> void:
	var first_person: bool = perspective != null and perspective.is_first_person
	var origin := _anchor(first_person)

	var to_target := target_position - origin
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return

	arrow.global_position = origin
	arrow.global_rotation = Vector3(
		0.0, atan2(-to_target.z, to_target.x) + deg_to_rad(yaw_offset_degrees), 0.0
	)

	if first_person and camera != null:
		arrow.rotate(camera.global_basis.x, deg_to_rad(first_person_tilt))

	arrow.scale = Vector3.ONE * (first_person_scale if first_person else third_person_scale)


## Over the player in third person, in front of the camera in first person
## where the cube itself is not on screen to hang it over
func _anchor(first_person: bool) -> Vector3:
	if first_person and camera != null:
		var view := camera.global_basis
		return camera.global_position - view.z * first_person_distance - view.y * first_person_drop

	var bob := sin(bob_time * bob_speed) * bob_height
	return player.global_position + Vector3.UP * (third_person_height + bob)
