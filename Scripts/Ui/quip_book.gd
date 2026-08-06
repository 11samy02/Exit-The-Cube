class_name QuipBook
extends RefCounted

## Everything the game says, in one file anybody can open.
##
## The lines used to live in three scripts as constants, which is fine until you
## want to change one — then it is a code edit and a rebuild. They are read out
## of a plain text file now, and the tables in the scripts are only what the game
## falls back on when the file has nothing to say about a pool.
##
## The format is as small as it can be: a name in square brackets opens a pool,
## every line under it is one thing the game might say, blank lines and lines
## starting with # are ignored. Nothing is escaped and nothing is quoted, so a
## line is exactly the text between the margin and the end of it

const PATH := "user://Quips.txt"

## Shipped alongside the game, copied out to the writable one the first time it
## is asked for. The player edits the copy; a patch never overwrites it
const SHIPPED := "res://Resources/Quips.txt"

## Pool name to its lines, read once and kept
static var _pools: Dictionary = {}
static var _read: bool = false


## The lines under that name, empty when the file says nothing about it
static func pool(key: String) -> PackedStringArray:
	_load()
	return _pools.get(key, PackedStringArray())


static func has(key: String) -> bool:
	_load()
	return _pools.has(key) and not (_pools[key] as PackedStringArray).is_empty()


## Where the file the player may edit actually is, for a menu to point at
static func file_path() -> String:
	return ProjectSettings.globalize_path(PATH)


## Reads the file once. A missing or unreadable one is not an error — every pool
## in the game has its own lines to fall back on
static func _load() -> void:
	if _read:
		return

	_read = true
	_ensure_copy()

	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return

	var key := ""

	while not file.eof_reached():
		var line := file.get_line().strip_edges()

		if line.is_empty() or line.begins_with("#"):
			continue

		if line.begins_with("[") and line.ends_with("]"):
			key = line.substr(1, line.length() - 2).strip_edges()
			if not _pools.has(key):
				_pools[key] = PackedStringArray()
			continue

		if key.is_empty():
			continue

		var lines: PackedStringArray = _pools[key]
		lines.append(line)
		_pools[key] = lines


## Puts the shipped copy where the player can reach it, the first time only
static func _ensure_copy() -> void:
	if FileAccess.file_exists(PATH):
		return

	var source := FileAccess.open(SHIPPED, FileAccess.READ)
	if source == null:
		return

	var target := FileAccess.open(PATH, FileAccess.WRITE)
	if target == null:
		return

	target.store_string(source.get_as_text())


## Forgets what was read, so an edit can be picked up without restarting
static func reload() -> void:
	_pools.clear()
	_read = false
