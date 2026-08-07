extends Node

## The catalogue of items, the roll that picks one out of it, and the sound
## spending one makes.
##
## What a cube is carrying used to live here as well, which is right for as long
## as there is one cube. Four of them need a slot each, so that moved onto the
## player as a PlayerInventory. The two properties below still answer for the
## first seat, because everything that was written when there was only ever one
## cube reads them and is still right on a screen that has only one

## Emitted whenever the first seat's slot changes, null means it is empty now
signal item_changed(item: ItemData)

## Emitted the moment an item is taken out of any slot and used
signal item_used(item: ItemData)

## Emitted once the effect of that item has run out
signal effect_finished(item: ItemData)

## Emitted when a run ends and everything that was up is torn down. An effect
## dies together with the player it hangs on, so a death frees it without it
## ever reporting itself as finished
signal effects_cleared

## What the first cube on this machine is carrying
var held_item: ItemData:
	get:
		var mine := primary()
		return mine.held_item if mine != null else null

## What is running on that cube. Handed back empty rather than null, so a caller
## may loop over it without asking first
var active_effects: Array[ItemEffect]:
	get:
		var mine := primary()
		return mine.active_effects if mine != null else _no_effects

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

## Stands in for the effects of a cube that is not in the level right now
var _no_effects: Array[ItemEffect] = []


func _ready() -> void:
	rng.randomize()
	_load_items()
	_create_sound_player()


## The inventory of the first seat, which is what everything written for a single
## cube means when it says "the player"
func primary() -> PlayerInventory:
	return inventory_of_seat(0)


func inventory_of_seat(seat: int) -> PlayerInventory:
	var cube := Player.at_seat(get_tree(), seat)
	return cube.inventory if cube != null else null


## Rolls a fresh item into a slot, an item that is still in there is replaced.
## Called by the item sphere the moment a player runs into it, and the body that
## ran into it is whose slot is filled. Only returns null when the project has no
## items at all
func grant_random_item(body: Node = null) -> ItemData:
	if items.is_empty():
		push_warning("ItemSystem: no items in %s, the sphere has nothing to hand out" % ItemData.FOLDER)
		return null

	var cube := Player.of(body) if body != null else Player.at_seat(get_tree(), 0)
	var target := cube.inventory if cube != null else null
	if target == null:
		return null

	var rolled := _roll_item(available_items(target))
	repeat_streak = repeat_streak + 1 if rolled == last_granted else 1
	last_granted = rolled

	target.grant(rolled)
	Match.count_item(cube.account())
	return rolled


## Everything the next sphere is allowed to hand out. The item that is already
## carried is left out so a pickup always changes what is in the slot, and an
## item that just came up max_in_a_row times is left out as well. Neither is a
## contingent, so this only ever narrows the roll and never empties it, unless
## the project has a single item to begin with
func available_items(holder: PlayerInventory = null) -> Array[ItemData]:
	var carried: ItemData = holder.held_item if holder != null else held_item
	var pool: Array[ItemData] = []

	for item in items:
		if item == carried:
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


## Empties every slot, kills every running effect and forgets what was rolled
## last, called whenever a map is built. The pool goes back to the full folder
## as well, the level narrows it down again right after and one that does not
## would otherwise inherit the restriction of the level before
func reset() -> void:
	stop_all_effects(true)
	items = all_items.duplicate()
	last_granted = null
	repeat_streak = 0
	item_changed.emit(null)
	effects_cleared.emit()


func stop_all_effects(cancelled: bool) -> void:
	for node in get_tree().get_nodes_in_group(PlayerInventory.GROUP):
		var holder := node as PlayerInventory
		holder.stop_all(cancelled)
		holder.grant(null)


## Every inventory reports through here as it comes up, so anything that only
## ever cared that an item was used at all still hears about it whichever cube
## did it. The slot signal stays the first seat's, it is what the shared HUD draws
func adopt(holder: PlayerInventory, seat: int) -> void:
	holder.item_used.connect(func(item: ItemData) -> void: item_used.emit(item))
	holder.effect_finished.connect(func(item: ItemData) -> void: effect_finished.emit(item))

	if seat == 0:
		holder.item_changed.connect(func(item: ItemData) -> void: item_changed.emit(item))


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


func play_use_sound(item: ItemData) -> void:
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
