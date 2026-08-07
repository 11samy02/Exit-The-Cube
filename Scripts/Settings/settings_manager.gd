extends Node

## Emitted after the window mode, the monitor, the resolution or the frame cap
## changed, the graphics tab rebuilds its dropdowns from it
signal display_changed

## Emitted whenever a binding was taken, dropped or reset to default
signal bindings_changed

## Emitted when the two player split was flipped between stacked and side by
## side, the rig relays its viewports on it
signal split_layout_changed

## Emitted after a bus volume moved, the sliders read the value back from here
signal audio_changed

## Emitted when the death splatter quality changed, the map puts its marks back
## up on it so the setting shows while the options are still open
signal splash_changed

## Emitted when the amount of commentary changed, the game UI takes a line that
## is still on screen down on it
signal commentary_changed

const CONFIG_PATH := "user://settings.cfg"

## The three ways the window can be put on the screen, in the order the
## dropdown lists them
const MODE_FULLSCREEN := 0
const MODE_WINDOWED := 1
const MODE_BORDERLESS := 2

## A binding lives in one of two slots, so a player can keep a key and a pad
## button on the same action without them overwriting each other
const SLOT_KEYBOARD := 0
const SLOT_GAMEPAD := 1

## How two cubes share one window. Stacked is the default on purpose: a corridor
## is read by looking down it, and a full width strip keeps more of that than a
## tall narrow one does
const SPLIT_STACKED := 0
const SPLIT_SIDE_BY_SIDE := 1

## How much of the paint a death leaves on the map is drawn, in the order the
## dropdown lists them
const SPLASH_OFF := 0
const SPLASH_LOW := 1
const SPLASH_MEDIUM := 2
const SPLASH_HIGH := 3

## How much the game talks over the player's shoulder while a level runs, in the
## order the dropdown lists them. The line on the summary screen is not part of
## this, that one belongs to the end of a run and not to playing it
const COMMENTARY_OFF := 0
const COMMENTARY_LOW := 1
const COMMENTARY_MEDIUM := 2
const COMMENTARY_HIGH := 3

## Offered in the resolution dropdown, everything larger than the monitor is
## dropped before the list is shown
const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(3840, 2160),
	Vector2i(2560, 1440),
	Vector2i(2560, 1080),
	Vector2i(1920, 1200),
	Vector2i(1920, 1080),
	Vector2i(1760, 990),
	Vector2i(1680, 1050),
	Vector2i(1600, 900),
	Vector2i(1440, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 800),
	Vector2i(1280, 720),
	Vector2i(1024, 600),
]

## Frame caps that are always offered as long as the monitor can reach them
const COMMON_FRAME_RATES: Array[int] = [30, 60, 90, 120, 144, 165, 240]

## Ends of the sensitivity sliders, 1.0 is the speed the camera was tuned at
const MIN_SENSITIVITY := 0.1
const MAX_SENSITIVITY := 3.0

## Ends of the interface scale, 1.0 draws the menus at the size the 1920 x 1080
## layout was designed at. Past 1.5 the title stops fitting on a small window
const MIN_UI_SCALE := 0.8
const MAX_UI_SCALE := 1.5

## Ends of the 3D render scale. Only the world is rendered smaller, the interface
## is always drawn at the full size of the window on top of it
const MIN_RENDER_SCALE := 0.5
const MAX_RENDER_SCALE := 1.0

## How a world rendered below the window size is stretched back up, in the order
## the dropdown lists them
const UPSCALER_BILINEAR := 0
const UPSCALER_FSR1 := 1
const UPSCALER_FSR2 := 2

## A screen no taller than this is a handheld. The desktop defaults are picked
## for a monitor an arm's length away and do not survive the trip to a 7 inch
## panel held in two hands
const HANDHELD_SCREEN_HEIGHT := 800

## What a first run on a handheld starts the interface on, the menus were laid
## out for a monitor roughly four times the size
const HANDHELD_UI_SCALE := 1.25

## The Deck's panel tops out here, every frame past it is paid for in battery and
## thrown away unseen
const HANDHELD_FRAME_CAP := 60

var window_mode: int = MODE_WINDOWED

var resolution := Vector2i(1920, 1080)

## Index into DisplayServer's screen list, the game window lives on that one.
## Worked out fresh on every start rather than read straight off the file: the
## list is renumbered whenever a screen is plugged in or taken away
var monitor: int = 0

## The screen the player actually picked, written down by what it is instead of
## by where it stood in the list.
##
## An index alone is not a screen. Unplug the first of two and the second one
## becomes number zero, and a game that saved "screen 1" opens on the wrong panel
## or, worse, on a number that no longer exists. So the choice is stored as a
## fingerprint of the panel — where it sits on the desktop, how big it is, how
## fast it refreshes — and matched back against what is plugged in at start.
##
## It also outlives a start without that screen. A laptop taken off its dock
## should not quietly forget which monitor the player prefers, so this is only
## ever overwritten when the player picks one, never by falling back
var _wanted_monitor: String = ""

var vsync: int = DisplayServer.VSYNC_ENABLED

## 0 means no cap, everything else is a hard limit in frames per second
var max_fps: int = 0

var msaa: int = Viewport.MSAA_4X

var screen_space_aa: int = Viewport.SCREEN_SPACE_AA_FXAA

var taa: bool = false

## Fraction of the window the world is rendered at before it is scaled back up.
## The cheapest frames there are on a handheld, and the menus stay sharp
var render_scale: float = 1.0

var upscaler: int = UPSCALER_BILINEAR

## Multiplier on top of the automatic fit to the window. The menus are laid out
## for 1920 x 1080, this is what makes them readable on a panel that is not
var ui_scale: float = 1.0

## Whether the cube is built out of flying debris at the start of a level or is
## simply dropped in
var spawn_animation: bool = true

## How much of the paint a death leaves behind is drawn, from nothing at all to
## the full show
var splash_quality: int = SPLASH_MEDIUM

## How two cubes share the window
var split_layout: int = SPLIT_STACKED

## Viewports besides the window itself that the quality settings have to reach.
## A split screen rig puts its own in here while it is up
var _extra_viewports: Array[Viewport] = []

## How many subtitles the game throws at the player while a level runs
var commentary: int = COMMENTARY_HIGH

## Whether the campaign may offer to play a level out for somebody it will not
## let past. Turned off for good the first time the offer is refused: it is an
## answer about how a player wants to be played at rather than about one run
var autopilot_offer: bool = true

## Bus name to linear volume between 0 and 1
var bus_volumes: Dictionary = {}

## Multiplier on the degrees per pixel the camera turns on mouse movement
var mouse_sensitivity: float = 1.0

## Multiplier on the degrees per second the camera turns at full stick
var controller_sensitivity: float = 1.0

## Action name to an array of serialised events, only the ones the player
## changed are in here, the rest stays on the project defaults
var _bindings: Dictionary = {}

## What the project shipped with, kept so the reset button has something to go
## back to. Filled before any saved binding is applied
var _default_events: Dictionary = {}

var _save_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_defaults()
	_read_project_defaults()
	_load()
	_resolve_monitor()
	apply_graphics()
	apply_display()
	apply_interface()
	apply_audio()
	apply_bindings()


## The window is gone by the time the tree drops us, a pending debounce would
## never fire
func _exit_tree() -> void:
	if _save_pending:
		save()


## Every action the options may rebind.
##
## The per seat copies are left out on purpose. They are built off these actions
## rather than being bindings of their own, and a conflict check that could see
## them would take the event straight back off the action it was just copied
## from — one rebind on a split screen and the controls are gone
func get_remappable_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for action in InputMap.get_actions():
		var name := String(action)
		if not name.begins_with("ui_") and not name.begins_with(SeatTable.PREFIX):
			actions.append(action)

	return actions


## Keyboard and mouse land in one slot, anything from a pad in the other
func slot_of(event: InputEvent) -> int:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return SLOT_GAMEPAD

	return SLOT_KEYBOARD


## The event currently sitting in that slot, null while the slot is empty
func get_binding(action: StringName, slot: int) -> InputEvent:
	if not InputMap.has_action(action):
		return null

	for event in InputMap.action_get_events(action):
		if slot_of(event) == slot:
			return event

	return null


## Takes the event off every other action first, two actions sharing a button
## is never what the player meant when they set it
func set_binding(action: StringName, slot: int, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return

	_erase_conflicts(action, event)
	_clear_slot(action, slot)
	InputMap.action_add_event(action, event)
	_store_action(action)
	_request_save()
	bindings_changed.emit()


## Leaves the slot empty, the action can still be triggered through its other one
func clear_binding(action: StringName, slot: int) -> void:
	if not InputMap.has_action(action):
		return

	_clear_slot(action, slot)
	_store_action(action)
	_request_save()
	bindings_changed.emit()


## Puts every action back on what the project shipped with
func reset_bindings() -> void:
	for action in _default_events:
		if not InputMap.has_action(action):
			continue

		InputMap.action_erase_events(action)
		for event in _default_events[action]:
			InputMap.action_add_event(action, event.duplicate())

	_bindings.clear()
	_request_save()
	bindings_changed.emit()


## Rebuilds the InputMap from the saved overrides, called once on start
func apply_bindings() -> void:
	for action in _bindings:
		var name := StringName(action)
		if not InputMap.has_action(name):
			continue

		InputMap.action_erase_events(name)
		for entry in _bindings[action]:
			var event := _deserialize_event(entry)
			if event != null:
				InputMap.action_add_event(name, event)

	bindings_changed.emit()


## Puts the window on that screen and remembers it as the one the player wants.
## Everything else that moves the window leaves the choice alone, so a fallback
## onto the primary screen never overwrites what was asked for
func set_monitor(index: int) -> void:
	monitor = clampi(index, 0, maxi(DisplayServer.get_screen_count() - 1, 0))
	_wanted_monitor = _fingerprint_of(monitor)
	apply_display()


## What a screen is, as far as this file is concerned. Position is what tells two
## identical panels apart, the rest is what tells the same panel apart from a
## different one that happens to have been moved into its place
func _fingerprint_of(screen: int) -> String:
	if screen < 0 or screen >= DisplayServer.get_screen_count():
		return ""

	var at := DisplayServer.screen_get_position(screen)
	var size := DisplayServer.screen_get_size(screen)

	return "%d,%d|%dx%d|%d|%d" % [
		at.x, at.y, size.x, size.y,
		int(round(DisplayServer.screen_get_refresh_rate(screen))),
		DisplayServer.screen_get_dpi(screen),
	]


## Which screen the saved choice is plugged into right now, -1 for none of them.
##
## An exact match is tried first. Failing that the position is dropped and the
## panel is looked for by what it is alone, which is what survives a desktop the
## player has rearranged since — the monitor is still there, it has just been
## given a different corner to live in
func _find_monitor(wanted: String) -> int:
	if wanted.is_empty():
		return -1

	for screen in DisplayServer.get_screen_count():
		if _fingerprint_of(screen) == wanted:
			return screen

	var panel := wanted.substr(wanted.find("|"))

	for screen in DisplayServer.get_screen_count():
		if _fingerprint_of(screen).ends_with(panel):
			return screen

	return -1


## Turns the saved choice back into a screen number for this start. A choice that
## is not plugged in falls back to the primary screen rather than to whatever
## number happens to still be in range — clamping an index quietly lands the game
## on a panel nobody asked for
func _resolve_monitor() -> void:
	var last := maxi(DisplayServer.get_screen_count() - 1, 0)

	if _wanted_monitor.is_empty():
		monitor = clampi(monitor, 0, last)
		return

	var found := _find_monitor(_wanted_monitor)
	monitor = found if found >= 0 else DisplayServer.get_primary_screen()


## Names for the monitor dropdown, the resolution and the refresh rate are in
## there because that is what tells two identical monitors apart
func get_monitor_names() -> Array[String]:
	var names: Array[String] = []
	for i in DisplayServer.get_screen_count():
		var size := DisplayServer.screen_get_size(i)
		var hz := int(round(DisplayServer.screen_get_refresh_rate(i)))
		var label := "Monitor %d  -  %d x %d" % [i + 1, size.x, size.y]
		if hz > 0:
			label += "  @ %d Hz" % hz
		if i == DisplayServer.get_primary_screen():
			label += "  (Primary)"
		names.append(label)

	return names


## Everything that fits on the chosen monitor, largest first
func get_available_resolutions() -> Array[Vector2i]:
	var screen_size := DisplayServer.screen_get_size(monitor)
	var list: Array[Vector2i] = []
	for res in COMMON_RESOLUTIONS:
		if res.x <= screen_size.x and res.y <= screen_size.y:
			list.append(res)

	if not list.has(screen_size) and screen_size.x > 0:
		list.append(screen_size)

	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y > b.x * b.y)
	return list


## Caps derived from what the chosen monitor can actually show, so a 240 Hz
## panel offers the halves and thirds of 240 next to the usual values. The 0 at
## the end is the uncapped entry
func get_available_frame_rates() -> Array[int]:
	var hz := int(round(DisplayServer.screen_get_refresh_rate(monitor)))
	if hz <= 0:
		hz = 60

	var found: Dictionary = {}
	for divider in [4.0, 3.0, 2.0, 1.5, 1.0]:
		found[int(round(hz / divider))] = true

	for common in COMMON_FRAME_RATES:
		if common <= hz:
			found[common] = true

	var rates: Array[int] = []
	for rate in found:
		if rate >= 24:
			rates.append(rate)

	rates.sort()
	rates.append(0)
	return rates


## Linear volume of that bus between 0 and 1, 1 is the level the mix was made at
func get_bus_volume(bus_name: String) -> float:
	return float(bus_volumes.get(bus_name, 1.0))


func set_bus_volume(bus_name: String, linear: float) -> void:
	bus_volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus_name)
	_request_save()
	audio_changed.emit()


## The next player that is spawned reads this one, whatever is on screen right
## now keeps running
func set_spawn_animation(enabled: bool) -> void:
	spawn_animation = enabled
	_request_save()


## The map rebuilds its marks on the signal, so a level that is already running
## shows the change while the options are still open
func set_splash_quality(value: int) -> void:
	splash_quality = clampi(value, SPLASH_OFF, SPLASH_HIGH)
	_request_save()
	splash_changed.emit()


## Read the next time the game has something to say, so turning it down takes
## effect on the spot. What is already on screen is taken down on the signal
func set_commentary(value: int) -> void:
	commentary = clampi(value, COMMENTARY_OFF, COMMENTARY_HIGH)
	_request_save()
	commentary_changed.emit()


## Read the next time a level would ask, so a refusal takes hold on the spot and
## outlives the run it was given in
func set_autopilot_offer(enabled: bool) -> void:
	autopilot_offer = enabled
	_request_save()


## The camera reads these every frame, so nothing has to be told about a change
func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	_request_save()


func set_controller_sensitivity(value: float) -> void:
	controller_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	_request_save()


## Pushes every stored volume onto the mixer, buses the player never touched
## keep the level from the bus layout
func apply_audio() -> void:
	for i in AudioServer.bus_count:
		_apply_bus(AudioServer.get_bus_name(i))


## Anti aliasing and the render scale run on the root viewport, every camera in
## the game renders through it.
## The 2D pass is deliberately left off. Nothing in the interface gains from it,
## text is smoothed by the font rasteriser and the panels round their own corners,
## and a multisampled canvas at the full size of the window is not free. It also
## cannot be combined with a render scale below 100 %, the two ask the renderer
## for framebuffers that do not fit together and the world stops being drawn
func apply_graphics() -> void:
	for viewport in _quality_viewports():
		_apply_quality(viewport)

	_request_save()


## Every viewport the picture is drawn into. A split screen renders the world in
## its own viewports, and each of them keeps a private copy of the anti aliasing
## and the render scale — a setting written onto the window alone simply would
## not reach them
func _quality_viewports() -> Array[Viewport]:
	var found: Array[Viewport] = [get_tree().root]

	for viewport in _extra_viewports:
		if is_instance_valid(viewport):
			found.append(viewport)

	return found


func _apply_quality(viewport: Viewport) -> void:
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.msaa_3d = msaa as Viewport.MSAA
	viewport.screen_space_aa = screen_space_aa as Viewport.ScreenSpaceAA
	viewport.use_taa = taa
	viewport.scaling_3d_mode = upscaler as Viewport.Scaling3DMode
	viewport.scaling_3d_scale = clampf(render_scale, MIN_RENDER_SCALE, MAX_RENDER_SCALE)


## Takes a split screen viewport on board, so the quality options reach it as
## well. It gets the current settings straight away rather than waiting for the
## player to move one
func register_viewport(viewport: Viewport) -> void:
	if viewport == null or _extra_viewports.has(viewport):
		return

	_extra_viewports.append(viewport)
	_apply_quality(viewport)


func unregister_viewport(viewport: Viewport) -> void:
	_extra_viewports.erase(viewport)


func set_split_layout(value: int) -> void:
	split_layout = clampi(value, SPLIT_STACKED, SPLIT_SIDE_BY_SIDE)
	split_layout_changed.emit()
	_request_save()


## The window scales the 1920 x 1080 layout to fit itself, this is the multiplier
## the player puts on top of that. Text is rasterised at the size it ends up on
## screen, so turning this up makes the menus bigger rather than blurrier
func apply_interface() -> void:
	get_window().content_scale_factor = ui_scale
	_request_save()


func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, MIN_UI_SCALE, MAX_UI_SCALE)
	apply_interface()


func set_render_scale(value: float) -> void:
	render_scale = clampf(value, MIN_RENDER_SCALE, MAX_RENDER_SCALE)
	apply_graphics()


## True on a Steam Deck, and on anything else whose screen is small enough that
## the desktop defaults would be unreadable and too expensive on it
func is_handheld() -> bool:
	if OS.get_environment("SteamDeck") == "1":
		return true

	if OS.get_processor_name().contains("AMD Custom APU"):
		return true

	var height := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()).y
	return height > 0 and height <= HANDHELD_SCREEN_HEIGHT


## Window mode, monitor, resolution, vsync and the frame cap all land on the
## window at once, they only make sense together
func apply_display() -> void:
	var screens := DisplayServer.get_screen_count()
	monitor = clampi(monitor, 0, maxi(screens - 1, 0))

	DisplayServer.window_set_vsync_mode(vsync as DisplayServer.VSyncMode)
	Engine.max_fps = max_fps

	match window_mode:
		MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_current_screen(monitor)
			DisplayServer.window_set_mode(_fullscreen_mode())
		MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_place_window(DisplayServer.screen_get_usable_rect(monitor))
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			_place_window(
				Rect2i(DisplayServer.screen_get_position(monitor), DisplayServer.screen_get_size(monitor))
			)

	_request_save()
	display_changed.emit()


## Writes the whole file, small enough that there is no point in touching only
## the section that changed
func save() -> void:
	_save_pending = false

	var config := ConfigFile.new()
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "resolution_x", resolution.x)
	config.set_value("display", "resolution_y", resolution.y)
	config.set_value("display", "monitor", monitor)
	config.set_value("display", "monitor_id", _wanted_monitor)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "max_fps", max_fps)
	config.set_value("graphics", "msaa", msaa)
	config.set_value("graphics", "screen_space_aa", screen_space_aa)
	config.set_value("graphics", "taa", taa)
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "upscaler", upscaler)
	config.set_value("graphics", "ui_scale", ui_scale)
	config.set_value("graphics", "spawn_animation", spawn_animation)
	config.set_value("graphics", "splash_quality", splash_quality)
	config.set_value("graphics", "split_layout", split_layout)
	config.set_value("game", "commentary", commentary)
	config.set_value("game", "autopilot_offer", autopilot_offer)
	config.set_value("audio", "buses", bus_volumes)
	config.set_value("input", "bindings", _bindings)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("input", "controller_sensitivity", controller_sensitivity)
	config.save(CONFIG_PATH)


## A slider drag would otherwise write the file on every single frame
func _request_save() -> void:
	if _save_pending:
		return

	_save_pending = true
	await get_tree().create_timer(0.5, true, false, true).timeout
	if _save_pending:
		save()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		_pick_first_run_defaults()
		return

	window_mode = clampi(int(config.get_value("display", "window_mode", window_mode)), MODE_FULLSCREEN, MODE_BORDERLESS)
	resolution = Vector2i(
		int(config.get_value("display", "resolution_x", resolution.x)),
		int(config.get_value("display", "resolution_y", resolution.y))
	)
	monitor = int(config.get_value("display", "monitor", monitor))
	_wanted_monitor = String(config.get_value("display", "monitor_id", ""))
	vsync = int(config.get_value("display", "vsync", vsync))
	max_fps = int(config.get_value("display", "max_fps", max_fps))
	msaa = int(config.get_value("graphics", "msaa", msaa))
	screen_space_aa = int(config.get_value("graphics", "screen_space_aa", screen_space_aa))
	taa = bool(config.get_value("graphics", "taa", taa))
	render_scale = clampf(
		float(config.get_value("graphics", "render_scale", render_scale)),
		MIN_RENDER_SCALE, MAX_RENDER_SCALE
	)
	upscaler = clampi(int(config.get_value("graphics", "upscaler", upscaler)), UPSCALER_BILINEAR, UPSCALER_FSR2)
	ui_scale = clampf(float(config.get_value("graphics", "ui_scale", ui_scale)), MIN_UI_SCALE, MAX_UI_SCALE)
	spawn_animation = bool(config.get_value("graphics", "spawn_animation", spawn_animation))
	splash_quality = clampi(int(config.get_value("graphics", "splash_quality", splash_quality)), SPLASH_OFF, SPLASH_HIGH)
	split_layout = clampi(int(config.get_value("graphics", "split_layout", split_layout)), SPLIT_STACKED, SPLIT_SIDE_BY_SIDE)
	commentary = clampi(int(config.get_value("game", "commentary", commentary)), COMMENTARY_OFF, COMMENTARY_HIGH)
	autopilot_offer = bool(config.get_value("game", "autopilot_offer", autopilot_offer))
	bus_volumes = config.get_value("audio", "buses", {})
	_bindings = config.get_value("input", "bindings", {})
	mouse_sensitivity = clampf(
		float(config.get_value("input", "mouse_sensitivity", mouse_sensitivity)),
		MIN_SENSITIVITY, MAX_SENSITIVITY
	)
	controller_sensitivity = clampf(
		float(config.get_value("input", "controller_sensitivity", controller_sensitivity)),
		MIN_SENSITIVITY, MAX_SENSITIVITY
	)


## Without a config file the window keeps the monitor it opened on and takes the
## largest offered resolution that still fits on it
func _pick_first_run_defaults() -> void:
	monitor = DisplayServer.window_get_current_screen()
	var offered := get_available_resolutions()
	var usable := DisplayServer.screen_get_usable_rect(monitor).size
	for res in offered:
		if res.x <= usable.x and res.y <= usable.y:
			resolution = res
			break

	if is_handheld():
		_pick_handheld_defaults()


## A handheld has no window to arrange and a fraction of the power the quality
## defaults assume, so it starts fullscreen, capped, and with the edge smoothing
## that costs the least. Every one of these is still the player's to change
func _pick_handheld_defaults() -> void:
	window_mode = MODE_FULLSCREEN
	max_fps = HANDHELD_FRAME_CAP
	vsync = DisplayServer.VSYNC_ENABLED
	msaa = Viewport.MSAA_2X
	screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	taa = false
	splash_quality = SPLASH_LOW
	ui_scale = HANDHELD_UI_SCALE


## The project settings are the ground truth for the quality defaults, the
## options menu only ever moves away from them
func _read_project_defaults() -> void:
	msaa = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", msaa))
	screen_space_aa = int(
		ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", screen_space_aa)
	)
	taa = bool(ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_taa", taa))


## A compositor that already owns the whole screen, like the one the Deck runs
## its games under, hands back a black window when a game asks it to take the
## display over exclusively
func _fullscreen_mode() -> DisplayServer.WindowMode:
	if is_handheld():
		return DisplayServer.WINDOW_MODE_FULLSCREEN

	return DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _place_window(area: Rect2i) -> void:
	DisplayServer.window_set_current_screen(monitor)

	var size := Vector2i(mini(resolution.x, area.size.x), mini(resolution.y, area.size.y))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(area.position + (area.size - size) / 2)


func _apply_bus(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return

	var linear := get_bus_volume(bus_name)
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func _capture_defaults() -> void:
	for action in get_remappable_actions():
		var copies: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			copies.append(event.duplicate())

		_default_events[action] = copies


func _clear_slot(action: StringName, slot: int) -> void:
	for event in InputMap.action_get_events(action):
		if slot_of(event) == slot:
			InputMap.action_erase_event(action, event)


## The same stick direction or button may only drive one action, so it is taken
## off wherever it sat before
func _erase_conflicts(action: StringName, event: InputEvent) -> void:
	for other in get_remappable_actions():
		for existing in InputMap.action_get_events(other):
			if not existing.is_match(event, true):
				continue

			InputMap.action_erase_event(other, existing)
			if other != action:
				_store_action(other)


func _store_action(action: StringName) -> void:
	var entries: Array = []
	for event in InputMap.action_get_events(action):
		var entry := _serialize_event(event)
		if not entry.is_empty():
			entries.append(entry)

	_bindings[String(action)] = entries


## Only the fields that make the event unique, an InputEvent written whole would
## break the file on the next engine update
func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"type": "key",
			"physical_keycode": int(event.physical_keycode),
			"keycode": int(event.keycode),
		}

	if event is InputEventMouseButton:
		return {"type": "mouse", "button_index": int(event.button_index)}

	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": int(event.button_index)}

	if event is InputEventJoypadMotion:
		return {"type": "joy_motion", "axis": int(event.axis), "axis_value": float(event.axis_value)}

	return {}


@warning_ignore("int_as_enum_without_cast")
func _deserialize_event(entry: Variant) -> InputEvent:
	if typeof(entry) != TYPE_DICTIONARY:
		return null

	var data: Dictionary = entry
	match String(data.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data.get("physical_keycode", 0))
			key.keycode = int(data.get("keycode", 0))
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data.get("button_index", 0))
			return mouse
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(data.get("button_index", 0))
			return button
		"joy_motion":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(data.get("axis", 0))
			motion.axis_value = float(data.get("axis_value", 0.0))
			return motion

	return null
