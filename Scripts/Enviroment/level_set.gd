@tool
extends Resource
class_name LevelSet

## The campaign. Every level of the game in the order they are played in, the
## first entry is what a fresh start drops into. A level that is built somewhere
## else only has to be dropped into this array to be part of the game, nothing
## else knows about the order

@export var levels: Array[MapData] = []


## The level at that position, null for anything outside the campaign
func level_at(index: int) -> MapData:
	if index < 0 or index >= levels.size():
		return null

	return levels[index]


## True when that level is a tutorial, one played on the way through the
## campaign rather than picked out of it
func is_tutorial_at(index: int) -> bool:
	var level := level_at(index)
	return level != null and level.is_tutorial()


## The name that level goes by, its own if it carries one and its position in
## the campaign otherwise
func title_at(index: int) -> String:
	var level := level_at(index)
	if level != null and not level.display_name.is_empty():
		return level.display_name

	return "LEVEL %d" % (index + 1)
