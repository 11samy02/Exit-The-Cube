class_name OptionsMenu
extends Control

## The whole options panel. It is a scene on its own so the title screen and a
## later pause menu can both put it up without duplicating anything

## Emitted after the panel closed itself, the screen underneath takes its focus
## back with it
signal closed

## Shown while the pointer is nowhere in particular and the tab has nothing of
## its own to say
const IDLE_DESCRIPTION := "Point at a setting to find out what it does."

@onready var _tabs: TabContainer = %Tabs
@onready var _back_button: Button = %BackButton
@onready var _description: Label = %DescriptionLabel

## The control whose description is on screen right now
var _described: Control = null

## The open dropdown list, watched frame by frame while it is up
var _open_popup: PopupMenu = null

## Entry of that list the pointer sits on, -1 while no list is open. Dropdowns
## describe the entry under the pointer instead of the one that is set
var _preview_index: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(false)
	visible = false
	_back_button.pressed.connect(close)
	_tabs.tab_changed.connect(_on_tab_changed)

	UiFeedback.attach_all(self)
	UiFeedback.use_back_sound(_back_button)

	_wire_descriptions(self)
	Settings.bindings_changed.connect(_refresh_description)
	set_process(false)
	_refresh_description()


## An open dropdown is polled rather than hooked up: PopupMenu only reports the
## entry under the pointer through get_focused_item, its id_focused signal fires
## for arrow keys alone
func _process(_delta: float) -> void:
	if _open_popup == null or not is_instance_valid(_open_popup):
		return

	var hovered := _open_popup.get_focused_item()
	if hovered != _preview_index:
		_preview_index = hovered
		_refresh_description()


## The tab bar itself cannot be reached with a stick, so the shoulder buttons
## page through the tabs instead. ESC and B only get here while no rebind slot
## is armed, an armed slot swallows them first and cancels itself
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		UiFeedback.play_back()
		close()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_page_up"):
		_step_tab(-1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_page_down"):
		_step_tab(1)
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	set_process_unhandled_input(true)
	_tabs.current_tab = 0
	_focus_first_in_tab()


func close() -> void:
	if not visible:
		return

	visible = false
	set_process_unhandled_input(false)
	closed.emit()


## Wraps around, paging past the last tab lands back on the first one
func _step_tab(direction: int) -> void:
	if _tabs.get_tab_count() <= 0:
		return

	_tabs.current_tab = wrapi(_tabs.current_tab + direction, 0, _tabs.get_tab_count())


## A pad has no way to click into the list, so the first setting of the tab is
## handed the focus and the stick walks down from there.
## The frame of waiting is not optional: the tab was only just made visible and
## its rows have no width yet, and the hover animation sizes itself from that
func _focus_first_in_tab() -> void:
	await get_tree().process_frame
	if not visible:
		return

	var page := _tabs.get_current_tab_control()
	var target := _first_focusable(page) if page != null else null
	if target != null:
		target.grab_focus()
	else:
		_back_button.grab_focus()


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE and child.is_visible_in_tree():
			return child

		var found := _first_focusable(child)
		if found != null:
			return found

	return null


func _on_tab_changed(_tab: int) -> void:
	_described = null
	_refresh_description()

	if visible:
		_focus_first_in_tab()


## Every control the tabs hung a description on gets told to report itself when
## the pointer or the focus lands on it. Value changes are picked up too, so a
## line that reacts to the setting updates while the dropdown is still open
func _wire_descriptions(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.has_meta(OptionsUi.DESCRIPTION_META):
			_wire_control(child)

		_wire_descriptions(child)


func _wire_control(control: Control) -> void:
	control.mouse_entered.connect(_on_described_entered.bind(control))
	control.focus_entered.connect(_on_described_entered.bind(control))
	control.mouse_exited.connect(_on_described_exited.bind(control))
	control.focus_exited.connect(_on_described_exited.bind(control))

	if control is OptionButton:
		var dropdown := control as OptionButton
		dropdown.item_selected.connect(func(_index: int) -> void: _refresh_description())

		var popup := dropdown.get_popup()
		popup.about_to_popup.connect(_on_popup_opened.bind(dropdown))
		popup.popup_hide.connect(_on_popup_closed)
	elif control is Range:
		(control as Range).value_changed.connect(func(_value: float) -> void: _refresh_description())
	elif control is BaseButton and (control as BaseButton).toggle_mode:
		(control as BaseButton).toggled.connect(func(_on: bool) -> void: _refresh_description())


func _on_described_entered(control: Control) -> void:
	_described = control
	_refresh_description()


## The pointer leaving does not have to mean nothing is selected, a control the
## pad left focused keeps talking
func _on_described_exited(control: Control) -> void:
	if _described != control:
		return

	var focused := get_viewport().gui_get_focus_owner()
	_described = focused if focused != null and focused.has_meta(OptionsUi.DESCRIPTION_META) else null
	_refresh_description()


## The list belongs to the dropdown that opened it, so the description keeps
## talking about that row while the player walks the entries
func _on_popup_opened(dropdown: OptionButton) -> void:
	_described = dropdown
	_open_popup = dropdown.get_popup()
	_preview_index = _open_popup.get_focused_item()
	set_process(true)
	_refresh_description()


func _on_popup_closed() -> void:
	_open_popup = null
	_preview_index = -1
	set_process(false)
	_refresh_description()


func _refresh_description() -> void:
	if _described == null or not is_instance_valid(_described):
		_description.text = _tab_default()
		return

	_description.text = OptionsUi.resolve_description(
		_described, _described.get_meta(OptionsUi.DESCRIPTION_META), _preview_index
	)


func _tab_default() -> String:
	var page := _tabs.get_current_tab_control()
	var found := _find_default(page) if page != null else ""
	return found if not found.is_empty() else IDLE_DESCRIPTION


func _find_default(node: Node) -> String:
	if node.has_meta(OptionsUi.DEFAULT_DESCRIPTION_META):
		return String(node.get_meta(OptionsUi.DEFAULT_DESCRIPTION_META))

	for child in node.get_children():
		var found := _find_default(child)
		if not found.is_empty():
			return found

	return ""
