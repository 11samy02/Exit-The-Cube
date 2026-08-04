@tool
extends Resource
class_name MapData

## Everything one level is made of. The map pushes these values onto its
## spawners before they run, so a level lives in a file instead of in the
## scene and can be swapped by swapping this one resource.
##
## Only the tuning lives in here. What a level is built from stays wired up on
## the spawner nodes: the scenes for player, key, elevator, saw and item, and
## the node paths between them. Those do not change from level to level.

@export_group("Level")

## Name the UI puts on this level, both on the start banner and on the summary.
## Empty falls back to the position of the level in the campaign
@export var display_name: String = ""

## Line shown under the name when the level starts, this is what makes a level
## a tutorial. Empty leaves the banner at the name alone
@export_multiline var hint_text: String = ""

## Input action the hint waits for. The hint stays up until the player has
## pressed it once, so a level can teach one control without a timer running
## out on it. Empty lets the hint fade on its own
@export var hint_action: String = ""

## Seconds the banner stays before it fades. A hint that waits for an action
## ignores this
@export var hint_duration: float = 6.0

@export_group("World")

## -1 = every part below keeps its own seed, otherwise this one seed rebuilds
## the exact same level. It overrules the seeds in the last group
@export var world_seed: int = -1

@export_group("Maze")

## Shape of the map
@export_enum("Square", "Round") var shape: int = 0

## Size for square maps (e.g. 16 = 16x16)
@export_range(8, 256) var size: int = 16

## Radius for round maps
@export var radius: int = 8

## 0.0 = classic perfect maze (many dead ends)
## 1.0 = very open (few dead ends, many loops)
@export_range(0.0, 1.0) var openness: float = 0.2

## Covers the maze with a roof layer on top of the walls
@export var with_roof: bool = false

## Roughly the share of the roof that is left open. 0.0 = closed roof, the maze
## cannot be seen from above at all, 1.0 = no roof is built. The openings are
## cut as whole shapes, so the number is met about and not to the tile
@export_range(0.0, 1.0) var roof_openness: float = 0.0

## How wide one opening in the roof grows, in cells. Small values break the roof
## into many small holes, large ones leave a few wide ones
@export_range(2.0, 24.0) var roof_hole_size: float = 6.0

## Item indices in the MeshLibrary of the GridMap
@export var ground_item_index: int = 0
@export var wall_item_index: int = 0
@export var roof_item_index: int = 0

@export_group("Player")

## How many candidate cells to store, only one is used per spawn
@export var player_spawn_point_count: int = 5

## Height the player is dropped in at, from there it falls onto the floor
@export var player_spawn_height: float = 3.0

## Whether the level has a key and a way out at all. A mode that is not about
## reaching an exit wants neither: the key would be a pickup that does nothing
## and the elevator would carry a player out of a round that is still running
@export var with_exit: bool = true

@export_group("Key")

## How many candidate cells to store, only one is used per spawn
@export var key_spawn_point_count: int = 5

## Minimum number of cells between the key and the player start
@export var key_min_distance_to_player: int = 8

@export_group("Elevator")

## Minimum number of cells between the exit and the key
@export var elevator_min_distance_to_key: int = 8

## Minimum number of cells between the exit and the player
@export var elevator_min_distance_to_player: int = 10

## How many candidate walls to store, 0 = all of them
@export var elevator_spawn_point_count: int = 0

## How many GridMap layers above the floor the elevator occupies
@export var elevator_height_in_cells: int = 2

## Extra rotation for models that do not face -Z
@export_range(-180.0, 180.0) var elevator_facing_offset_degrees: float = 0.0

@export_group("Saws")

## How many saws to spawn
@export var saw_count: int = 5

## How many waypoints a route has, rolled per saw between these two values
@export var saw_min_patrol_length: int = 3
@export var saw_max_patrol_length: int = 6

## Minimum and maximum random speed assigned per saw
@export var saw_min_speed: float = 1.0
@export var saw_max_speed: float = 3.0

## How many free cells stay between two routes, 0 = they may run side by side
@export var saw_route_spacing: int = 1

## How many steered saws to add on top of the patrolling ones. These have no
## route of their own, they read the level while it runs and decide where to go,
## so none of the tuning above applies to them. 0 leaves the level to the
## patrolling blades alone
@export var ai_saw_count: int = 0

@export_group("Glass walls")

## Panes set into the walls of the maze. They are wall like any other until the
## opener item drops them into the floor, and they come back up on their own
@export var with_glass_walls: bool = false

## How many of them to set in. A pane only fits where a straight run of wall has
## corridor on both sides, so a maze may well have room for fewer than this
@export var glass_wall_count: int = 0

## Item index of the glass cube in the MeshLibrary of the GridMap
@export var glass_wall_item_index: int = 2

## Minimum number of steps through the maze between two panes
@export var glass_wall_min_distance: int = 6

@export_group("Items")

## The only items the spheres may hand out on this level, every entry is picked
## from a dropdown of the item folder. Empty means the level does not care and
## everything in there is up for grabs
@export var item_pool: Array[String] = []

## How many item spheres to spawn
@export var item_count: int = 10

## Minimum number of cells between two spheres, never less than 1
@export var item_min_distance: int = 3

## Minimum number of cells between a sphere and the player start
@export var item_min_distance_to_player: int = 1

## Whether spheres are put back as they are taken. A level that is played to an
## exit is laid out once; one that runs to a clock is picked clean without this
@export var restock_items: bool = false

@export_group("Seeds")

## Only read while world_seed is -1, it overwrites every one of them otherwise.
## -1 means that part rolls fresh on every build
@export var map_seed: int = -1
@export var key_spawn_seed: int = -1
@export var saw_spawn_seed: int = -1
@export var elevator_spawn_seed: int = -1
@export var item_spawn_seed: int = -1
@export var player_spawn_seed: int = -1
@export var glass_wall_seed: int = -1


## True when this level teaches a control instead of standing on its own. The
## hint under the name is what makes it one, and it is why the level selection
## leaves it out: a tutorial is met on the way through the campaign, picking it
## on its own has nothing to offer
func is_tutorial() -> bool:
	return not hint_text.is_empty()


## Hands the inspector a dropdown per item pool entry instead of a text field,
## built from the files that are actually there. The list is read when the
## inspector draws the resource, so a freshly added item shows up after the
## resource is selected again
func _validate_property(property: Dictionary) -> void:
	if property.name != "item_pool":
		return

	property.hint = PROPERTY_HINT_TYPE_STRING
	property.hint_string = "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(ItemData.list_ids())]
