extends Node
class_name SawMover

## PING_PONG and LOOP are routes the saw keeps to forever. ONCE is walked to its
## end and then reported, it is what a saw that is being steered by something
## else runs on: the route is only ever the next leg of wherever it is going
enum Behavior { PING_PONG, LOOP, ONCE }

const PATH_SHADER := "res://Assets/shaders/SawPath.gdshader"

## Corners per tube ring, six already reads as round at debug thickness
const PATH_TUBE_SIDES := 6

## Which seat this blade belongs to, -1 while it is everybody's.
##
## A local race sets one set of blades per player into the same corridors. They
## run the identical routes, so the maze plays the same for all of them — but
## the freeze that stops them, the route the map item draws on them and the
## shield that breaks one are then that player's own and nobody else's
var seat: int = -1

## The Area3D that actually gets moved along the patrol route
@export var parent: Area3D

## Whether the saw bounces back and forth (A->B->C->B->A) or loops (A->B->C->A)
@export var behavior: Behavior = Behavior.PING_PONG

## Movement speed in world units per second
@export var speed: float = 2.0

## Scales that speed while an item holds the saws back, 1 is the speed above.
## Unlike a stall this is not eased, it is a different pace and not a stop
var speed_multiplier: float = 1.0

## How far in front of the first and the last waypoint the saw starts braking,
## the same ramp is used again when it picks up speed on the way back
@export var turn_slowdown_distance: float = 1.0

## How long the saw rests on the first and the last waypoint before it reverses
@export var turn_pause: float = 0.4

## The slowest the ramp may get, a saw that keeps halving its speed would
## never reach its waypoint
@export var turn_min_speed_factor: float = 0.15

@export_group("Stall")

## The blade spin, slowed down together with the saw. A stopped saw that is
## still whirring at full speed reads as a bug. Optional
@export var blade: AnimationPlayer

## The mesh that glows, dimmed while the saw is held. Optional
@export var glow: MeshInstance3D

## The light the saw throws into the corridor, dimmed with it. Optional
@export var danger_light: OmniLight3D

## How quickly the saw comes to a stop once something stalled it, in shares of
## its speed per second. Low is a long glide out
@export var brake_rate: float = 2.2

## How quickly it picks its speed back up when the stall is over
@export var resume_rate: float = 1.1

@export_group("Path")

## Debug aid, draws the patrol route into the level. Can be flipped at runtime
@export var show_path: bool = false:
	set(value):
		show_path = value
		_refresh_path_preview()

## Color of the debug route
@export var path_color: Color = Color(1.0, 0.35, 0.1)

## Radius of the tube the route is drawn as
@export var path_thickness: float = 0.06

## Arm length of the cross drawn on every waypoint
@export var path_marker_size: float = 0.2

## Length of one dash plus its gap, in world units
@export var path_dash_length: float = 0.6

## How fast the dashes travel along the route, in world units per second
@export var path_flow_speed: float = 1.5

## Seconds the saw still has to stand still, counted down while it is stalled
var stall_time: float = 0.0

## Where the saw is between standing and running, 1 being its full speed. It is
## eased on the way into the speed, so the saw glides out and back in
var stall_factor: float = 1.0

## How much of its glow the saw is left with at a full stop, 1 keeping it lit.
## Whatever stalls the blade decides this: one knocked out by a cube goes dark,
## one that was only frozen in place stays readable as a threat
var stall_dim: float = 1.0

var _glow_materials: Array[StandardMaterial3D] = []
var _glow_energies: PackedFloat32Array = PackedFloat32Array()
var _light_energy: float = 0.0
var _glow_factor: float = 1.0

## True once a ONCE route has been walked to its end and the saw is standing on
## its last waypoint with nowhere left to go. Whatever steers the saw watches
## this and answers with the next leg
var route_done: bool = false

var waypoints: Array[Vector3] = []
var target_index: int = 1
var direction: int = 1
var pause_timer: float = 0.0
var path_preview: MeshInstance3D = null
var route_material: ShaderMaterial = null
var marker_material: ShaderMaterial = null


func _ready() -> void:
	_take_over_glow()


## The glowing materials come out of the saw scene, so every blade in the level
## shares the same two. They are copied onto this one first, a single stalled
## saw would otherwise dim every saw in the level with it
func _take_over_glow() -> void:
	if danger_light != null:
		_light_energy = danger_light.light_energy

	if glow == null:
		return

	for i in range(glow.get_surface_override_material_count()):
		var material := glow.get_surface_override_material(i) as StandardMaterial3D
		if material == null:
			continue

		var copy := material.duplicate() as StandardMaterial3D
		glow.set_surface_override_material(i, copy)
		_glow_materials.append(copy)
		_glow_energies.append(copy.emission_energy_multiplier)


## Assigns the patrol waypoints and resets the saw to the first one.
##
## keep_position leaves the saw standing where it is and has it walk into the
## first waypoint instead of being placed on it. A route that is handed over
## while the saw is already running has to be picked up from where the blade
## actually is, dropping it onto the start of the new route would read as a
## teleport. The first waypoint is the cell it is standing in, so walking into
## it is a step of half a cell at most and never cuts a corner through a wall
func set_waypoints(points: Array[Vector3], keep_position: bool = false) -> void:
	waypoints = points
	direction = 1
	target_index = 0 if keep_position else mini(1, maxi(waypoints.size() - 1, 0))
	pause_timer = 0.0
	route_done = false

	if behavior == Behavior.LOOP and not _can_be_looped():
		push_warning("SawMover: route is not closed, falling back to PING_PONG")
		behavior = Behavior.PING_PONG

	if waypoints.size() > 0 and not keep_position:
		parent.global_position = waypoints[0]

	_refresh_path_preview()


## The way back to the first waypoint is a straight line, so it may not be
## longer than a regular step or the saw would cut across the level
func _can_be_looped() -> bool:
	if waypoints.size() < 3:
		return false

	var longest_step := 0.0
	for i in range(waypoints.size() - 1):
		longest_step = maxf(longest_step, waypoints[i].distance_to(waypoints[i + 1]))

	return waypoints[waypoints.size() - 1].distance_to(waypoints[0]) <= longest_step + 0.01


## Brings the saw to a stop for that long and lets it run on afterwards, dimmed
## to that share of its glow while it stands. A second call while it is already
## standing only ever extends the stop and takes the darker of the two, a blade
## that starts up again because it was touched twice would be a trap
func stall(seconds: float, dim: float = 1.0) -> void:
	stall_time = maxf(stall_time, seconds)
	stall_dim = minf(stall_dim, clampf(dim, 0.0, 1.0))


func _process(delta: float) -> void:
	_update_stall(delta)

	if waypoints.size() < 2:
		return

	if pause_timer > 0.0:
		pause_timer -= delta
		return

	var target: Vector3 = waypoints[target_index]
	var to_target := target - parent.global_position
	var distance := to_target.length()
	var step := _current_speed(distance) * delta

	if distance <= step or distance < 0.05:
		parent.global_position = target
		if behavior == Behavior.PING_PONG and _is_end_of_route(target_index):
			pause_timer = turn_pause
		_advance_target()
	else:
		parent.global_position += to_target.normalized() * step


## Runs the stop and the start up again. The factor itself moves at a steady
## rate and is eased where it is read, so the saw leaves and reaches its speed
## softly instead of snapping out of it
func _update_stall(delta: float) -> void:
	if stall_time > 0.0:
		stall_time = maxf(stall_time - delta, 0.0)

	var target := 0.0 if stall_time > 0.0 else 1.0
	var rate := brake_rate if target < stall_factor else resume_rate
	stall_factor = move_toward(stall_factor, target, rate * delta)

	if stall_time <= 0.0 and stall_factor >= 1.0:
		stall_dim = 1.0

	if blade != null:
		blade.speed_scale = _stall_ease()

	_apply_glow(lerpf(stall_dim, 1.0, _stall_ease()))


## Takes the saw down to its stalled glow and back up with it, so a blade that
## is winding down goes dark on the way instead of switching over
func _apply_glow(factor: float) -> void:
	if is_equal_approx(factor, _glow_factor):
		return

	_glow_factor = factor

	for i in range(_glow_materials.size()):
		_glow_materials[i].emission_energy_multiplier = _glow_energies[i] * factor

	if danger_light != null:
		danger_light.light_energy = _light_energy * factor


## What the saw is left of its speed, eased so both ends of the stop are soft
func _stall_ease() -> float:
	return smoothstep(0.0, 1.0, stall_factor)


## What the route asks for, held back by whatever stalled or slowed the saw
func _current_speed(distance_to_target: float) -> float:
	return _route_speed(distance_to_target) * _stall_ease() * speed_multiplier


## Brakes into the end of the route and accelerates back out of it. A looping
## saw never turns around, so it keeps its speed all the way
func _route_speed(distance_to_target: float) -> float:
	if behavior != Behavior.PING_PONG or turn_slowdown_distance <= 0.0:
		return speed

	var ramp := 1.0

	if _is_end_of_route(target_index):
		ramp = minf(ramp, distance_to_target / turn_slowdown_distance)

	var origin_index := target_index - direction
	if _is_end_of_route(origin_index):
		var travelled := parent.global_position.distance_to(waypoints[origin_index])
		ramp = minf(ramp, travelled / turn_slowdown_distance)

	return speed * maxf(ramp, turn_min_speed_factor)


func _is_end_of_route(index: int) -> bool:
	return index == 0 or index == waypoints.size() - 1


## The end of a ONCE route is the end of the job, so the saw stops there and
## says so through route_done rather than turning around. Whatever steers it
## reads that flag and hands it the next leg
func _advance_target() -> void:
	match behavior:
		Behavior.PING_PONG:
			target_index += direction
			if target_index >= waypoints.size():
				target_index = waypoints.size() - 2
				direction = -1
			elif target_index < 0:
				target_index = 1
				direction = 1
		Behavior.LOOP:
			target_index = (target_index + 1) % waypoints.size()
		Behavior.ONCE:
			if target_index >= waypoints.size() - 1:
				route_done = true
				return

			target_index += 1

	if route_material != null:
		_update_path_materials()


## Called on every change that the drawn route depends on, the exported flag
## can be toggled long before the waypoints exist
func _refresh_path_preview() -> void:
	if parent == null or not parent.is_inside_tree():
		return

	if not show_path or waypoints.size() < 2:
		if path_preview != null:
			path_preview.visible = false
		return

	if path_preview == null:
		_create_path_preview()

	path_preview.visible = true
	_update_path_materials()
	_build_path_mesh()


## The preview hangs under the saw so it dies with it, top_level keeps it from
## being dragged along when the saw moves
func _create_path_preview() -> void:
	route_material = ShaderMaterial.new()
	route_material.shader = load(PATH_SHADER)

	marker_material = ShaderMaterial.new()
	marker_material.shader = load(PATH_SHADER)
	marker_material.set_shader_parameter("solid", true)

	path_preview = MeshInstance3D.new()
	path_preview.mesh = ImmediateMesh.new()
	path_preview.top_level = true
	parent.add_child(path_preview)
	path_preview.global_transform = Transform3D.IDENTITY


## Pushed on every refresh so the exported values can be tuned while running.
## The dashes run with the saw, so the flow flips along with its direction
func _update_path_materials() -> void:
	route_material.set_shader_parameter("path_color", path_color)
	route_material.set_shader_parameter("dash_length", path_dash_length)
	route_material.set_shader_parameter("flow_speed", path_flow_speed * direction)
	marker_material.set_shader_parameter("path_color", path_color)


## A tube along the route plus a cross on every waypoint the route bends at. A
## looping route gets the closing leg back to the start drawn in as well, a ping
## pong one does not
func _build_path_mesh() -> void:
	var mesh: ImmediateMesh = path_preview.mesh
	mesh.clear_surfaces()

	var route := waypoints.duplicate()
	if behavior == Behavior.LOOP:
		route.append(waypoints[0])

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, route_material)
	var travelled := 0.0
	for i in range(route.size() - 1):
		travelled = _add_tube(mesh, route[i], route[i + 1], path_thickness, travelled)
	mesh.surface_end()

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, marker_material)
	for i in range(waypoints.size()):
		if not _is_path_corner(i):
			continue

		var point: Vector3 = waypoints[i]
		for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			var arm: Vector3 = axis * path_marker_size
			_add_tube(mesh, point - arm, point + arm, path_thickness * 0.6, 0.0)
	mesh.surface_end()


## A waypoint only earns a cross when the route actually turns there. The ends
## of a ping pong route always do, the saw reverses on them
func _is_path_corner(index: int) -> bool:
	var count := waypoints.size()

	if behavior == Behavior.PING_PONG and (index == 0 or index == count - 1):
		return true

	var previous: Vector3 = waypoints[(index - 1 + count) % count]
	var next: Vector3 = waypoints[(index + 1) % count]
	var incoming := waypoints[index] - previous
	var outgoing := next - waypoints[index]

	if incoming.length_squared() < 0.0001 or outgoing.length_squared() < 0.0001:
		return true

	return incoming.normalized().dot(outgoing.normalized()) < 0.999


## Wraps a ring of quads around the segment and returns the distance covered so
## far. That distance goes into UV.x, the shader scrolls its dashes along it,
## which keeps them evenly sized across segments of different length
func _add_tube(mesh: ImmediateMesh, from: Vector3, to: Vector3, radius: float, distance_offset: float) -> float:
	var axis := to - from
	var length := axis.length()
	if length < 0.0001:
		return distance_offset

	var forward := axis / length
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = forward.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(forward)

	var end_distance := distance_offset + length

	for i in range(PATH_TUBE_SIDES):
		var angle_a := TAU * i / PATH_TUBE_SIDES
		var angle_b := TAU * (i + 1) / PATH_TUBE_SIDES
		var offset_a := (side * cos(angle_a) + up * sin(angle_a)) * radius
		var offset_b := (side * cos(angle_b) + up * sin(angle_b)) * radius
		var v_a := float(i) / PATH_TUBE_SIDES
		var v_b := float(i + 1) / PATH_TUBE_SIDES

		mesh.surface_set_uv(Vector2(distance_offset, v_a))
		mesh.surface_add_vertex(from + offset_a)
		mesh.surface_set_uv(Vector2(end_distance, v_a))
		mesh.surface_add_vertex(to + offset_a)
		mesh.surface_set_uv(Vector2(end_distance, v_b))
		mesh.surface_add_vertex(to + offset_b)

		mesh.surface_set_uv(Vector2(distance_offset, v_a))
		mesh.surface_add_vertex(from + offset_a)
		mesh.surface_set_uv(Vector2(end_distance, v_b))
		mesh.surface_add_vertex(to + offset_b)
		mesh.surface_set_uv(Vector2(distance_offset, v_b))
		mesh.surface_add_vertex(from + offset_b)

	return end_distance
