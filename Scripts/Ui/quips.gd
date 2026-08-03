extends Node

## The commentary track. Everything that happens while a level runs is listened
## for here, and whatever it is worth saying about it goes out as one line the
## game UI puts up as a subtitle.
##
## Drawing the lines is the other half of the job. A pool never repeats itself
## until every line in it has been through, and because this is an autoload that
## memory survives the scene reload a death does, which is exactly the place
## where a repeated line would be noticed

## Emitted with the line the subtitle should show next
signal line_requested(text: String)

## Seconds between two lines about picked up items, the spheres come thick and
## fast on the later levels and every single one of them is not worth a comment
const ITEM_COOLDOWN := 14.0

## The same wait once the player asked for as much talking as there is
const ITEM_COOLDOWN_CHATTY := 5.0

## How often an ordinary death still gets a line on the quiet setting. A round
## number of deaths and an instant one always come through, those are the ones
## worth hearing about
const QUIET_DEATH_CHANCE := 0.35

## Lines that were already used, by the pool they were drawn from
var _used: Dictionary = {}

## The line the next map puts up. A death takes the whole scene with it, so what
## there is to say about it has to wait for the attempt after it
var _pending: String = ""

## When the last line about an item went out, in seconds since the game started
var _last_item_line: float = -INF

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	GameState.key_collected.connect(_on_key_collected)
	ItemSystem.item_changed.connect(_on_item_changed)
	ItemSystem.item_used.connect(_on_item_used)
	Settings.commentary_changed.connect(_on_commentary_changed)


## One line out of that pool, never the same one twice until the whole pool has
## been through. The key is what the pool is remembered under, so two different
## pools can share one key on purpose: the summary draws from a list that is
## mixed together fresh for every run and still never repeats itself
func pick(key: String, lines: Array) -> String:
	if lines.is_empty():
		return ""

	var used: Dictionary = _used.get(key, {})
	var fresh := lines.filter(func(line: String) -> bool: return not used.has(line))

	if fresh.is_empty():
		used.clear()
		fresh = lines.duplicate()

	var chosen: String = fresh[_rng.randi_range(0, fresh.size() - 1)]
	used[chosen] = true
	_used[key] = used
	return chosen


## Puts a line on screen right away, an empty one is quietly dropped
func say(text: String) -> void:
	if text.is_empty():
		return

	line_requested.emit(text)


## Holds a line back for the map that is built next. Used by everything that
## happens right before the scene is thrown away
func say_next(text: String) -> void:
	_pending = text


## The line that was held back, if any. Reading it clears it, so the same line
## cannot come up a second time on the map after that
func take_pending() -> String:
	var line := _pending
	_pending = ""
	return line


## Called by the cube that just burst. The line is held back for the attempt
## after it, where it reads as a comment on what went wrong last time
func report_death(deaths: int, survived: float) -> void:
	if not _allows(&"death"):
		return

	var worth_hearing := GameQuips.MILESTONES.has(deaths) or survived <= GameQuips.QUICK_DEATH_TIME
	if Settings.commentary == Settings.COMMENTARY_LOW and not worth_hearing \
		and _rng.randf() > QUIET_DEATH_CHANCE:
		return

	say_next(_death_line(deaths, survived))


## Whether that kind of remark is still wanted. Deaths are the last thing to go,
## they are the only comments that are about the run rather than about an item
func _allows(what: StringName) -> bool:
	var level := Settings.commentary

	if level == Settings.COMMENTARY_OFF:
		return false

	if level == Settings.COMMENTARY_LOW:
		return what == &"death"

	if level == Settings.COMMENTARY_MEDIUM:
		return what != &"item_used"

	return true


## Which of the death pools this one belongs in. A round number of deaths is
## worth its own remark, an instant death is worth a different one, and past a
## certain tally the whole thing occasionally stops being friendly
func _death_line(deaths: int, survived: float) -> String:
	if deaths >= GameQuips.EXTREME_FROM and _rng.randf() < GameQuips.EXTREME_CHANCE:
		return pick("death_extreme", GameQuips.EXTREME)

	if GameQuips.MILESTONES.has(deaths):
		return pick("death_at_%d" % deaths, GameQuips.MILESTONES[deaths])

	if survived <= GameQuips.QUICK_DEATH_TIME:
		return pick("death_quick", GameQuips.QUICK_DEATHS)

	return pick("death", GameQuips.DEATHS)


## Switched off between a death and the map after it, the line that was waiting
## has nowhere left to go
func _on_commentary_changed() -> void:
	if Settings.commentary == Settings.COMMENTARY_OFF:
		_pending = ""


func _on_key_collected() -> void:
	if _allows(&"key"):
		say(pick("key", GameQuips.KEY))


## A sphere handed out an item. The slot is also emptied through this signal, so
## only an item that actually arrived says anything
func _on_item_changed(item: ItemData) -> void:
	if item == null or not _allows(&"item"):
		return

	var wait := ITEM_COOLDOWN_CHATTY if Settings.commentary >= Settings.COMMENTARY_HIGH \
		else ITEM_COOLDOWN
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_item_line < wait:
		return

	var id := ItemSystem.id_of(item)
	if not GameQuips.ITEMS.has(id):
		return

	_last_item_line = now
	say(pick("item_%s" % id, GameQuips.ITEMS[id]))


func _on_item_used(_item: ItemData) -> void:
	if _allows(&"item_used"):
		say(pick("item_used", GameQuips.ITEM_USED))
