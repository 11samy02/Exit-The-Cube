extends CharacterBody3D
class_name Player

## The cube itself, and the one place anything outside it looks up the scripts
## hanging under it.
##
## Everything used to find those through get_first_node_in_group, which answers
## with whichever player happened to be added first. That is the right cube for
## as long as there is only ever one, and the wrong one the moment a second
## joins: a saw would burst the cube on the other side of the maze rather than
## the one that walked into it

## Where the accounts of the local seats start. Well clear of zero and stepping
## by a wide margin, so nothing that hashes an account lands four seats on four
## shades of the same colour
const ACCOUNT_BASE := 9001
const ACCOUNT_STEP := 137

## Which seat drives this cube. Written by the spawner before the node is added
## to the tree, so every script under it may read it in its own _ready
@export var seat: int = 0

## True for a cube the game drives itself. Written by the spawner alongside the
## seat, and read by everything under here that would otherwise reach for an
## input, a camera or a piece of the window that a bot does not have
@export var is_bot: bool = false

## True for a cube that was already out there before the level was rebuilt and
## has simply been put back where it was. It skips the entrance: a CPU that
## nobody killed must not pull itself together out of a swarm of debris just
## because somebody else walked into a blade
@export var carried_over: bool = false

@onready var movement: PlayerMovement = $Scripts/Movement
@onready var camera_rig: PlayerCamera = $Scripts/Camera
@onready var perspective: PlayerPerspective = $Scripts/Perspective
@onready var animator: PlayerAnimator = $Scripts/Animator
@onready var tint: PlayerColor = $Scripts/Color
@onready var audio: PlayerAudio = $Scripts/Audio
@onready var death: PlayerDeath = $Scripts/Death
@onready var spawn: PlayerSpawn = $Scripts/Spawn
@onready var inventory: PlayerInventory = $Scripts/Inventory
@onready var view: Camera3D = $"Camera Pivot/Camera3D"


## Who this cube is to a round. A local seat has no Steam account to go by, so
## it is handed one of its own that everything account keyed can be filed under
func account() -> int:
	return account_for(seat)


## The account that seat carries, without needing a cube to ask it of
static func account_for(index: int) -> int:
	return ACCOUNT_BASE + index * ACCOUNT_STEP


## The cube that node belongs to. Walks up rather than searching, so an effect
## or a script under the player finds its own and never somebody else's
static func of(node: Node) -> Player:
	var at := node

	while at != null:
		if at is Player:
			return at as Player

		at = at.get_parent()

	return null


## Every cube in the level, in seat order
static func all(tree: SceneTree) -> Array[Player]:
	var players: Array[Player] = []

	for node in tree.get_nodes_in_group("player"):
		if node is Player:
			players.append(node as Player)

	players.sort_custom(func(a: Player, b: Player) -> bool: return a.seat < b.seat)
	return players


## True for a cube that is only a shape going past in somebody else's maze. It
## may not touch anything the players share: no sphere off the floor, no blood
## on the walls, no doors opened, nothing a camera draws but the double
func is_ghosted() -> bool:
	return is_bot and Match.bots_are_ghosts()


## What this cube is called on the board and over its ghost
func display_name() -> String:
	return Bots.name_of(seat - Match.human_count()) if is_bot else "P%d" % (seat + 1)


static func at_seat(tree: SceneTree, index: int) -> Player:
	for node in tree.get_nodes_in_group("player"):
		if node is Player and (node as Player).seat == index:
			return node as Player

	return null


## The cube closest to that point, which is what something hunting through the
## maze wants rather than the first one that was spawned.
##
## A ghost is never hunted. In a race everybody reads the maze as their own, and
## a blade that leaves the player to go after a CPU has changed the level for
## somebody who cannot even see what it went after
static func nearest(tree: SceneTree, to: Vector3) -> Player:
	var best: Player = null
	var best_distance := INF

	for node in tree.get_nodes_in_group("player"):
		if not node is Player or (node as Player).is_ghosted():
			continue

		var distance := (node as Player).global_position.distance_squared_to(to)
		if distance < best_distance:
			best_distance = distance
			best = node as Player

	return best
