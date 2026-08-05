class_name PlayerInventory
extends Node

## What one cube is carrying, and what is running on it.
##
## The item system used to hold both, which is right for as long as there is one
## cube: a slot and a list of effects. Four cubes need four of each, and every
## one of them has to be able to spend what it is holding without touching the
## others — so the slot moves onto the player and the item system keeps what is
## genuinely shared, which is the catalogue of items and the roll that picks one

## Emitted whenever the slot changes, null means the slot is empty now
signal item_changed(item: ItemData)

## Emitted the moment an item is taken out of the slot and used
signal item_used(item: ItemData)

## Emitted once the effect of that item has run out
signal effect_finished(item: ItemData)

const GROUP := &"player_inventory"

## The item this cube carries, only ever one at a time
var held_item: ItemData = null

## The effects that are running on this cube right now, at most one per item.
## They run side by side, the UI draws a ring for each of them
var active_effects: Array[ItemEffect] = []

var _seat: int = 0
var _cube: Player = null


func _ready() -> void:
	add_to_group(GROUP)
	_cube = Player.of(self)
	_seat = _cube.seat if _cube != null else 0
	ItemSystem.adopt(self, _seat)

	if _cube != null and _cube.is_bot:
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Seats.action(_seat, &"use_item")):
		use()


## Puts an item into the slot, whatever was in there is replaced
func grant(item: ItemData) -> void:
	held_item = item
	item_changed.emit(held_item)


## True while there is an item in the slot to spend
func can_use() -> bool:
	return held_item != null


## Spends the item in the slot and starts its effect on this cube. Effects run
## next to each other, a second item does not cut the first one short
func use() -> bool:
	if not can_use() or _cube == null:
		return false

	var item := held_item
	held_item = null
	item_changed.emit(null)

	if not _cube.is_bot:
		GameState.count_item_used()

	ItemSystem.play_use_sound(item)
	_start_effect(item)
	item_used.emit(item)
	return true


## The running effect of that item on this cube, null while it is not up
func find_effect(item: ItemData) -> ItemEffect:
	for effect in active_effects:
		if is_instance_valid(effect) and effect.data == item:
			return effect

	return null


func stop_all(cancelled: bool) -> void:
	for effect in active_effects.duplicate():
		if is_instance_valid(effect):
			effect.stop(cancelled)

	active_effects.clear()


## Spawns the effect on the cube, so it dies together with the player it belongs
## to instead of outliving the run. The same item used twice does not stack, it
## winds its own effect back up — two rush effects would multiply the speed and
## then only take half of it away again
func _start_effect(item: ItemData) -> void:
	var running := find_effect(item)
	if running != null:
		running.restart()
		return

	if item.effect_scene == null:
		push_warning("PlayerInventory: %s has no effect scene, nothing happens" % item.display_name)
		return

	var effect := item.effect_scene.instantiate() as ItemEffect
	if effect == null:
		push_error("PlayerInventory: the effect scene of %s does not extend ItemEffect" \
			% item.display_name)
		return

	effect.data = item
	effect.player = _cube
	effect.seat = _seat
	active_effects.append(effect)
	effect.finished.connect(_on_effect_finished.bind(item, effect))
	_cube.add_child(effect)


func _on_effect_finished(item: ItemData, effect: ItemEffect) -> void:
	active_effects.erase(effect)
	effect_finished.emit(item)
