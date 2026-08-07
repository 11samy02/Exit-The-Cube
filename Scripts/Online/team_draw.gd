class_name TeamDraw
extends RefCounted

## Who is on whose side, and where each of them comes in.
##
## Both are worked out from the accounts in the lobby and the one seed the whole
## room shares, and nothing about either is sent. Every machine sorts the same
## accounts, shuffles them with the same seed and deals them out the same way, so
## they all reach the same teams without a word about it — the same trick the
## maze itself is built with.
##
## Sorting first is what makes that true. Steam hands the member list back in no
## particular order, and a shuffle of two differently ordered lists with the same
## seed gives two different answers

## Deals the accounts into that many teams, evenly.
##
## Round robin over a shuffled list, which cannot help but be balanced: the
## teams differ by at most one player however many turn up. Handing each player
## a random side instead is the obvious way and the wrong one — it is perfectly
## capable of putting five on one side and one on the other
static func teams_of(accounts: Array, count: int, race_seed: int) -> Dictionary:
	var sorted := _sorted(accounts)
	var rng := RandomNumberGenerator.new()
	rng.seed = race_seed
	_shuffle(sorted, rng)

	var teams: Dictionary = {}
	var sides := maxi(count, 1)

	for at in range(sorted.size()):
		teams[sorted[at]] = at % sides

	return teams


## Where every player comes in, one cell each and no two the same.
##
## Each team is given its own corner of the maze to start from, so a round opens
## with the sides apart rather than all of them treading on the same tiles. Team
## zero starts nearest one corner, the next one the corner across from it, and so
## on — with two teams that is opposite ends, with four it is all four corners.
##
## Within a corner the players are handed the closest free cells to it in turn,
## which keeps a side together without ever putting two cubes in one place
static func spawns_of(teams: Dictionary, count: int, cells: Array, size: int) -> Dictionary:
	var spawns: Dictionary = {}
	if cells.is_empty():
		return spawns

	var taken: Dictionary = {}
	var sides := maxi(count, 1)

	for team in range(sides):
		var corner := _corner_of(team, size)
		var members := _sorted(_members_of(teams, team))
		var ranked := _by_distance(cells, corner)

		for account: int in members:
			for cell: Vector2i in ranked:
				if not taken.has(cell):
					taken[cell] = true
					spawns[account] = cell
					break

	return spawns


## The stretch of maze a team calls its own, nearest cell to its corner first.
##
## Used for coming back rather than for coming in. A player who dies should not
## be handed the same tile every time — they have just painted everything around
## it, and standing them back on it makes a death cost the walk out and nothing
## else. Anywhere in their own end of the maze is fair, and it does not have to
## agree with the other machines: where this cube reappears reaches them as a
## position like every other one
static func region_of(team: int, cells: Array, size: int, take: int) -> Array:
	var ranked := _by_distance(cells, _corner_of(team, size))
	ranked.resize(mini(maxi(take, 1), ranked.size()))
	return ranked


## The corner of the map a team starts from. The first two are diagonally
## opposite on purpose, so a two team round opens at opposite ends of the maze
## rather than with both sides sharing a wall
static func _corner_of(team: int, size: int) -> Vector2i:
	var corners := [
		Vector2i(1, 1),
		Vector2i(size - 2, size - 2),
		Vector2i(size - 2, 1),
		Vector2i(1, size - 2),
	]

	return corners[team % corners.size()]


static func _members_of(teams: Dictionary, team: int) -> Array:
	var found: Array = []

	for account: int in teams:
		if int(teams[account]) == team:
			found.append(account)

	return found


## The cells nearest that corner first, measured straight across rather than
## through the corridors. It only decides which end of the map a side comes in
## at, and a flood fill per team per round is a great deal of work for that
static func _by_distance(cells: Array, corner: Vector2i) -> Array:
	var sorted := cells.duplicate()

	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(Vector2(corner)) \
			< Vector2(b).distance_squared_to(Vector2(corner)))

	return sorted


## Accounts in a fixed order, so that every machine starts from the same list
static func _sorted(accounts: Array) -> Array:
	var sorted := accounts.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool: return a < b)
	return sorted


## Array.shuffle draws from the global generator and would give every machine a
## different answer, which is the one thing this must never do
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for at in range(items.size() - 1, 0, -1):
		var to := rng.randi_range(0, at)
		var swap: Variant = items[at]
		items[at] = items[to]
		items[to] = swap
