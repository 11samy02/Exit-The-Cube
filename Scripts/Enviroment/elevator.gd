extends StaticBody3D
class_name Elevator

## Seconds the player takes to slide into the middle of the elevator
@export var snap_duration: float = 0.18

## Playback rate of the door animation, 1.0 is the speed it was authored at
@export var door_speed: float = 2.0

## How far up the cabin travels once the doors are shut
@export var flight_height: float = 40.0

## Seconds the cabin takes to climb that far
@export var flight_duration: float = 1.4

## Seconds between the cabin reaching the top and the summary going up
@export var summary_delay: float = 0.8

## How far apart cubes stand inside the cabin, in meters
const CABIN_RING := 0.6

## The burst a ghost leaves where it stepped in, and how long that lasts
const GHOST_BURST := 2.4
const GHOST_BURST_TIME := 0.55

## How bright the cabin glows while it is still shut
@export var idle_light_energy: float = 1.2

## How bright it goes once the doors are open, the light spilling into the
## corridor is what the player sees from inside the cube
@export var open_light_energy: float = 2.4

## Seconds the cabin takes to brighten
@export var light_fade: float = 0.6

@onready var animation_player: AnimationPlayer = $elevator_bottom/AnimationPlayer
@onready var blocker: CollisionShape3D = $CollisionShape3D
@onready var proximity_area: Area3D = $ProximityArea
@onready var entry_area: Area3D = $EntryArea
@onready var entry_point: Marker3D = $EntryPoint
@onready var inside_light: OmniLight3D = $InsideLight
@onready var locked_sound: AudioStreamPlayer3D = $LockedSound
@onready var open_sound: AudioStreamPlayer3D = $OpenSound
@onready var door_sound: AudioStreamPlayer3D = $DoorSound
@onready var flight_sound: AudioStreamPlayer3D = $FlightSound
@onready var boarding: Label3D = $Boarding

## True once the doors have finished opening
var is_open: bool = false

## True from the moment the cabin leaves, keeps the ride from restarting
var is_riding: bool = false

## Every cube standing in the open cabin right now, by seat.
##
## A set rather than a count, because a player can walk back out again and the
## doors closing behind somebody who left is worse than not closing at all
var _aboard: Dictionary = {}

## When each cube first reached the doors, by seat. What the board is timed on
var _arrived: Dictionary = {}

## Where the cabin stands while it is waiting, so it can be put back after a
## ride that is not the last one
var _resting_y: float = 0.0

## Which seat this cabin belongs to, -1 while it is everybody's.
##
## A race everybody reads as their own gets one lift per player, all in the same
## cell. Each is drawn on its own seat's layer, is solid to its own player alone
## and answers only to them — so a cabin can fly out through the roof with the
## one who earned it while everybody else's still stands there with its doors
## working. The blades, the panes, the keys and the spheres are all handed out
## the same way; this was the last thing in the maze that was not
var seat: int = -1

## The GridMap this elevator was carved into, handed over by the spawner
var grid_map: GridMap = null

## The cell the elevator replaced, the column above it is the way out
var grid_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	inside_light.light_energy = idle_light_energy
	GameState.key_collected.connect(_on_key_collected)
	_show_boarding()


## Hands this cabin to one seat: drawn on that seat's layer only, and solid to
## that player alone. Every other cube walks straight through where it stands.
##
## A bot gets one as well, and its own is neither seen nor heard. What it is for
## is the door: a CPU has to walk up to it, wait for it to open and step in like
## anybody else, instead of being lifted out of the maze the moment it came
## within reach of somebody else's
func claim(owner_seat: int, players: Array[Player]) -> void:
	seat = owner_seat

	if Match.is_bot_seat(owner_seat):
		SeatView.mark(self, 0)
		_go_quiet()
	else:
		SeatView.mark(self, SeatView.private_bit(owner_seat))

	for cube in players:
		if cube.seat != owner_seat:
			add_collision_exception_with(cube)


## A cabin nobody is looking at is a cabin nobody should be hearing either.
## Eleven of them cycling their doors in one cell is not ambience
func _go_quiet() -> void:
	for player: AudioStreamPlayer3D in [locked_sound, open_sound, door_sound, flight_sound]:
		if player != null:
			player.volume_db = -80.0


## True while that cube is one this cabin answers to at all
func _mine(cube: Player) -> bool:
	return cube != null and (seat < 0 or cube.seat == seat)


## Writes down when that cube reached the way out, the first time it does.
##
## This is what a run is timed at, for everybody alike: the moment of stepping
## into the cabin, which everybody now has to wait for their own door to allow.
## What comes after it — the snap, the doors shutting, the flight, the pause
## before the summary — is ceremony, and timing a player through four seconds of
## it while the CPUs behind them were not is how somebody who arrived first came
## eighth on the board
func _stamp_arrival(cube: Player) -> void:
	if _arrived.has(cube.seat):
		return

	_arrived[cube.seat] = GameState.run_time


## When that cube got here, or now if nothing was ever written down for it
func _arrival_of(cube: Player) -> float:
	return float(_arrived.get(cube.seat, GameState.run_time))


## True while every cube rides on its own and the cabin comes back for the next.
##
## That is a local race: one maze, one exit, and a key each. Everywhere else the
## ride is what ends the level — for one player in the campaign, for the room in
## co-op, and online for the one cube on this machine
func _rides_alone() -> bool:
	return Match.kind == Match.Kind.PARTY and Match.mode().with_exit


## True while that cube is carrying what the doors ask for
func _has_key(body: Node3D) -> bool:
	var cube := Player.of(body)
	return Match.has_key(cube.account()) if cube != null else GameState.has_key


## Called by the spawner right after placing the elevator, without it the
## cabin would fly straight into the ceiling
func set_grid_cell(map: GridMap, cell: Vector2i) -> void:
	grid_map = map
	grid_cell = cell


## Rattles at the player without the key, opens up for the player with it
func _on_proximity_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var cube := Player.of(body)

	if cube != null and cube.is_ghosted() and seat < 0:
		if _has_key(body):
			_send_off(cube)

		return

	if is_open or is_riding or not _mine(cube):
		return

	if _has_key(body):
		_open()
	elif not animation_player.is_playing():
		animation_player.play("closed", -1, door_speed)
		locked_sound.play()


## Pulls the cabin light up to its open brightness. The doors were in the way
## until now, so this is the moment the glow reaches the corridor
func _brighten() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(inside_light, "light_energy", open_light_energy, light_fade)


## Covers the case where the key is picked up while already standing here
func _on_key_collected() -> void:
	if is_open:
		return

	for body in proximity_area.get_overlapping_bodies():
		if body.is_in_group("player") and _mine(Player.of(body)) and _has_key(body):
			_open()
			return


## Runs the door animation and only then lets the player through
func _open() -> void:
	is_open = true
	open_sound.play()
	_brighten()
	animation_player.play("open", -1, door_speed)
	await animation_player.animation_finished

	blocker.set_deferred("disabled", true)
	entry_area.set_deferred("monitoring", true)
	_show_boarding()


## A cube stepping into the open cabin. The level ends when the room is out of
## it, not when the first of them is, so the cabin waits for the rest
func _on_entry_area_body_entered(body: Node3D) -> void:
	if is_riding or not body.is_in_group("player") or not _has_key(body):
		return

	var cube := Player.of(body)
	if not _mine(cube):
		return

	_stamp_arrival(cube)

	if cube.is_ghosted():
		_send_off(cube)
		return

	if cube != null and cube.is_bot and _rides_alone():
		_send_off(cube)
		return

	_aboard[cube.seat] = body
	_show_boarding()

	if _everyone_aboard():
		_depart()


## A bot never gets the cabin. The ride is a minute of ceremony for whoever is
## watching it, and holding the one lift in the maze while a CPU takes it would
## put the room's own way out behind a queue of them. In a race read as your own
## it never even reaches the doors — a ghost does not open them
func _send_off(cube: Player) -> void:
	if Match.showing_results(cube.account()):
		return

	BurstRing.burst(get_parent(), cube.global_position, Match.color_of(cube.account()),
		GHOST_BURST, GHOST_BURST_TIME)

	Match.finish(cube.account(), _arrival_of(cube))
	cube.queue_free()


func _on_entry_area_body_exited(body: Node3D) -> void:
	if is_riding or not body.is_in_group("player"):
		return

	_aboard.erase(Player.of(body).seat)
	_show_boarding()


## Nobody is left behind. Every seat has to be in the cabin and on its feet —
## the ride is what ends the level, and a cube four seconds from coming back
## would have the level ended without it
func _everyone_aboard() -> bool:
	if _rides_alone():
		return not _aboard.is_empty()

	if _aboard.size() < maxi(Seats.count(), 1):
		return false

	var coop := CoopCoordinator.find(get_tree())
	return coop == null or coop.everyone_alive()


## The height the cabin has to come back to is read here rather than when the
## node was built. The spawner adds the elevator and only then carves it into the
## wall, so at _ready it is still standing at the origin — and a cabin that came
## back down to that sank into the floor of the maze the moment the first player
## had ridden it
func _depart() -> void:
	_resting_y = global_position.y
	is_riding = true
	entry_area.set_deferred("monitoring", false)
	_show_boarding()
	_ride(_aboard.values())


## How much of the room is in the cabin, for the last player to see that the
## level is waiting on them.
##
## Only once the doors are open. Before that there is nothing to board and the
## count would be a number hanging over the far end of the maze from the first
## second of the level
func _show_boarding() -> void:
	if boarding == null:
		return

	boarding.visible = Seats.count() > 1 and is_open and not is_riding and not _rides_alone()
	boarding.text = "%d / %d" % [_aboard.size(), Seats.count()]


## Pulls everybody who is riding onto the platform and closes the doors again.
## Only the horizontal position is snapped, the height stays whatever the floor
## under each cube is
func _ride(riders: Array) -> void:
	var snap := create_tween()
	snap.set_parallel(true)
	snap.set_ease(Tween.EASE_OUT)
	snap.set_trans(Tween.TRANS_CUBIC)

	for at in range(riders.size()):
		var cube := Player.of(riders[at])
		if cube == null:
			continue

		cube.movement.disable()
		cube.perspective.lock_to_third_person()

		var target := entry_point.global_position + _cabin_offset(at, riders.size())
		target.y = cube.global_position.y
		snap.tween_property(cube, "global_position", target, snap_duration)

	await snap.finished

	GameState.enter_elevator()
	animation_player.play("open", -1, -door_speed, true)
	door_sound.play()
	await animation_player.animation_finished

	for rider in riders:
		var cube := Player.of(rider)
		if cube != null:
			cube.perspective.hide_mesh()

	_open_ceiling()
	await _fly_up(riders)
	_win(riders)


## Where each rider stands in the cabin. One of them takes the middle, and a
## room spreads out around it rather than standing inside each other
func _cabin_offset(at: int, total: int) -> Vector3:
	if total <= 1:
		return Vector3.ZERO

	var around := TAU * float(at) / float(total)
	return Vector3(cos(around), 0.0, sin(around)) * CABIN_RING


## Takes out every block stacked above the elevator, so the roof tile over the
## cabin is gone before it starts climbing
func _open_ceiling() -> void:
	if grid_map == null:
		return

	var top := 0
	for cell in grid_map.get_used_cells():
		if cell.x == grid_cell.x and cell.z == grid_cell.y:
			top = maxi(top, cell.y)

	for y in range(1, top + 1):
		grid_map.set_cell_item(Vector3i(grid_cell.x, y, grid_cell.y), GridMap.INVALID_CELL_ITEM)


## Lifts the cabin and the player standing in it up through the opened roof,
## the engine fades in with the climb and back out at the top
func _fly_up(riders: Array) -> void:
	flight_sound.volume_db = -30.0
	flight_sound.play()

	var flight := create_tween()
	flight.set_parallel(true)
	flight.set_ease(Tween.EASE_IN)
	flight.set_trans(Tween.TRANS_CUBIC)
	flight.tween_property(self, "global_position:y",
		global_position.y + flight_height, flight_duration)

	for rider in riders:
		var cube := rider as Node3D
		flight.tween_property(cube, "global_position:y", \
			cube.global_position.y + flight_height, flight_duration)

	flight.tween_property(flight_sound, "volume_db", 0.0, flight_duration * 0.5)
	flight.tween_property(flight_sound, "volume_db", -40.0, flight_duration * 0.4).set_delay(flight_duration * 0.6)
	await flight.finished

	flight_sound.stop()


## The run is over. Stopping the clock puts the summary up, what happens to the
## map after that is up to whichever button the player presses there.
##
## A local race ends one cube's run rather than the level: the others are still in
## the maze, and whether anything has to be done about that depends on whose lift
## this was. One the whole room shares goes back down for the next player. One that
## belongs to a single seat has carried the only cube it will ever answer to and
## stays exactly where it stopped — sending it back would drop it out from under
## the player standing in it, which on their half of the screen is the level
## rebuilding itself around a race they had just won
func _win(riders: Array) -> void:
	await get_tree().create_timer(summary_delay).timeout

	if not _rides_alone():
		GameState.finish_run()
		return

	for rider in riders:
		var cube := Player.of(rider)
		if cube != null:
			Match.finish(cube.account(), _arrival_of(cube))

	if seat < 0:
		_return()


## Brings a shared cabin back down for whoever is still running.
##
## The hole in the roof stays open. Putting the blocks back would be wrong twice
## over: the next cube needs the same shaft, and the one already out of the maze
## is standing in it
func _return() -> void:
	_aboard.clear()

	var drop := create_tween()
	drop.set_ease(Tween.EASE_IN_OUT)
	drop.set_trans(Tween.TRANS_CUBIC)
	drop.tween_property(self, "global_position:y", _resting_y, flight_duration)
	await drop.finished

	if not is_inside_tree():
		return

	animation_player.play("closed", -1, door_speed)
	blocker.set_deferred("disabled", false)
	is_open = false
	is_riding = false
	inside_light.light_energy = idle_light_energy
	_show_boarding()
