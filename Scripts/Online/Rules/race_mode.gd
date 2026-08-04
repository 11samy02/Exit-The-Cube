@tool
extends Resource
class_name RaceMode

## One thing a lobby can play. Adding a mode is adding one of these, not editing
## a script: everything that makes a mode different from another is a value here

## Read by code that has to tell one mode from another
@export var id: String = "race"

## What the lobby dropdown shows, and the line under it
@export var label: String = "RACE"
@export_multiline var blurb: String = ""

@export_group("Level")

## Whether the maze has a key and a way out. A mode that is not about leaving
## wants neither
@export var with_exit: bool = true

## Whether the floor takes the colour of whoever walks on it. Also what turns
## the teams, the round clock and the paint scoring on
@export var paints_floor: bool = false

## Whether spheres are put back as they are taken
@export var restock_items: bool = false

## The only spheres this mode hands out. Empty means every item is allowed
@export var item_pool: Array[String] = []

@export_group("Round")

## Seconds a round lasts, 0 for a mode that ends some other way
@export var round_seconds: float = 0.0

## What dying costs: tiles taken back, and seconds spent waiting
@export var death_tile_penalty: int = 0
@export var death_penalty_seconds: float = 0.0
