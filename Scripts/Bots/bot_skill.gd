@tool
extends Resource
class_name BotSkill

## One rung of the CPU ladder. Everything that makes a bot better at the game
## moves together in here, edited in the inspector rather than in a script

## How a bot reads the blades
enum Danger {
	## Only what it can actually see down a corridor, and only where it is now
	SIGHT,
	## Everything close by, wall or no wall, a moment into the future
	CORNER,
	## Where the blade will be by the time the bot gets there
	AHEAD,
}

## When a bot spends what it is carrying
enum Items {
	## Never, the slot is only ever filled
	NEVER,
	## As soon as it has held it long enough
	WHENEVER,
	## Only where the item actually buys it something
	WHEN_IT_PAYS,
}

@export var label: String = "NORMAL"
@export_multiline var blurb: String = ""

@export_group("Head")

## Seconds between two rethinks of where it is walking
@export var think_interval: float = 0.5

## Seconds a fresh decision takes to reach the feet
@export var reaction_time: float = 0.2

## Share of the cube's top speed it asks for
@export_range(0.2, 1.0) var pace: float = 0.9

## Chance per rethink that it walks off somewhere pointless instead
@export_range(0.0, 1.0) var mistake_chance: float = 0.05

## How many cells it weighs up before settling on one. More is a better choice
## and a longer think
@export var foresight: int = 40

@export_group("Eyes")

## Which of the three ways it reads a blade
@export var danger: Danger = Danger.CORNER

## Meters of room it tries to keep around a blade
@export var danger_range: float = 4.5

## Seconds of the blade's own travel it plays forward before judging the gap
@export var danger_lookahead: float = 0.6

## How many cells down its own route it checks for a blade before setting off.
## 0 leaves it walking into whatever crosses in front of it, which is the whole
## of what makes the bottom rung the bottom rung
@export var look_ahead_cells: int = 2

## Meters of room it insists on around a blade before it will step onto a cell.
## The better a rung reads where a blade is going, the finer it may cut it —
## a wide margin on a bot that already knows is a bot standing about
@export var blade_room: float = 1.8

## Whether it takes the way around a blade rather than waiting for one. It walks
## the corridors it can see are clear instead of stopping at the corner
@export var routes_around_blades: bool = false

## Whether it reads every blade in the maze rather than the ones near it. Only
## the top rung is given this: it knows where each of them is, how fast it runs
## and the route it is walking, so nothing in the level can surprise it
@export var sees_all_blades: bool = false

@export_group("Memory")

## True while it simply knows where the key and the way out are. Off, it has to
## walk close enough to one to find it
@export var knows_objectives: bool = false

## How far it counts as having seen the maze around itself, in cells
@export var sight_range: int = 16

@export_group("Items")

## Which of the three ways it decides to spend an item
@export var items: Items = Items.WHEN_IT_PAYS

## Seconds it sits on a fresh item before it may be spent
@export var item_delay: float = 1.2

## How far off its way it walks for a sphere it has seen, in cells. 0 leaves it
## picking up only what it runs into anyway
@export var item_detour: int = 6

@export_group("Painting")

## How many cells of fresh floor it lines up at a time. A painter does not want
## the shortest way anywhere — it wants the longest run of floor nobody has taken
## yet, and this is how far ahead it lays one out
@export var paint_route: int = 12

@export_group("Teamwork")

## How hard a team mate's patch of the map pushes this one off it. 0 leaves four
## bots on a side walking the same corridor
@export_range(0.0, 1.0) var spread: float = 0.5

## How many cells around a team mate's target count as taken
@export var spread_radius: int = 14
