extends Node

## Emitted when a pad of another brand takes over or the player goes back to
## the keyboard, every prompt on screen redraws itself from it
signal device_changed(device: int)

enum Device { KEYBOARD, XBOX, PLAYSTATION, SWITCH, STEAM_DECK, GENERIC }

const ICON_ROOT := "res://Assets/Ui/InputPrompts/"

## A pad we do not recognise gets the Xbox glyphs, that is the layout every
## no name controller on a PC reports itself in
const FOLDERS := {
	Device.KEYBOARD: "Keyboard",
	Device.XBOX: "Xbox",
	Device.PLAYSTATION: "PlayStation",
	Device.SWITCH: "Switch",
	Device.STEAM_DECK: "SteamDeck",
	Device.GENERIC: "Xbox",
}

## Matched against the lowercased driver name, first hit wins, so the more
## specific entries have to come first
const DEVICE_KEYWORDS := [
	["steam deck", Device.STEAM_DECK],
	["steamdeck", Device.STEAM_DECK],
	["playstation", Device.PLAYSTATION],
	["dualsense", Device.PLAYSTATION],
	["dualshock", Device.PLAYSTATION],
	["ps3", Device.PLAYSTATION],
	["ps4", Device.PLAYSTATION],
	["ps5", Device.PLAYSTATION],
	["sony", Device.PLAYSTATION],
	["nintendo", Device.SWITCH],
	["switch", Device.SWITCH],
	["joy-con", Device.SWITCH],
	["joycon", Device.SWITCH],
	["pro controller", Device.SWITCH],
	["xbox", Device.XBOX],
	["xinput", Device.XBOX],
	["x-box", Device.XBOX],
]

## Godot names its pad buttons after the Xbox layout, so on a Switch pad the
## bottom button is called A here but has to be drawn as B
const JOY_BUTTONS := {
	Device.XBOX: {
		JOY_BUTTON_A: "xbox_button_a",
		JOY_BUTTON_B: "xbox_button_b",
		JOY_BUTTON_X: "xbox_button_x",
		JOY_BUTTON_Y: "xbox_button_y",
		JOY_BUTTON_BACK: "xbox_button_view",
		JOY_BUTTON_GUIDE: "xbox_guide",
		JOY_BUTTON_START: "xbox_button_menu",
		JOY_BUTTON_LEFT_STICK: "xbox_stick_l_press",
		JOY_BUTTON_RIGHT_STICK: "xbox_stick_r_press",
		JOY_BUTTON_LEFT_SHOULDER: "xbox_lb",
		JOY_BUTTON_RIGHT_SHOULDER: "xbox_rb",
		JOY_BUTTON_DPAD_UP: "xbox_dpad_up",
		JOY_BUTTON_DPAD_DOWN: "xbox_dpad_down",
		JOY_BUTTON_DPAD_LEFT: "xbox_dpad_left",
		JOY_BUTTON_DPAD_RIGHT: "xbox_dpad_right",
		JOY_BUTTON_MISC1: "xbox_button_share",
	},
	Device.PLAYSTATION: {
		JOY_BUTTON_A: "playstation_button_color_cross",
		JOY_BUTTON_B: "playstation_button_color_circle",
		JOY_BUTTON_X: "playstation_button_color_square",
		JOY_BUTTON_Y: "playstation_button_color_triangle",
		JOY_BUTTON_BACK: "playstation5_button_create",
		JOY_BUTTON_GUIDE: "playstation_button_analog",
		JOY_BUTTON_START: "playstation5_button_options",
		JOY_BUTTON_LEFT_STICK: "playstation_button_l3",
		JOY_BUTTON_RIGHT_STICK: "playstation_button_r3",
		JOY_BUTTON_LEFT_SHOULDER: "playstation_trigger_l1",
		JOY_BUTTON_RIGHT_SHOULDER: "playstation_trigger_r1",
		JOY_BUTTON_DPAD_UP: "playstation_dpad_up",
		JOY_BUTTON_DPAD_DOWN: "playstation_dpad_down",
		JOY_BUTTON_DPAD_LEFT: "playstation_dpad_left",
		JOY_BUTTON_DPAD_RIGHT: "playstation_dpad_right",
		JOY_BUTTON_MISC1: "playstation5_button_mute",
		JOY_BUTTON_TOUCHPAD: "playstation5_touchpad_press",
	},
	Device.SWITCH: {
		JOY_BUTTON_A: "switch_button_b",
		JOY_BUTTON_B: "switch_button_a",
		JOY_BUTTON_X: "switch_button_y",
		JOY_BUTTON_Y: "switch_button_x",
		JOY_BUTTON_BACK: "switch_button_minus",
		JOY_BUTTON_GUIDE: "switch_button_home",
		JOY_BUTTON_START: "switch_button_plus",
		JOY_BUTTON_LEFT_STICK: "switch_stick_l_press",
		JOY_BUTTON_RIGHT_STICK: "switch_stick_r_press",
		JOY_BUTTON_LEFT_SHOULDER: "switch_button_l",
		JOY_BUTTON_RIGHT_SHOULDER: "switch_button_r",
		JOY_BUTTON_DPAD_UP: "switch_dpad_up",
		JOY_BUTTON_DPAD_DOWN: "switch_dpad_down",
		JOY_BUTTON_DPAD_LEFT: "switch_dpad_left",
		JOY_BUTTON_DPAD_RIGHT: "switch_dpad_right",
		JOY_BUTTON_MISC1: "switch_button_sync",
	},
	Device.STEAM_DECK: {
		JOY_BUTTON_A: "steamdeck_button_a",
		JOY_BUTTON_B: "steamdeck_button_b",
		JOY_BUTTON_X: "steamdeck_button_x",
		JOY_BUTTON_Y: "steamdeck_button_y",
		JOY_BUTTON_BACK: "steamdeck_button_view",
		JOY_BUTTON_GUIDE: "steamdeck_button_guide",
		JOY_BUTTON_START: "steamdeck_button_options",
		JOY_BUTTON_LEFT_STICK: "steamdeck_stick_l_press",
		JOY_BUTTON_RIGHT_STICK: "steamdeck_stick_r_press",
		JOY_BUTTON_LEFT_SHOULDER: "steamdeck_button_l1",
		JOY_BUTTON_RIGHT_SHOULDER: "steamdeck_button_r1",
		JOY_BUTTON_DPAD_UP: "steamdeck_dpad_up",
		JOY_BUTTON_DPAD_DOWN: "steamdeck_dpad_down",
		JOY_BUTTON_DPAD_LEFT: "steamdeck_dpad_left",
		JOY_BUTTON_DPAD_RIGHT: "steamdeck_dpad_right",
		JOY_BUTTON_MISC1: "steamdeck_button_quickaccess",
	},
}

## Per axis the icon for the negative and the positive direction, the triggers
## only have one direction and name the same file twice
const JOY_AXES := {
	Device.XBOX: {
		JOY_AXIS_LEFT_X: ["xbox_stick_l_left", "xbox_stick_l_right"],
		JOY_AXIS_LEFT_Y: ["xbox_stick_l_up", "xbox_stick_l_down"],
		JOY_AXIS_RIGHT_X: ["xbox_stick_r_left", "xbox_stick_r_right"],
		JOY_AXIS_RIGHT_Y: ["xbox_stick_r_up", "xbox_stick_r_down"],
		JOY_AXIS_TRIGGER_LEFT: ["xbox_lt", "xbox_lt"],
		JOY_AXIS_TRIGGER_RIGHT: ["xbox_rt", "xbox_rt"],
	},
	Device.PLAYSTATION: {
		JOY_AXIS_LEFT_X: ["playstation_stick_l_left", "playstation_stick_l_right"],
		JOY_AXIS_LEFT_Y: ["playstation_stick_l_up", "playstation_stick_l_down"],
		JOY_AXIS_RIGHT_X: ["playstation_stick_r_left", "playstation_stick_r_right"],
		JOY_AXIS_RIGHT_Y: ["playstation_stick_r_up", "playstation_stick_r_down"],
		JOY_AXIS_TRIGGER_LEFT: ["playstation_trigger_l2", "playstation_trigger_l2"],
		JOY_AXIS_TRIGGER_RIGHT: ["playstation_trigger_r2", "playstation_trigger_r2"],
	},
	Device.SWITCH: {
		JOY_AXIS_LEFT_X: ["switch_stick_l_left", "switch_stick_l_right"],
		JOY_AXIS_LEFT_Y: ["switch_stick_l_up", "switch_stick_l_down"],
		JOY_AXIS_RIGHT_X: ["switch_stick_r_left", "switch_stick_r_right"],
		JOY_AXIS_RIGHT_Y: ["switch_stick_r_up", "switch_stick_r_down"],
		JOY_AXIS_TRIGGER_LEFT: ["switch_button_zl", "switch_button_zl"],
		JOY_AXIS_TRIGGER_RIGHT: ["switch_button_zr", "switch_button_zr"],
	},
	Device.STEAM_DECK: {
		JOY_AXIS_LEFT_X: ["steamdeck_stick_l_left", "steamdeck_stick_l_right"],
		JOY_AXIS_LEFT_Y: ["steamdeck_stick_l_up", "steamdeck_stick_l_down"],
		JOY_AXIS_RIGHT_X: ["steamdeck_stick_r_left", "steamdeck_stick_r_right"],
		JOY_AXIS_RIGHT_Y: ["steamdeck_stick_r_up", "steamdeck_stick_r_down"],
		JOY_AXIS_TRIGGER_LEFT: ["steamdeck_button_l2", "steamdeck_button_l2"],
		JOY_AXIS_TRIGGER_RIGHT: ["steamdeck_button_r2", "steamdeck_button_r2"],
	},
}

const KEY_ICONS := {
	KEY_A: "a", KEY_B: "b", KEY_C: "c", KEY_D: "d", KEY_E: "e", KEY_F: "f",
	KEY_G: "g", KEY_H: "h", KEY_I: "i", KEY_J: "j", KEY_K: "k", KEY_L: "l",
	KEY_M: "m", KEY_N: "n", KEY_O: "o", KEY_P: "p", KEY_Q: "q", KEY_R: "r",
	KEY_S: "s", KEY_T: "t", KEY_U: "u", KEY_V: "v", KEY_W: "w", KEY_X: "x",
	KEY_Y: "y", KEY_Z: "z",
	KEY_0: "0", KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4",
	KEY_5: "5", KEY_6: "6", KEY_7: "7", KEY_8: "8", KEY_9: "9",
	KEY_F1: "f1", KEY_F2: "f2", KEY_F3: "f3", KEY_F4: "f4", KEY_F5: "f5",
	KEY_F6: "f6", KEY_F7: "f7", KEY_F8: "f8", KEY_F9: "f9", KEY_F10: "f10",
	KEY_F11: "f11", KEY_F12: "f12",
	KEY_SPACE: "space",
	KEY_ENTER: "enter",
	KEY_KP_ENTER: "numpad_enter",
	KEY_ESCAPE: "escape",
	KEY_TAB: "tab",
	KEY_SHIFT: "shift",
	KEY_CTRL: "ctrl",
	KEY_ALT: "alt",
	KEY_META: "win",
	KEY_BACKSPACE: "backspace",
	KEY_DELETE: "delete",
	KEY_INSERT: "insert",
	KEY_HOME: "home",
	KEY_END: "end",
	KEY_PAGEUP: "page_up",
	KEY_PAGEDOWN: "page_down",
	KEY_LEFT: "arrow_left",
	KEY_RIGHT: "arrow_right",
	KEY_UP: "arrow_up",
	KEY_DOWN: "arrow_down",
	KEY_CAPSLOCK: "capslock",
	KEY_NUMLOCK: "numlock",
	KEY_SCROLLLOCK: "scroll_lock",
	KEY_PRINT: "printscreen",
	KEY_PAUSE: "pause",
	KEY_PLUS: "plus",
	KEY_KP_ADD: "numpad_plus",
	KEY_MINUS: "minus",
	KEY_EQUAL: "equals",
	KEY_COMMA: "comma",
	KEY_PERIOD: "period",
	KEY_SLASH: "slash_forward",
	KEY_BACKSLASH: "slash_back",
	KEY_SEMICOLON: "semicolon",
	KEY_COLON: "colon",
	KEY_APOSTROPHE: "apostrophe",
	KEY_QUOTEDBL: "quote",
	KEY_QUOTELEFT: "tilde",
	KEY_ASCIITILDE: "tilde",
	KEY_BRACKETLEFT: "bracket_open",
	KEY_BRACKETRIGHT: "bracket_close",
	KEY_LESS: "bracket_less",
	KEY_GREATER: "bracket_greater",
	KEY_ASTERISK: "asterisk",
	KEY_QUESTION: "question",
	KEY_EXCLAM: "exclamation",
	KEY_UNDERSCORE: "underscore",
	KEY_ASCIICIRCUM: "caret",
}

const MOUSE_ICONS := {
	MOUSE_BUTTON_LEFT: "mouse_left",
	MOUSE_BUTTON_RIGHT: "mouse_right",
	MOUSE_BUTTON_MIDDLE: "mouse_scroll",
	MOUSE_BUTTON_WHEEL_UP: "mouse_scroll_up",
	MOUSE_BUTTON_WHEEL_DOWN: "mouse_scroll_down",
	MOUSE_BUTTON_XBUTTON1: "mouse_side_back",
	MOUSE_BUTTON_XBUTTON2: "mouse_side_forward",
}

## The brand whose glyphs are shown for pad prompts, it survives the player
## touching the keyboard so the pad does not have to be re-detected
var pad_device: int = Device.GENERIC

## What the player used last, keyboard prompts and pad prompts are never both
## on screen
var active_device: int = Device.KEYBOARD

## What brand each connected pad is, by its joypad number. The single pad_device
## above is still what a menu draws with — a menu is used by one person at a time
## — but a split screen has a HUD per seat and each of them shows its own pad
var _brand_by_device: Dictionary = {}

var _cache: Dictionary = {}

## The dummy display server of a headless run cannot translate physical keys
var _knows_keyboard_layout: bool = DisplayServer.get_name() != "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_pad()


## Only watches which kind of device is in the player's hands, it never eats an
## event
func _input(event: InputEvent) -> void:
	var device := active_device
	if event is InputEventJoypadButton:
		device = pad_device
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		device = pad_device
	elif event is InputEventKey or event is InputEventMouseButton:
		device = Device.KEYBOARD
	else:
		return

	if device != active_device:
		active_device = device
		device_changed.emit(active_device)


## The icon for that event, drawn in the style of whatever pad is plugged in.
## Null when nothing fits, the caller falls back to the text.
##
## A brand may be named instead, which is what a seat on a split screen does:
## the binding is the one the options hold, only the pad it is drawn as belongs
## to that seat
func get_event_texture(event: InputEvent, brand: int = -1) -> Texture2D:
	if event == null:
		return null

	var pad := pad_device if brand < 0 else brand

	if event is InputEventKey:
		var suffix: String = KEY_ICONS.get(_effective_keycode(event), "")
		return _texture(Device.KEYBOARD, "keyboard_%s" % suffix) if suffix != "" else null

	if event is InputEventMouseButton:
		var mouse: String = MOUSE_ICONS.get(event.button_index, "")
		return _texture(Device.KEYBOARD, mouse) if mouse != "" else null

	if event is InputEventJoypadButton:
		var table: Dictionary = JOY_BUTTONS.get(_glyph_device(pad), {})
		var button: String = table.get(event.button_index, "")
		return _texture(pad, button) if button != "" else null

	if event is InputEventJoypadMotion:
		var axes: Dictionary = JOY_AXES.get(_glyph_device(pad), {})
		var pair: Array = axes.get(event.axis, [])
		if pair.size() != 2:
			return null

		return _texture(pad_device, pair[1] if event.axis_value > 0.0 else pair[0])

	return null


## Short label for an event, used where no icon exists and inside the rebind
## buttons while they wait for input
func get_event_text(event: InputEvent) -> String:
	if event == null:
		return "-"

	if event is InputEventKey:
		return OS.get_keycode_string(_effective_keycode(event))

	if event is InputEventMouseButton:
		return "Mouse %d" % event.button_index

	if event is InputEventJoypadButton:
		return "Button %d" % event.button_index

	if event is InputEventJoypadMotion:
		return "Axis %d%s" % [event.axis, "+" if event.axis_value > 0.0 else "-"]

	return event.as_text()


## Icon of the first event that action has in that slot, for prompts in the HUD
func get_action_texture(action: StringName, slot: int) -> Texture2D:
	return get_event_texture(Settings.get_binding(action, slot))


## Which of the two binding slots a prompt should be read from right now
func prompt_slot() -> int:
	return Settings.SLOT_KEYBOARD if active_device == Device.KEYBOARD else Settings.SLOT_GAMEPAD


## Reads the pad brand again, a controller that was swapped mid session must not
## keep showing the glyphs of the one before it
func _refresh_pad() -> void:
	var detected := Device.GENERIC
	var pads := Input.get_connected_joypads()

	_brand_by_device.clear()
	for pad: int in pads:
		_brand_by_device[pad] = _detect(Input.get_joy_name(pad))

	if not pads.is_empty():
		detected = int(_brand_by_device[pads[0]])

	if detected == pad_device:
		return

	pad_device = detected
	if active_device != Device.KEYBOARD:
		active_device = pad_device

	device_changed.emit(active_device)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_pad()


func _detect(joy_name: String) -> int:
	var lowered := joy_name.to_lower()
	for entry in DEVICE_KEYWORDS:
		if lowered.contains(entry[0]):
			return entry[1]

	return Device.GENERIC


## An unknown pad borrows the Xbox glyph names, its own folder holds no face
## buttons to tell A from B
func _glyph_device(pad: int = -1) -> int:
	var brand := pad_device if pad < 0 else pad
	return Device.XBOX if brand == Device.GENERIC else brand


## What brand that joypad is, for a HUD that has to draw one pad rather than
## whichever one the menus last saw
func brand_of_device(device: int) -> int:
	return int(_brand_by_device.get(device, Device.GENERIC))


## The name the driver reports for that pad, so a seat card can say which one it
## just took rather than only that it took one
func name_of_device(device: int) -> String:
	return Input.get_joy_name(device) if device >= 0 else "Keyboard"


## The glyph that seat should show for an action. The binding is read off the
## base action, so the options stay the one place a binding lives, and only the
## brand is that seat's own
func get_seat_action_texture(seat: int, base: StringName) -> Texture2D:
	var slot := Seats.slot_of(seat)
	var event := Settings.get_binding(base, slot)

	if slot == Settings.SLOT_KEYBOARD:
		return get_event_texture(event)

	return get_event_texture(event, brand_of_device(Seats.device_of(seat)))


## Bindings are stored on the physical key so the layout does not matter for
## playing, but the label has to show what is printed on the player's keyboard
func _effective_keycode(event: InputEventKey) -> int:
	if event.keycode != KEY_NONE:
		return event.keycode

	if event.physical_keycode == KEY_NONE:
		return event.key_label

	if _knows_keyboard_layout:
		return DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)

	return event.physical_keycode


func _texture(device: int, file_name: String) -> Texture2D:
	if file_name.is_empty():
		return null

	var path := "%s%s/%s.png" % [ICON_ROOT, FOLDERS.get(device, "Xbox"), file_name]
	if _cache.has(path):
		return _cache[path]

	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)

	_cache[path] = texture
	return texture
