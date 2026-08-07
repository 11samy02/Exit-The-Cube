extends VBoxContainer

## Everything in here is read off the machine at runtime. The monitor list, the
## resolutions and the frame caps are whatever this PC can actually do, not a
## list somebody typed into the editor.
## Each row hands the menu a line about itself, built from the value that is set
## right now, so the panel at the bottom explains rather than the layout

const WINDOW_MODES := ["Fullscreen", "Windowed", "Borderless Window"]

const VSYNC_MODES := ["Off", "On", "Adaptive", "Mailbox"]

const MSAA_MODES := ["Off", "2x", "4x", "8x"]

const SCREEN_SPACE_AA_MODES := ["Off", "FXAA", "SMAA 1x"]

const UPSCALER_MODES := ["Bilinear", "FSR 1", "FSR 2"]

const SPLASH_MODES := ["Off", "Low", "Medium", "High"]

const COMMENTARY_MODES := ["Off", "Low", "Medium", "Lots"]

const SPLIT_LAYOUTS := ["Stacked (top and bottom)", "Side by side (left and right)"]

const DEFAULT_DESCRIPTION := "Display decides where the window sits. Quality decides how hard your graphics card has to work for it."

var _monitor: OptionButton
var _window_mode: OptionButton
var _resolution: OptionButton
var _vsync: OptionButton
var _frame_rate: OptionButton
var _render_scale: HSlider
var _render_scale_readout: Label
var _upscaler: OptionButton
var _msaa: OptionButton
var _screen_space_aa: OptionButton
var _taa: NeonSwitch
var _spawn_animation: NeonSwitch
var _splash: OptionButton
var _ui_scale: HSlider
var _ui_scale_readout: Label
var _commentary: OptionButton
var _split_layout: OptionButton

var _resolutions: Array[Vector2i] = []
var _frame_rates: Array[int] = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	set_meta(OptionsUi.DEFAULT_DESCRIPTION_META, DEFAULT_DESCRIPTION)
	_build()
	Settings.display_changed.connect(_sync)
	_sync()


func _build() -> void:
	add_child(OptionsUi.make_heading("DISPLAY"))

	_monitor = OptionsUi.make_dropdown(Settings.get_monitor_names(), Settings.monitor)
	_monitor.disabled = DisplayServer.get_screen_count() <= 1
	_monitor.item_selected.connect(_on_monitor_selected)
	add_child(OptionsUi.make_row("Monitor", _monitor, _describe_monitor))

	_window_mode = OptionsUi.make_dropdown(WINDOW_MODES, Settings.window_mode)
	_window_mode.item_selected.connect(_on_window_mode_selected)
	add_child(OptionsUi.make_row("Window Mode", _window_mode, _describe_window_mode))

	_resolution = OptionsUi.make_dropdown([], 0)
	_resolution.item_selected.connect(_on_resolution_selected)
	add_child(OptionsUi.make_row("Resolution", _resolution, _describe_resolution))

	_vsync = OptionsUi.make_dropdown(VSYNC_MODES, Settings.vsync)
	_vsync.item_selected.connect(_on_vsync_selected)
	add_child(OptionsUi.make_row("V-Sync", _vsync, _describe_vsync))

	_frame_rate = OptionsUi.make_dropdown([], 0)
	_frame_rate.item_selected.connect(_on_frame_rate_selected)
	add_child(OptionsUi.make_row("Max FPS", _frame_rate, _describe_frame_rate))

	add_child(OptionsUi.make_separator())
	add_child(OptionsUi.make_heading("QUALITY"))

	_render_scale = OptionsUi.make_slider(
		Settings.MIN_RENDER_SCALE, Settings.MAX_RENDER_SCALE, 0.05, Settings.render_scale
	)
	_render_scale_readout = OptionsUi.make_readout(_percent(Settings.render_scale))
	_render_scale.value_changed.connect(_on_render_scale_changed)
	add_child(OptionsUi.make_row(
		"Render Scale",
		OptionsUi.make_slider_box(_render_scale, _render_scale_readout),
		_describe_render_scale
	))

	_upscaler = OptionsUi.make_dropdown(UPSCALER_MODES, Settings.upscaler)
	_upscaler.item_selected.connect(_on_upscaler_selected)
	add_child(OptionsUi.make_row("Upscaling", _upscaler, _describe_upscaler))

	_msaa = OptionsUi.make_dropdown(MSAA_MODES, Settings.msaa)
	_msaa.item_selected.connect(_on_msaa_selected)
	add_child(OptionsUi.make_row("Anti-Aliasing (MSAA)", _msaa, _describe_msaa))

	_screen_space_aa = OptionsUi.make_dropdown(SCREEN_SPACE_AA_MODES, Settings.screen_space_aa)
	_screen_space_aa.item_selected.connect(_on_screen_space_aa_selected)
	add_child(OptionsUi.make_row("Edge Smoothing", _screen_space_aa, _describe_screen_space_aa))

	_taa = OptionsUi.make_toggle(Settings.taa)
	_taa.toggled.connect(_on_taa_toggled)
	add_child(OptionsUi.make_row("Temporal AA", _taa, _describe_taa))

	add_child(OptionsUi.make_separator())
	add_child(OptionsUi.make_heading("EFFECTS"))

	_spawn_animation = OptionsUi.make_toggle(Settings.spawn_animation)
	_spawn_animation.toggled.connect(_on_spawn_animation_toggled)
	add_child(OptionsUi.make_row("Spawn Animation", _spawn_animation, _describe_spawn_animation))

	_splash = OptionsUi.make_dropdown(SPLASH_MODES, Settings.splash_quality)
	_splash.item_selected.connect(_on_splash_selected)
	add_child(OptionsUi.make_row("Death Splatter", _splash, _describe_splash))

	add_child(OptionsUi.make_separator())
	add_child(OptionsUi.make_heading("SPLIT SCREEN"))

	_split_layout = OptionsUi.make_dropdown(SPLIT_LAYOUTS, Settings.split_layout)
	_split_layout.item_selected.connect(_on_split_layout_selected)
	add_child(OptionsUi.make_row("Two Player Split", _split_layout, _describe_split_layout))

	add_child(OptionsUi.make_separator())
	add_child(OptionsUi.make_heading("INTERFACE"))

	_ui_scale = OptionsUi.make_slider(Settings.MIN_UI_SCALE, Settings.MAX_UI_SCALE, 0.05, Settings.ui_scale)
	_ui_scale_readout = OptionsUi.make_readout(_percent(Settings.ui_scale))
	_ui_scale.value_changed.connect(_on_ui_scale_changed)
	add_child(OptionsUi.make_row(
		"UI Scale", OptionsUi.make_slider_box(_ui_scale, _ui_scale_readout), _describe_ui_scale
	))

	_commentary = OptionsUi.make_dropdown(COMMENTARY_MODES, Settings.commentary)
	_commentary.item_selected.connect(_on_commentary_selected)
	add_child(OptionsUi.make_row("Commentary", _commentary, _describe_commentary))


## Pulls every dropdown back in line with what is really set, the monitor may
## have changed the lists underneath them
func _sync() -> void:
	_resolutions = Settings.get_available_resolutions()
	_frame_rates = Settings.get_available_frame_rates()

	OptionsUi.refill_dropdown(_monitor, Settings.get_monitor_names(), Settings.monitor)
	OptionsUi.refill_dropdown(_resolution, _resolution_entries(), _resolutions.find(Settings.resolution))
	OptionsUi.refill_dropdown(_frame_rate, _frame_rate_entries(), _frame_rates.find(Settings.max_fps))

	_window_mode.select(Settings.window_mode)
	_vsync.select(Settings.vsync)
	_resolution.disabled = Settings.window_mode == Settings.MODE_FULLSCREEN
	_upscaler.disabled = Settings.render_scale >= 0.999


func _resolution_entries() -> Array[String]:
	var entries: Array[String] = []
	for res in _resolutions:
		entries.append("%d x %d" % [res.x, res.y])

	return entries


func _frame_rate_entries() -> Array[String]:
	var entries: Array[String] = []
	for rate in _frame_rates:
		entries.append("Unlimited" if rate == 0 else "%d FPS" % rate)

	return entries


## Every dropdown description takes the entry the pointer is on. -1 means the
## list is closed, so it falls back to whatever is set
func _describe_monitor(index: int) -> String:
	if DisplayServer.get_screen_count() <= 1:
		return "Only one screen plugged in, so this one has nothing to argue about."

	var screen := Settings.monitor if index < 0 else index
	var size := DisplayServer.screen_get_size(screen)
	var hz := int(round(DisplayServer.screen_get_refresh_rate(screen)))
	return "Opens the game on screen %d: %d x %d at %d Hz. Windows and 'the good monitor' rarely agree, this settles it." % [
		screen + 1, size.x, size.y, maxi(hz, 60)
	]


func _describe_window_mode(index: int) -> String:
	match (Settings.window_mode if index < 0 else index):
		Settings.MODE_FULLSCREEN:
			return "Fullscreen: the card stops sharing the screen with anything else. Fastest, but alt-tab needs a moment to think."
		Settings.MODE_BORDERLESS:
			return "Borderless: fullscreen without the drama. Alt-tab is instant, costs you a frame or two."

	return "Windowed: a plain window with a title bar. Handy for having a browser open, terrible for atmosphere."


func _describe_resolution(index: int) -> String:
	if Settings.window_mode == Settings.MODE_FULLSCREEN:
		return "Fullscreen already takes the monitor's own resolution, so there is nothing to pick here."

	var size := Settings.resolution
	if index >= 0 and index < _resolutions.size():
		size = _resolutions[index]

	if size == DisplayServer.screen_get_size(Settings.monitor):
		return "%d x %d, the native resolution. Every pixel your panel owns is doing honest work." % [size.x, size.y]

	if size.x >= 2560:
		return "%d x %d. That is an awful lot of pixels for a game made of cubes. No notes." % [size.x, size.y]

	return "%d x %d. Fewer pixels, more frames. The oldest trade in the business." % [size.x, size.y]


func _describe_vsync(index: int) -> String:
	match (Settings.vsync if index < 0 else index):
		0:
			return "Off: frames leave the moment they are done. Lowest input lag, and the picture can tear straight across the middle."
		1:
			return "On: every frame waits politely for the monitor. No tearing, a little more lag between your hand and the cube."
		2:
			return "Adaptive: V-Sync until the frame rate drops, then it lets go instead of halving. Best of both, most nights."

	return "Mailbox: renders ahead and shows the newest frame there is. Smooth and tear free, if your driver feels like playing along."


## The one place the refresh rate still shows up, and only because the joke
## needs it
func _describe_frame_rate(index: int) -> String:
	var hz := int(round(DisplayServer.screen_get_refresh_rate(Settings.monitor)))
	var rate := Settings.max_fps
	if index >= 0 and index < _frame_rates.size():
		rate = _frame_rates[index]

	if rate <= 0:
		return "No cap. The card runs flat out, your room gets warmer, and every frame past %d Hz is thrown away unseen." % maxi(hz, 60)

	if rate >= 240:
		return "%d FPS. Oh, you're rich. Lovely panel, lovely card, lovely electricity bill." % rate

	if rate >= 144:
		return "%d FPS. Smooth enough that a falling cube really looks like it means it." % rate

	if rate >= 90:
		return "%d FPS. The sensible spot: silky to look at and the fans stay polite." % rate

	if rate >= 60:
		return "60 FPS. The number every trailer promised in 2005 and roughly half of them delivered."

	return "%d FPS. Quiet fans, cool laptop, and a cube that moves like it is thinking things over." % rate


## The one setting that actually buys frames on a handheld, and the one place
## the menus are promised they will not be dragged down with the world
func _describe_render_scale() -> String:
	var scale := Settings.render_scale
	if scale >= 0.999:
		return "Full resolution. Every pixel the window has is rendered properly. The way it was meant to look."

	if scale >= 0.8:
		return "%d %%. The world is drawn slightly smaller and stretched back up. Cheap frames, and almost nobody notices." % _percent_value(scale)

	if scale >= 0.6:
		return "%d %%. A real chunk of work saved. Edges go soft, the frame rate stops arguing with you." % _percent_value(scale)

	return "%d %%. The last resort. It runs, and it looks like it is being described to you over a bad phone line." % _percent_value(scale)


func _describe_upscaler(index: int) -> String:
	if Settings.render_scale >= 0.999:
		return "Nothing to upscale while the render scale sits at 100 %. Turn that down first and this starts to matter."

	match (Settings.upscaler if index < 0 else index):
		Settings.UPSCALER_BILINEAR:
			return "Bilinear: the plain stretch. Free, and exactly as soft as you would expect."
		Settings.UPSCALER_FSR1:
			return "FSR 1: sharpens while it stretches. Costs almost nothing and looks a great deal better than the plain one."

	return "FSR 2: rebuilds the detail out of the last few frames. The best picture of the three, and the only one that thinks about it."


func _describe_msaa(index: int) -> String:
	match (Settings.msaa if index < 0 else index):
		0:
			return "Off. Every cube edge is a tiny staircase. Free, honest and jagged."
		1:
			return "2x. Takes the worst off the edges for almost nothing in return."
		2:
			return "4x. The sweet spot for a game built entirely out of straight lines."

	return "8x. Complete overkill for cubes. Do it anyway, those edges are gorgeous."


func _describe_screen_space_aa(index: int) -> String:
	match (Settings.screen_space_aa if index < 0 else index):
		0:
			return "Off. Sharp and aliased, exactly what the renderer drew. Warts included."
		1:
			return "FXAA: smears the jagged bits away after the fact. Nearly free, slightly soft."

	return "SMAA: cleverer than FXAA and keeps more of the detail. Costs a little more thinking."


## FSR 2 already blends the last few frames to rebuild what it upscaled, so the
## renderer drops TAA on the floor while it is on rather than do the work twice
func _describe_taa() -> String:
	if Settings.upscaler == Settings.UPSCALER_FSR2 and Settings.render_scale < 0.999:
		return "FSR 2 is already doing this, and better. This switch is ignored until you pick another upscaler."

	if Settings.taa:
		return "On: blends the last few frames together. Beautifully calm standing still, a bit smeary when the cube sprints."

	return "Off: sharper image, more shimmer on thin edges. Switch it on if the saw blades sparkle at you."


## Only two players have a choice worth offering. Three and four are quadrants
## either way, and one is the whole window
func _on_split_layout_selected(at: int) -> void:
	Settings.set_split_layout(at)


func _describe_split_layout(index: int) -> String:
	match (Settings.split_layout if index < 0 else index):
		Settings.SPLIT_STACKED:
			return "Stacked: two wide strips, one over the other. A corridor is read by looking down it, and a full width strip keeps more of that. Three and four players are always quarters."

	return "Side by side: two tall strips. More corridor above and below you, less of it ahead. Three and four players are always quarters."


func _describe_spawn_animation() -> String:
	if Settings.spawn_animation:
		return "On: every level starts with the cube pulling itself together out of the debris it died as. Costs you about a second."

	return "Off: the cube is simply there and drops in. Faster on the retry you have already seen eleven times."


func _describe_splash(index: int) -> String:
	match (Settings.splash_quality if index < 0 else index):
		Settings.SPLASH_OFF:
			return "Off: the walls stay clean. Every attempt looks like the first one, which is either tidy or a little lonely."
		Settings.SPLASH_LOW:
			return "Low: a handful of marks, flat paint, no fine spray. Cheap enough that your card will not notice it happened."
		Settings.SPLASH_MEDIUM:
			return "Medium: the full mark with its wet edge and its thrown droplets. What the corridors were built to look like."

	return "High: more deaths stay up, they reach further, and the paint gets every speck of its spray. For cards with something to prove."


## The menus are laid out for a 1920 x 1080 screen and fitted to whatever window
## they end up in. This is what saves them on a handheld, where that fit alone
## leaves the text too small to read
func _describe_ui_scale() -> String:
	var scale := Settings.ui_scale
	if scale <= 0.999:
		return "%d %%. Smaller menus, more room around them. For big screens and good eyes." % _percent_value(scale)

	if scale <= 1.001:
		return "100 %. The size the menus were drawn at. Correct on a monitor, optimistic on a handheld."

	if scale <= 1.3:
		return "%d %%. Everything a size up. This is the one for a Steam Deck or a laptop panel held close." % _percent_value(scale)

	return "%d %%. Large and unmissable. The longest lines start crowding the edges up here." % _percent_value(scale)


## The subtitles the game throws in while a level runs. The line on the summary
## screen is not one of them and keeps coming either way
func _describe_commentary(index: int) -> String:
	match (Settings.commentary if index < 0 else index):
		Settings.COMMENTARY_OFF:
			return "Off: the game keeps its opinions to itself. Only the summary at the end still has something to say."
		Settings.COMMENTARY_LOW:
			return "Low: it speaks up when you die, and mostly only when the death was worth mentioning."
		Settings.COMMENTARY_MEDIUM:
			return "Medium: deaths, the key and whatever the sphere just handed you. Enough to explain the items, quiet enough to think."

	return "Lots: every pickup, every item spent, every single death. The maze becomes a talk show with saws in it."


func _on_commentary_selected(index: int) -> void:
	Settings.set_commentary(index)


func _on_splash_selected(index: int) -> void:
	Settings.set_splash_quality(index)


## Picking a screen here is the one thing that writes it down as the wanted one,
## so that every other way the window gets moved leaves the choice alone
func _on_monitor_selected(index: int) -> void:
	Settings.set_monitor(index)


func _on_window_mode_selected(index: int) -> void:
	Settings.window_mode = index
	Settings.apply_display()


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= _resolutions.size():
		return

	Settings.resolution = _resolutions[index]
	Settings.apply_display()


func _on_vsync_selected(index: int) -> void:
	Settings.vsync = index
	Settings.apply_display()


func _on_frame_rate_selected(index: int) -> void:
	if index < 0 or index >= _frame_rates.size():
		return

	Settings.max_fps = _frame_rates[index]
	Settings.apply_display()


## The upscaler row explains itself in terms of the render scale, so it is told
## to say its line again whenever the slider moves off or back onto 100 %
func _on_render_scale_changed(value: float) -> void:
	_render_scale_readout.text = _percent(value)
	Settings.set_render_scale(value)
	_upscaler.disabled = value >= 0.999


func _on_upscaler_selected(index: int) -> void:
	Settings.upscaler = index
	Settings.apply_graphics()


func _on_ui_scale_changed(value: float) -> void:
	_ui_scale_readout.text = _percent(value)
	Settings.set_ui_scale(value)


func _percent(value: float) -> String:
	return "%d %%" % _percent_value(value)


func _percent_value(value: float) -> int:
	return int(round(value * 100.0))


func _on_msaa_selected(index: int) -> void:
	Settings.msaa = index
	Settings.apply_graphics()


func _on_screen_space_aa_selected(index: int) -> void:
	Settings.screen_space_aa = index
	Settings.apply_graphics()


func _on_taa_toggled(enabled: bool) -> void:
	Settings.taa = enabled
	Settings.apply_graphics()


func _on_spawn_animation_toggled(enabled: bool) -> void:
	Settings.set_spawn_animation(enabled)
