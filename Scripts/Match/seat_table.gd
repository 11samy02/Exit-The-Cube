extends Node
class_name SeatTable

## Who is sitting at this machine, and which device each of them is holding.
##
## Godot's input map answers a question about the whole machine — is the left
## stick pushed left — which is exactly right for one player and useless for
## four. An action's events may carry a device though, and the map only matches
## an event against a stored one when the stored device is ALL_DEVICES or the
## same number. So when more than one seat is taken, every action a player drives
## is copied once per seat with that seat's pad written into the copy, and each
## cube reads its own copy.
##
## Copying rather than reading the raw axes is what keeps the rest of the game
## as it was: the deadzones stay the ones tuned in the project, is_action_pressed
## keeps working, and a rebind in the options is still the one place a binding
## lives — the copies are simply built again off the base action

## A seat was taken or given up
signal seats_changed

## The seats are set and the copies are in the input map
signal seats_locked

## What a seat is playing on. One keyboard exists, so at most one seat may be on
## it; a pad is told apart by its device number
enum Source { NONE, KEYBOARD, PAD }

const MAX_SEATS := 4

## The prefix every copied action carries. The options filter on it, so a rebind
## cannot see a copy as a conflict with the very action it was made from
const PREFIX := "seat"

## Which actions a seat owns a private copy of. `pause` is deliberately not one
## of them: any pad in the room may open the menu
const SEAT_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"look_left", &"look_right", &"look_up", &"look_down",
	&"toggle_perspective", &"use_item",
]

## Fixed and far apart, so a glance at a split screen says whose cube is whose.
## The hashed ghost colour is no use here — four accounts a seat apart land on
## four shades of the same red
const COLORS: Array[Color] = [
	Color(0.20, 0.85, 1.00),
	Color(1.00, 0.45, 0.25),
	Color(0.45, 1.00, 0.45),
	Color(1.00, 0.40, 0.85),
]


## One player at this machine. The index is its place in the list and nothing
## else, so giving a seat up closes the gap behind it
class Seat:
	var index: int = 0
	var source: int = 0
	var device: int = -1


var seats: Array[Seat] = []

## True once the copies are in the map. Until then every seat still drives the
## base actions, which is what the seat select screen needs
var locked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.bindings_changed.connect(_rebuild_actions)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func count() -> int:
	return seats.size()


func seat_at(index: int) -> Seat:
	return seats[index] if index >= 0 and index < seats.size() else null


## The account that seat is filed under everywhere a round keeps score
func account_of(index: int) -> int:
	return Player.account_for(index)


func accounts() -> Array[int]:
	var found: Array[int] = []

	for seat in seats:
		found.append(account_of(seat.index))

	return found


func color_of(index: int) -> Color:
	return COLORS[index % COLORS.size()]


## True for the one seat that may look with the mouse
func uses_mouse(index: int) -> bool:
	var seat := seat_at(index)
	return seat != null and seat.source == Source.KEYBOARD


## Which half of the options that seat's bindings come from
func slot_of(index: int) -> int:
	return Settings.SLOT_KEYBOARD if uses_mouse(index) else Settings.SLOT_GAMEPAD


func device_of(index: int) -> int:
	var seat := seat_at(index)
	return seat.device if seat != null else -1


func is_pad_taken(device: int) -> bool:
	for seat in seats:
		if seat.source == Source.PAD and seat.device == device:
			return true

	return false


func has_keyboard_seat() -> bool:
	for seat in seats:
		if seat.source == Source.KEYBOARD:
			return true

	return false


## Sits that pad down, and says which seat it got. -1 when the room is full or
## the pad already has one
func claim_pad(device: int) -> int:
	if locked or seats.size() >= MAX_SEATS or is_pad_taken(device):
		return -1

	return _add(Source.PAD, device)


func claim_keyboard() -> int:
	if locked or seats.size() >= MAX_SEATS or has_keyboard_seat():
		return -1

	return _add(Source.KEYBOARD, -1)


func _add(source: int, device: int) -> int:
	var seat := Seat.new()
	seat.index = seats.size()
	seat.source = source
	seat.device = device
	seats.append(seat)
	seats_changed.emit()
	return seat.index


## Gives a seat up and closes the gap behind it. The indices have to stay a run
## from zero — a cube is found by its seat, and a hole in the middle would leave
## the fourth player looking for a third that is not there
func release(index: int) -> void:
	if locked or index < 0 or index >= seats.size():
		return

	seats.remove_at(index)
	_reindex()
	seats_changed.emit()


func seat_of_device(device: int) -> int:
	for seat in seats:
		if seat.source == Source.PAD and seat.device == device:
			return seat.index

	return -1


func seat_of_keyboard() -> int:
	for seat in seats:
		if seat.source == Source.KEYBOARD:
			return seat.index

	return -1


func clear() -> void:
	unlock()
	seats.clear()
	seats_changed.emit()


## Freezes the room and puts the copies into the map
func lock() -> void:
	if seats.is_empty():
		return

	locked = true
	_rebuild_actions()
	seats_locked.emit()


func unlock() -> void:
	locked = false
	_drop_actions()


## The action that seat drives. One seat is the game as it always was — the base
## action itself, with no copies in the map at all
func action(index: int, base: StringName) -> StringName:
	if not locked or seats.size() <= 1:
		return base

	return StringName("%s%d_%s" % [PREFIX, index, base])


## Builds one private copy of every seat action per seat, carrying only the
## events of that seat's own half of the options and, for a pad, its own device.
##
## Run again whenever a binding changes, so a key remapped in the options is the
## same key in all four copies a moment later
func _rebuild_actions() -> void:
	_drop_actions()

	if not locked or seats.size() <= 1:
		return

	for seat in seats:
		var slot := slot_of(seat.index)

		for base in SEAT_ACTIONS:
			if not InputMap.has_action(base):
				continue

			var name := action(seat.index, base)
			InputMap.add_action(name, InputMap.action_get_deadzone(base))

			for event in InputMap.action_get_events(base):
				if Settings.slot_of(event) != slot:
					continue

				var copy := event.duplicate()
				if slot == Settings.SLOT_GAMEPAD:
					copy.device = seat.device

				InputMap.action_add_event(name, copy)


func _drop_actions() -> void:
	for existing in InputMap.get_actions():
		if String(existing).begins_with(PREFIX):
			InputMap.erase_action(existing)


func _reindex() -> void:
	for at in range(seats.size()):
		seats[at].index = at


## A pad that was unplugged takes its seat with it. Leaving the seat behind
## would leave a cube in the level nobody can move
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return

	var at := seat_of_device(device)
	if at < 0:
		return

	if locked:
		return

	release(at)
