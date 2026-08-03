extends Node

## Where the player is in the campaign. The map scene is the same one for every
## level, only the MapData it builds from is swapped, so moving on is a matter
## of stepping this index and loading the scene again

const SET_PATH := "res://Resources/Maps/Campaign.tres"

## The campaign. Loaded with this node instead of in _ready, the first map can
## be built before the tree has finished starting up
var level_set: LevelSet = load(SET_PATH) as LevelSet

## Position in the campaign, -1 while no campaign runs. A map opened straight
## out of the editor leaves it there and keeps the level on its own node
var index: int = -1


func _ready() -> void:
	if level_set == null:
		push_warning("Levels: %s is not a LevelSet, the map falls back to its own level" % SET_PATH)
	elif level_set.levels.is_empty():
		push_warning("Levels: %s lists no levels, the map falls back to its own level" % SET_PATH)


## Opens the campaign at that level, called when the player starts a game
func start(at: int = 0) -> void:
	index = at if count() > at else -1


## Leaves the campaign, the next map built is whatever its own node carries
func stop() -> void:
	index = -1


## True while a campaign is being played, false for a map opened on its own
func is_running() -> bool:
	return index >= 0


## The level that is being played, null while no campaign runs
func current() -> MapData:
	if not is_running() or level_set == null:
		return null

	return level_set.level_at(index)


## The levels the selection lists, by their place in the campaign. Everything
## but the tutorials: those teach a control on the way through the campaign and
## are nothing to pick on their own, so they are only ever met in order
func selectable() -> Array[int]:
	var picks: Array[int] = []
	if level_set == null:
		return picks

	for level in range(count()):
		if not level_set.is_tutorial_at(level):
			picks.append(level)

	return picks


## The name of any level of the campaign, whether it is the one being played or
## not. Used by the level selection, which lists them all
func title_of(index: int) -> String:
	return level_set.title_at(index) if level_set != null else ""


## The name of the level that is being played
func title() -> String:
	if not is_running() or level_set == null:
		return ""

	return level_set.title_at(index)


## True while there is a level after this one
func has_next() -> bool:
	return is_running() and index + 1 < count()


## Steps to the next level, false when this was the last one
func advance() -> bool:
	if not has_next():
		return false

	index += 1
	return true


## Which level of the campaign this is, counted from one for the UI. The
## tutorials sit in front of level one, so this is not the number on the level
func number() -> int:
	return index + 1


## Where the level being played stands among the numbered levels, counted from
## one. That is the number written on it, and the one the level selection lists
## it under. A tutorial is not one of them and reports 0
func listed_number() -> int:
	return selectable().find(index) + 1


## How many numbered levels the campaign has, the tutorials left out
func listed_count() -> int:
	return selectable().size()


func count() -> int:
	return level_set.levels.size() if level_set != null else 0
