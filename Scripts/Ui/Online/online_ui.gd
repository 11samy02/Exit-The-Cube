class_name OnlineUi
extends RefCounted

## The look of the online screens, in one place. All three of them are built in
## code rather than in the editor: the lobby is a list that changes every time
## somebody presses a button, the standings are a list that changes twelve times
## a second, and neither of those is anything the editor can hold.
##
## Everything below draws from the same menu theme the rest of the game uses, so
## the buttons, the panels and the fonts already match. What is added here is
## only the parts the theme has no entry for: headings, accents and the framed
## rows the lobby and the standings are made of

const HEADING_FONT := preload("res://Assets/Fonts/Orbitron-Variable.ttf")
const BODY_FONT := preload("res://Assets/Fonts/Rajdhani-Medium.ttf")
const THEME := preload("res://Assets/Themes/menu_theme.tres")

## The background the title screen uses, so the online screens are the same room
const BACKGROUND_SHADER := preload("res://Assets/shaders/title_bg.gdshader")

## The cyan everything focused and everything live is drawn in
const ACCENT := Color(0.129, 0.855, 1.0)

## The violet the panels are edged with
const EDGE := Color(0.353, 0.125, 0.851)

## Ordinary text, and the quieter text under it
const TEXT := Color(0.878, 0.859, 0.988)
const MUTED := Color(0.616, 0.588, 0.749)

## A player who has readied up, and one who has not
const READY := Color(0.34, 1.0, 0.55)
const WAITING := Color(1.0, 0.62, 0.25)

## The three places that get their own color on the results panel
const PODIUM := [
	Color(1.0, 0.84, 0.28),
	Color(0.78, 0.82, 0.9),
	Color(0.86, 0.55, 0.3),
]


## A heading in the display font. The sizes are handed in rather than fixed, the
## same builder makes the screen title and the small caption over a column
static func heading(text: String, size: int, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = LabelSettings.new()
	label.label_settings.font = _heading_font()
	label.label_settings.font_size = size
	label.label_settings.font_color = color
	return label


## A line of ordinary text
static func body(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = LabelSettings.new()
	label.label_settings.font = BODY_FONT
	label.label_settings.font_size = size
	label.label_settings.font_color = color
	return label


## The screen title, with the glow the title screen puts on its own
static func screen_title(text: String) -> Label:
	var label := heading(text, 64)
	label.label_settings.outline_size = 8
	label.label_settings.outline_color = Color(EDGE.r, EDGE.g, EDGE.b, 0.85)
	label.label_settings.shadow_size = 22
	label.label_settings.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## A framed box, the panel every list and every card on these screens sits in
static func panel(accent: Color = EDGE, fill: float = 0.55) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", panel_style(accent, fill))
	return box


static func panel_style(accent: Color, fill: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.047, 0.09, fill)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	return style


## A button that answers to the mouse and the pad like every other one in the
## game. Wiring the feedback here means no screen has to remember to
static func button(text: String, width: float = 0.0) -> Button:
	var control := Button.new()
	control.text = text
	if width > 0.0:
		control.custom_minimum_size = Vector2(width, 62)
	UiFeedback.attach(control)
	return control


## The dropdown the host picks a setting out of. A member gets the same control
## with everything switched off, so both sides of the lobby read the same
static func choice(labels: Array, at: int, enabled: bool) -> OptionButton:
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.custom_minimum_size = Vector2(0, 52)
	picker.disabled = not enabled
	picker.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

	for label: String in labels:
		picker.add_item(label)

	picker.selected = clampi(at, 0, maxi(labels.size() - 1, 0))
	UiFeedback.attach(picker)
	return picker


## The animated grid the title screen stands on. Every online screen gets one so
## walking from the menu into the lobby does not read as leaving the game
static func background() -> ColorRect:
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_SHADER
	material.set_shader_parameter("sky_top", Color(0.006, 0, 0.024, 1))
	material.set_shader_parameter("sky_bottom", Color(0.09, 0.012, 0.2, 1))
	material.set_shader_parameter("grid_color", EDGE)
	material.set_shader_parameter("glow_color", Color(0, 0.85, 1, 1))
	material.set_shader_parameter("horizon", 0.58)
	material.set_shader_parameter("speed", 0.35)
	material.set_shader_parameter("lane_width", 6.0)
	material.set_shader_parameter("grid_depth", 0.6)
	material.set_shader_parameter("scanline_strength", 0.06)
	material.set_shader_parameter("vignette_strength", 0.55)

	var rect := ColorRect.new()
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## Ties two controls side by side, so sideways walks from one to the other and
## back again.
##
## Godot works its focus neighbours out from the geometry when they are not set,
## and that guess is only as good as the layout is flat. On the online screens it
## is not: the buttons sit inside cards inside rows, and the search has been seen
## to step straight past the one that is plainly next to it and land on something
## a row below. Anything a pad has to walk through is therefore wired by hand
static func link_across(left: Control, right: Control) -> void:
	left.focus_neighbor_right = left.get_path_to(right)
	right.focus_neighbor_left = right.get_path_to(left)
	left.focus_next = left.get_path_to(right)
	right.focus_previous = right.get_path_to(left)


## The same downwards
static func link_down(top: Control, bottom: Control) -> void:
	top.focus_neighbor_bottom = top.get_path_to(bottom)
	bottom.focus_neighbor_top = bottom.get_path_to(top)


## Walks a row of controls, tying each to the next. The ends are left open, a row
## that wrapped around would make the pad circle forever with nothing saying so
static func link_row(controls: Array) -> void:
	for at in range(controls.size() - 1):
		link_across(controls[at] as Control, controls[at + 1] as Control)


## The same for a column
static func link_column(controls: Array) -> void:
	for at in range(controls.size() - 1):
		link_down(controls[at] as Control, controls[at + 1] as Control)


## Empty space of a fixed height, the layouts are full of it
static func gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## A row that pushes whatever comes after it to the far side
static func stretch() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## Minutes and seconds, the way the summary screen writes them
static func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%d:%05.2f" % [minutes, seconds - minutes * 60]


## The heading font at the weight the theme uses
static func _heading_font() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = HEADING_FONT
	font.variation_opentype = {2003265652: 800}
	font.spacing_glyph = 3
	return font
