extends ItemEffect
class_name GlassWallEffect

## Drops every pane in the level into the floor and leaves them down for as long
## as this runs. While they are down the maze has holes in it that are not on
## anybody's map of it, and the way through can be cut straight across.
##
## What the item does not do is warn the player when it is over. The panes come
## back up wherever they are, and a cube standing on one comes up with it. That
## is the whole trade: the shortcut and the ride onto the roof of the maze are
## the same item, and both of them run on the same clock.

## The panes this effect dropped, and only those. One that was already down is
## not this item's to bring back up
var lowered: Array[GlassWall] = []


func _start() -> void:
	for node in get_tree().get_nodes_in_group("glass_wall"):
		var wall := node as GlassWall
		if wall == null or wall.is_open:
			continue

		if wall.seat >= 0 and wall.seat != seat:
			continue

		wall.open()
		lowered.append(wall)



func _stop(_cancelled: bool) -> void:
	for wall in lowered:
		if is_instance_valid(wall):
			wall.close()

	lowered.clear()
