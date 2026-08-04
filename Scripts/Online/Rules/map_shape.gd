@tool
extends Resource
class_name MapShape

## One entry of the map shape dropdown

@export var label: String = "SQUARE"

## What the maze generator calls this shape: 0 square, 1 round
@export_enum("Square", "Round") var shape: int = 0

@export_multiline var blurb: String = ""
