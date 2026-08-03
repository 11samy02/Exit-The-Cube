extends Node

## What is left of the cubes that burst on this level. The list outlives a scene
## reload, so every attempt walks past the splatter of the ones before it

## How many deaths are kept, the oldest one drops out when the next comes in.
## The number is set on the Blood Spawner of the map, it pushes it over from
## there before it puts the marks back up
var max_marks: int = 10

## One entry per death, oldest first. A mark is
## { "color": Color, "center": Vector3, "radius": float, "seed": float,
##   "faces": Array[Transform3D] }, the faces being the surfaces of the map the
## ink was painted onto
var marks: Array[Dictionary] = []

## How many prints the cubes may leave behind before the first ones are walked
## out of the level again
var max_prints: int = 90

## Every print a cube tracked out of a mark, oldest first. One print is
## { "transform": Transform3D, "color": Color }, the alpha of that color being
## how much paint was left on the cube when it came down
var prints: Array[Dictionary] = []

## The level the marks were sprayed on, splatter of another map would hang in
## mid air over this one
var level_id: String = ""


## Drops everything as soon as another level is built, called before the map
## goes up. The same level again keeps its splatter, that is the whole point
func begin_level(level: MapData) -> void:
	var id := level.resource_path if level != null else ""
	if id == level_id:
		return

	level_id = id
	clear()


## Remembers one death, the oldest is pushed off the end
func add(mark: Dictionary) -> void:
	marks.append(mark)

	while marks.size() > max_marks:
		marks.pop_front()


## Remembers one step out of the wet paint, the oldest is pushed off the end
func add_print(entry: Dictionary) -> void:
	prints.append(entry)

	while prints.size() > max_prints:
		prints.pop_front()


## Wipes the walls and the floor, called when a fresh run is started
func clear() -> void:
	marks.clear()
	prints.clear()
