@tool
extends Resource
class_name Difficulty

## One rung of the difficulty ladder. Everything that makes a maze harder moves
## together in here, and all of it is relative to the map rather than fixed:
## the numbers are shares and spacings, not counts

@export var label: String = "NORMAL"
@export_multiline var blurb: String = ""

@export_group("Maze")

## 0 is a perfect maze of dead ends, 1 is wide open
@export_range(0.0, 1.0) var openness: float = 0.28

## Below 0 there is no roof. 0 is a closed lid, higher leaves holes in it
@export_range(-1.0, 1.0) var roof: float = -1.0

@export var glass_walls: bool = true

@export_group("Blades")

## One blade per this many corridor cells. Spacing rather than a count, so the
## same rung means the same pressure on every map size
@export var corridors_per_saw: float = 36.0

## Blade speed as a share of the cube's own. Above 1 cannot be outrun
@export var speed := Vector2(0.75, 0.95)

## Steered blades, capped again by how big the maze is
@export var ai_saws: int = 1

## Waypoints per patrol route, and free cells kept between two routes
@export var patrol := Vector2i(3, 10)
@export var spacing: int = 2

@export_group("Items")

## One sphere per this many corridor cells
@export var corridors_per_item: float = 36.0
