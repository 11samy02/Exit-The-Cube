class_name RunComments

## The line the summary screen puts under the title. Every bucket below is tied
## to one way of finishing a run, and a run usually hits more than one of them,
## so the line is drawn out of everything that matched. A run that hit nothing
## in particular falls back to the plain ones.
##
## Drawing is left to the Quips autoload, which is what keeps the summary from
## saying the same thing two levels in a row

## Seconds under which a run counts as fast
const FAST_TIME := 90.0

## Seconds over which the run gets a comment about how long it took
const SLOW_TIME := 300.0

## Seconds from which it stopped being a run and became an expedition
const CRAWL_TIME := 600.0

## Deaths from which the roast stops being friendly
const MANY_DEATHS := 10

## Deaths from which it stops being a roast
const BRUTAL_DEATHS := 30

## Deaths that are worth a remark but not worth a roast
const SOME_DEATHS := 4

## Items spent from which the player clearly leaned on them
const HEAVY_ITEM_USE := 4

const FLAWLESS_FAST := [
	"No deaths, no detours. Was this maze even switched on?",
	"Flawless and fast. The saws are filing a complaint.",
	"That was surgical. Frame this run and hang it somewhere.",
	"Perfect and quick. You are legally allowed to be smug about this.",
	"Nobody is beating that. Absolutely nobody. Especially not you, next time.",
	"Clean and fast. Somewhere a speedrunner just woke up sweating.",
	"You walked through that like you built it.",
	"Not one scratch and not one wasted second. Show off.",
	"The maze had one job and you did not give it the chance.",
	"That run belongs in a museum. A small one, but still.",
]

const FLAWLESS := [
	"Not a single death. Boring for the saws, great for you.",
	"Untouched. The blades never even got to say hi.",
	"Clean sheet. Show off.",
	"Zero deaths. Somebody has been practising.",
	"You did not lose a single cube. The factory is confused.",
	"No wrecks on the floor. The walls stayed their original colour.",
	"Perfect run. Slow, but perfect, and perfect is the rare one.",
	"The saws spun the whole time for nothing.",
	"Flawless. Do that again and it stops being luck.",
	"Not one respawn. Suspicious, honestly.",
]

const FAST := [
	"Fast, messy, effective. A speedrun with casualties.",
	"You sprinted through it and only exploded a bit on the way. Deal.",
	"Quick exit. The maze barely had time to be a maze.",
	"Speed over safety, and it somehow paid off.",
	"You did not solve that maze, you outran it.",
	"Reckless and quick. The best kind of wrong.",
	"That was fast enough that the saws are still looking for you.",
	"Blink and it was over. For you and for several cubes.",
	"Quick, loud and expensive. Worth it.",
	"You took the short way. The short way took a few of you.",
]

const MANY_DEATHS_LINES := [
	"At this point the saws know you by name.",
	"You did not solve this maze, you slowly bled through it.",
	"That is a lot of respawns. The cube factory wants a word.",
	"Every blade in here got a turn with you. How generous.",
	"You made it out. Statistically, something had to work eventually.",
	"Brute force is a strategy. Not a good one, but a strategy.",
	"The walls are more colourful than when you started.",
	"You wore the level down instead of beating it. Counts the same.",
	"That was less a run and more a series of short ones.",
	"Persistence: yes. Technique: to be discussed.",
	"The elevator saw you coming and it saw you not coming, repeatedly.",
	"You finished. The bodies are somebody else's problem.",
]

const BRUTAL_DEATHS_LINES := [
	"That death count is not a number any more, it is a diagnosis.",
	"You beat that level the way water beats a rock. Very slowly.",
	"The maze did not get easier, you just ran out of ways to die.",
	"Nobody needs to know how many attempts that took. Nobody.",
	"You have donated more cubes to this level than it had corners.",
	"Congratulations, technically.",
	"That was not a victory, that was an eviction.",
	"The saws are honestly a little embarrassed for both of you.",
	"You got there. Please do not look at the death counter again.",
	"A win is a win, and this one is barely one.",
]

const SOME_DEATHS_LINES := [
	"A few deaths, nothing a little denial cannot fix.",
	"You left some cube bits behind. Consider it decoration.",
	"Not clean, not a disaster. The middle of the road, like your driving.",
	"A handful of mistakes and one good decision at the end.",
	"You paid for that exit, but you did not overpay.",
	"Some wrecks, some progress. Fair trade.",
	"Nearly clean. Nearly is doing a lot of work in that sentence.",
	"A couple of blades got lucky. Only a couple.",
	"That is the normal amount of dying. Almost respectable.",
	"You lost a few and learned a few. Even split.",
]

const SLOW := [
	"That took a while. The elevator almost went home.",
	"Slow and steady. Mostly slow.",
	"You did not beat the maze, you outlasted it.",
	"Were you taking pictures in there?",
	"Careful pace. Very careful. Extremely careful.",
	"The saws had time to develop hobbies.",
	"You explored every corridor, including the ones nobody needed.",
	"Patience is a virtue and you have somehow overdone it.",
	"That was a walk, not a run.",
	"The maze got old waiting for you.",
]

const CRAWL := [
	"That was not a run, that was an occupation.",
	"You lived in that maze. You had a routine in there.",
	"The clock gave up somewhere around the middle.",
	"At that pace the elevator could have come to you.",
	"You spent long enough in there to learn the wallpaper.",
	"Ten minutes. In a maze this size. Genuinely a choice.",
	"Somebody should check whether you were actually moving.",
	"The saws took shifts.",
]

const NO_ITEMS := [
	"Not one item picked up. Purist, or just walking past everything?",
	"Zero items. Bare handed through a room full of saws, respect. Or stupidity.",
	"You ignored every sphere out there. Bold.",
	"No items at all. The spheres are still sitting there, waiting.",
	"You did that raw. Nobody asked you to, but you did.",
	"Not a single pickup. The maze put those there for a reason.",
	"Hard mode by accident, probably.",
	"The items were free. You still said no.",
	"Untouched spheres everywhere. They will be fine.",
	"No help, no items, no problem, apparently.",
]

const HOARDER := [
	"You collected items and used exactly none. They are not souvenirs.",
	"Nice little collection. Pressing the button would have been the point.",
	"Carrying items to the exit does not unlock anything, you know.",
	"You held on to every single one. For what, exactly?",
	"Items are consumables, not trophies.",
	"The slot was full the whole way and stayed that way. Bold.",
	"Saving them for a special occasion? That was the occasion.",
	"You picked things up and then simply refused to use them.",
	"That is not inventory management, that is hoarding.",
	"Every item you found is still unopened. Impressive restraint, terrible plan.",
]

const ITEM_JUNKIE := [
	"Can't find your way without items, huh?",
	"You used everything you touched. The items did that run, be honest.",
	"That was less a maze and more an item tutorial.",
	"Item, item, item. Did you walk at all?",
	"The spheres carried you and they know it.",
	"You spent them faster than the maze could hand them out.",
	"Nothing wrong with using items. That many, though.",
	"You cleared it with help. A lot of help.",
	"At some point that stops being a run and starts being a shopping trip.",
	"The maze was hard. The items made it a formality.",
]

const PLAIN := [
	"Out. Barely elegant, but out.",
	"Exit found. The maze regenerates and forgets you immediately.",
	"Level cleared. The cube lives another day.",
	"Solid run. Nothing to brag about, nothing to hide.",
	"Done. Next set of walls is already waiting.",
	"That worked. Do not ask how.",
	"You are out and the maze is still in there. Somewhere.",
	"Cleared. The elevator did the last bit for you, as always.",
	"Good enough. Good enough is underrated.",
	"One level down. There are more. There are always more.",
	"That was a run. It happened. It is over.",
	"The doors closed behind you and nothing exploded. Rare.",
]


## Every line that fits this run, one bucket after the other. The buckets are
## not exclusive on purpose, a fast run without items should be able to say
## either of those things. Never comes back empty, the plain bucket catches
## everything that matched nothing
static func matching_lines(deaths: int, run_time: float, collected: int, used: int) -> Array:
	var lines := []

	if deaths == 0 and run_time <= FAST_TIME:
		lines.append_array(FLAWLESS_FAST)
	elif deaths == 0:
		lines.append_array(FLAWLESS)
	elif run_time <= FAST_TIME:
		lines.append_array(FAST)

	if deaths >= BRUTAL_DEATHS:
		lines.append_array(BRUTAL_DEATHS_LINES)
	elif deaths >= MANY_DEATHS:
		lines.append_array(MANY_DEATHS_LINES)
	elif deaths >= SOME_DEATHS:
		lines.append_array(SOME_DEATHS_LINES)

	if run_time >= CRAWL_TIME:
		lines.append_array(CRAWL)
	elif run_time >= SLOW_TIME:
		lines.append_array(SLOW)

	if collected == 0:
		lines.append_array(NO_ITEMS)
	elif used == 0:
		lines.append_array(HOARDER)
	elif used >= HEAVY_ITEM_USE:
		lines.append_array(ITEM_JUNKIE)

	if lines.is_empty():
		lines.append_array(PLAIN)

	return lines
