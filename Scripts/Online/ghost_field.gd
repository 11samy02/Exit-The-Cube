class_name GhostField
extends Node3D

## The other players, drawn into this machine's own maze. Every cube in the race
## walks an identical copy of the same level, so a position from another machine
## means the same thing here as it did there and can simply be placed.
##
## They are ghosts and not bodies on purpose: nothing about them collides, nothing
## about them can be walked into, and none of it is simulated. A packet says where
## a cube was, this slides its ghost there over the next few frames, and that is
## the whole of it.
##
## The spectator camera lives here as well. Once the elevator has carried the
## local cube out, the ghosts are the only thing left worth looking at, and they
## are already standing in the right places

## Put into a group so the race panel can reach the camera without a path
const GROUP := &"ghost_field"

## How wide a ghost cube is, the same as the player mesh
const GHOST_SIZE := 1.19

## How much of the level shows through a ghost
const GHOST_ALPHA := 0.32

## How brightly a ghost burns in its own color
const GHOST_EMISSION := 1.4

## How far above a ghost its name floats
const NAME_HEIGHT := 1.5

## Past this many meters a name is not drawn, otherwise a twelve player lobby
## puts a wall of text across the screen
const NAME_RANGE := 26.0

## How quickly a ghost catches up to the position it was last told about. It is
## a rate and not a step, so a ghost that fell behind closes the gap faster
const FOLLOW_SPEED := 14.0

## The same for the direction it faces
const TURN_SPEED := 10.0

## How far a ghost hops while it is moving, and how often
const BOUNCE_HEIGHT := 0.09
const BOUNCE_SPEED := 7.0

## Speed a ghost has to be doing before it counts as running, in meters a second
const MOVING_SPEED := 0.6

## Where the spectator camera sits behind whoever is being watched
const WATCH_OFFSET := Vector3(0.0, 7.0, 8.5)

## How quickly that camera follows, low enough to read as a camera operator
const WATCH_SPEED := 4.0

## One node per cube, by the account it belongs to
var _ghosts: Dictionary = {}

## The account being watched, 0 while the player is playing rather than looking
var _watching: int = 0

var _camera: Camera3D = null


func _ready() -> void:
	add_to_group(GROUP)
	_camera = Camera3D.new()
	_camera.current = false
	add_child(_camera)


func _process(delta: float) -> void:
	if not Online.is_racing():
		return

	for id: int in Online.runners:
		if id == Online.steam.id:
			continue

		_update_ghost(id, Online.runners[id], delta)

	_drop_gone_ghosts()
	_move_camera(delta)


## A ghost is on the map while its cube has sent a position, is still alive and
## has not ridden the elevator out. Everything else takes it off again
func _update_ghost(id: int, runner: Dictionary, delta: float) -> void:
	var wanted: bool = bool(runner["placed"]) and not bool(runner["finished"])

	if not wanted:
		if _ghosts.has(id):
			_ghosts[id].visible = false
		return

	var ghost: Node3D = _ghosts.get(id, null)
	if ghost == null:
		ghost = _build_ghost(runner)
		_ghosts[id] = ghost

	ghost.visible = not bool(runner["dead"])
	_step(ghost, runner, delta)


## Walks the ghost towards the last position that arrived for it. The runner
## keeps its own smoothed position rather than the node doing it, so a ghost
## that is rebuilt after a map reload comes back where it belongs
func _step(ghost: Node3D, runner: Dictionary, delta: float) -> void:
	var from: Vector3 = runner["position"]
	var to: Vector3 = runner["target"]
	var blend := minf(FOLLOW_SPEED * delta, 1.0)

	runner["position"] = from.lerp(to, blend)
	runner["yaw"] = lerp_angle(float(runner["yaw"]), float(runner["target_yaw"]), \
		minf(TURN_SPEED * delta, 1.0))

	var speed := from.distance_to(to) / maxf(delta, 0.0001)
	ghost.global_position = runner["position"]
	_animate(ghost, speed, delta)
	_show_name(ghost, float(runner["yaw"]))


## The hop the cube itself does while it runs, cheaply. A ghost that slides
## along the floor perfectly flat reads as a bug rather than as a player
func _animate(ghost: Node3D, speed: float, delta: float) -> void:
	var mesh := ghost.get_child(0) as Node3D
	var running := speed > MOVING_SPEED
	var phase := float(ghost.get_meta(&"bounce", 0.0))

	phase = wrapf(phase + delta * BOUNCE_SPEED, 0.0, TAU) if running else 0.0
	ghost.set_meta(&"bounce", phase)
	mesh.position.y = absf(sin(phase)) * BOUNCE_HEIGHT


## The name floats above the cube, turned to face the camera and dropped once it
## is too far off to be worth reading
func _show_name(ghost: Node3D, yaw: float) -> void:
	var mesh := ghost.get_child(0) as Node3D
	mesh.rotation.y = yaw

	var label := ghost.get_child(1) as Label3D
	var viewer := get_viewport().get_camera_3d()
	label.visible = viewer != null and viewer.global_position.distance_to(ghost.global_position) < NAME_RANGE


## One transparent cube with a name over it. Built in code because it is only
## ever three nodes and every one of them is colored per player anyway
func _build_ghost(runner: Dictionary) -> Node3D:
	var color := ghost_color(int(runner["id"]))

	var ghost := Node3D.new()
	add_child(ghost)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3.ONE * GHOST_SIZE
	mesh.material_override = _ghost_material(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(mesh)

	var label := Label3D.new()
	label.text = String(runner["name"]).to_upper()
	label.font_size = 44
	label.pixel_size = 0.0042
	label.modulate = color
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	label.position.y = NAME_HEIGHT
	ghost.add_child(label)

	return ghost


## Unshaded on purpose. A ghost lit like the rest of the level disappears into
## the dark corridors it is supposed to be seen glowing down
func _ghost_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, GHOST_ALPHA)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = GHOST_EMISSION
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## The color a cube goes by, everywhere it is drawn. It is worked out from the
## account rather than rolled, so the ghost, the name in the lobby and the row
## in the standings are all the same color on every machine in the race
static func ghost_color(account: int) -> Color:
	var hue := float(account % 997) / 997.0
	return Color.from_hsv(hue, 0.55, 1.0)


## Ghosts of accounts that are no longer in the race at all
func _drop_gone_ghosts() -> void:
	for id: int in _ghosts.keys():
		if not Online.runners.has(id):
			_ghosts[id].queue_free()
			_ghosts.erase(id)


## Whoever can be watched right now: everybody still walking around in the maze,
## in the order they are ranked
func watchable() -> Array:
	var found: Array = []

	for runner in Online.standings():
		if int(runner["id"]) == Online.steam.id:
			continue

		if not bool(runner["finished"]) and bool(runner["placed"]):
			found.append(runner)

	return found


func watching() -> int:
	return _watching


## Takes the view off the player and puts it behind that cube. The camera is not
## parented to the ghost, it follows it: a camera bolted to a hopping cube hops
## with it and is unwatchable within seconds
func watch(account: int) -> void:
	if not _ghosts.has(account):
		return

	_watching = account
	_camera.global_position = _ghosts[account].global_position + WATCH_OFFSET
	_camera.make_current()


## Steps to the next or the previous cube that is still in the maze
func watch_step(direction: int) -> void:
	var options := watchable()
	if options.is_empty():
		_watching = 0
		return

	for i in range(options.size()):
		if int(options[i]["id"]) == _watching:
			watch(int(options[wrapi(i + direction, 0, options.size())]["id"]))
			return

	watch(int(options[0]["id"]))


## Hands the view back to the player's own camera
func stop_watching() -> void:
	_watching = 0

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var camera := player.get_node_or_null("Camera Pivot/Camera3D") as Camera3D
	if camera != null:
		camera.make_current()


## Trails the watched cube from behind and above, and drops the whole thing when
## that cube dies, finishes or drops off the network
func _move_camera(delta: float) -> void:
	if _watching == 0:
		return

	var ghost: Node3D = _ghosts.get(_watching, null)
	var runner: Dictionary = Online.runners.get(_watching, {})

	if ghost == null or runner.is_empty() or bool(runner["finished"]) or not bool(runner["placed"]):
		watch_step(1)
		return

	var wanted := ghost.global_position + WATCH_OFFSET
	_camera.global_position = _camera.global_position.lerp(wanted, minf(WATCH_SPEED * delta, 1.0))
	_camera.look_at(ghost.global_position + Vector3.UP * 0.5)
