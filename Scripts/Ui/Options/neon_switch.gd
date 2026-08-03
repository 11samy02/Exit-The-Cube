class_name NeonSwitch
extends BaseButton

## An on/off switch drawn by hand. CheckButton takes its switch graphic from
## Godot's default theme as a texture, which cannot be recoloured, so it always
## looked like a stock control dropped into this menu

const TRACK_SIZE := Vector2(84, 38)

## Gap between the knob and the rim of the track
const KNOB_PADDING := 5.0

const TRACK_OFF := Color(0.078, 0.043, 0.153, 0.9)
const TRACK_ON := Color(0.086, 0.4, 0.51, 0.95)
const BORDER_OFF := Color(0.404, 0.263, 0.784, 0.63)
const BORDER_ON := Color(0.129, 0.855, 1, 0.95)
const FOCUS_BORDER := Color(0.129, 0.855, 1, 1)
const KNOB_OFF := Color(0.616, 0.588, 0.749, 1)
const KNOB_ON := Color(0.851, 0.976, 1, 1)

## Seconds the knob takes to slide across
const SLIDE_DURATION := 0.18

## 0 while off, 1 while on. Everything the switch draws is read off this, so
## the whole thing animates by tweening one number
var _slide: float = 0.0:
	set(value):
		_slide = value
		queue_redraw()

var _track := StyleBoxFlat.new()


## Toggle mode has to be on before anyone sets a state: BaseButton silently
## drops button_pressed while it is off, so a switch built in _ready would
## always come up empty no matter what the setting said
func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = TRACK_SIZE


func _ready() -> void:
	_slide = 1.0 if button_pressed else 0.0

	_track.border_width_left = 2
	_track.border_width_top = 2
	_track.border_width_right = 2
	_track.border_width_bottom = 2

	toggled.connect(_on_toggled)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var radius := size.y * 0.5
	var lit := has_focus() or is_hovered()

	_track.bg_color = TRACK_OFF.lerp(TRACK_ON, _slide)
	_track.border_color = BORDER_OFF.lerp(BORDER_ON, _slide)
	if lit:
		_track.border_color = _track.border_color.lerp(FOCUS_BORDER, 0.65)

	_track.set_corner_radius_all(int(radius))
	draw_style_box(_track, Rect2(Vector2.ZERO, size))

	var knob_radius := radius - KNOB_PADDING
	var travel := size.x - 2.0 * (knob_radius + KNOB_PADDING)
	var center := Vector2(KNOB_PADDING + knob_radius + travel * _slide, radius)

	var halo := maxf(_slide, 0.35 if lit else 0.0)
	if halo > 0.01:
		draw_circle(center, knob_radius + 6.0, Color(BORDER_ON, 0.22 * halo), true, -1.0, true)

	draw_circle(center, knob_radius, KNOB_OFF.lerp(KNOB_ON, _slide), true, -1.0, true)


## Sets the switch without animating or reporting it, for filling the menu in
func set_state(on: bool) -> void:
	set_pressed_no_signal(on)
	_slide = 1.0 if on else 0.0


func _on_toggled(on: bool) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_slide", 1.0 if on else 0.0, SLIDE_DURATION)
