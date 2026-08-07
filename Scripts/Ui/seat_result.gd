class_name SeatResult
extends CanvasLayer

## What one player sees in their own piece of the window once they are out of the
## maze.
##
## A race on one screen ends four times, at four different moments. The window's
## own race panel cannot say any of that: it belongs to the whole screen, and
## putting it up the moment the first cube got out would take the level away from
## the three who are still running for it. So a finished seat is answered in that
## seat's own split and nowhere else — a place, a time, and the others to watch
## until the room is done and the real board goes up over everything.
##
## Nothing in here is a button. A split window has one focus per viewport and one
## mouse between four people, so the prompts are read off that seat's own pad
## instead, which is the only device in the room that certainly belongs to this
## half of the screen

## Over this seat's HUD. It is a canvas of its own either way — the window's race
## panel is on the window's canvas and still covers this when the round ends
const RESULT_LAYER := 8

## How dark the maze goes behind the card. Not black: the corridor this cube came
## out of is still worth seeing behind the result
const SHADE := Color(0, 0, 0, 0.62)

## How far the watch bar sits off the bottom of its own split
const BAR_MARGIN := 26.0

## Which of that seat's own actions does what once it is out of the maze. The
## cube is finished, so every one of them is free — the item is spent, the view is
## locked and the movement is off
const WATCH_ACTION := &"use_item"
const BACK_ACTION := &"toggle_perspective"
const PREVIOUS_ACTION := &"move_left"
const NEXT_ACTION := &"move_right"

## Which seat this belongs to, written by the rig before the node is added to the
## tree so the first prompt drawn is already the right pad's
var seat: int = -1

var _root: Control = null
var _shade: ColorRect = null
var _card: PanelContainer = null
var _title: Label = null
var _time: Label = null
var _hint: Label = null
var _bar: PanelContainer = null
var _watched: Label = null

## Every prompt glyph on screen, each carrying the action it stands for so a pad
## swapped mid round redraws all of them off one signal
var _icons: Array[TextureRect] = []

## The camera this seat watches through, borrowed from the ghost field the first
## time it asks
var _cam: SpectatorCam = null

## True while this seat's cube is out of the maze and the room is not done yet
var _out: bool = false


func _ready() -> void:
	layer = RESULT_LAYER
	_build()
	_draw_prompts()

	Match.standings_updated.connect(_check)
	Match.round_over.connect(_close)
	InputIcons.device_changed.connect(_on_device_changed)
	_check()


## The camera is handed back before this goes, so a split that is torn down mid
## round does not leave its piece of the window pointed at a freed node
func _exit_tree() -> void:
	_stop_watching()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = OnlineUi.THEME
	_root.visible = false
	add_child(_root)

	_shade = ColorRect.new()
	_shade.color = SHADE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)

	_build_card()
	_build_bar()


## The card that says what this player's run came to. It is the online result
## panel with everything cut off it that a quarter of a window has no room for:
## the full board is still going up for everybody once the room is done
func _build_card() -> void:
	_card = OnlineUi.panel(OnlineUi.ACCENT, 0.9)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_card.add_child(column)

	_title = OnlineUi.heading("", 32, OnlineUi.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_time = OnlineUi.body("", 24, OnlineUi.TEXT)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_time)

	column.add_child(OnlineUi.gap(10))

	var prompt := HBoxContainer.new()
	prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt.add_theme_constant_override("separation", 8)
	column.add_child(prompt)

	prompt.add_child(_glyph(WATCH_ACTION))
	_hint = OnlineUi.body("", 19, OnlineUi.MUTED)
	prompt.add_child(_hint)


## The thin bar that stands in for the card while somebody else is being watched.
## Thin on purpose — the point of spectating is the maze, not the furniture
func _build_bar() -> void:
	_bar = OnlineUi.panel(OnlineUi.ACCENT, 0.9)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.visible = false
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -BAR_MARGIN
	_bar.offset_bottom = -BAR_MARGIN
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_bar)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_bar.add_child(column)

	_watched = OnlineUi.body("", 22, OnlineUi.TEXT)
	_watched.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_watched)

	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 6)
	column.add_child(keys)

	keys.add_child(_glyph(PREVIOUS_ACTION))
	keys.add_child(_glyph(NEXT_ACTION))
	keys.add_child(OnlineUi.body("SWITCH", 17, OnlineUi.MUTED))
	keys.add_child(OnlineUi.body("·", 17, OnlineUi.EDGE))
	keys.add_child(_glyph(BACK_ACTION))
	keys.add_child(OnlineUi.body("BACK", 17, OnlineUi.MUTED))


## One prompt glyph, remembering which action it stands for. The binding is the
## one the options hold and only the pad it is drawn as is this seat's own
func _glyph(base: StringName) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta(&"action", base)

	_icons.append(icon)
	return icon


## Reads that seat's pad, every frame it is out of the maze.
##
## The pad is polled rather than listened to. A layer inside a sub viewport is not
## where the window's input events end up, and this half of the screen has to
## answer its own player whatever the other three are doing
func _process(_delta: float) -> void:
	if not _out:
		return

	if not _bar.visible:
		if Input.is_action_just_pressed(Seats.action(seat, WATCH_ACTION)):
			_start_watching()

		return

	if not _is_watching():
		_stop_watching()
		return

	_read_watch_keys()
	_draw_watched()


func _read_watch_keys() -> void:
	if Input.is_action_just_pressed(Seats.action(seat, BACK_ACTION)):
		_stop_watching()
	elif Input.is_action_just_pressed(Seats.action(seat, PREVIOUS_ACTION)):
		_cam.watch_step(-1)
	elif Input.is_action_just_pressed(Seats.action(seat, NEXT_ACTION)):
		_cam.watch_step(1)


## Comes up the moment this seat's cube is out of the maze. Called on every change
## to the board as well, so the line about whether anybody is left to watch is
## right on the frame the last of them gets out
func _check() -> void:
	var out := Match.is_split() and Match.showing_results(_account())

	if out != _out:
		_out = out
		_root.visible = out
		_card.visible = out
		_bar.visible = false

	if _out and not _bar.visible:
		_draw_card()


## The whole room is done. The window's own panel has the full board on it and the
## way back to the title, and this would only be in front of it
func _close() -> void:
	_stop_watching()
	_out = false
	_root.visible = false


func _account() -> int:
	return Match.account_of_seat(seat)


func _is_watching() -> bool:
	return _cam != null and is_instance_valid(_cam) and _cam.watching() != 0


func _start_watching() -> void:
	var field := get_tree().get_first_node_in_group(GhostField.GROUP) as GhostField
	if field == null:
		return

	_cam = field.cam_for(seat)
	_cam.watch_step(1)

	if not _is_watching():
		return

	_point_split_at(_cam.camera())
	_card.visible = false
	_shade.visible = false
	_bar.visible = true
	_draw_watched()


func _stop_watching() -> void:
	if _cam != null and is_instance_valid(_cam):
		_cam.stop()

	_point_split_at(null)

	if _bar == null:
		return

	_bar.visible = false
	_shade.visible = true
	_card.visible = _out

	if _out:
		_draw_card()


## Where this run came in, and what there is left to do about it
func _draw_card() -> void:
	var runner: Dictionary = Match.runners().get(_account(), {})
	var place := Match.rank_of(_account())

	_title.text = "FIRST OUT" if place == 1 else "OUT  ·  PLACE %d" % place
	_time.text = OnlineUi.format_time(float(runner.get("time", 0.0)))

	var left := not _watchable().is_empty()
	_hint.text = "WATCH THE OTHERS" if left else "WAITING FOR THE OTHERS"

	for icon in _icons:
		if icon.get_meta(&"action") == WATCH_ACTION:
			icon.visible = left and icon.texture != null


## Hands this seat's piece of the window to a camera that is not its player's, or
## to nothing to give it back. A split is never told which camera is current, it
## copies a source — so this is the one thing that has to change, and the cube's
## own rig goes on writing its camera either way
func _point_split_at(camera: Camera3D) -> void:
	var rig := get_tree().get_first_node_in_group(SplitRig.GROUP) as SplitRig
	if rig != null:
		rig.watch_through(seat, camera)


## Everybody this seat could still be watching, which is nobody once the last cube
## in the maze is out
func _watchable() -> Array:
	var field := get_tree().get_first_node_in_group(GhostField.GROUP) as GhostField
	return field.cam_for(seat).watchable() if field != null else []


## Who is being followed, redrawn while it runs: a watched cube that dies or
## finishes hands the camera on to the next one without anybody pressing anything
func _draw_watched() -> void:
	var runner: Dictionary = Match.runners().get(_cam.watching(), {})

	if runner.is_empty():
		_watched.text = "NOBODY LEFT IN THE MAZE"
		return

	var deaths := int(runner["deaths"])

	_watched.text = "%s  ·  %s" % [
		String(runner["name"]).to_upper(),
		"%d death" % deaths if deaths == 1 else "%d deaths" % deaths,
	]
	_watched.label_settings.font_color = Match.color_of(_cam.watching())


func _on_device_changed(_device: int) -> void:
	_draw_prompts()


## Every glyph read again off the pad that seat is holding
func _draw_prompts() -> void:
	for icon in _icons:
		icon.texture = InputIcons.get_seat_action_texture(seat, icon.get_meta(&"action"))
		icon.visible = icon.texture != null

	if _out and not _bar.visible:
		_draw_card()
