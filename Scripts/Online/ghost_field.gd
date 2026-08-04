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

## How much of the level shows through a ghost. They are meant to read as
## somebody being somewhere, not as a cube standing in your corridor
const GHOST_ALPHA := 0.20

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

## How far a ghost snaps outwards as it bursts, and how long the burst and the
## way back in take
const DEATH_BURST := 1.9
const DEATH_TIME := 0.35
const SPAWN_TIME := 0.3

## Where the spectator camera sits behind whoever is being watched
const WATCH_OFFSET := Vector3(0.0, 7.0, 8.5)

## How quickly that camera follows, low enough to read as a camera operator
const WATCH_SPEED := 4.0

## One node per cube, by the account it belongs to
var _ghosts: Dictionary = {}

## How quickly a blade slides onto the spot the watched player reports. Snapping
## it there makes ten packets a second read as ten jumps a second
const SAW_FOLLOW := 0.35

## The account being watched, 0 while the player is playing rather than looking
var _watching: int = 0

## Blades whose own movement is switched off because a watched player is
## reporting where they are, by their place in the spawn order
var _held_saws: Dictionary = {}

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

	_show_death(ghost, bool(runner["dead"]))

	if ghost.visible:
		_step(ghost, runner, delta)


## A cube twenty corridors away that simply blinks out reads as a dropped
## connection, not as somebody dying. So it goes the way the player's own cube
## goes — a snap outwards, then gone — and comes back the same way in reverse.
##
## It is deliberately only a scale and a fade. The real death throws a few
## hundred particles and shakes the camera, and eleven of those going off around
## the map at once would be a light show rather than a race
func _show_death(ghost: Node3D, dead: bool) -> void:
	if bool(ghost.get_meta(&"dead", false)) == dead:
		return

	ghost.set_meta(&"dead", dead)
	var running: Variant = ghost.get_meta(&"burst", null)

	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()

	var burst := create_tween()
	burst.set_parallel(true)
	ghost.set_meta(&"burst", burst)

	var fade := _fade_of(ghost)

	if dead:
		burst.tween_property(ghost, "scale", Vector3.ONE * DEATH_BURST, DEATH_TIME) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		burst.tween_method(fade, 1.0, 0.0, DEATH_TIME)
		burst.chain().tween_callback(func() -> void: ghost.visible = false)
		return

	ghost.visible = true
	ghost.scale = Vector3.ONE * DEATH_BURST
	burst.tween_property(ghost, "scale", Vector3.ONE, SPAWN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst.tween_method(fade, 0.0, 1.0, SPAWN_TIME)


## Fades the whole ghost, cube and name together. A Node3D carries no modulate
## of its own, so the two are dimmed by hand off the colour they were built in
func _fade_of(ghost: Node3D) -> Callable:
	var mesh := ghost.get_child(0) as MeshInstance3D
	var label := ghost.get_child(1) as Label3D
	var material := mesh.material_override as StandardMaterial3D
	var tint: Color = label.modulate

	var solid := Online.is_painting()

	return func(amount: float) -> void:
		material.albedo_color = Color(tint.r, tint.g, tint.b, (1.0 if solid else GHOST_ALPHA) * amount)
		material.emission_energy_multiplier = GHOST_EMISSION * amount
		label.modulate = Color(tint.r, tint.g, tint.b, amount)


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
	var color := Online.color_of(int(runner["id"]))

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
## the dark corridors it is supposed to be seen glowing down.
##
## In a mode where the others are in the maze with you rather than running their
## own copy of it, they are drawn solid. A see-through cube says "this player is
## somewhere else"; in a team round they are on the same floor, fighting over the
## same tiles, and they should look like it
func _ghost_material(color: Color) -> StandardMaterial3D:
	var solid := Online.is_painting()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if solid \
		else BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color if solid else Color(color.r, color.g, color.b, GHOST_ALPHA)
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
	_release_saws()

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var camera := player.get_node_or_null("Camera Pivot/Camera3D") as Camera3D
	if camera != null:
		camera.make_current()


## Puts the blades where the watched player sees them.
##
## Every machine built the same level from the same seed, so blade number nine
## is the same blade everywhere — the watched cube only has to say which ones
## and where, and its own copy is moved onto that spot. Without this a watcher
## sees their own blades, which have been drifting apart since the race began
## and are stalled by whatever items the watcher used: the cube being followed
## then appears to walk through a blade, or to die against nothing at all.
##
## The movers are switched off while this runs, otherwise the local simulation
## and the packets fight over the same node every frame
func _sync_watched_saws() -> void:
	var spawner := get_tree().get_first_node_in_group(&"saw_spawner") as SawSpawner
	var runner: Dictionary = Online.runners.get(_watching, {})

	if spawner == null or runner.is_empty():
		return

	var reported: Array = runner.get("saws", [])
	var seen: Dictionary = {}

	for at in range(0, reported.size() - 1, 2):
		var index := int(reported[at])
		if index < 0 or index >= spawner.spawned_saws.size():
			continue

		var saw: Node3D = spawner.spawned_saws[index]
		if not is_instance_valid(saw):
			continue

		seen[index] = true
		_hold_saw(saw, true)
		saw.global_position = saw.global_position.lerp(reported[at + 1] as Vector3, SAW_FOLLOW)

	_held_saws.merge(seen)


## Hands every blade back to its own simulation, called when watching stops
func _release_saws() -> void:
	var spawner := get_tree().get_first_node_in_group(&"saw_spawner") as SawSpawner
	if spawner != null:
		for index: int in _held_saws:
			if index < spawner.spawned_saws.size() and is_instance_valid(spawner.spawned_saws[index]):
				_hold_saw(spawner.spawned_saws[index], false)

	_held_saws.clear()


## Switches one blade's own movement off or back on
func _hold_saw(saw: Node3D, held: bool) -> void:
	for child in saw.get_children():
		if child is SawMover or child is SawAi:
			(child as Node).set_process(not held)
			(child as Node).set_physics_process(not held)


## Trails the watched cube from behind and above, and drops the whole thing when
## that cube dies, finishes or drops off the network
func _move_camera(delta: float) -> void:
	if _watching == 0:
		return

	_sync_watched_saws()

	var ghost: Node3D = _ghosts.get(_watching, null)
	var runner: Dictionary = Online.runners.get(_watching, {})

	if ghost == null or runner.is_empty() or bool(runner["finished"]) or not bool(runner["placed"]):
		watch_step(1)
		return

	var wanted := ghost.global_position + WATCH_OFFSET
	_camera.global_position = _camera.global_position.lerp(wanted, minf(WATCH_SPEED * delta, 1.0))
	_camera.look_at(ghost.global_position + Vector3.UP * 0.5)
