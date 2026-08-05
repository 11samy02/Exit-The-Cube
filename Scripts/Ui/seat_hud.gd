class_name SeatHud
extends CanvasLayer

## What only one player on a split screen should see.
##
## It lives inside that seat's own viewport, which is what makes it private: a
## viewport builds its own canvas, so a layer added in here is drawn over that
## one piece of the window and nowhere else. Everything genuinely shared — the
## level banner, the key, the death tally, the pause menu — stays on the window
## itself and is not repeated four times.
##
## It carries the seat tag, that cube's own item slot, and the holder an item
## vignette is parented into — so a jolt tints one half of the screen rather
## than the whole of it

## Put in a group so an item effect can find the piece of the window it should
## be drawing itself over, without a path from the player to the rig
const GROUP := &"seat_hud"

## Over the world, under anything the window itself puts up
const HUD_LAYER := 4

## How far the seat tag sits off the corner of its own split
const TAG_MARGIN := 18.0

## How much of the full sized respawn card fits into one piece of a split window
const DOWN_CARD_SCALE := 0.62

## How big the item slot is drawn, and how far off the top it sits. Smaller than
## the one the shared HUD uses, a quarter of a window has less room in it.
##
## Up rather than down: the bottom of a split is the corridor the player is
## walking into, and an item sitting there covers exactly the floor they are
## about to step on
const SLOT_SIZE := Vector2(96.0, 96.0)
const SLOT_MARGIN := 16.0

## Which seat this HUD belongs to. Written by the rig before the node is added
## to the tree, so the slot inside knows whose pad it is prompting for by the
## time it comes up
var seat: int = -1

var _root: Control = null
var _tag: Label = null
var _vignette: Control = null
var _slot: ItemSlot = null
var _down: DownCard = null


func _ready() -> void:
	layer = HUD_LAYER
	add_to_group(GROUP)
	_build()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_vignette = Control.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)

	_tag = OnlineUi.heading("", 26)
	_tag.name = "Tag"
	_tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_tag.position = Vector2(TAG_MARGIN, TAG_MARGIN)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tag)

	_slot = _build_slot()
	_root.add_child(_slot)

	_down = DownCard.new(DOWN_CARD_SCALE)
	_down.name = "Down"
	_down.center_in(_root)

	Status.set_screen_parent(seat, _root)


## The wait a death costs, counted down in this player's own piece of the window.
## A cube that burst and then sits looking at an empty corridor for five seconds
## has no way of telling a penalty from a hang
func _process(_delta: float) -> void:
	if seat < 0 or _down == null:
		return

	_down.show_wait(_wait_left(), DownCard.cost_line())


## Both ways of sitting out a death answer here: the round's own penalty in a
## party mode, and the co-op coordinator in the campaign
func _wait_left() -> float:
	if Match.is_racing():
		return Match.penalty_left(Match.account_of_seat(seat))

	var coop := CoopCoordinator.find(get_tree())
	return coop.down_for(seat) if coop != null else 0.0


## The swimming screen belongs to the status system and is only lent out, so it
## goes back before this HUD is freed with the split it was in
func _exit_tree() -> void:
	Status.set_screen_parent(seat, null)


## The same slot the shared HUD carries, built here rather than instanced: it is
## four nodes and every one of them has to be told its own size anyway, and the
## alternative is pulling the box out of the game UI scene and handing both of
## them a third file to keep in step
func _build_slot() -> ItemSlot:
	var slot := ItemSlot.new()
	slot.name = "ItemSlot"
	slot.seat = seat
	slot.custom_minimum_size = SLOT_SIZE
	slot.size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_anchors_preset(Control.PRESET_CENTER_TOP)
	slot.offset_left = -SLOT_SIZE.x * 0.5
	slot.offset_right = SLOT_SIZE.x * 0.5
	slot.offset_top = SLOT_MARGIN
	slot.offset_bottom = SLOT_MARGIN + SLOT_SIZE.y
	slot.ring_radius = 0.0
	slot.ring_width = 4.0
	slot.ring_spacing = 8.0

	var icon := TextureRect.new()
	icon.name = "item icon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var hint := OnlineUi.body("", 18, OnlineUi.MUTED)
	hint.name = "use_hint"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -SLOT_SIZE.x * 0.5
	hint.offset_right = SLOT_SIZE.x * 0.5
	hint.offset_top = 0.0
	hint.offset_bottom = 26.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(hint)

	var prompt := TextureRect.new()
	prompt.name = "use_icon"
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -22.0
	prompt.offset_right = 22.0
	prompt.offset_top = 0.0
	prompt.offset_bottom = 44.0
	prompt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prompt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(prompt)

	slot.icon = icon
	slot.hint = hint
	slot.use_icon = prompt
	return slot


## Names the seat this piece of the window belongs to and ties the slot to that
## cube. Called again whenever the cube behind it was rebuilt, so everything read
## off the player is read fresh
func bind(at: int) -> void:
	seat = at

	if _tag == null:
		return

	_tag.text = "P%d" % (at + 1)
	_tag.add_theme_color_override("font_color", Seats.color_of(at))
	_tag.visible = Seats.count() > 1

	var cube := Player.at_seat(get_tree(), at)
	_slot.bind(cube.inventory if cube != null else null)


## Where an effect hangs its full screen glow, so it covers this player's own
## piece of the window instead of everybody's
func vignette_parent() -> Control:
	return _vignette
