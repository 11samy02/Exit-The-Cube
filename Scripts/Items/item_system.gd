extends Node

## Emitted whenever the slot changes, null means the slot is empty now
signal item_changed(item: ItemData)

## Emitted the moment an item is taken out of the slot and used
signal item_used(item: ItemData)

## Emitted once the effect of that item has run out
signal effect_finished(item: ItemData)

## Emitted when a run ends and everything that was up is torn down. An effect
## dies together with the player it hangs on, so a death frees it without it
## ever reporting itself as finished
signal effects_cleared

## The item the player carries, only ever one at a time
var held_item: ItemData = null

## The effects that are running right now, at most one per item. They run
## side by side, the UI draws a ring for each of them
var active_effects: Array[ItemEffect] = []

## Every item that was found in the folder, whether the level allows it or not
var all_items: Array[ItemData] = []

## The same items under the id a level picks them by, their file name
var items_by_id: Dictionary = {}

## Every item a sphere can roll right now, a level may narrow this down to a
## handful of them
var items: Array[ItemData] = []

## The item the last sphere handed out, the repeat filter works off it
var last_granted: ItemData = null

## How often that item came up in a row
var repeat_streak: int = 0

var rng := RandomNumberGenerator.new()

var use_sound: AudioStreamPlayer = null


func _ready() -> void:
	rng.randomize()
	_load_items()
	_create_sound_player()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item"):
		use_held_item()


## Rolls a fresh item into the slot, an item that is still in there is replaced.
## Called by the item sphere the moment the player runs into it. Only returns
## null when the project has no items at all
func grant_random_item() -> ItemData:
	if items.is_empty():
		push_warning("ItemSystem: no items in %s, the sphere has nothing to hand out" % ItemData.FOLDER)
		return null

	var rolled := _roll_item(available_items())
	repeat_streak = repeat_streak + 1 if rolled == last_granted else 1
	last_granted = rolled

	held_item = rolled
	item_changed.emit(held_item)
	return held_item


## Everything the next sphere is allowed to hand out. The item that is already
## carried is left out so a pickup always changes what is in the slot, and an
## item that just came up max_in_a_row times is left out as well. Neither is a
## contingent, so this only ever narrows the roll and never empties it, unless
## the project has a single item to begin with
func available_items() -> Array[ItemData]:
	var pool: Array[ItemData] = []

	for item in items:
		if item == held_item:
			continue
		if item == last_granted and item.max_in_a_row > 0 and repeat_streak >= item.max_in_a_row:
			continue

		pool.append(item)

	return pool if not pool.is_empty() else items


## The file name that item is filed under, empty for one that is not in the
## folder. It is what a level picks an item by, so it is also what everything
## else that has to tell them apart goes by
func id_of(item: ItemData) -> String:
	for id: String in items_by_id:
		if items_by_id[id] == item:
			return id

	return ""


## True while there is an item in the slot to spend
func can_use_item() -> bool:
	return held_item != null


## Spends the item in the slot and starts its effect on the player. Effects
## run next to each other, a second item does not cut the first one short
func use_held_item() -> bool:
	if not can_use_item():
		return false

	var target := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if target == null:
		return false

	var item := held_item
	held_item = null
	item_changed.emit(null)

	GameState.count_item_used()
	_play_use_sound(item)
	_start_effect(item, target)
	item_used.emit(item)
	return true


## Empties the slot, kills every running effect and forgets what was rolled
## last, called whenever a map is built. The pool goes back to the full folder
## as well, the level narrows it down again right after and one that does not
## would otherwise inherit the restriction of the level before
func reset() -> void:
	stop_all_effects(true)
	items = all_items.duplicate()
	last_granted = null
	repeat_streak = 0
	held_item = null
	item_changed.emit(null)
	effects_cleared.emit()


## The running effect of that item, null while it is not up
func find_effect(item: ItemData) -> ItemEffect:
	for effect in active_effects:
		if is_instance_valid(effect) and effect.data == item:
			return effect

	return null


func stop_all_effects(cancelled: bool) -> void:
	for effect in active_effects.duplicate():
		if is_instance_valid(effect):
			effect.stop(cancelled)

	active_effects.clear()


## Spawns the effect on the player, so it dies together with the player it
## belongs to instead of outliving the run. The same item used twice does not
## stack, it winds its own effect back up. Two rush effects would multiply the
## speed and then only take half of it away again
func _start_effect(item: ItemData, target: CharacterBody3D) -> void:
	var running := find_effect(item)
	if running != null:
		running.restart()
		return

	if item.effect_scene == null:
		push_warning("ItemSystem: %s has no effect scene, nothing happens" % item.display_name)
		return

	var effect := item.effect_scene.instantiate() as ItemEffect
	if effect == null:
		push_error("ItemSystem: the effect scene of %s does not extend ItemEffect" % item.display_name)
		return

	effect.data = item
	effect.player = target
	active_effects.append(effect)
	effect.finished.connect(_on_effect_finished.bind(item, effect))
	target.add_child(effect)


func _on_effect_finished(item: ItemData, effect: ItemEffect) -> void:
	active_effects.erase(effect)
	effect_finished.emit(item)


## Cuts the pool down to the items the level lists, everything else stops
## coming up until the next map. An empty list is read as no preference at all
## and puts the whole folder back in, a level that lists nothing is far more
## likely to be an unfilled field than a level that wants no items
func set_item_pool(ids: Array[String]) -> void:
	items.clear()

	for id in ids:
		if not items_by_id.has(id):
			push_warning("ItemSystem: the level asks for the item %s, %s has no such file" \
				% [id, ItemData.FOLDER])
			continue

		var item: ItemData = items_by_id[id]
		if not items.has(item):
			items.append(item)

	if items.is_empty():
		items = all_items.duplicate()


## Reads the item folder once on start, an item is filed under its own file
## name because that is what a level picks it by
func _load_items() -> void:
	all_items.clear()
	items_by_id.clear()

	for id in ItemData.list_ids():
		var path := ItemData.path_for(id)
		var item := load(path) as ItemData
		if item == null:
			push_warning("ItemSystem: %s is not an ItemData, skipped" % path)
			continue

		all_items.append(item)
		items_by_id[id] = item

	items = all_items.duplicate()

	if all_items.is_empty():
		push_warning("ItemSystem: no items found in %s, the spheres have nothing to hand out" % ItemData.FOLDER)


## One shared player, the item is gone from the world when it is used so it
## cannot carry its own sound
func _create_sound_player() -> void:
	use_sound = AudioStreamPlayer.new()
	use_sound.bus = &"sfx" if AudioServer.get_bus_index("sfx") >= 0 else &"Master"
	add_child(use_sound)


func _play_use_sound(item: ItemData) -> void:
	if item.use_sound == null:
		return

	use_sound.stream = item.use_sound
	use_sound.play()


## Draws one item, an item with twice the weight comes up twice as often
func _roll_item(pool: Array[ItemData]) -> ItemData:
	var total := 0.0
	for item in pool:
		total += maxf(item.weight, 0.0)

	if total <= 0.0:
		return pool[rng.randi_range(0, pool.size() - 1)]

	var roll := rng.randf() * total
	for item in pool:
		roll -= maxf(item.weight, 0.0)
		if roll <= 0.0:
			return item

	return pool[pool.size() - 1]
