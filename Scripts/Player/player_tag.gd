class_name PlayerTag
extends Label3D

## The name floating over a cube.
##
## Built rather than put in the player scene: a level with one cube in it has
## nobody to tell apart, and a name hanging over your own head in the campaign
## is a label on a room you are alone in.
##
## Which cameras see it is the same question the ghost answers. In a race read as
## your own, the tag belongs to the double and not to the body — you should read
## the name off the shape going past, not off the cube you are looking through

## How far over the cube it floats
const HEIGHT := 1.35

## Metres past which the name is no longer worth drawing. A maze full of tags
## seen through every corridor is a scoreboard laid over the level
const READ_RANGE := 26.0


## One tag on that cube, or nothing when the level has nobody to name
static func attach_to(cube: Player) -> PlayerTag:
	var made := PlayerTag.new()
	made.name = "Tag"
	made._dress(cube)
	cube.add_child(made)
	made.position = Vector3.UP * HEIGHT
	return made


## The name, in the colour the round draws that cube in, on the layer whoever is
## meant to read it is looking at
func _dress(cube: Player) -> void:
	text = cube.display_name()
	modulate = Match.color_of(cube.account())
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = false
	fixed_size = true
	pixel_size = 0.0007
	font_size = 64
	outline_size = 22
	outline_modulate = Color(0, 0, 0, 0.85)
	visibility_range_end = READ_RANGE
	visibility_range_end_margin = 4.0

	if Match.is_private_race():
		layers = SeatView.ghost_bit_of(cube)
