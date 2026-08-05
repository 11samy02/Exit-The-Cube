class_name MatchTransport
extends RefCounted

## The seam between a round and the machines it is being played on.
##
## A splitscreen round has no wire at all: everything that happens has already
## happened on the one machine watching it, and there is nobody to tell. So the
## router holds one of these only when there is somewhere for a change to go,
## and the round itself never learns which of the two it is in.
##
## Only what one machine decides on its own behalf goes out. Positions, counters
## and the blade tracking stay in the online node — those are its own traffic,
## not a change to the round anybody else could have made

## This cube took a tile
func send_paint(_account: int, _cell: Vector2i, _stamp: float) -> void:
	pass


## This cube gave tiles back, as [cell, stamp] pairs
func send_unpaint(_account: int, _tiles: Array) -> void:
	pass


## A roller scrubbed a tile bare, whoever it belonged to
func send_erase(_cell: Vector2i) -> void:
	pass


## Something was done to a cube this machine does not own. Their machine decides
## what it means
func send_status(_account: int, _effect: String, _seconds: float) -> void:
	pass


## A cube this machine does not own was caught. Their machine does the killing —
## nobody else gets to decide when your cube dies
func send_hit(_account: int) -> void:
	pass
