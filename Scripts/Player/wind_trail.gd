class_name WindTrail
extends MeshInstance3D

## The streak a running cube drags behind it.
##
## A ribbon and not a puff of particles. What reads as speed is one unbroken
## line that bends where the cube turned — a cloud of specks reads as dust, and
## dust is what a cube kicks up when it lands, not when it runs.
##
## It is drawn low, under the body, so it looks like something being dragged
## rather than something coming off the cube's shoulders. The points are kept in
## world space and the node itself is top level, so the tail stays where it was
## laid down instead of swinging around with the cube that laid it

## How many points the ribbon is built from. More is a longer tail
const POINTS := 20

## How far the cube has to move before another point is laid down, in meters
const STEP := 0.2

## How far under the middle of the cube the ribbon runs
const DROP := 0.44

## How wide it is where it leaves the cube, in meters. It tapers to nothing
const WIDTH := 0.38

## Seconds the tail takes to be eaten up once the item is over
const FADE := 0.4

## The cube it hangs off, and the line it has laid down so far, oldest first
var _cube: Player = null
var _points: PackedVector3Array = PackedVector3Array()

var _material: StandardMaterial3D = null
var _color := Color.WHITE

## True once the item is over: nothing more is laid down and the tail is eaten
var _fading: bool = false
var _eat_timer: float = 0.0


## Hangs one on that cube. It follows the cube around and trails out behind it
static func attach_to(cube: Player, color: Color) -> WindTrail:
	var made := WindTrail.new()
	made.name = "Wind"
	made._cube = cube
	made._color = color
	made._dress()

	cube.add_child(made)
	made.top_level = true
	made.global_transform = Transform3D.IDENTITY
	return made


## Stops laying the ribbon down and lets what is already out there run off the
## end, so switching the item off does not snap a line out of the air
func fade_out() -> void:
	_fading = true


func _dress() -> void:
	mesh = ImmediateMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = _color
	_material.emission_enabled = true
	_material.emission = _color
	_material.emission_energy_multiplier = 2.4


func _process(delta: float) -> void:
	if _fading:
		_eat_the_tail(delta)
	else:
		_lay_a_point()

	_redraw()

	if _fading and _points.size() < 2:
		queue_free()


## One more point, once the cube has got far enough from the last one. Sampling
## by distance rather than by time keeps the ribbon the same shape whether the
## cube is sprinting or walking into a wall
func _lay_a_point() -> void:
	if not is_instance_valid(_cube):
		_fading = true
		return

	var at := _cube.global_position + Vector3.DOWN * DROP

	if not _points.is_empty() and _points[_points.size() - 1].distance_to(at) < STEP:
		return

	_points.append(at)

	while _points.size() > POINTS:
		_points.remove_at(0)


## Takes the oldest point off at the rate the whole tail would run out at
func _eat_the_tail(delta: float) -> void:
	_eat_timer -= delta
	if _eat_timer > 0.0:
		return

	_eat_timer = FADE / float(POINTS)

	if not _points.is_empty():
		_points.remove_at(0)


## The ribbon itself: a strip of quads, each one turned flat around the way the
## line is running there, narrowing and fading towards the tail
func _redraw() -> void:
	var strip := mesh as ImmediateMesh
	strip.clear_surfaces()

	if _points.size() < 2:
		return

	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)

	for at in range(_points.size()):
		var through := float(at) / float(_points.size() - 1)
		var side := _across(at) * WIDTH * 0.5 * through
		var shade := Color(_color.r, _color.g, _color.b, through * through)

		strip.surface_set_color(shade)
		strip.surface_add_vertex(_points[at] - side)
		strip.surface_set_color(shade)
		strip.surface_add_vertex(_points[at] + side)

	strip.surface_end()


## Which way the ribbon lies flat at that point, across the line it is running
func _across(at: int) -> Vector3:
	var before: Vector3 = _points[maxi(at - 1, 0)]
	var after: Vector3 = _points[mini(at + 1, _points.size() - 1)]
	var along := after - before

	if along.length_squared() < 0.0001:
		return Vector3.RIGHT

	var side := along.normalized().cross(Vector3.UP)
	return side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
