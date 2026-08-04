extends Control

## The room everybody waits in. Twelve slots down the left, the rules the host
## is picking down the right, and the ready state of every cube in between.
##
## The host owns the four settings and everybody else reads them. That is not a
## rule this screen enforces, it is simply what the lobby data is: the host is
## the only account Steam lets write it, so a member's dropdowns are shown as
## disabled rather than pretending they would do something

const TITLE_SCENE := "res://Scenes/Ui/title_screen.tscn"

## How often the whole panel is rebuilt off Steam even without a callback. A
## dropped update would otherwise leave somebody looking at a stale ready count
const REFRESH_INTERVAL := 1.0

## How often the line under the title rolls over
const QUIP_INTERVAL := 9.0

## Seconds between the room going green and the maze opening. Long enough to
## notice and to take it back, short enough that nobody waits on it
const START_COUNTDOWN := 3.0

@onready var _layout: VBoxContainer = %Layout

var _subtitle: Label = null
var _quip: Label = null
var _slots: VBoxContainer = null
var _ready_count: Label = null
var _pickers: Dictionary = {}
var _random_button: Button = null
var _countdown: Label = null

## Seconds left before the race starts itself, negative while the room is not
## green. Reset the moment anybody unreadies
var _starting_in: float = -1.0
var _friends_root: Control = null
var _friends_list: VBoxContainer = null
var _friends_note: Label = null
var _friends_close: Button = null
var _action_button: Button = null
var _invite_button: Button = null
var _leave_button: Button = null

var _refresh_timer: float = 0.0
var _quip_timer: float = QUIP_INTERVAL

## True from the moment the lobby is being left, nothing here reacts after that
var _leaving: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	add_child(OnlineUi.background())
	move_child(get_child(get_child_count() - 1), 0)

	_build()
	_build_friends()
	Online.lobby_updated.connect(_show_lobby)
	Online.lobby_closed.connect(_on_lobby_closed)
	_show_lobby()
	_action_button.grab_focus()


## The list the invite button falls back on. Steam's own invite window is only
## in the process when the game was started through Steam, and a build handed to
## a friend over a link never is — so the game carries its own
func _build_friends() -> void:
	_friends_root = Control.new()
	_friends_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_friends_root.visible = false
	add_child(_friends_root)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_friends_root.add_child(shade)

	var frame := OnlineUi.panel(OnlineUi.EDGE, 0.95)
	frame.custom_minimum_size = Vector2(760, 640)
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_friends_root.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)

	var title := OnlineUi.heading("INVITE FRIENDS", 32, OnlineUi.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_friends_note = OnlineUi.body("", 20, OnlineUi.MUTED)
	_friends_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_friends_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_friends_note)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_friends_list = VBoxContainer.new()
	_friends_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_friends_list)

	_friends_close = OnlineUi.button("CLOSE", 260)
	_friends_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_friends_close.pressed.connect(_close_friends)
	UiFeedback.use_back_sound(_friends_close)
	column.add_child(_friends_close)


func _process(delta: float) -> void:
	if _leaving:
		return

	_tick_start(delta)

	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_show_lobby()

	_quip_timer -= delta
	if _quip_timer <= 0.0:
		_quip_timer = QUIP_INTERVAL
		_swap_quip()


func _build() -> void:
	_layout.add_child(OnlineUi.screen_title("LOBBY"))

	_subtitle = OnlineUi.body("", 26, OnlineUi.ACCENT)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout.add_child(_subtitle)

	_quip = OnlineUi.body("", 22, OnlineUi.MUTED)
	_quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout.add_child(_quip)

	_layout.add_child(OnlineUi.gap(26))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 30)
	_layout.add_child(columns)

	columns.add_child(_build_players())
	columns.add_child(_build_rules())

	_layout.add_child(OnlineUi.gap(14))

	_countdown = OnlineUi.body("", 24, OnlineUi.READY)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout.add_child(_countdown)

	_layout.add_child(OnlineUi.gap(10))
	_build_actions()
	_swap_quip()


## One slot per seat, filled or not. Showing the empty ones is the point: a
## lobby that only lists who turned up says nothing about how many more fit
func _build_players() -> Control:
	var frame := OnlineUi.panel(OnlineUi.EDGE)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.15

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(OnlineUi.heading("PLAYERS", 26, OnlineUi.ACCENT))
	header.add_child(OnlineUi.stretch())

	_ready_count = OnlineUi.body("", 22, OnlineUi.MUTED)
	header.add_child(_ready_count)

	column.add_child(OnlineUi.gap(6))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_slots = VBoxContainer.new()
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.add_theme_constant_override("separation", 8)
	scroll.add_child(_slots)

	return frame


## The four settings the race is run under, the host's to pick
func _build_rules() -> Control:
	var frame := OnlineUi.panel(OnlineUi.EDGE)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)

	column.add_child(OnlineUi.heading("RULES", 26, OnlineUi.ACCENT))
	column.add_child(OnlineUi.gap(6))

	_add_rule(column, "mode", "GAME MODE")
	_add_rule(column, "size", "MAP SIZE")
	_add_rule(column, "shape", "MAP SHAPE")
	_add_rule(column, "difficulty", "DIFFICULTY")

	column.add_child(OnlineUi.gap(4))
	_random_button = OnlineUi.button("SURPRISE US")
	_random_button.pressed.connect(_on_random_pressed)
	column.add_child(_random_button)

	return frame


func _add_rule(column: VBoxContainer, key: String, title: String) -> void:
	column.add_child(OnlineUi.body(title, 20, OnlineUi.MUTED))

	var picker := OnlineUi.choice(RaceRules.labels_for(key), int(Online.settings.get(key, 0)), \
		Online.is_host)
	picker.item_selected.connect(_on_rule_picked.bind(key))
	column.add_child(picker)
	column.add_child(OnlineUi.gap(6))
	_pickers[key] = picker


func _build_actions() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_layout.add_child(row)

	_invite_button = OnlineUi.button("INVITE FRIENDS", 300)
	_invite_button.pressed.connect(_on_invite_pressed)
	row.add_child(_invite_button)

	_action_button = OnlineUi.button("READY", 300)
	_action_button.pressed.connect(_on_action_pressed)
	row.add_child(_action_button)

	_leave_button = OnlineUi.button("LEAVE", 260)
	_leave_button.pressed.connect(_on_leave_pressed)
	UiFeedback.use_back_sound(_leave_button)
	row.add_child(_leave_button)

	_wire_focus()


## The lobby is a row of three buttons with the four rule dropdowns standing
## above them in their own column. Up off the buttons walks into the rules from
## the bottom, so the host can reach every setting without a mouse; a member's
## dropdowns take no focus at all and up simply stays where it is
func _wire_focus() -> void:
	OnlineUi.link_row([_invite_button, _action_button, _leave_button])

	var pickers: Array = []
	for key: String in ["mode", "size", "shape", "difficulty"]:
		pickers.append(_pickers[key])

	pickers.append(_random_button)
	OnlineUi.link_column(pickers)

	for button: Control in [_invite_button, _action_button, _leave_button]:
		button.focus_neighbor_top = button.get_path_to(_random_button)

	_random_button.focus_neighbor_bottom = _random_button.get_path_to(_action_button)


## Everything on the screen comes from one place, so a callback, a timer tick
## and a button press can all simply call this
func _show_lobby() -> void:
	if _leaving:
		return

	_subtitle.text = RaceRules.title_of(Online.settings)
	_show_rules()
	_show_slots()
	_show_action()


func _show_rules() -> void:
	for key: String in _pickers:
		var picker: OptionButton = _pickers[key]
		var at := int(Online.settings.get(key, 0))

		picker.disabled = not Online.is_host
		picker.focus_mode = Control.FOCUS_ALL if Online.is_host else Control.FOCUS_NONE

		if picker.selected != at:
			picker.selected = at

	_random_button.disabled = not Online.is_host


func _show_slots() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()

	for at in range(Online.MAX_PLAYERS):
		if at < Online.members.size():
			_slots.add_child(_build_slot(Online.members[at]))
		else:
			_slots.add_child(_build_empty_slot(at))

	var ready_now := 0
	for member in Online.members:
		if bool(member["ready"]):
			ready_now += 1

	_ready_count.text = "%d / %d READY" % [ready_now, Online.members.size()]


## One taken seat. The dot on the left is the color that cube's ghost runs
## around in, so the lobby already teaches who is who before the race starts
func _build_slot(member: Dictionary) -> Control:
	var is_ready := bool(member["ready"])
	var frame := OnlineUi.panel(OnlineUi.READY if is_ready else OnlineUi.EDGE, 0.4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	frame.add_child(row)

	row.add_child(_build_dot(GhostField.ghost_color(int(member["id"]))))

	var name_label := OnlineUi.body(String(member["name"]).to_upper(), 24, OnlineUi.TEXT)
	row.add_child(name_label)

	if bool(member["host"]):
		row.add_child(OnlineUi.body("HOST", 18, OnlineUi.ACCENT))

	if int(member["id"]) == Online.steam.id:
		row.add_child(OnlineUi.body("YOU", 18, OnlineUi.MUTED))

	row.add_child(OnlineUi.stretch())
	row.add_child(OnlineUi.body("READY" if is_ready else "WAITING", 20, \
		OnlineUi.READY if is_ready else OnlineUi.WAITING))

	return frame


func _build_empty_slot(at: int) -> Control:
	var frame := OnlineUi.panel(Color(OnlineUi.MUTED, 0.35), 0.2)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	frame.add_child(row)

	row.add_child(_build_dot(Color(OnlineUi.MUTED, 0.3)))
	row.add_child(OnlineUi.body("SEAT %02d" % (at + 1), 22, Color(OnlineUi.MUTED, 0.5)))
	row.add_child(OnlineUi.stretch())
	row.add_child(OnlineUi.body("OPEN", 20, Color(OnlineUi.MUTED, 0.5)))

	return frame


func _build_dot(color: Color) -> Control:
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot


## Everybody gets the same button, the host included. Nobody presses start any
## more — the room going green is what starts the race
func _show_action() -> void:
	_invite_button.visible = Online.in_lobby()
	_action_button.disabled = false
	_action_button.text = "NOT READY" if Online.is_ready() else "READY"


func _on_action_pressed() -> void:
	if _leaving:
		return

	Online.set_ready(not Online.is_ready())
	_show_lobby()


## Counts the room down once everybody is green and calls it off the moment
## anybody changes their mind. Starting on the instant the last light comes on
## reads as the game deciding for itself, and leaves nobody a second to take it
## back — so the countdown is the warning, not a formality.
##
## Only the host actually starts it. Everyone sees the same number because
## everybody has the same list in front of them, but the lobby data is the host's
## to write and the race begins when that number lands
func _tick_start(delta: float) -> void:
	if not Online.in_lobby() or not Online.everyone_ready():
		if _starting_in >= 0.0:
			_starting_in = -1.0
			_countdown.text = ""
		return

	if _starting_in < 0.0:
		_starting_in = START_COUNTDOWN

	_starting_in -= delta
	_countdown.text = "ALL READY  ·  STARTING IN %d" % maxi(ceili(_starting_in), 0)

	if _starting_in <= 0.0 and Online.is_host:
		_starting_in = START_COUNTDOWN
		Online.start_race()


## Steam's own invite window is the nicer one where it exists, so it is asked
## first and the game's own list is only put up when it does not
func _on_invite_pressed() -> void:
	if Online.invite_friends():
		return

	_open_friends()


func _open_friends() -> void:
	var friends := Online.friend_list()

	for child in _friends_list.get_children():
		_friends_list.remove_child(child)
		child.queue_free()

	_friends_note.text = "steam's own invite window only exists when the game was started " \
		+ "through steam. here is the list instead"

	if friends.is_empty():
		_friends_note.text = "steam handed over no friends list at all"

	var rows: Array = []

	for friend: Dictionary in friends:
		rows.append(_add_friend_row(friend))

	OnlineUi.link_column(rows)

	if not rows.is_empty():
		OnlineUi.link_down(rows.back() as Control, _friends_close)
		_friends_close.focus_neighbor_top = _friends_close.get_path_to(rows.back() as Control)

	_friends_root.visible = true

	if rows.is_empty():
		_friends_close.grab_focus()
	else:
		rows[0].grab_focus()


## One friend: a dot for whether they are signed in, the name, and the button.
## Hands the button back so the panel can walk a pad down the list — the row
## around it is a frame and takes no focus of its own.
##
## The button says what happened after it was pressed rather than going quiet. An
## invite leaves no trace in this window otherwise, and nobody can tell a sent one
## from a missed click
func _add_friend_row(friend: Dictionary) -> Button:
	var online := bool(friend["online"])
	var frame := OnlineUi.panel(OnlineUi.READY if online else Color(OnlineUi.MUTED, 0.3), 0.35)
	_friends_list.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	frame.add_child(row)

	row.add_child(_build_dot(OnlineUi.READY if online else Color(OnlineUi.MUTED, 0.4)))
	row.add_child(OnlineUi.body(String(friend["name"]), 22, \
		OnlineUi.TEXT if online else Color(OnlineUi.MUTED, 0.7)))
	row.add_child(OnlineUi.stretch())

	var invite := OnlineUi.button("INVITE", 180)
	invite.pressed.connect(_on_friend_invited.bind(int(friend["id"]), invite))
	row.add_child(invite)

	return invite


func _on_friend_invited(friend: int, button: Button) -> void:
	Online.invite_friend(friend)
	button.text = "SENT"
	button.disabled = true


func _close_friends() -> void:
	_friends_root.visible = false
	_invite_button.grab_focus()


func _on_rule_picked(at: int, key: String) -> void:
	Online.set_setting(key, at)
	_show_lobby()


## Hands every rule that may be rolled over to the dice at once. Nothing is
## decided here — the roll happens when the race starts, off the seed the whole
## lobby shares, so the room finds out together
func _on_random_pressed() -> void:
	var rolled := RaceRules.all_random()

	for key: String in rolled:
		Online.set_setting(key, int(rolled[key]))

	_show_lobby()


## The line under the title says something different to the host, to a member,
## and to a room that is only waiting on somebody to press start
func _swap_quip() -> void:
	var pool := OnlineQuips.LOBBY_WAITING

	if Online.everyone_ready() and Online.members.size() > 1:
		pool = OnlineQuips.LOBBY_ALL_READY
	elif not Online.is_host:
		pool = OnlineQuips.LOBBY_MEMBER

	_quip.text = Quips.pick("online_lobby", pool)


func _on_leave_pressed() -> void:
	if _leaving:
		return

	_leaving = true
	Online.leave_lobby()
	Transition.change_scene(TITLE_SCENE)


## The lobby went away under this screen, which is what happens when the host
## closes the game. There is nothing left to look at
func _on_lobby_closed(_reason: String) -> void:
	if _leaving:
		return

	_leaving = true
	Transition.change_scene(TITLE_SCENE)


## Back steps out of the friends list first and only leaves the lobby once there
## is nothing left on top of it
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	get_viewport().set_input_as_handled()
	UiFeedback.play_back()

	if _friends_root.visible:
		_close_friends()
	else:
		_on_leave_pressed()
