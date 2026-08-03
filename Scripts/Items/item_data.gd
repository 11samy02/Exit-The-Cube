@tool
extends Resource
class_name ItemData

## Where the items live, every .tres in here counts as one. Dropping a new file
## in is all it takes to put it into the pool and into the level dropdown
const FOLDER := "res://Resources/Items/"

## Name of the item, the UI and the warnings use it
@export var display_name: String = ""

## Icon that goes into the item slot in the game UI
@export var icon: Texture2D

## Seconds the effect stays up once the item is used
@export var duration: float = 20.0

## Color of the countdown ring while this item runs
@export var accent_color: Color = Color(1, 1, 1)

## Scene that is spawned on the player and does the actual work, its root node
## has to extend ItemEffect
@export var effect_scene: PackedScene

## Chance of this item being rolled, relative to every other item
@export var weight: float = 1.0

## How often this item may come up in a row before the next sphere is forced
## to hand out a different one, 0 lifts the filter. This is not a contingent,
## the item stays in the pool for the whole run
@export var max_in_a_row: int = 2

## Played the moment the item is activated
@export var use_sound: AudioStream

## Takes the game music over for as long as the effect runs, empty leaves the
## music alone
@export var music: AudioStream

## Volume that track is played at, in decibels
@export var music_volume_db: float = -10.0


## The id of every item in the folder, sorted. The id is the file name without
## its suffix, an exported build hands the files out behind a .remap so that
## one is taken off first. Static so the editor can read the list without the
## running game and its autoloads
static func list_ids() -> PackedStringArray:
	var ids := PackedStringArray()

	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return ids

	for file_name in dir.get_files():
		var clean := file_name.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			ids.append(clean.trim_suffix(".tres"))

	ids.sort()
	return ids


## The file an id points at
static func path_for(id: String) -> String:
	return FOLDER + id + ".tres"
