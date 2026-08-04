@tool
extends Resource
class_name MapSize

## One entry of the map size dropdown

@export var label: String = "MEDIUM"

## How wide the maze gets, in cells. A round map takes half of it as its radius
@export_range(8, 256) var cells: int = 32

@export_multiline var blurb: String = ""
