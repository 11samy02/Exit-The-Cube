extends Node

## The offer the campaign makes to somebody a level will not let past, and the
## one place anything asks whether a CPU is playing right now.
##
## This is the campaign alone. A round with rules of its own already has CPUs in
## it, sat in seats of their own and scored like anybody else; here there is one
## cube and one player, and all that changes is who is holding it. What the
## takeover actually does lives in AutopilotDriver — this only decides whether it
## may be suggested, and puts it on the cube once it has been said yes to

## Emitted when a CPU took a level over, and again when it hands it back
signal changed

## The rung a takeover is played at. Deliberately not one of the ones the party
## screen lists: it is not a difficulty anybody picks, it is the game finishing a
## level it said it would finish
const SKILL_PATH := "res://Resources/Bots/Skill4_autopilot.tres"

var _driver: AutopilotDriver = null


## True while a CPU is playing the level on screen
func is_running() -> bool:
	return is_instance_valid(_driver)


## True while the CPU was already given this level and the map has just come up
## again under it, which is what a death does.
##
## The CPU is mortal, so a takeover is a promise that spans attempts rather than
## one run through the maze. Nothing has to be stored for it: the level itself
## remembers it was handed over, and that memory is wiped the moment another one
## is opened
func should_resume() -> bool:
	if is_running() or not GameState.level_cpu_driving:
		return false

	return not Match.is_racing() and Levels.is_running() and GameState.is_running


## The death count this level has just gone past and has not been asked about
## yet, or 0 while there is nothing to ask.
##
## The offer is made more than once because a level costs more than once. Ten
## deaths is the game noticing; fifty is it insisting; a hundred is it not letting
## the level be the reason somebody stops playing. Each mark is asked about a
## single time, and the largest one that has been passed is the one that asks.
##
## Only ever a campaign level with one person on it. A round with rules of its own
## is out — those are scored against other people, and finishing one for somebody
## is cheating rather than helping. So is a room playing together: the cube is one
## seat of several and there is nobody to hand the other ones to. And so is a level
## opened straight out of the editor, which is not a campaign at all
func due_offer(marks: Array) -> int:
	if not Settings.autopilot_offer or is_running():
		return 0

	if Match.is_racing() or not Levels.is_running() or Seats.count() > 1:
		return 0

	var deaths := GameState.level_deaths()
	var due := 0

	for mark: int in marks:
		if deaths >= mark and mark > GameState.level_offer_mark and mark > due:
			due = mark

	return due


## Writes down that the mark was asked about, whatever the answer was. A question
## nobody has answered yet is still asked again on the next attempt, so this is
## set when the panel goes up rather than when a button is pressed
func mark_offered(mark: int) -> void:
	GameState.level_offer_mark = maxi(GameState.level_offer_mark, mark)


## The player would rather keep dying, and would rather not be asked again. Kept
## in the settings file: the answer is about how somebody wants to be played at
## and not about the run they happen to be on
func decline() -> void:
	Settings.set_autopilot_offer(false)


## Hands the level to a CPU. False when there is nothing to hand it to, which is
## a level that is being torn down or one this was called on twice
func take_over() -> bool:
	if is_running():
		return false

	var cube := Player.at_seat(get_tree(), 0)
	var map := _map()
	if cube == null or map == null:
		return false

	_build_squad(map)
	_driver = AutopilotDriver.attach_to(cube, _skill())
	_driver.tree_exited.connect(_on_driver_gone)
	GameState.level_was_helped = true
	GameState.level_cpu_driving = true
	changed.emit()
	return true


## The player wants the cube back. The stamp on the level stays — a CPU did play
## part of it, and that does not stop being true — but the level is theirs again,
## and a death from here on puts them back in it rather than the CPU
func give_back() -> void:
	GameState.level_cpu_driving = false

	if is_instance_valid(_driver):
		_driver.hand_back()


## What the takeover plays like, with the top rung of the ladder to fall back on
## if the file ever goes missing
func _skill() -> BotSkill:
	var rung := load(SKILL_PATH) as BotSkill
	return rung if rung != null else Bots.skill_of(Bots.book().skills.size() - 1)


func _on_driver_gone() -> void:
	_driver = null
	changed.emit()


## The shared reading of the maze every brain walks by. A round with bots in it
## is handed one by the router when the map goes up; a campaign level has never
## needed one, so the takeover brings its own
func _build_squad(map: Node) -> void:
	if BotSquad.find(get_tree()) != null:
		return

	var squad := BotSquad.new()
	squad.name = "BotSquad"
	map.add_child(squad)


## The map node, reached through the generator. It is the one part of a level
## that is in a group, and the grid it fills in is the map itself — which is what
## the squad has to hang under to find the rest of the spawners
func _map() -> Node:
	var walker := get_tree().get_first_node_in_group("map_generator") as MapGenerator
	return walker.grid_map if walker != null else null
