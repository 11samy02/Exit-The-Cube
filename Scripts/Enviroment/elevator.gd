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

## True once the doors have finished opening
var is_open: bool = false

## True from the moment the player steps in, keeps the ride from restarting
var is_riding: bool = false

## The GridMap this elevator was carved into, handed over by the spawner
var grid_map: GridMap = null

## The cell the elevator replaced, the column above it is the way out
var grid_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	inside_light.light_energy = idle_light_energy
	GameState.key_collected.connect(_on_key_collected)


## Called by the spawner right after placing the elevator, without it the
## cabin would fly straight into the ceiling
func set_grid_cell(map: GridMap, cell: Vector2i) -> void:
	grid_map = map
	grid_cell = cell


## Rattles at the player without the key, opens up for the player with it
func _on_proximity_area_body_entered(body: Node3D) -> void:
	if is_open or not body.is_in_group("player"):
		return

	if GameState.has_key:
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
		if body.is_in_group("player"):
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


## The player stepping into the open cabin, the ride starts right away
func _on_entry_area_body_entered(body: Node3D) -> void:
	if is_riding or not body.is_in_group("player"):
		return

	is_riding = true
	entry_area.set_deferred("monitoring", false)
	_ride(body)


## Pulls the player onto the center of the platform and closes the doors again.
## Only the horizontal position is snapped, the height stays whatever the
## floor under the player is.
func _ride(player: Node3D) -> void:
	var movement := get_tree().get_first_node_in_group("player_movement") as PlayerMovement
	if movement != null:
		movement.disable()

	var perspective := get_tree().get_first_node_in_group("player_perspective") as PlayerPerspective
	if perspective != null:
		perspective.lock_to_third_person()

	var target := entry_point.global_position
	target.y = player.global_position.y

	var snap := create_tween()
	snap.set_ease(Tween.EASE_OUT)
	snap.set_trans(Tween.TRANS_CUBIC)
	snap.tween_property(player, "global_position", target, snap_duration)
	await snap.finished

	GameState.enter_elevator()
	animation_player.play("open", -1, -door_speed, true)
	door_sound.play()
	await animation_player.animation_finished

	if perspective != null:
		perspective.hide_mesh()

	_open_ceiling()
	await _fly_up(player)
	_win()


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
func _fly_up(player: Node3D) -> void:
	flight_sound.volume_db = -30.0
	flight_sound.play()

	var flight := create_tween()
	flight.set_parallel(true)
	flight.set_ease(Tween.EASE_IN)
	flight.set_trans(Tween.TRANS_CUBIC)
	flight.tween_property(self, "global_position:y", global_position.y + flight_height, flight_duration)
	flight.tween_property(player, "global_position:y", player.global_position.y + flight_height, flight_duration)
	flight.tween_property(flight_sound, "volume_db", 0.0, flight_duration * 0.5)
	flight.tween_property(flight_sound, "volume_db", -40.0, flight_duration * 0.4).set_delay(flight_duration * 0.6)
	await flight.finished

	flight_sound.stop()


## The run is over. Stopping the clock puts the summary up, what happens to the
## map after that is up to whichever button the player presses there
func _win() -> void:
	await get_tree().create_timer(summary_delay).timeout
	GameState.finish_run()
