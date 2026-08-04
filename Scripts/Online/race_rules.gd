class_name RaceRules
extends RefCounted

## What a race is set up from. The lobby only ever stores four numbers — mode,
## size, shape and difficulty — and this turns them into the MapData the map
## scene builds itself out of.
##
## Everything in here is pure: the same four numbers and the same seed give the
## same level on every machine, which is the whole point of a race. Nothing may
## reach for the global rng or for a setting the player could change on their
## own, or the maze would drift apart between two players standing in it

## What a lobby can play. A mode is an id the rest of the game answers to, so a
## third one is an entry here plus whatever reads that id
const MODES := [
	{
		"id": "race",
		"label": "RACE",
		"blurb": "same maze, same key, same exit. first one out wins",
	},
	{
		"id": "paint",
		"label": "PAINT",
		"blurb": "teams, five minutes, and a floor that remembers who walked on it",
	},
]

## The id of the mode that is about painting the floor rather than leaving
const MODE_PAINT := "paint"

## How the room can be split up. Kept as its own setting rather than worked out
## from how many turned up, because two teams of six and four teams of three are
## different games and the room should get to say which one it is playing
const TEAM_COUNTS := [
	{"label": "2 TEAMS", "count": 2},
	{"label": "3 TEAMS", "count": 3},
	{"label": "4 TEAMS", "count": 4},
]

## What a team looks like. Far enough apart to be told from each other on a floor
## in the dark, and none of them close to the violet the maze walls glow in
const TEAM_COLORS := [
	Color(0.16, 0.78, 1.00),
	Color(1.00, 0.30, 0.55),
	Color(1.00, 0.68, 0.16),
	Color(0.42, 0.94, 0.42),
]

## Seconds a painting round lasts
const ROUND_SECONDS := 300.0

## How many of the tiles a player painted are taken back off them when they die.
## It has to hurt enough to make a blade worth avoiding while still leaving the
## bulk of a good run standing
const DEATH_TILE_PENALTY := 10

## Seconds a player sits out after dying, before the cube is put back
const DEATH_PENALTY_SECONDS := 5.0

## The spheres a painting round hands out.
##
## Two of the eight are left out rather than reworded. The arrow points at what
## you still need and the echo draws the way there, and both of those mean the
## key and the exit — neither of which a painting round has. They would be a
## pickup that visibly does nothing, which is worse than one that never drops
const PAINT_ITEMS: Array[String] = [
	"freeze", "glass_opener", "rush", "saw_paths", "shield", "speed",
]

## How wide the maze gets, in cells. A round map takes half of it as its radius,
## which lands it on roughly the same walk
const SIZES := [
	{"label": "VERY SMALL", "cells": 16, "blurb": "over before the ambience loops"},
	{"label": "SMALL", "cells": 24, "blurb": "a warm up with teeth"},
	{"label": "MEDIUM", "cells": 32, "blurb": "the honest one"},
	{"label": "LARGE", "cells": 48, "blurb": "bring a sense of direction"},
	{"label": "VERY LARGE", "cells": 64, "blurb": "you will forget where you came in"},
	{"label": "GIGANTIC", "cells": 96, "blurb": "pack a lunch"},
]

## Square is the full grid, round cuts a disc out of it
const SHAPES := [
	{"label": "SQUARE", "shape": 0, "blurb": "corners, and plenty of them"},
	{"label": "ROUND", "shape": 1, "blurb": "no corners to hide in"},
]

## What the cube itself does. Every blade speed below is written as a share of
## this rather than as a number of its own, and that is the point: a blade
## quicker than the cube cannot be outrun, only dodged, and whether dodging is
## possible depends entirely on how much maze there is to dodge into
const PLAYER_SPEED := 6.0

## The size the whole table is written for. Smaller maps get room made for them
## and larger ones get pressure taken off, both measured out from here
const REFERENCE_SIZE := 48.0

## About what share of a square map is corridor once the maze has been cut.
## Counted over every size the lobby offers — it climbs a little with size, and
## the middle of that range is close enough to space blades by
const CORRIDOR_SHARE := 0.45

## A round map is the disc inside that square, so it keeps roughly this much
const ROUND_SHARE := 0.785

## Under this a maze gets no roof at all. A lid over a maze this tight leaves the
## third person camera nowhere to sit
const ROOF_MIN_SIZE := 24

## The five settings the whole level is tuned by. Everything that makes a maze
## harder moves together in here: the corridors stop looping, the blades get
## closer together and faster, the spheres get rarer, and the top two put a roof
## over it so the map cannot be read from above.
##
## Blades are spaced by corridors rather than counted by area, because a corridor
## is the thing a player actually walks down. Counting per area let the small
## maps quietly end up the densest ones on the list
const DIFFICULTIES := [
	{
		"label": "STROLL",
		"blurb": "wide halls, lazy blades, a sphere on every corner",
		"openness": 0.62,
		"corridors_per_saw": 90.0,
		"speed": Vector2(0.45, 0.60),
		"ai_saws": 0,
		"patrol": Vector2i(3, 6),
		"spacing": 3,
		"corridors_per_item": 22.0,
		"glass_walls": false,
		"roof": -1.0,
	},
	{
		"label": "EASY",
		"blurb": "a maze that still lets you double back",
		"openness": 0.45,
		"corridors_per_saw": 55.0,
		"speed": Vector2(0.60, 0.78),
		"ai_saws": 0,
		"patrol": Vector2i(3, 8),
		"spacing": 2,
		"corridors_per_item": 28.0,
		"glass_walls": false,
		"roof": -1.0,
	},
	{
		"label": "NORMAL",
		"blurb": "the one the campaign would call a tuesday",
		"openness": 0.28,
		"corridors_per_saw": 36.0,
		"speed": Vector2(0.75, 0.95),
		"ai_saws": 1,
		"patrol": Vector2i(3, 10),
		"spacing": 2,
		"corridors_per_item": 36.0,
		"glass_walls": true,
		"roof": -1.0,
	},
	{
		"label": "HARD",
		"blurb": "dead ends, a lid on top, and blades that keep up with you",
		"openness": 0.13,
		"corridors_per_saw": 26.0,
		"speed": Vector2(0.90, 1.15),
		"ai_saws": 3,
		"patrol": Vector2i(3, 12),
		"spacing": 1,
		"corridors_per_item": 46.0,
		"glass_walls": true,
		"roof": 0.35,
	},
	{
		"label": "NIGHTMARE",
		"blurb": "a maze of dead ends, sealed shut, hunted",
		"openness": 0.03,
		"corridors_per_saw": 20.0,
		"speed": Vector2(1.05, 1.35),
		"ai_saws": 6,
		"patrol": Vector2i(3, 14),
		"spacing": 1,
		"corridors_per_item": 58.0,
		"glass_walls": true,
		"roof": 0.0,
	},
]


## About how many corridor cells a map of that size and shape comes out with
static func corridor_count(size: int, shape: int) -> float:
	var cells := float(size * size) * CORRIDOR_SHARE
	return cells * ROUND_SHARE if shape == 1 else cells


## How much further apart the blades have to stand on this map than the table
## asks for.
##
## Only a little on the small maps. What made a tiny nightmare unplayable was
## never the number of blades, it was that they were twice the cube's speed with
## nowhere to break away to — and the answer to that is the two below, not fewer
## blades. Thinning them out as well leaves a plaza with three saws in it.
##
## The long maps are the ones that really need relief, and for a different
## reason: the pressure at any one corner is fine, there are simply four times as
## many corners to get through alive
static func saw_relief(size: int) -> float:
	var cramped := clampf(1.0 + (REFERENCE_SIZE - float(size)) / 128.0, 1.0, 1.25)
	var lengthy := clampf(float(size) / REFERENCE_SIZE, 1.0, 1.6)
	return cramped * lengthy


## How much of the tabled blade speed a map this size may actually use. Anything
## quicker than the cube has to be dodged rather than outrun, and a small maze
## gives less warning that something is coming — so the top end comes down a
## little, not far enough to make a blade something you can simply walk away from
static func speed_scale(size: int) -> float:
	return clampf(0.80 + float(size) / 160.0, 0.85, 1.0)


## Loops a small maze is given whatever the difficulty asked for. A perfect maze
## is all dead ends, and a dead end with a faster blade coming down it is not a
## hard corner, it is a death there was never anything to do about.
##
## Enough of them to break a chase and no more. Opening a sixteen cell map up
## properly does not make it a fair nightmare, it makes it a car park
static func openness_floor(size: int) -> float:
	return clampf((32.0 - float(size)) / 130.0, 0.0, 0.13)


## Holes a small maze is given in its roof, so that a lid does not also take the
## view away in the one place there is least room to see
static func roof_floor(size: int) -> float:
	return clampf((40.0 - float(size)) / 60.0, 0.0, 0.4)

## The extra entry a randomisable list gets at the end of its dropdown. A
## setting holding it is not a choice, it is a promise to roll one when the race
## starts
const RANDOM_LABEL := "RANDOM"

## Which settings may be left to the dice, how far the dice may go, and what to
## tell the lobby about it.
##
## The ends of the two long lists are deliberately out of reach. A race is
## something a room of friends has to be able to finish in one sitting, and both
## a gigantic maze and a nightmare one are things you choose on purpose or not at
## all — landing on either by accident is not a surprise, it is a wasted evening.
##
## The salt is what keeps the three rolls apart. They all come off the one race
## seed so that every machine lands on the same maze, and without a number of
## their own they would all draw the identical value from it
const RANDOM_RANGE := {
	"size": {
		"from": 0,
		"to": 4,
		"salt": 101,
		"blurb": "anything from very small to very large. never gigantic",
	},
	"shape": {
		"from": 0,
		"to": 1,
		"salt": 211,
		"blurb": "square or round, settled the moment the race starts",
	},
	"difficulty": {
		"from": 0,
		"to": 3,
		"salt": 307,
		"blurb": "anything from stroll to hard. never nightmare",
	},
	"teams": {
		"from": 0,
		"to": 2,
		"salt": 409,
		"blurb": "two, three or four sides, decided when the round starts",
	},
}

## Ceilings on what a gigantic map may be filled with. The counts are worked out
## per cell, and the biggest map is thirty times the area of the smallest one:
## without these the top difficulty on the top size would spawn a blade wall the
## machine has to draw rather than a level anybody could finish
const MAX_SAWS := 220
const MAX_AI_SAWS := 6
const MAX_ITEMS := 120
const MAX_GLASS_WALLS := 40

## The smallest maps would be left with one sphere or none by the spacing alone,
## and a race with nothing to pick up is a walk
const MIN_ITEMS := 3

## One pane per this many corridors. They are shortcuts and cost nothing to
## walk past, so they are handed out the same way at every difficulty that has
## them at all
const CORRIDORS_PER_GLASS_WALL := 90.0

## Where the key and the exit stop being pushed further away. They keep growing
## with the map well past the small sizes, then hold: the spawners already draw
## from the far end of whatever is left, so a gigantic maze puts them a long way
## off without also being told the walk has to be sixty corridors on top
const MAX_KEY_DISTANCE := 30
const MAX_EXIT_TO_KEY := 28
const MAX_EXIT_DISTANCE := 38

## The MeshLibrary slots the campaign builds from, the race uses the same ones
const GROUND_ITEM := 1
const WALL_ITEM := 1
const ROOF_ITEM := 1
const GLASS_ITEM := 2


## The level a lobby with those settings plays. The seed is what every player in
## the lobby shares, so it is spread over the parts of the level here the same
## way the campaign spreads its own world seed.
##
## Anything the lobby left on random is rolled first, off that same seed, so the
## whole room walks into the same maze without a word being sent about it
static func build_level(settings: Dictionary, race_seed: int) -> MapData:
	var rolled := resolve(settings, race_seed)
	var size := size_of(rolled)
	var shape := shape_of(rolled)
	var rules := difficulty_of(rolled)
	var corridors := corridor_count(size, shape)

	var level := MapData.new()
	level.display_name = title_of(rolled)
	level.world_seed = -1
	level.with_exit = not is_paint(rolled)

	_apply_maze(level, size, shape, rules)
	_apply_spawns(level, size)
	_apply_saws(level, size, corridors, rules)
	_apply_items(level, corridors, rules, is_paint(rolled))
	_apply_glass(level, corridors, rules)
	_apply_seeds(level, race_seed)

	return level


static func _apply_maze(level: MapData, size: int, shape: int, rules: Dictionary) -> void:
	level.shape = shape
	level.size = size
	level.radius = size / 2
	level.openness = maxf(float(rules["openness"]), openness_floor(size))
	level.ground_item_index = GROUND_ITEM
	level.wall_item_index = WALL_ITEM
	level.roof_item_index = ROOF_ITEM

	var roof := float(rules["roof"])
	level.with_roof = roof >= 0.0 and size >= ROOF_MIN_SIZE
	level.roof_openness = maxf(roof, roof_floor(size)) if level.with_roof else 0.0
	level.roof_hole_size = 12.0


## The distances grow with the map so a large maze does not put the key around
## the first corner, but they stop growing well before the map does. Every one of
## them is only a floor — the spawners draw from the far end of what is left
## anyway, so a gigantic map still puts the key a long way off without also being
## told it has to be sixty corridors.
##
## Every one of them is a wish rather than a rule: the spawners fall back to the
## farthest cell they can find when a map turns out too small for what was asked
static func _apply_spawns(level: MapData, size: int) -> void:
	level.player_spawn_point_count = 1
	level.player_spawn_height = 3.0
	level.key_spawn_point_count = 6
	level.key_min_distance_to_player = mini(int(size * 0.55), MAX_KEY_DISTANCE)
	level.elevator_min_distance_to_key = mini(int(size * 0.5), MAX_EXIT_TO_KEY)
	level.elevator_min_distance_to_player = mini(int(size * 0.7), MAX_EXIT_DISTANCE)
	level.elevator_spawn_point_count = 6
	level.elevator_height_in_cells = 2


## Blades are spaced out by corridor rather than counted by area, and both their
## number and their speed are pulled back on the maps that cannot carry them.
##
## A hunter walks the corridors towards the cube and decides again when it gets
## there, and it is the one thing that makes the top of the list feel like the
## top of the list. Small maps get one rather than none: taking them away
## entirely was what left a tiny nightmare with nothing in it that hunts
static func _apply_saws(level: MapData, size: int, corridors: float, rules: Dictionary) -> void:
	var patrol: Vector2i = rules["patrol"]
	var speed: Vector2 = rules["speed"] * PLAYER_SPEED * speed_scale(size)
	var per_saw := float(rules["corridors_per_saw"]) * saw_relief(size)
	var hunters := mini(int(rules["ai_saws"]), MAX_AI_SAWS)

	level.saw_count = clampi(int(round(corridors / per_saw)), 1, MAX_SAWS)
	level.ai_saw_count = mini(hunters, maxi(size / 24, 1))
	level.saw_min_patrol_length = patrol.x
	level.saw_max_patrol_length = patrol.y
	level.saw_min_speed = speed.x
	level.saw_max_speed = speed.y
	level.saw_route_spacing = int(rules["spacing"])


## An empty pool means the level does not care which item a sphere hands out,
## which is what a race wants: everybody draws from the same full shelf.
##
## Spheres are spaced by corridor as well, so a long map hands out more of them
## rather than the same handful spread thinner. The floor is there for the
## smallest maps, where the spacing alone would leave barely any
static func _apply_items(level: MapData, corridors: float, rules: Dictionary, paint: bool) -> void:
	var pool: Array[String] = []

	if paint:
		pool.assign(PAINT_ITEMS)

	level.item_pool = pool
	level.item_count = clampi(int(round(corridors / float(rules["corridors_per_item"]))), \
		MIN_ITEMS, MAX_ITEMS)
	level.item_min_distance = 4
	level.item_min_distance_to_player = 3
	level.restock_items = paint


static func _apply_glass(level: MapData, corridors: float, rules: Dictionary) -> void:
	level.with_glass_walls = bool(rules["glass_walls"])
	level.glass_wall_count = mini(int(round(corridors / CORRIDORS_PER_GLASS_WALL)), MAX_GLASS_WALLS)
	level.glass_wall_item_index = GLASS_ITEM
	level.glass_wall_min_distance = 6


## One offset per part of the level, the same number everywhere would have them
## all draw the identical sequence of values. This is what makes the maze the
## same on every machine in the lobby, so it is deliberately not randomised
static func _apply_seeds(level: MapData, race_seed: int) -> void:
	level.map_seed = race_seed
	level.key_spawn_seed = race_seed + 1
	level.saw_spawn_seed = race_seed + 2
	level.elevator_spawn_seed = race_seed + 3
	level.item_spawn_seed = race_seed + 4
	level.player_spawn_seed = race_seed + 5
	level.glass_wall_seed = race_seed + 6


## The numbers a fresh lobby opens on
static func default_settings() -> Dictionary:
	return {"mode": 0, "size": 2, "shape": 0, "difficulty": 2, "teams": 0}


## True while the lobby is set up to play the painting mode
static func is_paint(settings: Dictionary) -> bool:
	return String(mode_of(settings)["id"]) == MODE_PAINT


## How many teams the room is split into
static func team_count(settings: Dictionary) -> int:
	return int(TEAM_COUNTS[index_of(settings, "teams", TEAM_COUNTS.size())]["count"])


## The colour of one team, safe against a number that came off the network
static func team_color(team: int) -> Color:
	return TEAM_COLORS[clampi(team, 0, TEAM_COLORS.size() - 1)]


## What a team goes by on screen
static func team_name(team: int) -> String:
	return ["CYAN", "PINK", "AMBER", "GREEN"][clampi(team, 0, 3)]


## The same four settings with every random one rolled into a real value. Only
## the race seed goes in, so two machines with the same lobby and the same seed
## come out of here holding the identical settings without having compared them
static func resolve(settings: Dictionary, race_seed: int) -> Dictionary:
	var rolled := settings.duplicate()
	var rng := RandomNumberGenerator.new()

	for key: String in RANDOM_RANGE:
		if not is_random(key, int(settings.get(key, 0))):
			continue

		var range_of: Dictionary = RANDOM_RANGE[key]
		rng.seed = race_seed + int(range_of["salt"])
		rolled[key] = rng.randi_range(int(range_of["from"]), int(range_of["to"]))

	return rolled


## The list one setting is picked out of
static func options_for(key: String) -> Array:
	match key:
		"mode":
			return MODES
		"size":
			return SIZES
		"shape":
			return SHAPES
		"teams":
			return TEAM_COUNTS

	return DIFFICULTIES


## True for a setting that may be left to the dice. The mode is not one of them:
## there is only the one so far, and rolling it would be a coin with one side
static func allows_random(key: String) -> bool:
	return RANDOM_RANGE.has(key)


## True when that value is the random entry rather than one of the real ones. It
## sits one past the end of the list, which is where its dropdown entry is too
static func is_random(key: String, value: int) -> bool:
	return allows_random(key) and value >= options_for(key).size()


## What that setting's dropdown offers, random included where it is allowed
static func labels_for(key: String) -> Array:
	var labels: Array = []

	for option: Dictionary in options_for(key):
		labels.append(String(option["label"]))

	if allows_random(key):
		labels.append(RANDOM_LABEL)

	return labels


## The line under that dropdown, which for a random one says how far it may go
static func blurb_for(key: String, value: int) -> String:
	if is_random(key, value):
		return String(RANDOM_RANGE[key]["blurb"])

	var options := options_for(key)
	return String(options[clampi(value, 0, options.size() - 1)]["blurb"])


## What one setting reads as, on the lobby heading and in the browser
static func label_of(settings: Dictionary, key: String) -> String:
	var value := int(settings.get(key, 0))
	if is_random(key, value):
		return RANDOM_LABEL

	var options := options_for(key)
	return String(options[clampi(value, 0, options.size() - 1)]["label"])


## Every randomisable setting turned over to the dice at once
static func all_random() -> Dictionary:
	var rolled: Dictionary = {}

	for key: String in RANDOM_RANGE:
		rolled[key] = options_for(key).size()

	return rolled


## Reads one setting back out, clamped into the list it belongs to. Everything
## in a lobby arrives as text over the network, and a value that fell off the
## end of a list must not take the level generation down with it
static func index_of(settings: Dictionary, key: String, count: int) -> int:
	return clampi(int(settings.get(key, 0)), 0, maxi(count - 1, 0))


static func mode_of(settings: Dictionary) -> Dictionary:
	return MODES[index_of(settings, "mode", MODES.size())]


static func size_of(settings: Dictionary) -> int:
	return int(SIZES[index_of(settings, "size", SIZES.size())]["cells"])


static func shape_of(settings: Dictionary) -> int:
	return int(SHAPES[index_of(settings, "shape", SHAPES.size())]["shape"])


static func difficulty_of(settings: Dictionary) -> Dictionary:
	return DIFFICULTIES[index_of(settings, "difficulty", DIFFICULTIES.size())]


## The line the lobby, the loading banner and the results panel all go by. A
## setting still on random says so, which is the point of it being visible: the
## lobby is agreeing to a roll, not to a maze
static func title_of(settings: Dictionary) -> String:
	var parts: Array[String] = [
		label_of(settings, "mode"),
		label_of(settings, "size"),
		label_of(settings, "shape"),
		label_of(settings, "difficulty"),
	]

	if is_paint(settings):
		parts.append(label_of(settings, "teams"))

	return "  ·  ".join(parts)


## The short version, for a row in the lobby browser where there is no room
static func short_title_of(settings: Dictionary) -> String:
	return "%s · %s" % [label_of(settings, "size"), label_of(settings, "difficulty")]
