extends Control

## The rules of a round played on one screen.
##
## The same six settings the online lobby offers, because they are the same
## modes: the rulebook is a resource and neither screen owns any of it. What is
## missing here is everything the lobby has that a room in one place does not
## need — nobody has to be invited, nobody has to be told the rules were changed,
## and there is no host, so every dropdown is simply live

const SEAT_SELECT_SCENE := "res://Scenes/Ui/seat_select.tscn"
const TITLE_SCENE := "res://Scenes/Ui/title_screen.tscn"

## The order the settings are listed in, which is also the order a stick walks
## down them
const RULE_KEYS: Array[String] = [
	"mode", "size", "shape", "difficulty", "teams", "minutes",
	Bots.COUNT_KEY, Bots.SKILL_KEY,
]

## How many settings stand side by side. Eight of them in one column runs off
## the bottom of the screen and takes the START button with it
const COLUMNS := 2

## How wide the panel is, which is what two dropdowns beside each other need
const PANEL_WIDTH := 880.0

const RULE_TITLES := {
	"mode": "GAME MODE",
	"size": "MAP SIZE",
	"shape": "MAP SHAPE",
	"difficulty": "DIFFICULTY",
	"teams": "TEAMS",
	"minutes": "ROUND TIME",
	Bots.COUNT_KEY: "CPU PLAYERS",
	Bots.SKILL_KEY: "CPU SKILL",
}

@onready var _layout: VBoxContainer = %Layout

## What the round will be played under. Nothing writes this but this screen
var _rules: Dictionary = _default_rules()

var _subtitle: Label = null
var _pickers: Dictionary = {}
var _rule_rows: Dictionary = {}
var _random_button: Button = null
var _start_button: Button = null
var _back_button: Button = null
var _seats_line: Label = null
var _leaving: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	add_child(OnlineUi.background())
	move_child(get_child(get_child_count() - 1), 0)

	_build()
	UiFeedback.attach_all(self)
	UiFeedback.use_back_sound(_back_button)
	_show_rules()
	_start_button.grab_focus()


func _build() -> void:
	_layout.add_child(OnlineUi.screen_title("PARTY"))

	_subtitle = OnlineUi.body("", 24, OnlineUi.MUTED)
	_layout.add_child(_subtitle)

	_seats_line = OnlineUi.body(_seats_text(), 22, OnlineUi.ACCENT)
	_layout.add_child(_seats_line)

	_layout.add_child(OnlineUi.gap(22.0))

	var frame := OnlineUi.panel(OnlineUi.EDGE)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_layout.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	frame.add_child(column)

	column.add_child(OnlineUi.heading("RULES", 26, OnlineUi.ACCENT))

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(grid)

	for key in RULE_KEYS:
		_add_rule(grid, key)

	_random_button = OnlineUi.button("SURPRISE US")
	_random_button.pressed.connect(_on_random_pressed)
	column.add_child(_random_button)

	_layout.add_child(OnlineUi.gap(20.0))
	_build_actions()


## One setting as a cell of the grid: its name over its dropdown, the two of
## them one piece so a setting the chosen mode has no use for comes off the
## panel together and the rest close the gap behind it
func _add_rule(grid: GridContainer, key: String) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(cell)

	cell.add_child(OnlineUi.body(String(RULE_TITLES[key]), 19, OnlineUi.MUTED))

	var picker := OnlineUi.choice(_labels_for(key), int(_rules.get(key, 0)), true)
	picker.item_selected.connect(_on_rule_picked.bind(key))
	cell.add_child(picker)

	_pickers[key] = picker
	_rule_rows[key] = [cell]


## The rules a party screen comes up on. The six of the round are the ones both
## screens share, the two about the bots belong to this one alone — nobody is
## brought along to a lobby, the room fills up with the people who joined it
func _default_rules() -> Dictionary:
	var rules := RaceRules.default_settings()
	rules[Bots.COUNT_KEY] = 0
	rules[Bots.SKILL_KEY] = Bots.default_skill()
	return rules


## What that dropdown offers. Only the round's own settings come out of the
## rulebook, the two about the bots are counted against the seats in the room
func _labels_for(key: String) -> Array:
	match key:
		Bots.COUNT_KEY:
			return Bots.count_labels(Seats.count())
		Bots.SKILL_KEY:
			return Bots.skill_labels()

	return RaceRules.labels_for(key)


func _build_actions() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_layout.add_child(row)

	_start_button = OnlineUi.button("START", 300)
	_start_button.pressed.connect(_on_start_pressed)
	row.add_child(_start_button)

	_back_button = OnlineUi.button("BACK", 260)
	_back_button.pressed.connect(_on_back_pressed)
	row.add_child(_back_button)

	OnlineUi.link_row([_start_button, _back_button])
	_wire_rule_focus()


## Rebuilt whenever a setting comes or goes, because the chain has to skip the
## dropdowns the chosen mode has hidden. Walking into one that is not on screen
## looks like the stick has stopped working.
##
## Up and down walk the settings in reading order, left and right step between
## the two that share a row — which is what a grid has to answer for that a
## single column never did
func _wire_rule_focus() -> void:
	if _random_button == null:
		return

	var pickers: Array = []

	for key in RULE_KEYS:
		var picker: OptionButton = _pickers[key]
		if picker.visible:
			pickers.append(picker)

	var chain := pickers.duplicate()
	chain.append(_random_button)
	OnlineUi.link_column(chain)
	_link_rows(pickers)

	for button: Control in [_start_button, _back_button]:
		button.focus_neighbor_top = button.get_path_to(_random_button)

	_random_button.focus_neighbor_bottom = _random_button.get_path_to(_start_button)


## Ties each pair of settings on one row of the grid together sideways
func _link_rows(pickers: Array) -> void:
	for at in range(0, pickers.size() - 1, COLUMNS):
		var left: Control = pickers[at]
		var right: Control = pickers[at + 1]
		left.focus_neighbor_right = left.get_path_to(right)
		right.focus_neighbor_left = right.get_path_to(left)


func _show_rules() -> void:
	_subtitle.text = RaceRules.title_of(_rules)

	for key: String in _pickers:
		var picker: OptionButton = _pickers[key]
		var at := int(_rules.get(key, 0))

		if picker.selected != at:
			picker.selected = at

	_show_rule("teams", RaceRules.is_paint(_rules))
	_show_rule("minutes", RaceRules.is_timed(_rules))
	_show_rule(Bots.SKILL_KEY, _bot_count() > 0)
	_seats_line.text = _seats_text()
	_wire_rule_focus()


## Hides a setting the chosen mode has no use for, label and all. A dropdown
## that does nothing is worse than one that is not there
func _show_rule(key: String, shown: bool) -> void:
	for node: Node in _rule_rows.get(key, []):
		(node as CanvasItem).visible = shown


## Who is in the round: the seats in the room, and whatever the game brings along
func _seats_text() -> String:
	var bots := _bot_count()
	var room := "%d players on one screen" % Seats.count() if Seats.count() > 1 \
		else "one seat taken"

	if bots > 0:
		return "%s  ·  %d in the maze, %d of them cpus" % [room, Seats.count() + bots, bots]

	if Seats.count() <= 1:
		return "one seat taken  ·  go back for somebody else, or bring a cpu"

	return room


## How many bots the round is set to, already cut down to what the room has left
func _bot_count() -> int:
	return Bots.count_in(_rules, Seats.count())


func _on_rule_picked(at: int, key: String) -> void:
	_rules[key] = at
	_show_rules()


func _on_random_pressed() -> void:
	var rolled := RaceRules.all_random()

	for key: String in rolled:
		_rules[key] = int(rolled[key])

	_show_rules()


## Rolls the seed the whole round is built from and opens the maze. Nothing here
## touches Steam, and nothing carries the level: every cube is in the same one
func _on_start_pressed() -> void:
	if _leaving:
		return

	_leaving = true

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	Match.start_party(_rules, rng.randi_range(0, 0x7FFFFFF), Seats.accounts())
	Levels.stop()
	GameState.is_running = false
	GameState.start_run()
	Transition.change_scene(Match.MAP_SCENE)


func _on_back_pressed() -> void:
	if _leaving:
		return

	_leaving = true
	Transition.change_scene(SEAT_SELECT_SCENE)
