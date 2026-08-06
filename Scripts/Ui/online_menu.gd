extends Control

## The question every online session starts with: are you opening a lobby or
## walking into one. Two cards, a line of advice under them, and the browser
## behind the join card.
##
## Steam is brought up here rather than at startup. A player who only ever plays
## the campaign never signs into anything, and if the client is shut this is the
## one screen that has to say so

const TITLE_SCENE := "res://Scenes/Ui/title_screen.tscn"

## How often the line under the title is swapped for another one
const QUIP_INTERVAL := 7.0

## How far a lobby row's contents sit inside its own edge, so the text does not
## run into the border the button draws around itself
const ROW_PADDING := 20

@onready var _layout: VBoxContainer = %Layout

var _quip: Label = null
var _cards: HBoxContainer = null
var _browser: VBoxContainer = null
var _lobby_list: VBoxContainer = null
var _status: Label = null
var _host_button: Button = null
var _join_button: Button = null
var _back_button: Button = null
var _refresh_button: Button = null
var _cancel_button: Button = null

## True from the moment a lobby is being opened or joined, a second press must
## not fire another one into the one that is already running
var _busy: bool = false

var _quip_timer: float = QUIP_INTERVAL


## Online is always one cube per machine, so whatever the splitscreen left in
## the seat table is put away before the lobby is opened
## Nothing online is played out of a seat — the whole of it runs on one cube and
## the Steam account behind it, and this node never asks the seat table anything.
## It used to sit a keyboard down and lock the room here anyway, which told the
## rest of the game a keyboard was playing while somebody was holding a pad.
## Clearing is still worth doing: a party left the room locked with a private
## copy of every action per seat, and those have to go before a race opens
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Seats.clear()

	add_child(OnlineUi.background())
	move_child(get_child(get_child_count() - 1), 0)

	_build()
	Online.lobby_closed.connect(_on_lobby_closed)
	Online.lobby_list_ready.connect(_on_lobby_list)

	_connect_steam()


## The line under the title rolls over on its own, there is nothing else to look
## at on this screen while somebody makes up their mind
func _process(delta: float) -> void:
	if _browser.visible:
		return

	_quip_timer -= delta
	if _quip_timer <= 0.0:
		_quip_timer = QUIP_INTERVAL
		_swap_quip()


func _build() -> void:
	_layout.add_child(OnlineUi.screen_title("ONLINE"))

	_quip = OnlineUi.body(Quips.pick("online_menu", OnlineQuips.HOST_OR_JOIN), 26, OnlineUi.MUTED)
	_quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout.add_child(_quip)

	_layout.add_child(OnlineUi.gap(40))
	_build_cards()
	_build_browser()

	_status = OnlineUi.body("", 22, OnlineUi.WAITING)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout.add_child(_status)

	_layout.add_child(OnlineUi.gap(24))

	_back_button = OnlineUi.button("BACK", 260)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(_on_back_pressed)
	UiFeedback.use_back_sound(_back_button)
	_layout.add_child(_back_button)

	_wire_focus()


## The two cards and the button under them. Left and right stay on the cards,
## down drops to Back from either of them, and up comes back to Host
func _wire_focus() -> void:
	OnlineUi.link_across(_host_button, _join_button)
	_host_button.focus_neighbor_bottom = _host_button.get_path_to(_back_button)
	_join_button.focus_neighbor_bottom = _join_button.get_path_to(_back_button)
	_back_button.focus_neighbor_top = _back_button.get_path_to(_host_button)
	_back_button.focus_previous = _back_button.get_path_to(_join_button)
	_join_button.focus_next = _join_button.get_path_to(_back_button)


## The two cards, side by side. Each one is a heading, a line about what it gets
## you and the button that does it
func _build_cards() -> void:
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 34)
	_layout.add_child(_cards)

	_host_button = OnlineUi.button("HOST", 300)
	_host_button.pressed.connect(_on_host_pressed)
	_cards.add_child(_build_card("HOST", Quips.pick("online_host", OnlineQuips.HOST_HINT), _host_button))

	_join_button = OnlineUi.button("JOIN", 300)
	_join_button.pressed.connect(_on_join_pressed)
	_cards.add_child(_build_card("JOIN", Quips.pick("online_join", OnlineQuips.JOIN_HINT), _join_button))


func _build_card(title: String, blurb: String, action: Button) -> Control:
	var card := OnlineUi.panel(OnlineUi.EDGE)
	card.custom_minimum_size = Vector2(400, 0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)

	var name_label := OnlineUi.heading(title, 34, OnlineUi.ACCENT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)

	var blurb_label := OnlineUi.body(blurb, 21, OnlineUi.MUTED)
	blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_label.custom_minimum_size = Vector2(0, 60)
	column.add_child(blurb_label)

	action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(action)

	return card


## The lobby browser sits where the cards are and only comes up once join was
## pressed. It is a list of what is open right now and nothing else
func _build_browser() -> void:
	_browser = VBoxContainer.new()
	_browser.visible = false
	_browser.add_theme_constant_override("separation", 12)
	_layout.add_child(_browser)

	var frame := OnlineUi.panel(OnlineUi.EDGE)
	frame.custom_minimum_size = Vector2(840, 380)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_browser.add_child(frame)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	_lobby_list = VBoxContainer.new()
	_lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_lobby_list)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_browser.add_child(row)

	_refresh_button = OnlineUi.button("REFRESH", 240)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	row.add_child(_refresh_button)

	_cancel_button = OnlineUi.button("CANCEL", 240)
	_cancel_button.pressed.connect(_close_browser)
	UiFeedback.use_back_sound(_cancel_button)
	row.add_child(_cancel_button)

	OnlineUi.link_across(_refresh_button, _cancel_button)


## Brings Steam up and, if it will not come, says why and switches the screen
## off rather than letting somebody press a button that cannot work
func _connect_steam() -> void:
	if Online.connect_to_steam():
		_status.text = "signed in as %s" % Online.steam.persona(Online.steam.id)
		_status.label_settings.font_color = OnlineUi.MUTED
		_host_button.grab_focus()
		return

	_status.text = Online.steam_error()
	_host_button.disabled = true
	_join_button.disabled = true
	_back_button.grab_focus()


func _swap_quip() -> void:
	_quip.text = Quips.pick("online_menu", OnlineQuips.HOST_OR_JOIN)

	var tween := create_tween()
	tween.tween_property(_quip, "modulate:a", 1.0, 0.3).from(0.0)


func _on_host_pressed() -> void:
	if _busy:
		return

	_busy = true
	_status.text = "opening a lobby..."
	Online.host_lobby()


func _on_join_pressed() -> void:
	_cards.visible = false
	_browser.visible = true
	_on_refresh_pressed()


func _close_browser() -> void:
	_browser.visible = false
	_cards.visible = true
	_join_button.grab_focus()


func _on_refresh_pressed() -> void:
	_clear_list()
	_lobby_list.add_child(OnlineUi.body("looking for lobbies...", 22, OnlineUi.MUTED))
	Online.refresh_lobbies()


## One row per open lobby: who is hosting, what they picked and how full it is.
## The whole row is the button, a list of names with a join button beside each
## one is three times the clicking for the same thing
func _on_lobby_list(lobbies: Array) -> void:
	_clear_list()

	if lobbies.is_empty():
		_lobby_list.add_child(OnlineUi.body("nobody is hosting. be the one who does", 22, OnlineUi.MUTED))
		return

	var rows: Array = []

	for lobby: Dictionary in lobbies:
		var row := _build_lobby_row(lobby)
		_lobby_list.add_child(row)
		rows.append(row)

	OnlineUi.link_column(rows)
	OnlineUi.link_down(rows.back() as Control, _refresh_button)
	_refresh_button.focus_neighbor_top = _refresh_button.get_path_to(rows.back() as Control)
	_cancel_button.focus_neighbor_top = _cancel_button.get_path_to(rows.back() as Control)
	rows[0].grab_focus()


## One lobby, built out of parts rather than as one long button caption.
##
## A caption is what decides a button's smallest possible width, and a host with
## a long name and a spelled out ruleset made that wider than the panel it lives
## in — which, with sideways scrolling switched off, simply cut the row off at
## both ends. Laying it out gives the name room to be clipped on its own while
## the count on the right stays where it belongs
func _build_lobby_row(lobby: Dictionary) -> Button:
	var host := String(lobby["host"])
	var title := String(lobby["title"])
	var players := int(lobby["players"])

	var row := OnlineUi.button("")
	row.custom_minimum_size = Vector2(0, 66)
	row.disabled = players >= Online.MAX_PLAYERS
	row.pressed.connect(_on_lobby_picked.bind(int(lobby["id"])))

	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = ROW_PADDING
	line.offset_right = -ROW_PADDING
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 16)
	row.add_child(line)

	var name_label := OnlineUi.body(host.to_upper() if not host.is_empty() else "SOMEBODY", 22)
	name_label.clip_text = true
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)

	var rules := OnlineUi.body(title if not title.is_empty() else "RACE", 20, OnlineUi.MUTED)
	rules.clip_text = true
	rules.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(rules)

	var count := OnlineUi.body("%d / %d" % [players, Online.MAX_PLAYERS], 22, OnlineUi.ACCENT)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.custom_minimum_size = Vector2(90, 0)
	line.add_child(count)

	return row


func _on_lobby_picked(lobby: int) -> void:
	if _busy:
		return

	_busy = true
	_status.text = "knocking..."
	Online.join_lobby(lobby)


func _clear_list() -> void:
	for child in _lobby_list.get_children():
		_lobby_list.remove_child(child)
		child.queue_free()


## A lobby that would not open leaves the screen where it was, with the reason
## under the cards
func _on_lobby_closed(reason: String) -> void:
	_busy = false

	if not reason.is_empty():
		_status.text = reason
		_status.label_settings.font_color = OnlineUi.WAITING


func _on_back_pressed() -> void:
	Transition.change_scene(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	get_viewport().set_input_as_handled()
	UiFeedback.play_back()

	if _browser.visible:
		_close_browser()
	else:
		_on_back_pressed()
