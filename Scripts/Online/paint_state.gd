class_name PaintState
extends RefCounted

## Who owns which tile of the floor, and the rules that decide it.
##
## Nothing in here touches the network or the screen. It is the one place that
## answers "whose colour is this cell", so that the renderer, the scoreboard and
## the machine on the other end of the line all agree by construction rather
## than by three separate pieces of code happening to work the same way.
##
## Every claim carries a stamp. Two players stepping on the same tile at nearly
## the same moment reach the two machines in either order, and a rule of "the
## last packet wins" would leave them permanently disagreeing about the colour.
## The higher stamp wins instead, and an equal stamp is broken by the account
## number — both machines see the same pair of claims and reach the same answer
## whichever arrived first

## One claim on one cell
class Claim:
	var team: int
	var owner: int
	var stamp: float

	func _init(from_team: int, from_owner: int, at: float) -> void:
		team = from_team
		owner = from_owner
		stamp = at

## Cell to Claim, for every cell anybody has painted
var claims: Dictionary = {}

## How many cells each player has taken at any point, whether they still hold
## them or not. This is what "who painted the most" means: repainting over
## somebody counts for the player who did it, and losing it again later does not
## take the work back
var painted_total: Dictionary = {}


## Lays a claim, and says whether it changed anything. A claim that loses to the
## one already on the cell is dropped, which is what makes the order packets
## arrive in stop mattering
func claim(cell: Vector2i, team: int, owner: int, stamp: float) -> bool:
	var standing: Claim = claims.get(cell, null)

	if standing != null and not _beats(owner, stamp, standing):
		return false

	claims[cell] = Claim.new(team, owner, stamp)
	painted_total[owner] = int(painted_total.get(owner, 0)) + 1
	return true


## Takes a cell back off a player, used when a death costs them their last few.
## It only lifts a claim that is still theirs and still the one it was: a tile
## somebody else has painted over since is no longer ours to give up, and taking
## it would hand them a hole in their own colour
func release(cell: Vector2i, owner: int, stamp: float) -> bool:
	var standing: Claim = claims.get(cell, null)

	if standing == null or standing.owner != owner or not is_equal_approx(standing.stamp, stamp):
		return false

	claims.erase(cell)
	return true


## How many cells each team holds right now, by team number
func tally() -> Dictionary:
	var counts: Dictionary = {}

	for cell: Vector2i in claims:
		var team: int = (claims[cell] as Claim).team
		counts[team] = int(counts.get(team, 0)) + 1

	return counts


## How many cells that player is holding at the moment
func held_by(owner: int) -> int:
	var held := 0

	for cell: Vector2i in claims:
		if (claims[cell] as Claim).owner == owner:
			held += 1

	return held


## The team with the most floor, -1 while nothing is painted at all. A draw is
## reported as a draw rather than as whichever team happened to be counted first
func leader() -> int:
	var counts := tally()
	var best := -1
	var most := 0
	var drawn := false

	for team: int in counts:
		var held: int = counts[team]
		if held > most:
			most = held
			best = team
			drawn = false
		elif held == most:
			drawn = true

	return -1 if drawn else best


func clear() -> void:
	claims.clear()
	painted_total.clear()


## Whether a new claim takes a cell off the one standing on it. Later wins, and
## an exact tie goes to the lower account so that both machines agree without
## having to ask each other
func _beats(owner: int, stamp: float, standing: Claim) -> bool:
	if not is_equal_approx(stamp, standing.stamp):
		return stamp > standing.stamp

	return owner < standing.owner
