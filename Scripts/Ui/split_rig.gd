class_name SplitRig
extends CanvasLayer

## The window cut into one piece per seat.
##
## Each piece is a viewport of its own with a camera in it, and every one of them
## draws the same World3D — a SubViewport that is not told to own a world finds
## the one its parent viewport has, which is the window the map is already in. So
## nothing about the level moves or is built twice; only the cameras are new.
##
## The 2D side is the opposite: a viewport builds its own canvas, so the game UI,
## the pause menu and the scene transition keep drawing over the whole window
## rather than once per split, which is what they are for. What genuinely belongs
## to one player goes into that split's own HUD instead

## Under the game UI, so every existing overlay still covers the whole window
const RIG_LAYER := -1

## How thick the border around a split is, in pixels. Thin enough to be a seam
## rather than a frame, thick enough to say which colour is whose
const FRAME_WIDTH := 3.0

var _grid: Control = null
var _views: Array[SubViewport] = []
var _cameras: Array[SplitCamera] = []
var _huds: Array[SeatHud] = []
var _frames: Array[Panel] = []

## The camera that holds the window itself, see _park_window_camera
var _parked: Camera3D = null


func _ready() -> void:
	layer = RIG_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build()
	_lay_out()
	Settings.split_layout_changed.connect(_lay_out)


## Hands the window back the way it was found. A rig that is torn down without
## this leaves every cube's own camera switched off and the screen black
func _exit_tree() -> void:
	get_viewport().audio_listener_enable_3d = true

	for view in _views:
		Settings.unregister_viewport(view)

	for player in Player.all(get_tree()):
		if not player.is_bot and is_instance_valid(player.view):
			player.view.current = true


## The cube of a seat is not there on the frame a death rebuilt the map, and it
## is a different node after a respawn, so the source is looked up rather than
## held on to
func _process(_delta: float) -> void:
	for at in range(_cameras.size()):
		var player := Player.at_seat(get_tree(), at)
		if player == null or not is_instance_valid(player.view):
			continue

		if _cameras[at].source != player.view:
			_cameras[at].source = player.view
			_huds[at].bind(at)

		player.view.current = false


func _build() -> void:
	_grid = Control.new()
	_grid.name = "Grid"
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)

	get_viewport().audio_listener_enable_3d = false

	for at in range(Seats.count()):
		_build_split(at)

	_park_window_camera()


## Takes the window's own camera off the cubes.
##
## Switching a camera off does not leave a viewport without one — the engine
## simply promotes another camera in it, so with four cubes one of them always
## ends up holding the window and the whole maze is drawn a fifth time behind
## splits that cover every pixel of it.
##
## So the window is handed a camera of its own that draws nothing: a cull mask
## with no layer in it, and a bare environment so the sky and the glow do not
## come along either. It is the cheapest pass there is, and it is what keeps the
## engine from reaching for a player's camera
func _park_window_camera() -> void:
	var blank := Environment.new()
	blank.background_mode = Environment.BG_COLOR
	blank.background_color = Color.BLACK
	blank.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED

	_parked = Camera3D.new()
	_parked.name = "ParkedCamera"
	_parked.cull_mask = 0
	_parked.environment = blank
	add_child(_parked)
	_parked.make_current()


## One split: a container that keeps its viewport the size of the piece, the
## viewport itself, the camera that copies the cube's own, and the HUD of things
## only that player should see
func _build_split(at: int) -> void:
	var holder := SubViewportContainer.new()
	holder.name = "Split%d" % at
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_child(holder)

	var view := SubViewport.new()
	view.own_world_3d = false
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.handle_input_locally = false
	view.audio_listener_enable_3d = true
	holder.add_child(view)
	Settings.register_viewport(view)

	var camera := SplitCamera.new()
	camera.name = "Camera"
	view.add_child(camera)

	var hud := SeatHud.new()
	hud.name = "SeatHud"
	hud.seat = at
	view.add_child(hud)

	var frame := Panel.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _frame_style(at))
	holder.add_child(frame)

	_views.append(view)
	_cameras.append(camera)
	_huds.append(hud)
	_frames.append(frame)


## A hollow box in the seat's colour, so the border says whose half is whose
func _frame_style(at: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Seats.color_of(at)
	style.set_border_width_all(int(FRAME_WIDTH))
	return style


## Puts every split where it belongs, in fractions of the window, so a resize
## needs no code at all.
##
## The aspect a camera keeps is part of the layout rather than a setting of its
## own: a wide, short strip that holds its height crops the sides away and turns
## a corridor into a slot, and a tall narrow one that holds its width does the
## same the other way round
func _lay_out() -> void:
	var rects := _rects()

	for at in range(mini(rects.size(), _views.size())):
		var rect: Rect2 = rects[at]
		var holder := _views[at].get_parent() as SubViewportContainer

		holder.anchor_left = rect.position.x
		holder.anchor_top = rect.position.y
		holder.anchor_right = rect.position.x + rect.size.x
		holder.anchor_bottom = rect.position.y + rect.size.y
		holder.offset_left = 0.0
		holder.offset_top = 0.0
		holder.offset_right = 0.0
		holder.offset_bottom = 0.0

		_cameras[at].keep_aspect = Camera3D.KEEP_WIDTH if rect.size.x > rect.size.y \
			else Camera3D.KEEP_HEIGHT


## Where each seat sits. Three players get a full width strip along the bottom
## rather than an empty quadrant: a quarter of the window standing black is the
## screen telling everybody about the friend who did not turn up
func _rects() -> Array[Rect2]:
	match Seats.count():
		2:
			if Settings.split_layout == Settings.SPLIT_SIDE_BY_SIDE:
				return [Rect2(0, 0, 0.5, 1), Rect2(0.5, 0, 0.5, 1)] as Array[Rect2]

			return [Rect2(0, 0, 1, 0.5), Rect2(0, 0.5, 1, 0.5)] as Array[Rect2]
		3:
			return [
				Rect2(0, 0, 0.5, 0.5), Rect2(0.5, 0, 0.5, 0.5), Rect2(0, 0.5, 1, 0.5),
			] as Array[Rect2]
		4:
			return [
				Rect2(0, 0, 0.5, 0.5), Rect2(0.5, 0, 0.5, 0.5),
				Rect2(0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5),
			] as Array[Rect2]

	return [Rect2(0, 0, 1, 1)] as Array[Rect2]
