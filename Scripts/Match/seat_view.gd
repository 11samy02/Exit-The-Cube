class_name SeatView

## Who sees what on a split screen.
##
## A local race is one maze that everybody walks through at once, but it has to
## read like the online one: your own cube solid, the others as ghosts, your own
## key and nobody else's. Building a maze per player would be the literal way to
## get that and costs four of everything — four sets of physics, four sets of
## blades, four of the same corridors drawn.
##
## So the maze stays one and the answer is which camera looks at which layer. A
## visual layer is per object and a cull mask is per camera, which is exactly the
## shape of the question: this cube is seat two's, and seat two's camera is the
## only one that draws it.
##
## Three bands of four bits each, well clear of the eight the level itself uses:
##
##   ghost   the cube as everybody else sees it — transparent, no solid mesh
##   body    the cube as its own player sees it, dropped again in ego view
##   private that seat's own things: its key, and whatever its items put up

## Where each band starts
const GHOST_BASE := 8
const BODY_BASE := 12
const PRIVATE_BASE := 16

## The layers the level itself is drawn on, which everybody sees
const WORLD_MASK := 0xFF

## The one layer inside that band anything shared is put on. A bot belongs to
## nobody in particular, so it is drawn where the maze itself is drawn: every
## camera in the window already looks at this, and it costs no band of its own
const SHARED := 1 << 0

## How many seats the bands have room for
const MAX_SEATS := 4


static func ghost_bit(seat: int) -> int:
	return 1 << (GHOST_BASE + clampi(seat, 0, MAX_SEATS - 1))


static func body_bit(seat: int) -> int:
	return 1 << (BODY_BASE + clampi(seat, 0, MAX_SEATS - 1))


static func private_bit(seat: int) -> int:
	return 1 << (PRIVATE_BASE + clampi(seat, 0, MAX_SEATS - 1))


## What that seat's camera is allowed to draw: the level, its own cube, its own
## things, and everybody else's ghost — but not their cubes and not their keys
static func mask_for(seat: int) -> int:
	var mask := WORLD_MASK | body_bit(seat) | private_bit(seat)

	for other in range(MAX_SEATS):
		if other != seat:
			mask |= ghost_bit(other)

	return mask


## Which layer that cube's ghost belongs on. A bot has no seat anybody is
## sitting in, so its double is the one thing in the maze everybody sees alike
static func ghost_bit_of(cube: Player) -> int:
	return SHARED if cube.is_bot else ghost_bit(cube.seat)


## Puts a whole subtree onto one layer, so an item that threw up half a dozen
## meshes does not have to name every one of them
static func mark(from: Node, layers: int) -> void:
	if from is VisualInstance3D:
		(from as VisualInstance3D).layers = layers

	for child in from.get_children():
		mark(child, layers)
