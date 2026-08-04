@tool
extends Resource
class_name StatusEffectData

## Something done to a cube by somebody else — a slow, a stun. Unlike an item
## the player never chooses it, so it announces itself with a sound and an icon

## What the network and the code call it
@export var id: String = ""

## What the player sees it called
@export var display_name: String = ""

@export var icon: Texture2D
@export var sound: AudioStream

## Colour of the badge and of whatever it puts on the screen
@export var accent_color := Color(1, 1, 1)

## Seconds it lasts unless whoever applied it says otherwise
@export var duration: float = 8.0

@export_group("What it does")

## What the cube is left of its speed. 1 leaves it alone
@export_range(0.1, 2.0) var speed_multiplier: float = 1.0

## How hard the view swims. 0 leaves the screen alone
@export_range(0.0, 1.0) var wobble: float = 0.0

## Whether the cube is held still entirely for the first moment of it
@export var stun_seconds: float = 0.0
