class_name SplitCamera
extends Camera3D

## The camera of one split, copied every frame off the cube's own rig.
##
## Copying rather than moving the rig's camera into the viewport is what keeps
## the rest of the player untouched. Everything about the view is worked out over
## there — the arm slides the camera in by hand and writes a pivot local
## position, the perspective lerps the field of view, the death shake writes the
## rotation and the lens offsets — and all three of those keep working when the
## finished pose is simply read off at the end of the frame.
##
## Moving it instead would break the first of them outright: a position that
## means "seven metres behind the pivot" means something else entirely once the
## camera hangs under a viewport

## The camera on the cube's rig this one follows
var source: Camera3D = null


func _ready() -> void:
	process_priority = 1000
	current = true


func _process(_delta: float) -> void:
	if source == null or not is_instance_valid(source):
		return

	global_transform = source.global_transform
	fov = source.fov
	h_offset = source.h_offset
	v_offset = source.v_offset
	near = source.near
	far = source.far
	cull_mask = source.cull_mask
