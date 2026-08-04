@tool
extends Resource
class_name RaceRulebook

## Everything a lobby can be set to, and the numbers the level generator scales
## by. One file, edited in the inspector rather than in a script

@export_group("Lobby")

@export var modes: Array[RaceMode] = []
@export var sizes: Array[MapSize] = []
@export var shapes: Array[MapShape] = []

## How many sides the room can be split into
@export var team_counts: Array[int] = [2, 3, 4]

@export var difficulties: Array[Difficulty] = []

@export_group("Teams")

## Team colours are rolled per round rather than fixed, and spaced evenly around
## the wheel so no two sides can come out looking alike
@export_range(0.0, 1.0) var team_saturation: float = 0.75
@export_range(0.0, 1.0) var team_value: float = 1.0

## How far a colour may wander off its even slot. Kept well under the gap
## between slots, which is what guarantees they stay apart
@export_range(0.0, 0.5) var team_hue_drift: float = 0.05

@export_group("Scaling")

## What the cube itself does. Blade speeds are shares of this
@export var player_speed: float = 6.0

## The map size the difficulty table is written for
@export var reference_size: float = 48.0

## Share of a square map that ends up corridor, and what a round map keeps of it
@export var corridor_share: float = 0.45
@export var round_share: float = 0.785

## Under this a maze gets no roof, whatever the difficulty asks
@export var roof_min_size: int = 24

@export_group("Ceilings")

@export var max_saws: int = 220
@export var max_ai_saws: int = 6
@export var max_items: int = 120
@export var min_items: int = 3
@export var max_glass_walls: int = 40
@export var corridors_per_glass_wall: float = 90.0

## Where the key and the exit stop being pushed further away
@export var max_key_distance: int = 30
@export var max_exit_to_key: int = 28
@export var max_exit_distance: int = 38

@export_group("MeshLibrary")

## Which slots of the GridMap's library the level is built from
@export var ground_item: int = 1
@export var wall_item: int = 1
@export var roof_item: int = 1
@export var glass_item: int = 2
