extends Node

## Emitted the moment the player runs into the key
signal key_collected

## Emitted once the player has stepped into the open elevator
signal elevator_entered

## Emitted after a death, the UI counts the attempts with it
signal death_count_changed(deaths: int)

## Emitted when the ride out is over, the summary screen goes up on it
signal run_finished

## The level that is being played, the UI reads its name and its hint off it
var level: MapData = null

## True while the player carries the key, read by the elevator and the UI
var has_key: bool = false

## How often the player died so far, this one outlives the scene reload
var deaths: int = 0

## Seconds the run took, every attempt of it added up
var run_time: float = 0.0

## Item spheres the player ran into over the whole run
var items_collected: int = 0

## How many of those were spent instead of carried to the exit
var items_used: int = 0

## True while the clock runs, a finished run keeps its time for the summary
var is_running: bool = false

## Where the tally stood when the level on screen was opened. A run counts over
## the whole campaign, so a single level is whatever has been added since. The
## marks stay put over a death, that attempt belongs to the level as well
var level_start_time: float = 0.0
var level_start_deaths: int = 0

## True once a CPU was put on the level that is being played. It belongs to the
## level rather than to the run: it survives a rebuild the way the death tally
## does, and it is wiped as soon as another level is opened. What reads it is the
## save, which stamps a level that was not cleared on the player's own
var level_was_helped: bool = false

## True while a CPU is meant to be driving this level, which is not the same
## question. The stamp above is about the level's history and never comes off
## once it is on; this is about right now, and a player who took the cube back off
## the CPU turns it off — otherwise the next death would hand it straight over
## again, which is the game arguing with somebody who has said what they want
var level_cpu_driving: bool = false

## The highest death count this level has already made the offer at. The offer is
## made again as things get worse rather than once and never, so this is what
## keeps each of those marks to a single asking
var level_offer_mark: int = 0

## The view the player last switched to. A death reloads the scene and a fresh
## player would come up in third person every time, so which way the cube was
## being looked through is kept out here where the reload cannot reach it. It
## is deliberately not part of what start_run wipes: it is how the player likes
## to play and not something the run tallied up
var is_first_person: bool = false


func _process(delta: float) -> void:
	if is_running:
		run_time += delta


## Wipes the tally and starts the clock. Called when a run is started from the
## title screen, everything the summary shows is counted from here
func start_run() -> void:
	has_key = false
	deaths = 0
	run_time = 0.0
	items_collected = 0
	items_used = 0
	is_running = true
	level_start_time = 0.0
	level_start_deaths = 0
	level_was_helped = false
	level_cpu_driving = false
	level_offer_mark = 0
	DeathMarks.clear()
	death_count_changed.emit(deaths)


## Seconds spent on the level that is being played, every attempt of it added up
func level_time() -> float:
	return maxf(run_time - level_start_time, 0.0)


## Deaths on the level that is being played
func level_deaths() -> int:
	return maxi(deaths - level_start_deaths, 0)


## Called by the key when the player touches it, the second call does nothing
func collect_key() -> void:
	if has_key:
		return

	has_key = true
	key_collected.emit()


## Called by the elevator once the player stands inside it
func enter_elevator() -> void:
	elevator_entered.emit()


## Counts a death, called right before the map is rebuilt
func add_death() -> void:
	deaths += 1
	death_count_changed.emit(deaths)


## Called by an item sphere the player burst open
func count_item_collected() -> void:
	items_collected += 1


## Called when an item is taken out of the slot and spent
func count_item_used() -> void:
	items_used += 1


## Stops the clock and hands the run over to the summary screen, called by the
## elevator once it has carried the player out
func finish_run() -> void:
	if not is_running:
		return

	is_running = false
	run_finished.emit()


## Puts the attempt back to its starting state, called before a map is built.
## The tally deliberately survives a rebuild, it is counted over every attempt
## of the level. A map that is built while no run is open starts one, so both a
## finished level and a scene opened straight out of the editor count from zero
func begin_level(new_level: MapData) -> void:
	var opened_another := new_level != level
	level = new_level
	has_key = false

	if not is_running:
		start_run()

	if opened_another:
		level_start_time = run_time
		level_start_deaths = deaths
		level_was_helped = false
		level_cpu_driving = false
		level_offer_mark = 0
