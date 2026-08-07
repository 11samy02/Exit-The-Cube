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
	fov = _fitted_fov(source.fov)
	h_offset = source.h_offset
	v_offset = source.v_offset
	near = source.near
	far = source.far
	cull_mask = source.cull_mask


## The source's field of view read for whichever axis this split holds.
##
## A cube writes a vertical angle, because that is what fov means to a camera
## with the whole window to itself. A split that keeps its width instead reads
## the same number as a horizontal one, and a wide short strip handed 75 there
## ends up narrower than the window ever was — the picture zooms in by the
## difference, which is what the top and bottom halves were doing.
##
## So the vertical angle is opened out into the horizontal one the window itself
## would have had. Every piece then draws at the same degrees per pixel however
## the screen was cut: a strip loses height rather than gaining magnification
func _fitted_fov(vertical: float) -> float:
	if keep_aspect != Camera3D.KEEP_WIDTH:
		return vertical

	var window := get_window()
	if window == null or window.size.y <= 0:
		return vertical

	var aspect := float(window.size.x) / float(window.size.y)
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(vertical) * 0.5) * aspect))
