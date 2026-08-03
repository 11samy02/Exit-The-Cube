extends VBoxContainer

## One slider per bus of the mixer. The list is read from the AudioServer, a bus
## added to the layout later shows up here on its own

const PREVIEW_SOUND := preload("res://Assets/Sounds/UI & Menus/Select.wav")

const DEFAULT_DESCRIPTION := "Let go of a slider and it plays a sound on that bus, so you can set the level by ear instead of by number."

## Names the player should see instead of the bus names from the layout
const BUS_LABELS := {
	"Master": "Master",
	"sfx": "Sound Effects",
	"music": "Music",
	"ambiant": "Ambience",
}

## What each bus actually carries, shown while it is hovered
const BUS_DESCRIPTIONS := {
	"Master": "Everything at once. The panic slider for when someone walks in.",
	"sfx": "Footsteps, saw blades, keys and elevator doors. The half of the sound that is trying to warn you.",
	"music": "The soundtrack. Pull it down if you would rather hear the saw coming than the bassline.",
	"ambiant": "The background hum of the cube. You stop noticing it after a minute, which is exactly the job.",
}

var _preview: AudioStreamPlayer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	set_meta(OptionsUi.DEFAULT_DESCRIPTION_META, DEFAULT_DESCRIPTION)

	_preview = AudioStreamPlayer.new()
	_preview.stream = PREVIEW_SOUND
	add_child(_preview)

	add_child(OptionsUi.make_heading("VOLUME"))
	for i in AudioServer.bus_count:
		_add_bus_row(AudioServer.get_bus_name(i))


func _add_bus_row(bus_name: String) -> void:
	var slider := OptionsUi.make_slider(0.0, 1.0, 0.01, Settings.get_bus_volume(bus_name))
	var readout := OptionsUi.make_readout(_percent(slider.value))

	slider.value_changed.connect(func(value: float) -> void:
		readout.text = _percent(value)
		Settings.set_bus_volume(bus_name, value)
	)
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			_play_preview(bus_name)
	)

	var label: String = BUS_LABELS.get(bus_name, bus_name.capitalize())
	add_child(OptionsUi.make_row(
		label, OptionsUi.make_slider_box(slider, readout), _describe_bus.bind(bus_name, label)
	))


## Silence and full blast both deserve a remark, everything in between gets the
## plain explanation of what the bus carries
func _describe_bus(bus_name: String, label: String) -> String:
	var level := Settings.get_bus_volume(bus_name)

	if level <= 0.001:
		return "%s is muted. Bold choice. Enjoy the silence." % label

	if level >= 0.999:
		return "%s at full blast. %s" % [label, BUS_DESCRIPTIONS.get(bus_name, "")]

	return String(BUS_DESCRIPTIONS.get(bus_name, "Sets how loud this bus plays."))


## Master carries everything, so the preview is played on the bus the player is
## dragging and is heard through their new level
func _play_preview(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		return

	_preview.bus = StringName(bus_name)
	_preview.play()


func _percent(value: float) -> String:
	return "%d %%" % int(round(value * 100.0))
