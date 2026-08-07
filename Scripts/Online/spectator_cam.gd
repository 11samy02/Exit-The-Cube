class_name SpectatorCam
extends Node3D

## The camera that follows somebody who is still in the maze.
##
## This used to be a part of the ghost field, which was right for as long as only
## one person per machine could ever be out of a race. A race on one screen ends
## four times though, at four different moments, and each of those players wants
## to watch a different one of the three still running — so the camera is a node
## anybody may own one of, and the field simply keeps the window's.
##
## It is never parented to what it follows. A camera bolted to a hopping cube hops
## with it and is unwatchable within seconds; this orbits a point that eases onto
## the cube instead, at an angle that belongs to the watcher and not to them

## How far out the camera starts, and how far it may be pushed
const DISTANCE := 9.0
const NEAR := 2.5
const FAR := 34.0

## Where it starts looking from, in degrees, and how far it may be tilted
const START_PITCH := -22.0
const PITCH_LIMITS := Vector2(-85.0, 40.0)

## How far above the cube it aims
const HEIGHT := 0.8

## Degrees a second at full stick, and degrees per pixel of mouse drag
const TURN := 150.0
const DRAG := 0.22

## Units the wheel and the stick move it in and out by
const ZOOM_STEP := 1.6
const ZOOM_RATE := 12.0

## How quickly the point it orbits catches up to the cube. The angle is the
## watcher's own and is never smoothed, only the spot it swings around
const FOLLOW := 8.0

## Which seat is looking through this one. It decides two things: whose stick
## turns it, and which piece of a split window it is put into.
##
## -1 is the camera a whole window shares, which is what an online race and a
## race played alone against the CPUs both have
var seat: int = -1

## Where a cube is looked up. Online it is a drawing the ghost field keeps, on one
## screen it is the player itself, and the field is the one node that has both
var field: GhostField = null

var _camera: Camera3D = null

## The account being watched, 0 while nobody is
var _watching: int = 0

## Where the watcher has put the camera: how it looks around whoever is being
## followed, and how far out it sits. It is theirs and not the cube's — being
## locked behind somebody else's shoulder is not watching, it is riding
var _yaw: float = 0.0
var _pitch: float = START_PITCH
var _distance: float = DISTANCE

## The spot the camera swings around, eased so a hopping cube does not shake it
var _pivot := Vector3.ZERO

## True while a mouse button is held, which is what turns a drag into a turn. The
## buttons of whatever is drawn underneath have to keep working, so the mouse is
## never captured for this
var _dragging: bool = false


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.current = false
	add_child(_camera)


func camera() -> Camera3D:
	return _camera


func watching() -> int:
	return _watching


## Takes the view off the player and puts it behind that cube
func watch(account: int) -> void:
	var body := _body_of(account)
	if body == null:
		return

	_watching = account
	_look_through_eyes_of(account)
	_pivot = body.global_position + Vector3.UP * HEIGHT
	_camera.global_position = _pivot + _arm()
	_camera.look_at(_pivot)
	_take_the_view()


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


## Hands the view back to whoever was looking through this
func stop() -> void:
	_watching = 0
	_dragging = false
	_give_the_view_back()


## Whoever this watcher may follow: everybody still walking around in the maze, in
## the order they are ranked, minus the one doing the watching.
##
## Which one that is has to be asked per seat and not per machine. On a split
## screen every cube in the round belongs to this machine, and a list that dropped
## all of them would leave the player who got out first with nobody to watch but
## the CPUs — in a race they had spent the last five minutes running against three
## friends who are all still in there
func watchable() -> Array:
	var found: Array = []

	for runner in Match.standings():
		if _is_me(int(runner["id"])):
			continue

		if not bool(runner["finished"]) and bool(runner["placed"]):
			found.append(runner)

	return found


## True for the cube whose player is the one looking through this camera
func _is_me(account: int) -> bool:
	if seat >= 0:
		return account == Match.account_of_seat(seat)

	return Match.is_mine(account)


## Trails the watched cube from behind and above, and steps on when that cube
## dies, finishes or drops off the network
func _process(delta: float) -> void:
	if _watching == 0:
		return

	var body := _body_of(_watching)
	var runner: Dictionary = Match.runners().get(_watching, {})

	if body == null or runner.is_empty() or bool(runner["finished"]) or not bool(runner["placed"]):
		watch_step(1)
		return

	_read_input(delta)

	var aim := body.global_position + Vector3.UP * HEIGHT
	_pivot = _pivot.lerp(aim, minf(FOLLOW * delta, 1.0))
	_camera.global_position = _pivot + _arm()
	_camera.look_at(_pivot)


## The thing in the level that stands for that account
func _body_of(account: int) -> Node3D:
	return field.body_of(account) if field != null else null


## Hands this camera the watched player's own view of the maze.
##
## In a race everybody reads as their own, every player is looking at a different
## level: their cube is the solid one, their key is the one on the floor, their
## blades are where their run has pushed them to. A watcher who kept their own
## mask would be following a ghost through a maze that has none of that in it and
## watching it die against a blade only the other player can see. So the camera is
## given the mask of whoever it is pointed at, which is the whole of what makes
## this the same picture that player has
func _look_through_eyes_of(account: int) -> void:
	if not Match.is_private_race():
		return

	var watched := Match.seat_of_account(account)
	if watched >= 0:
		_camera.cull_mask = SeatView.mask_for(watched)


## Puts this camera in front of the window, which is the whole of what a race with
## one camera in it needs.
##
## A seat on a split screen is deliberately not answered here. Its piece of the
## window holds a camera that copies a source every frame rather than being told
## which camera is live, so what has to change there is which source it copies —
## and that is the split's own business, not this one's. Whoever asked for the
## watching does it; see SeatResult
func _take_the_view() -> void:
	if seat < 0:
		_camera.make_current()


## The reverse, for a watcher who has seen enough
func _give_the_view_back() -> void:
	if seat >= 0 or Match.is_split():
		return

	var cube := Player.at_seat(get_tree(), 0)
	if cube != null and is_instance_valid(cube.view):
		cube.view.make_current()


## Where the camera sits relative to the spot it is orbiting
func _arm() -> Vector3:
	var yaw := deg_to_rad(_yaw)
	var pitch := deg_to_rad(_pitch)
	var flat := cos(pitch) * _distance

	return Vector3(sin(yaw) * flat, -sin(pitch) * _distance, cos(yaw) * flat)


## The stick, every frame. The mouse comes in as events instead
func _read_input(delta: float) -> void:
	var look := Input.get_vector(_action(&"look_left"), _action(&"look_right"),
		_action(&"look_up"), _action(&"look_down"))

	if look != Vector2.ZERO:
		_turn_by(look.x * TURN * delta * Settings.controller_sensitivity,
			look.y * TURN * delta * Settings.controller_sensitivity)

	var push := Input.get_axis(_action(&"move_forward"), _action(&"move_back"))
	if not is_zero_approx(push):
		_zoom_by(push * ZOOM_RATE * delta)


## That seat's own copy of an action, or the base one for a camera the whole
## window shares. Reading the base action from a split would be every pad in the
## room at once, and one player looking around would swing all four of these
func _action(base: StringName) -> StringName:
	return Seats.action(seat, base) if seat >= 0 else base


func _turn_by(yaw: float, pitch: float) -> void:
	_yaw = wrapf(_yaw - yaw, -180.0, 180.0)
	_pitch = clampf(_pitch - pitch, PITCH_LIMITS.x, PITCH_LIMITS.y)


func _zoom_by(step: float) -> void:
	_distance = clampf(_distance + step, NEAR, FAR)


## Turning with the mouse, but only while a button is held. Whatever is drawn
## underneath has to stay clickable, so the pointer is never taken away
func _unhandled_input(event: InputEvent) -> void:
	if _watching == 0 or not _has_the_mouse():
		return

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton

		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_zoom_by(-ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_zoom_by(ZOOM_STEP)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				_dragging = button.pressed

	elif event is InputEventMouseMotion and _dragging:
		var moved := (event as InputEventMouseMotion).relative
		_turn_by(moved.x * DRAG * Settings.mouse_sensitivity,
			moved.y * DRAG * Settings.mouse_sensitivity)


## True while the one mouse in front of this machine belongs to whoever is
## looking through this camera. There may be four of them and there is one of it
func _has_the_mouse() -> bool:
	return seat < 0 or Seats.uses_mouse(seat)
