class_name RaceRules
extends RefCounted

## Turns the four numbers a lobby stores into the MapData the map builds itself
## from. What the numbers mean lives in Resources/Online/Rulebook.tres, not here.
##
## Everything below is pure: the same settings and the same seed give the same
## level on every machine, which is what lets a race share a maze without
## sending one. Nothing here may reach for the global rng.

const BOOK_PATH := "res://Resources/Online/Rulebook.tres"

## The extra dropdown entry that leaves a setting to the dice
const RANDOM_LABEL := "RANDOM"

## Which settings may be rolled, how far, and what to tell the lobby.
##
## The ends of the two long lists are out of reach on purpose: a gigantic maze
## and a nightmare one are things you choose, not things you should be handed.
## The salt keeps the rolls apart — they all come off the one race seed, and
## without a number of their own they would draw the same value
const RANDOM_RANGE := {
	"size": {"to": -2, "salt": 101, "blurb": "anything but the largest map"},
	"shape": {"to": -1, "salt": 211, "blurb": "square or round, settled at the start"},
	"difficulty": {"to": -2, "salt": 307, "blurb": "anything but nightmare"},
	"teams": {"to": -1, "salt": 409, "blurb": "however many sides there are"},
}

static var _book: RaceRulebook = null


## The rulebook, loaded once
static func book() -> RaceRulebook:
	if _book == null:
		_book = load(BOOK_PATH) as RaceRulebook

	return _book


## The level a lobby with those settings plays. Anything left on random is
## rolled off the same seed first, so the whole room lands on the same maze
static func build_level(settings: Dictionary, race_seed: int) -> MapData:
	var rolled := resolve(settings, race_seed)
	var mode := mode_of(rolled)
	var rules := difficulty_of(rolled)
	var size := size_of(rolled)
	var shape := shape_of(rolled)
	var corridors := corridor_count(size, shape)

	var level := MapData.new()
	level.display_name = title_of(rolled)
	level.world_seed = -1
	level.with_exit = mode.with_exit
	level.restock_items = mode.restock_items
	level.item_pool = mode.item_pool.duplicate()

	_apply_maze(level, size, shape, rules)
	_apply_spawns(level, size)
	_apply_saws(level, size, corridors, rules)
	_apply_items(level, corridors, rules)
	_apply_glass(level, corridors, rules)
	_apply_seeds(level, race_seed)

	return level


static func _apply_maze(level: MapData, size: int, shape: int, rules: Difficulty) -> void:
	var at := book()

	level.shape = shape
	level.size = size
	level.radius = size / 2
	level.openness = maxf(rules.openness, openness_floor(size))
	level.ground_item_index = at.ground_item
	level.wall_item_index = at.wall_item
	level.roof_item_index = at.roof_item
	level.with_roof = rules.roof >= 0.0 and size >= at.roof_min_size
	level.roof_openness = maxf(rules.roof, roof_floor(size)) if level.with_roof else 0.0
	level.roof_hole_size = 12.0


## The distances grow with the map and then stop. They are floors, not targets —
## the spawners draw from the far end of what is left anyway
static func _apply_spawns(level: MapData, size: int) -> void:
	var at := book()

	level.player_spawn_point_count = 1
	level.player_spawn_height = 3.0
	level.key_spawn_point_count = 6
	level.key_min_distance_to_player = mini(int(size * 0.55), at.max_key_distance)
	level.elevator_min_distance_to_key = mini(int(size * 0.5), at.max_exit_to_key)
	level.elevator_min_distance_to_player = mini(int(size * 0.7), at.max_exit_distance)
	level.elevator_spawn_point_count = 6
	level.elevator_height_in_cells = 2


## Blades are spaced by corridor rather than counted by area, and both their
## number and their speed are pulled back on maps that cannot carry them
static func _apply_saws(level: MapData, size: int, corridors: float, rules: Difficulty) -> void:
	var at := book()
	var speed := rules.speed * at.player_speed * speed_scale(size)

	level.saw_count = clampi(int(round(corridors / (rules.corridors_per_saw * saw_relief(size)))),
		1, at.max_saws)
	level.ai_saw_count = mini(mini(rules.ai_saws, at.max_ai_saws), maxi(size / 24, 1))
	level.saw_min_patrol_length = rules.patrol.x
	level.saw_max_patrol_length = rules.patrol.y
	level.saw_min_speed = speed.x
	level.saw_max_speed = speed.y
	level.saw_route_spacing = rules.spacing


static func _apply_items(level: MapData, corridors: float, rules: Difficulty) -> void:
	var at := book()

	level.item_count = clampi(int(round(corridors / rules.corridors_per_item)),
		at.min_items, at.max_items)
	level.item_min_distance = 4
	level.item_min_distance_to_player = 3


static func _apply_glass(level: MapData, corridors: float, rules: Difficulty) -> void:
	var at := book()

	level.with_glass_walls = rules.glass_walls
	level.glass_wall_count = mini(int(round(corridors / at.corridors_per_glass_wall)),
		at.max_glass_walls)
	level.glass_wall_item_index = at.glass_item
	level.glass_wall_min_distance = 6


## One offset per part of the level. The same number everywhere would have them
## all draw the identical sequence
static func _apply_seeds(level: MapData, race_seed: int) -> void:
	level.map_seed = race_seed
	level.key_spawn_seed = race_seed + 1
	level.saw_spawn_seed = race_seed + 2
	level.elevator_spawn_seed = race_seed + 3
	level.item_spawn_seed = race_seed + 4
	level.player_spawn_seed = race_seed + 5
	level.glass_wall_seed = race_seed + 6


## About how many corridor cells a map of that size and shape comes out with
static func corridor_count(size: int, shape: int) -> float:
	var at := book()
	var cells := float(size * size) * at.corridor_share
	return cells * at.round_share if shape == 1 else cells


## How much further apart the blades stand than the table asks. Small maps have
## nowhere to dodge to, long ones simply have more corners to survive
static func saw_relief(size: int) -> float:
	var reference := book().reference_size
	return clampf(1.0 + (reference - float(size)) / 128.0, 1.0, 1.25) \
		* clampf(float(size) / reference, 1.0, 1.6)


## Share of the tabled blade speed a map this size may use
static func speed_scale(size: int) -> float:
	return clampf(0.80 + float(size) / 160.0, 0.85, 1.0)


## Loops a small maze gets whatever the difficulty asked. A dead end with a
## faster blade in it is a death nobody could have avoided
static func openness_floor(size: int) -> float:
	return clampf((32.0 - float(size)) / 130.0, 0.0, 0.13)


## Holes a small maze gets in its roof, so a lid does not also take the view
static func roof_floor(size: int) -> float:
	return clampf((40.0 - float(size)) / 60.0, 0.0, 0.4)


## The four sides' colours for one round, rolled off the race seed.
##
## Evenly spaced around the wheel from a random start, so they are different by
## construction rather than by luck — the drift is kept well under the gap
static func roll_team_colors(race_seed: int, count: int) -> Array[Color]:
	var at := book()
	var rng := RandomNumberGenerator.new()
	rng.seed = race_seed + 613

	var start := rng.randf()
	var gap := 1.0 / float(maxi(count, 1))
	var colors: Array[Color] = []

	for team in range(maxi(count, 1)):
		var hue := fmod(start + team * gap + rng.randf_range(-at.team_hue_drift,
			at.team_hue_drift) * gap, 1.0)
		colors.append(Color.from_hsv(hue, at.team_saturation, at.team_value))

	return colors


static func default_settings() -> Dictionary:
	return {"mode": 0, "size": 2, "shape": 0, "difficulty": 2, "teams": 0}


## The same settings with every random one rolled into a real value
static func resolve(settings: Dictionary, race_seed: int) -> Dictionary:
	var rolled := settings.duplicate()
	var rng := RandomNumberGenerator.new()

	for key: String in RANDOM_RANGE:
		if not is_random(key, int(settings.get(key, 0))):
			continue

		rng.seed = race_seed + int(RANDOM_RANGE[key]["salt"])
		rolled[key] = rng.randi_range(0, _random_top(key))

	return rolled


## The highest entry a roll may land on. The range stores it counted back from
## the end of the list, so adding a size or a difficulty keeps the top ones out
## of reach without anybody having to remember to update a number
static func _random_top(key: String) -> int:
	return maxi(options_for(key).size() + int(RANDOM_RANGE[key]["to"]), 0)


static func options_for(key: String) -> Array:
	match key:
		"mode":
			return book().modes
		"size":
			return book().sizes
		"shape":
			return book().shapes
		"teams":
			return book().team_counts

	return book().difficulties


static func allows_random(key: String) -> bool:
	return RANDOM_RANGE.has(key)


## True when that value is the random entry, which sits one past the list
static func is_random(key: String, value: int) -> bool:
	return allows_random(key) and value >= options_for(key).size()


static func index_of(settings: Dictionary, key: String) -> int:
	return clampi(int(settings.get(key, 0)), 0, maxi(options_for(key).size() - 1, 0))


static func mode_of(settings: Dictionary) -> RaceMode:
	return book().modes[index_of(settings, "mode")]


static func size_of(settings: Dictionary) -> int:
	return book().sizes[index_of(settings, "size")].cells


static func shape_of(settings: Dictionary) -> int:
	return book().shapes[index_of(settings, "shape")].shape


static func difficulty_of(settings: Dictionary) -> Difficulty:
	return book().difficulties[index_of(settings, "difficulty")]


static func team_count(settings: Dictionary) -> int:
	return book().team_counts[index_of(settings, "teams")]


## True while the lobby is set to a mode that colours the floor
static func is_paint(settings: Dictionary) -> bool:
	return mode_of(settings).paints_floor


static func team_name(team: int) -> String:
	return ["ALPHA", "BRAVO", "CHARLIE", "DELTA"][clampi(team, 0, 3)]


## What that setting's dropdown offers, random included where it is allowed
static func labels_for(key: String) -> Array:
	var labels: Array = []

	for option: Variant in options_for(key):
		labels.append(_label_of(option))

	if allows_random(key):
		labels.append(RANDOM_LABEL)

	return labels


## The line under that dropdown
static func blurb_for(key: String, value: int) -> String:
	if is_random(key, value):
		return String(RANDOM_RANGE[key]["blurb"])

	var option: Variant = options_for(key)[clampi(value, 0, options_for(key).size() - 1)]
	return String(option.blurb) if option is Resource and "blurb" in option else ""


## What one setting reads as on the lobby heading and in the browser
static func label_of(settings: Dictionary, key: String) -> String:
	var value := int(settings.get(key, 0))
	if is_random(key, value):
		return RANDOM_LABEL

	return _label_of(options_for(key)[index_of(settings, key)])


## Team counts are plain numbers, everything else carries its own name
static func _label_of(option: Variant) -> String:
	return "%d TEAMS" % int(option) if option is int else String(option.label)


## Every randomisable setting turned over to the dice at once
static func all_random() -> Dictionary:
	var rolled: Dictionary = {}

	for key: String in RANDOM_RANGE:
		rolled[key] = options_for(key).size()

	return rolled


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


## The short version, for a row in the lobby browser
static func short_title_of(settings: Dictionary) -> String:
	return "%s · %s" % [label_of(settings, "size"), label_of(settings, "difficulty")]
