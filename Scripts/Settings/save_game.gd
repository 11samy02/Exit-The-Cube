extends Node

## How far the campaign got. One slot per way of playing it, written every time a
## level is cleared and read by the continue button on the title screen.
##
## Two people playing through the game together are not playing the campaign one
## of them started alone, so a co-op clear must never move somebody else's
## continue point. The fields below are always the slot that is being played;
## switching slots puts the old one away and brings the other one out, which is
## why nothing that reads them had to learn about any of this

const SAVE_PATH := "user://save.cfg"

## What a record holds while nobody has walked that level out on their own hands
## yet. A level a CPU cleared has a stamp and an unlocked one after it, and these
## two — the selection reads them and shows a dash instead of a number
const NO_TIME := INF
const NO_DEATHS := 9999

## Which campaign is being played
enum Slot { SOLO, COOP }

## Where each slot is written in the file
const SECTIONS := {
	Slot.SOLO: ["campaign", "run"],
	Slot.COOP: ["campaign_coop", "run_coop"],
}

var slot: int = Slot.SOLO

## The level a continue picks the campaign up at, -1 while there is nothing to
## pick up
var level_index: int = -1

## The tally of the run the slot was written from. A campaign is counted over
## all of its levels, so a continue has to carry these back into the run or the
## summary at the end would only show what happened after the last load
var deaths: int = 0
var run_time: float = 0.0
var items_collected: int = 0
var items_used: int = 0

## The best a level was ever cleared in, by its place in the campaign:
## { "time": float, "deaths": int, "helped": bool }. The two numbers are kept
## apart on purpose, the fastest way through a level is rarely also the cleanest
## one — and the flag says the only clear it ever got was one a CPU finished
var records: Dictionary = {}

## Every slot that is not the one being played, by its enum value
var _slots: Dictionary = {}


## The slot is written off the run that just ended, so it is listened for here
## instead of every place that finishes a level having to remember to save
func _ready() -> void:
	_load()
	GameState.run_finished.connect(_on_run_finished)


## Puts the slot that was being played away and brings another one out. Called
## before anything reads has_save or unlocked_picks, so the title screen and the
## level selection show the campaign that is about to be played
func use_slot(new_slot: int) -> void:
	if new_slot == slot:
		return

	_stash()
	slot = new_slot
	_unstash()


## Keeps the slot that is being left, so switching back and forth does not need
## the file
func _stash() -> void:
	_slots[slot] = {
		"level_index": level_index,
		"deaths": deaths,
		"run_time": run_time,
		"items_collected": items_collected,
		"items_used": items_used,
		"records": records,
	}


func _unstash() -> void:
	var held: Dictionary = _slots.get(slot, {})
	level_index = int(held.get("level_index", -1))
	deaths = int(held.get("deaths", 0))
	run_time = float(held.get("run_time", 0.0))
	items_collected = int(held.get("items_collected", 0))
	items_used = int(held.get("items_used", 0))
	records = held.get("records", {})


## True while there is a level left to pick up. A campaign that was played to
## the end has nothing to continue into, its levels can still be picked
func has_save() -> bool:
	return level_index >= 0 and level_index < Levels.count()


## What that level was ever cleared in at best, empty while it never was
func record_of(index: int) -> Dictionary:
	return records.get(index, {})


## True while every clear that level ever got was one a CPU played out. Walking
## it yourself takes the stamp back off — the mark is about the level still owing
## you a clean run, not about ever having asked for a hand
func was_helped(index: int) -> bool:
	return bool(record_of(index).get("helped", false))


## How many levels of the campaign may be picked, counted from the front. Every
## level up to and including the one a continue would open is cleared ground
func unlocked_levels() -> int:
	if level_index < 0:
		return 0

	return mini(level_index + 1, Levels.count())


## How many of the levels the selection lists are open. The tutorials are not
## listed, so a player who has not come past them yet has nothing to pick and
## the selection is not worth opening
func unlocked_picks() -> int:
	return picks_under(unlocked_levels())


## How many of the listed levels sit below that point in the campaign
func picks_under(levels: int) -> int:
	var open := 0

	for level in Levels.selectable():
		if level < levels:
			open += 1

	return open


## How far the campaign has been played in any slot at all.
##
## The co-op campaign keeps its own continue point, which is right — a room
## should not overwrite somebody's solo run. But it also meant a room sitting
## down together started from nothing however far the player had already come,
## and had no level selection to open. What one way of playing has cleared is
## open to the other; only the continue point stays private to its slot
func best_unlocked_levels() -> int:
	var best := level_index

	for other: int in _slots:
		best = maxi(best, int((_slots[other] as Dictionary).get("level_index", -1)))

	if best < 0:
		return 0

	return mini(best + 1, Levels.count())


func best_unlocked_picks() -> int:
	return picks_under(best_unlocked_levels())


## Writes the slot at that level, with the run as it stands right now
func store(next_level: int) -> void:
	level_index = next_level
	deaths = GameState.deaths
	run_time = GameState.run_time
	items_collected = GameState.items_collected
	items_used = GameState.items_used
	_write()


## Puts the saved tally back into the run, called after the campaign was opened
## at the saved level. The run itself has to be started before this
func restore() -> void:
	GameState.deaths = deaths
	GameState.run_time = run_time
	GameState.items_collected = items_collected
	GameState.items_used = items_used
	GameState.death_count_changed.emit(deaths)


## Empties the slot, a campaign that was played to the end has nothing left to
## continue into
func clear() -> void:
	level_index = -1
	deaths = 0
	run_time = 0.0
	items_collected = 0
	items_used = 0
	_write()


## The elevator carried the player out of a level. What a continue opens is the
## level after the cleared one, so the slot is written one ahead.
##
## The slot only ever moves forward. A level picked again from the selection is
## cleared a second time, and that must not push the campaign back to it
func _on_run_finished() -> void:
	if not Levels.is_running():
		return

	_remember(Levels.index, GameState.level_time(), GameState.level_deaths(),
		GameState.level_was_helped)

	if Levels.index + 1 > level_index:
		store(Levels.index + 1)
	else:
		_write()


## Keeps whichever of the two numbers this run beat, and whether the level still
## owes the player a clear of their own.
##
## A run a CPU played out leaves both numbers exactly where they were. They are
## the player's record of what they did with that level and nothing else belongs
## in them — a time somebody watched somebody else set is not a best time, and
## putting it there would quietly take the level's own record away from them.
##
## The stamp only survives a clear that was also helped. One run walked out on
## the player's own hands takes it off for good, and it can never come back —
## which is the whole point of it: it marks a level that has not been beaten yet,
## not a level somebody once accepted help on
func _remember(index: int, time: float, deaths_taken: int, helped: bool) -> void:
	var record: Dictionary = records.get(index, {})
	var best_time := float(record.get("time", INF))
	var fewest := int(record.get("deaths", NO_DEATHS))

	records[index] = {
		"time": best_time if helped else minf(time, best_time),
		"deaths": fewest if helped else mini(deaths_taken, fewest),
		"helped": helped and bool(record.get("helped", true)),
	}


## Both slots go into the one file, each under its own pair of sections. A save
## written before co-op existed only has the solo pair and loads unchanged
func _write() -> void:
	_stash()

	var config := ConfigFile.new()

	for which: int in SECTIONS:
		var held: Dictionary = _slots.get(which, {})
		if held.is_empty():
			continue

		var sections: Array = SECTIONS[which]
		config.set_value(sections[0], "level_index", held["level_index"])
		config.set_value(sections[0], "records", held["records"])
		config.set_value(sections[1], "deaths", held["deaths"])
		config.set_value(sections[1], "run_time", held["run_time"])
		config.set_value(sections[1], "items_collected", held["items_collected"])
		config.set_value(sections[1], "items_used", held["items_used"])

	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	for which: int in SECTIONS:
		var sections: Array = SECTIONS[which]
		_slots[which] = {
			"level_index": int(config.get_value(sections[0], "level_index", -1)),
			"records": config.get_value(sections[0], "records", {}),
			"deaths": int(config.get_value(sections[1], "deaths", 0)),
			"run_time": float(config.get_value(sections[1], "run_time", 0.0)),
			"items_collected": int(config.get_value(sections[1], "items_collected", 0)),
			"items_used": int(config.get_value(sections[1], "items_used", 0)),
		}

	_unstash()
