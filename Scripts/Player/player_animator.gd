extends Node
class_name PlayerAnimator

## The mesh that gets squashed, stretched and turned
@export var mesh: Node3D

## Movement script the animation reads speed and direction from
@export var movement: PlayerMovement

## How far the cube leans into its running direction, in degrees
@export var lean_angle: float = 12.0

## Height of a single hop while running, in world units
@export var bounce_height: float = 0.06

## Hops per second at full speed
@export var bounce_speed: float = 2.8

## How much the cube stretches and squashes per hop
@export var run_stretch: float = 0.16

## How much the cube breathes while standing still
@export var idle_stretch: float = 0.055

## Breaths per second while standing still
@export var idle_speed: float = 1.4

## Degrees the cube rocks from side to side while standing still
@export var idle_sway: float = 4.0

## How long the cube takes to blend between standing and running
@export var blend_speed: float = 4.5

## How quickly the cube turns towards its running direction
@export var turn_speed: float = 9.0

var base_position: Vector3
var half_height: float = 0.5
var half_depth: float = 0.5
var speed_ratio: float = 0.0
var run_time: float = 0.0
var idle_time: float = 0.0
var facing_yaw: float = 0.0
var lean: float = 0.0
var stretch: float = 1.0
var lift: float = 0.0


func _ready() -> void:
	base_position = mesh.position
	facing_yaw = mesh.rotation.y
	_measure_extents()


## Only the speed is smoothed, the pose itself is a continuous curve over
## time. Smoothing it as well would keep it from ever reaching the squash
## that puts the cube back on the floor.
func _process(delta: float) -> void:
	var target_ratio := clampf(movement.current_speed / maxf(movement.max_speed, 0.01), 0.0, 1.0)
	speed_ratio = lerpf(speed_ratio, target_ratio, minf(blend_speed * delta, 1.0))

	run_time = wrapf(run_time + delta * bounce_speed * PI * speed_ratio, 0.0, TAU)
	idle_time = wrapf(idle_time + delta * idle_speed * TAU, 0.0, TAU * 2.0)

	_animate_rotation(delta)
	_animate_pose()


## Turns the cube towards where it is running and lets it lean into the motion,
## runs before the pose because the lean decides how far the cube has to be
## lifted to keep its tilted edge off the floor
func _animate_rotation(delta: float) -> void:
	var direction := movement.facing_direction
	var target_yaw := atan2(-direction.x, -direction.z)
	facing_yaw = lerp_angle(facing_yaw, target_yaw, minf(turn_speed * delta, 1.0))

	lean = deg_to_rad(-lean_angle) * speed_ratio
	var sway := deg_to_rad(idle_sway) * sin(idle_time * 0.5) * (1.0 - speed_ratio)
	mesh.rotation = Vector3(lean, facing_yaw, sway)


## Blends the running hop with the idle breathing, volume stays constant so
## the cube gets wider whenever it gets flatter. The cube is fully squashed
## the moment it touches down and stretched at the top of its hop.
func _animate_pose() -> void:
	var run_pose := -cos(run_time * 2.0) * run_stretch * speed_ratio
	var idle_pose := sin(idle_time) * idle_stretch * (1.0 - speed_ratio)

	stretch = 1.0 + run_pose + idle_pose
	lift = absf(sin(run_time)) * bounce_height * speed_ratio

	mesh.scale = Vector3(1.0 / sqrt(stretch), stretch, 1.0 / sqrt(stretch))
	mesh.position = base_position + Vector3.UP * (lift + _ground_offset())


## Squashing and leaning both happen around the center of the cube, which
## would sink it into the floor or lift it off it. This keeps its lowest
## edge exactly where the collision shape stands.
func _ground_offset() -> float:
	var scaled_height := half_height * stretch
	var scaled_depth := half_depth / sqrt(stretch)
	var lowest := scaled_height * cos(lean) + scaled_depth * absf(sin(lean))
	return lowest - half_height


## Reads how far the mesh reaches below and behind its own origin
func _measure_extents() -> void:
	var instance := mesh as MeshInstance3D
	if instance == null or instance.mesh == null:
		return

	var aabb := instance.mesh.get_aabb()
	half_height = absf(aabb.position.y)
	half_depth = absf(aabb.position.z)
