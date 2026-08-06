class_name Bots
extends RefCounted

## The one place anything asks about the CPU players. What they are like lives
## in Resources/Bots/Bots.tres, not here.
##
## The rung a round is played on is a number in the party settings, exactly like
## the map size or the difficulty, so a bot needs nothing carried alongside the
## rules it was started with

const BOOK_PATH := "res://Resources/Bots/Bots.tres"

## What the party screen and the lobby store under, next to the rules
const COUNT_KEY := "cpus"
const SKILL_KEY := "cpu_skill"

## Where the accounts of bots in an online round start, and how far apart.
##
## Small numbers on purpose: a Steam account is a sixty four bit id in the
## quadrillions, so nothing down here can ever collide with a real one. Every
## machine works the same accounts out of the lobby's own bot count, which is
## what lets a client put a CPU on its board without a word being sent about it
const ACCOUNT_BASE := 4001
const ACCOUNT_STEP := 91


## The account the bot in that slot runs under
static func account_for(index: int) -> int:
	return ACCOUNT_BASE + index * ACCOUNT_STEP


## True for an account that belongs to a bot rather than to somebody's Steam
static func is_bot_account(account: int) -> bool:
	if account < ACCOUNT_BASE or (account - ACCOUNT_BASE) % ACCOUNT_STEP != 0:
		return false

	return (account - ACCOUNT_BASE) / ACCOUNT_STEP < max_players()


## The accounts of every bot in a round with that many of them
static func accounts_for(count: int) -> Array[int]:
	var found: Array[int] = []

	for at in range(maxi(count, 0)):
		found.append(account_for(at))

	return found

static var _book: BotBook = null


## The book, loaded once
static func book() -> BotBook:
	if _book == null:
		_book = load(BOOK_PATH) as BotBook

	return _book


## How many cubes a round on one screen may hold at all, humans and bots
static func max_players() -> int:
	return maxi(book().max_players, 1)


## How many bots may still be added with that many people in the room
static func max_bots(humans: int) -> int:
	return maxi(max_players() - maxi(humans, 1), 0)


static func skill_of(rung: int) -> BotSkill:
	var ladder := book().skills
	if ladder.is_empty():
		return BotSkill.new()

	return ladder[clampi(rung, 0, ladder.size() - 1)]


static func default_skill() -> int:
	return clampi(book().default_skill, 0, maxi(book().skills.size() - 1, 0))


## What that rung reads as on the party screen
static func skill_labels() -> Array:
	var labels: Array = []

	for skill in book().skills:
		labels.append(skill.label)

	return labels


## The dropdown for how many of them there are, capped by the room
static func count_labels(humans: int) -> Array:
	var labels: Array = ["NO CPUS"]

	for count in range(1, max_bots(humans) + 1):
		labels.append("%d CPU%s" % [count, "" if count == 1 else "S"])

	return labels


## What the bot in that slot is called on the board
static func name_of(index: int) -> String:
	var names := book().names
	if names.is_empty():
		return "CPU %d" % (index + 1)

	if index < names.size():
		return String(names[index])

	return "CPU %d" % (index + 1)


## How many bots those settings ask for, already cut down to what fits
static func count_in(settings: Dictionary, humans: int) -> int:
	return clampi(int(settings.get(COUNT_KEY, 0)), 0, max_bots(humans))


## The same count read off a lobby, clamped by nothing but the size of a room.
##
## Every machine has to reach the same number or the boards disagree about who is
## even in the race — and the member list is exactly the thing that arrives at a
## different moment on each of them, so it may not be part of the sum. The lobby
## setting is the only input
static func count_in_lobby(settings: Dictionary) -> int:
	return clampi(int(settings.get(COUNT_KEY, 0)), 0, max_players() - 1)


static func skill_in(settings: Dictionary) -> BotSkill:
	return skill_of(int(settings.get(SKILL_KEY, default_skill())))
