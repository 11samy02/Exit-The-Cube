class_name DownCard
extends PanelContainer

## The card that comes up while a cube is sitting out a death.
##
## A player who bursts and then waits five seconds looking at an empty corridor
## has no way of telling a penalty from a hang. This says how long is left, that
## the cube is coming back, and what the death cost.
##
## The race panel puts one over the whole window and a split screen puts a
## smaller one into each seat's own piece. They are the same card on purpose: a
## wait that looks like a panel online and like a bare number in splitscreen
## reads as two different things happening

## How wide the card is. Fixed so the number inside it does not make the whole
## thing jump between one digit and two
const WIDTH := 380.0

var _title: Label = null
var _clock: Label = null
var _cost: Label = null


## Scaled down rather than laid out again for a smaller split: a quarter of a
## window is a quarter of the room, not a different design
func _init(size_scale: float = 1.0) -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH * size_scale, 0)
	add_theme_stylebox_override("panel", _style(size_scale))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(8 * size_scale))
	add_child(column)

	_title = OnlineUi.heading("RESPAWN IN", roundi(24 * size_scale), OnlineUi.WAITING)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_clock = OnlineUi.heading("", roundi(82 * size_scale), OnlineUi.TEXT)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_clock)

	_cost = OnlineUi.body("", roundi(21 * size_scale), OnlineUi.MUTED)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_cost)


## The card's own frame rather than the shared one. The panels elsewhere are
## built for rows of text and their padding is measured for that; a single
## eighty point number inside the same margins sits against its own border
func _style(size_scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.94)
	style.border_color = OnlineUi.WAITING
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(12 * size_scale))
	style.content_margin_left = 40.0 * size_scale
	style.content_margin_right = 40.0 * size_scale
	style.content_margin_top = 22.0 * size_scale
	style.content_margin_bottom = 26.0 * size_scale
	return style


## Puts the card up with the seconds left on it, and takes it down again at zero.
## The number is read off the same clock the cube is serving, so it cannot drift
## away from it. An empty cost line simply is not drawn — a campaign death takes
## nothing but the time
func show_wait(seconds: float, cost: String = "") -> void:
	visible = seconds > 0.0

	if not visible:
		return

	_clock.text = "%d" % maxi(ceili(seconds), 1)
	_cost.text = cost
	_cost.visible = not cost.is_empty()


## What the death took, which only a painting round has an answer to. A race and
## a campaign level cost the time and nothing else
static func cost_line() -> String:
	if not Match.is_painting():
		return ""

	return "%d tiles lost" % Match.mode().death_tile_penalty


## Sticks the card in the middle of whatever it hangs in — a layer covering the
## whole window, or the control that fills one piece of a split
func center_in(holder: Node) -> void:
	holder.add_child(self)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
