extends Node
class_name ScreenShake

## The camera that gets rattled, only its rotation and its lens offset are
## touched, the distance along the arm stays with the camera rig
@export var camera: Camera3D

## Degrees of pitch and yaw at full trauma
@export var max_angle: float = 3.5

## Degrees of roll at full trauma, the tilt is what sells the hit
@export var max_roll: float = 6.0

## Units the lens slides off center at full trauma
@export var max_offset: float = 0.2

## Trauma lost per second, a full kick is gone after roughly one over this
@export var decay: float = 1.1

## Steps per second taken through the noise, higher rattles faster
@export var frequency: float = 24.0

## How hard the camera is hit right now, one is a full kick
var trauma: float = 0.0

## Position in the noise, walks forward while the shake runs
var noise_time: float = 0.0

var noise := FastNoiseLite.new()


func _ready() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_octaves = 1
	noise.frequency = 1.0
	noise.seed = randi()
	set_process(false)


## Kicks the camera, further hits stack up but never go past a full kick
func shake(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)
	set_process(true)


func _process(delta: float) -> void:
	trauma = maxf(trauma - decay * delta, 0.0)
	noise_time += delta * frequency
	_apply()

	if trauma <= 0.0:
		set_process(false)


## Squaring the trauma keeps the tail of the shake calm and the first frames
## hard, at zero this writes the camera back to neutral
func _apply() -> void:
	var strength := trauma * trauma

	camera.rotation_degrees = Vector3(
		max_angle * strength * _sample(0),
		max_angle * strength * _sample(1),
		max_roll * strength * _sample(2))
	camera.h_offset = max_offset * strength * _sample(3)
	camera.v_offset = max_offset * strength * _sample(4)


## One wobble per channel, the channels sit far enough apart in the noise to
## move on their own
func _sample(channel: int) -> float:
	return noise.get_noise_2d(channel * 64.0, noise_time)
