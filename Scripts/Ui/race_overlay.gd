class_name RaceOverlay
extends CanvasLayer

## Everything the race puts on screen over the top of the map: the standings
## while it runs, the ranking once this cube is out, and the bar that steers the
## camera around the ones who are still in there.
##
## It is added to the map by the Online node rather than sitting in the map
## scene, so the map scene itself knows nothing about any of this and still
## opens and plays on its own

## Above the game UI and above the pause menu, below the scene transition. The
## race panel is the one thing in a map that must not have something drawn over
## the top of it
const OVERLAY_LAYER := 70

## How often the standings redraw. They also redraw whenever a packet moves
## something, this is only so a running clock does not sit still
const TICK := 0.25

## How far the results panel drops in from
const PANEL_DROP := Vector2(0, -60)

## How wide the corner strip is, and how far it sits off the edge
const STRIP_WIDTH := 340.0
const STRIP_MARGIN := 26.0

## The border and the padding one framed row of the results panel costs, which
## is how far the column titles over it have to be pushed in to line up
const ROW_INSET := 18

## How wide the card that counts a death down is. Fixed so the number inside it
## does not make the whole thing jump between one digit and two
const DOWN_CARD_WIDTH := 380.0

## How far the spectator bar sits off the bottom. Clear of the level banner the
## game UI puts down there, the two of them are up at the same time
const WATCH_MARGIN := 130.0

var _strip: PanelContainer = null
var _strip_note: Label = null
var _link: Label = null
var _standings: VBoxContainer = null
var _panel_root: Control = null
var _panel_rows: VBoxContainer = null
var _panel_title: Label = null
var _panel_comment: Label = null
var _spectate_button: Button = null
var _lobby_button: Button = null
var _lobby_note: Label = null
var _watch_bar: Control = null
var _watch_name: Label = null
var _watch_item: Label = null
var _watch_back: Button = null
var _down_card: PanelContainer = null
var _down_clock: Label = null
var _down_cost: Label = null

var _tick: float = 0.0

## True while the camera is off following somebody else
var _spectating: bool = false

## True once the local cube has ridden the elevator out
var _finished: bool = false


func _ready() -> void:
	layer = OVERLAY_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_standings()
	_build_panel()
	_build_watch_bar()
	_build_down_card()
	_apply_theme()

	Online.standings_updated.connect(_redraw)
	Online.paint_changed.connect(_redraw)
	Online.round_over.connect(_on_round_over)
	GameState.run_finished.connect(_on_finished)
	_redraw()


## The clock ran out on a painting round. Everybody sees it at once, nobody rode
## an elevator, and the panel is the same one a finished race puts up
func _on_round_over() -> void:
	if _finished:
		return

	_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_panel()


func _process(delta: float) -> void:
	if Online.is_painting():
		_draw_down_card()

	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_redraw()


## The strip in the corner. Everybody in the race, in the order they stand, so a
## glance sideways is enough to know whether the friend two rooms over is ahead
func _build_standings() -> void:
	var frame := OnlineUi.panel(OnlineUi.EDGE, 0.45)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(STRIP_WIDTH, 0)
	add_child(frame)
	_pin(frame, 1.0, 0.0, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END, \
		Vector2(-STRIP_MARGIN, STRIP_MARGIN))
	_strip = frame

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	frame.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(OnlineUi.heading("STANDINGS", 20, OnlineUi.ACCENT))
	header.add_child(OnlineUi.stretch())

	_strip_note = OnlineUi.body("", 17, OnlineUi.MUTED)
	header.add_child(_strip_note)

	column.add_child(OnlineUi.gap(4))

	_standings = VBoxContainer.new()
	_standings.add_theme_constant_override("separation", 4)
	column.add_child(_standings)

	column.add_child(OnlineUi.gap(4))
	_link = OnlineUi.body("", 15, OnlineUi.MUTED)
	column.add_child(_link)


## The card that comes up while this cube is sitting out a death.
##
## A player who bursts and then waits five seconds looking at an empty corridor
## has no way of telling a penalty from a hang. This says how long is left, what
## it cost, and that the cube is coming back
func _build_down_card() -> void:
	var frame := PanelContainer.new()
	frame.visible = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(DOWN_CARD_WIDTH, 0)
	frame.add_theme_stylebox_override("panel", _down_style())
	add_child(frame)
	_pin(frame, 0.5, 0.5, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH, Vector2.ZERO)
	_down_card = frame

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	frame.add_child(column)

	var title := OnlineUi.heading("RESPAWN IN", 24, OnlineUi.WAITING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_down_clock = OnlineUi.heading("", 82, OnlineUi.TEXT)
	_down_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_down_clock)

	_down_cost = OnlineUi.body("", 21, OnlineUi.MUTED)
	_down_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_down_cost)


## The card's own frame rather than the shared one. The panels elsewhere are
## built for rows of text and their padding is measured for that; a single
## eighty point number inside the same margins sits against its own border
func _down_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.94)
	style.border_color = OnlineUi.WAITING
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 40.0
	style.content_margin_right = 40.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 26.0
	return style


## Counts the wait down, and says what the death took. The number is read off
## the same clock the cube is serving, so it cannot drift away from it
func _draw_down_card() -> void:
	var left := Online.penalty_left()
	_down_card.visible = left > 0.0

	if not _down_card.visible:
		return

	_down_clock.text = "%d" % maxi(ceili(left), 1)
	_down_cost.text = "%d tiles lost" % RaceRules.DEATH_TILE_PENALTY


## Sticks a control to one corner and lets it size itself from there. Handing a
## preset a minimum size instead bakes in whatever the panel measured while it
## was still empty, and a list that fills up afterwards then grows straight off
## the side of the screen
func _pin(control: Control, x: float, y: float, grow_x: int, grow_y: int, offset: Vector2) -> void:
	control.anchor_left = x
	control.anchor_right = x
	control.anchor_top = y
	control.anchor_bottom = y
	control.offset_left = offset.x
	control.offset_right = offset.x
	control.offset_top = offset.y
	control.offset_bottom = offset.y
	control.grow_horizontal = grow_x
	control.grow_vertical = grow_y


## The panel that goes up once this cube is out of the maze
func _build_panel() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_root.visible = false
	add_child(_panel_root)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_root.add_child(shade)

	var frame := OnlineUi.panel(OnlineUi.EDGE, 0.92)
	frame.custom_minimum_size = Vector2(880, 0)
	_panel_root.add_child(frame)
	_pin(frame, 0.5, 0.5, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH, Vector2.ZERO)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)

	_panel_title = OnlineUi.heading("RACE OVER", 44, OnlineUi.ACCENT)
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_panel_title)

	_panel_comment = OnlineUi.body("", 22, OnlineUi.MUTED)
	_panel_comment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_panel_comment)

	column.add_child(OnlineUi.gap(10))
	column.add_child(_build_header())

	_panel_rows = VBoxContainer.new()
	_panel_rows.add_theme_constant_override("separation", 6)
	column.add_child(_panel_rows)

	column.add_child(OnlineUi.gap(14))
	column.add_child(_build_buttons())

	_lobby_note = OnlineUi.body("", 20, OnlineUi.MUTED)
	_lobby_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lobby_note)


## The column titles, in the order the ranking sorts by. Reading them left to
## right is the whole tie break rule, which saves explaining it anywhere else.
##
## Every row under this sits in a framed panel and the titles do not, so they
## are inset by exactly what that frame costs. Without it the whole header
## stands a border and a margin to the left of the numbers it names
func _build_header() -> Control:
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", ROW_INSET)
	inset.add_theme_constant_override("margin_right", ROW_INSET)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	inset.add_child(row)

	row.add_child(_column(OnlineUi.body("#", 19, OnlineUi.MUTED), 60))
	row.add_child(_column(OnlineUi.body("PLAYER", 19, OnlineUi.MUTED), 0))
	row.add_child(_column(OnlineUi.body("DEATHS", 19, OnlineUi.MUTED), 110))
	row.add_child(_column(OnlineUi.body("TIME", 19, OnlineUi.MUTED), 150))
	row.add_child(_column(OnlineUi.body("ITEMS", 19, OnlineUi.MUTED), 100))

	return inset


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)

	_spectate_button = OnlineUi.button("SPECTATE", 280)
	_spectate_button.pressed.connect(_start_spectating)
	row.add_child(_spectate_button)

	_lobby_button = OnlineUi.button("BACK TO LOBBY", 300)
	_lobby_button.pressed.connect(_on_lobby_pressed)
	row.add_child(_lobby_button)

	OnlineUi.link_across(_spectate_button, _lobby_button)
	return row


## The bar that comes up in place of the panel while somebody else is being
## watched. It is thin on purpose, the point of spectating is the maze
func _build_watch_bar() -> void:
	var frame := OnlineUi.panel(OnlineUi.ACCENT, 0.94)
	frame.visible = false
	add_child(frame)
	_pin(frame, 0.5, 1.0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN, \
		Vector2(0.0, -WATCH_MARGIN))
	_watch_bar = frame

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	frame.add_child(row)

	var previous := OnlineUi.button("<", 70)
	previous.pressed.connect(_watch_step.bind(-1))
	row.add_child(previous)

	var watched := VBoxContainer.new()
	watched.custom_minimum_size = Vector2(340, 0)
	watched.add_theme_constant_override("separation", 0)
	row.add_child(watched)

	_watch_name = OnlineUi.body("", 26, OnlineUi.TEXT)
	_watch_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	watched.add_child(_watch_name)

	_watch_item = OnlineUi.body("", 18, OnlineUi.MUTED)
	_watch_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	watched.add_child(_watch_item)

	var next := OnlineUi.button(">", 70)
	next.pressed.connect(_watch_step.bind(1))
	row.add_child(next)

	_watch_back = OnlineUi.button("STANDINGS", 260)
	_watch_back.pressed.connect(_stop_spectating)
	UiFeedback.use_back_sound(_watch_back)
	row.add_child(_watch_back)

	OnlineUi.link_row([previous, next, _watch_back])


## A layer is not a Control and hands nothing down to the controls under it, so
## the menu theme has to be put on each of the three roots by hand. Without it
## the race panel comes up in the plain grey Godot buttons
func _apply_theme() -> void:
	for root: Control in [_strip, _panel_root, _watch_bar, _down_card]:
		root.theme = OnlineUi.THEME


func _redraw() -> void:
	if Online.is_painting():
		_draw_teams()
	else:
		_draw_strip(Online.standings())

	if _panel_root.visible:
		_draw_panel(Online.standings())

	if _spectating:
		_show_watched()


## The corner board of a painting round: how much floor each side holds, and how
## long is left. Which cube is ahead of which matters far less here than which
## colour the map is turning
func _draw_teams() -> void:
	for child in _standings.get_children():
		_standings.remove_child(child)
		child.queue_free()

	var counts := Online.paint.tally()
	var total := maxi(Online.paint.claims.size(), 1)
	var mine := Online.team_of(Online.steam.id)

	for team in range(RaceRules.team_count(Online.settings)):
		var held := int(counts.get(team, 0))
		_standings.add_child(_build_team_row(team, held, float(held) / float(total), team == mine))

	_strip_note.text = OnlineUi.format_time(Online.round_left())
	_draw_link()


## One side: its colour, its name, how much of the painted floor is theirs. The
## share is what says who is winning — a raw count means nothing until you know
## what the other numbers are
func _build_team_row(team: int, held: int, share: float, mine: bool) -> Control:
	var color := RaceRules.team_color(team)

	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _row_style(color, mine))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	frame.add_child(row)

	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	row.add_child(_column(OnlineUi.body(RaceRules.team_name(team) + ("  ·  YOU" if mine else ""), \
		20, color), 0))
	row.add_child(OnlineUi.body("%d  ·  %d%%" % [held, roundi(share * 100.0)], 19, OnlineUi.MUTED))

	return frame


## The corner strip. The place, the name and where that cube has got to — the
## full numbers are on the panel where there is room for them
func _draw_strip(standings: Array) -> void:
	for child in _standings.get_children():
		_standings.remove_child(child)
		child.queue_free()

	for runner: Dictionary in standings:
		_standings.add_child(_build_strip_row(runner))

	_strip_note.text = OnlineUi.format_time(GameState.run_time)
	_draw_link()


## The state of the lines to the other cubes, in one line under the board.
##
## It is there because "nothing is syncing" is the least useful bug report there
## is and this turns it into a readable one. Packets leaving with none coming
## back is a line that never opened; both numbers climbing with a board that is
## still wrong is something further up entirely
func _draw_link() -> void:
	var report := Online.link_report()
	var peers := int(report["peers"])

	if peers <= 0:
		_link.text = "racing alone"
		_link.label_settings.font_color = OnlineUi.MUTED
		return

	var open := int(report["open"])
	var failed := int(report["failed"])
	var line := "net  %d up  %d down  ·  %d / %d linked" % [
		int(report["sent"]), int(report["received"]), open, peers,
	]

	if failed > 0:
		line += "  ·  %d unreachable" % failed

	_link.text = line
	_link.label_settings.font_color = OnlineUi.MUTED if int(report["received"]) > 0 \
		else OnlineUi.WAITING


## The place is drawn in the podium colors and the row this machine is on burns
## in its own frame, so the one thing anybody actually looks for mid corridor —
## am I still up there — is a glance and not a read
func _build_strip_row(runner: Dictionary) -> Control:
	var mine := int(runner["id"]) == Online.steam.id
	var place := int(runner["rank"])
	var accent := _place_color(place)

	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _row_style(accent, mine))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	frame.add_child(row)

	row.add_child(_column(OnlineUi.heading(str(place), 19, accent), 30))

	var name_label := OnlineUi.body(String(runner["name"]).to_upper(), 20, \
		Color.WHITE if mine else GhostField.ghost_color(int(runner["id"])))
	name_label.clip_text = true
	row.add_child(_column(name_label, 0))

	row.add_child(_progress_label(runner))
	return frame


## Where that cube has got to, in the fewest words the row has room for
func _progress_label(runner: Dictionary) -> Label:
	if bool(runner["finished"]):
		return OnlineUi.body(OnlineUi.format_time(float(runner["time"])), 19, OnlineUi.READY)

	var deaths := int(runner["deaths"])
	var counted := "%d death" % deaths if deaths == 1 else "%d deaths" % deaths

	if bool(runner["has_key"]):
		return OnlineUi.body("KEY  ·  %s" % counted, 19, OnlineUi.ACCENT)

	return OnlineUi.body(counted, 19, OnlineUi.MUTED)


## A row of the strip. Only this machine's own gets a filled frame, twelve lit
## rows would be a wall of boxes rather than a board
func _row_style(accent: Color, mine: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.16) if mine else Color(0, 0, 0, 0)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0

	if mine:
		style.border_width_left = 3
		style.border_color = accent

	return style


## The full ranking, with the podium colors on the first three places
func _draw_panel(standings: Array) -> void:
	for child in _panel_rows.get_children():
		_panel_rows.remove_child(child)
		child.queue_free()

	if Online.is_painting():
		_draw_paint_result()
	else:
		for runner: Dictionary in standings:
			_panel_rows.add_child(_build_panel_row(runner))

	_spectate_button.visible = Online.anyone_running() and not Online.is_painting()
	_lobby_button.visible = true
	_lobby_note.text = _lobby_hint()


func _build_panel_row(runner: Dictionary) -> Control:
	var place := int(runner["rank"])
	var mine := int(runner["id"]) == Online.steam.id
	var accent := _place_color(place)

	var frame := OnlineUi.panel(accent if mine else Color(accent, 0.5), 0.5 if mine else 0.25)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	frame.add_child(row)

	row.add_child(_column(OnlineUi.heading(str(place), 26, accent), 60))

	var name_label := OnlineUi.body(String(runner["name"]).to_upper(), 24, \
		Color.WHITE if mine else GhostField.ghost_color(int(runner["id"])))
	row.add_child(_column(name_label, 0))

	row.add_child(_column(OnlineUi.body(str(int(runner["deaths"])), 22), 110))
	row.add_child(_column(OnlineUi.body(OnlineUi.format_time(float(runner["time"])) \
		if bool(runner["finished"]) else "still in there", 22, \
		OnlineUi.TEXT if bool(runner["finished"]) else OnlineUi.WAITING), 150))
	row.add_child(_column(OnlineUi.body(str(int(runner["items"])), 22), 100))

	return frame


## How a painting round ended: every side by how much floor it holds, and under
## it every player by how much of that they laid down themselves.
##
## The two are worth keeping apart. A side wins on the floor it holds at the
## whistle, which is a team result and nothing to do with who worked hardest —
## a player can paint half the map and lose it all to the other side in the last
## minute. The per player count is what they actually did
func _draw_paint_result() -> void:
	var counts := Online.paint.tally()
	var sides: Array = []

	for team in range(RaceRules.team_count(Online.settings)):
		sides.append({"team": team, "held": int(counts.get(team, 0))})

	sides.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["held"]) > int(b["held"]))

	var total := maxi(Online.paint.claims.size(), 1)

	for at in range(sides.size()):
		var side: Dictionary = sides[at]
		_panel_rows.add_child(_build_result_team(at + 1, int(side["team"]), int(side["held"]), \
			float(side["held"]) / float(total)))

		for runner: Dictionary in _players_of(int(side["team"])):
			_panel_rows.add_child(_build_result_player(runner))


## Everybody on that side, the one who painted the most first
func _players_of(team: int) -> Array:
	var found: Array = []

	for id: int in Online.runners:
		if Online.team_of(id) == team:
			var runner: Dictionary = Online.runners[id].duplicate()
			runner["painted"] = int(Online.paint.painted_total.get(id, 0))
			runner["held"] = Online.paint.held_by(id)
			found.append(runner)

	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["painted"]) > int(b["painted"]))

	return found


func _build_result_team(place: int, team: int, held: int, share: float) -> Control:
	var color := RaceRules.team_color(team)
	var frame := OnlineUi.panel(color, 0.35)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	frame.add_child(row)

	row.add_child(_column(OnlineUi.heading(str(place), 26, color), 60))
	row.add_child(_column(OnlineUi.heading(RaceRules.team_name(team), 26, color), 0))
	row.add_child(_column(OnlineUi.body("%d tiles" % held, 22), 150))
	row.add_child(_column(OnlineUi.body("%d%%" % roundi(share * 100.0), 22, color), 100))

	return frame


func _build_result_player(runner: Dictionary) -> Control:
	var mine := int(runner["id"]) == Online.steam.id
	var deaths := int(runner["deaths"])

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _row_style(OnlineUi.MUTED, mine))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	frame.add_child(row)

	row.add_child(_column(OnlineUi.body("", 20), 60))
	row.add_child(_column(OnlineUi.body(String(runner["name"]).to_upper(), 21, \
		Color.WHITE if mine else OnlineUi.TEXT), 0))
	row.add_child(_column(OnlineUi.body("%d painted" % int(runner["painted"]), 20, \
		OnlineUi.MUTED), 150))
	row.add_child(_column(OnlineUi.body("%d death" % deaths if deaths == 1 \
		else "%d deaths" % deaths, 20, OnlineUi.MUTED), 100))

	return frame


## The line under the buttons. A painting round is over for everybody at the
## same moment, so there is nobody left to leave behind and nothing to say
func _lobby_hint() -> String:
	if Online.is_painting() or not Online.anyone_running():
		return ""

	return "the others keep racing without you"


## Gold, silver and bronze for the podium, plain text for everybody else
func _place_color(place: int) -> Color:
	if place >= 1 and place <= OnlineUi.PODIUM.size():
		return OnlineUi.PODIUM[place - 1]

	return OnlineUi.MUTED


## A cell of a fixed width, or one that takes whatever is left when it is zero
func _column(control: Control, width: float) -> Control:
	if width > 0.0:
		control.custom_minimum_size = Vector2(width, 0)
	else:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return control


## The elevator carried this cube out. The single player summary stays down in a
## race, this panel is what takes its place
func _on_finished() -> void:
	if _finished:
		return

	_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_panel()


func _show_panel() -> void:
	_panel_root.visible = true
	_watch_bar.visible = false
	_spectating = false

	if Online.is_painting():
		_panel_title.text = _paint_title()
		_panel_comment.text = "five minutes, one floor, and this is what it looks like"
	else:
		var rank := Online.local_rank()
		_panel_title.text = _title_for(rank)
		_panel_comment.text = Quips.pick("online_result", 			OnlineQuips.result_pool(rank, Online.finisher_count()))

	_redraw()

	if _spectate_button.visible:
		_spectate_button.grab_focus()
	elif _lobby_button.visible:
		_lobby_button.grab_focus()

	_drop_in()


## Who took the floor, from the point of view of the player reading it
func _paint_title() -> String:
	var winner := Online.paint.leader()

	if winner < 0:
		return "A DEAD HEAT"

	return "YOUR TEAM TOOK IT" if winner == Online.team_of(Online.steam.id) 		else "%s TOOK IT" % RaceRules.team_name(winner)


func _title_for(rank: int) -> String:
	if rank <= 0:
		return "OUT ALIVE"

	return "FIRST OUT" if rank == 1 else "OUT ALIVE  ·  PLACE %d" % rank


func _drop_in() -> void:
	_panel_root.offset_transform_enabled = true
	_panel_root.offset_transform_position = PANEL_DROP
	_panel_root.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel_root, "offset_transform_position", Vector2.ZERO, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel_root, "modulate", Color(1, 1, 1, 1), 0.22)


func _start_spectating() -> void:
	var field := _field()
	if field == null:
		return

	_spectating = true
	_panel_root.visible = false
	_watch_bar.visible = true
	_watch_back.grab_focus()
	field.watch_step(1)
	_show_watched()


func _stop_spectating() -> void:
	var field := _field()
	if field != null:
		field.stop_watching()

	_show_panel()


func _watch_step(direction: int) -> void:
	var field := _field()
	if field == null:
		return

	field.watch_step(direction)
	_show_watched()


## Whoever is being followed, and the line that says nobody is left to follow
func _show_watched() -> void:
	var field := _field()
	if field == null:
		return

	var watching := field.watching()
	if watching == 0 or not Online.runners.has(watching):
		_watch_name.text = "nobody left in the maze"
		return

	var runner: Dictionary = Online.runners[watching]
	var deaths := int(runner["deaths"])
	var held := String(runner.get("item", ""))

	_watch_name.text = "%s  ·  %s" % [
		String(runner["name"]).to_upper(),
		"%d death" % deaths if deaths == 1 else "%d deaths" % deaths,
	]
	_watch_name.label_settings.font_color = GhostField.ghost_color(watching)
	_watch_item.text = "carrying  %s" % held.to_upper() if not held.is_empty() else "empty handed"


## Steps this player back to the lobby and nobody else. The others are still in
## their mazes, and being finished is not a reason to end their race
func _on_lobby_pressed() -> void:
	Online.leave_race()


func _field() -> GhostField:
	return get_tree().get_first_node_in_group(GhostField.GROUP) as GhostField


## While the panel or the watch bar is up, cancel and the sideways keys belong
## to this and not to whatever is underneath it
func _input(event: InputEvent) -> void:
	if _spectating:
		_spectate_input(event)
		return

	if not _panel_root.visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()


func _spectate_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		UiFeedback.play_back()
		_stop_spectating()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_watch_step(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_watch_step(1)
