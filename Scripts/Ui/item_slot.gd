extends Control
class_name ItemSlot

## The action the hint under the slot spells out
const USE_ACTION := &"use_item"

## Icon of the item that is currently carried
@export var icon: TextureRect

## Fallback hint, it spells the binding out whenever no prompt icon fits it
@export var hint: Label

## The prompt image of the key or pad button the item is used with
@export var use_icon: TextureRect

## Seconds the icon takes to pop into the slot
@export var pop_duration: float = 0.35

## Radius of the innermost countdown ring, 0 takes it from the size of the
## slot instead
@export var ring_radius: float = 60.0

## Thickness of a ring
@export var ring_width: float = 6.0

## How far apart two rings sit, every running effect gets one of its own
@export var ring_spacing: float = 11.0

## How far outside the slot the innermost ring sits while its radius is on
## automatic
@export var ring_padding: float = 8.0

## Color of the part of the ring that has already run out
@export var ring_background: Color = Color(1, 1, 1, 0.1)

## How much the ring dims on a blink once the effect is nearly over
@export_range(0.0, 1.0) var warning_dim: float = 0.25

## Seconds before the end at which the ring starts blinking
@export var warning_time: float = 5.0

## Blinks per second while the effect runs out
@export var warning_blink_speed: float = 4.0

## How much of its duration each running effect has left, one entry per ring
var ring_progress: Array[float] = []

## The color of every one of those rings, taken from the item it belongs to
var ring_colors: Array[Color] = []

## True while the slot holds an item, the prompt is only up together with it
var _has_item: bool = false

## Which cube this slot draws, -1 for the shared HUD that draws the first one.
## A split screen binds one slot per seat and each of them shows its own pad
var seat: int = -1

## The inventory the slot reads, null while it draws the first seat through the
## item system instead
var _holder: PlayerInventory = null

## Stands in for the effects of a cube that is not in the level right now
var _no_effects: Array[ItemEffect] = []


## Plugging a pad in halfway through a run is normal and so is rebinding the
## key in the options, the prompt follows both instead of being decided once
func _ready() -> void:
	InputIcons.device_changed.connect(_on_device_changed)
	Settings.bindings_changed.connect(_refresh_prompt)

	if seat < 0:
		ItemSystem.item_changed.connect(_on_item_changed)
		_show_item(ItemSystem.held_item)


## Ties this slot to one cube's own inventory. A death rebuilds the cube, so
## this is called again with whatever is standing there now
func bind(holder: PlayerInventory) -> void:
	if _holder == holder:
		return

	if _holder != null and is_instance_valid(_holder) \
			and _holder.item_changed.is_connected(_on_item_changed):
		_holder.item_changed.disconnect(_on_item_changed)

	_holder = holder

	if _holder != null:
		_holder.item_changed.connect(_on_item_changed)
		_show_item(_holder.held_item)
	else:
		_show_item(null)


## Whatever is running on the cube this slot draws
func _effects() -> Array[ItemEffect]:
	if seat < 0:
		return ItemSystem.active_effects

	return _holder.active_effects if _holder != null else _no_effects


## The rings belong to the running effects, not to what sits in the slot. Both
## can differ, a new item can be picked up while older ones are still going
func _process(_delta: float) -> void:
	var was_empty := ring_progress.is_empty()

	ring_progress.clear()
	ring_colors.clear()

	for effect in _effects():
		if not is_instance_valid(effect):
			continue

		ring_progress.append(effect.progress())
		ring_colors.append(_ring_color(effect))

	if not ring_progress.is_empty() or not was_empty:
		queue_redraw()


## Every running effect gets its own ring in the color of its item, so a glance
## says which of them is about to run out. They keep the order they were
## started in, a ring that jumps around would be harder to follow than to read
func _draw() -> void:
	var center := size * 0.5
	var base := ring_radius if ring_radius > 0.0 else minf(size.x, size.y) * 0.5 + ring_padding
	var start := -PI * 0.5

	if ring_progress.is_empty():
		draw_arc(center, base, 0.0, TAU, 64, ring_background, ring_width, true)
		return

	for i in ring_progress.size():
		var radius := base + i * ring_spacing
		draw_arc(center, radius, 0.0, TAU, 64, ring_background, ring_width, true)
		draw_arc(
			center, radius, start, start + TAU * ring_progress[i], 64,
			ring_colors[i], ring_width, true
		)


## Fades on the blink over the last seconds instead of going out completely,
## a ring that vanishes would read as one that is already over
func _ring_color(effect: ItemEffect) -> Color:
	var color := effect.data.accent_color if effect.data != null else Color.WHITE

	if not effect.warning_blink(warning_time, warning_blink_speed):
		color.a *= warning_dim

	return color


func _on_item_changed(item: ItemData) -> void:
	_show_item(item)

	if item != null:
		_pop()


func _show_item(item: ItemData) -> void:
	icon.texture = item.icon if item != null else null
	icon.visible = item != null
	_has_item = item != null
	_refresh_prompt()

	if item == null:
		return

	icon.scale = Vector2.ONE
	icon.modulate = Color(1, 1, 1, 1)


## Same overbright pop the key icon uses, so a fresh item reads at a glance
func _pop() -> void:
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2(0.3, 0.3)
	icon.modulate = Color(4, 4, 4, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE, pop_duration).set_trans(Tween.TRANS_BACK)
	tween.tween_property(icon, "modulate", Color(1, 1, 1, 1), pop_duration).set_trans(Tween.TRANS_EXPO)


func _on_device_changed(_device: int) -> void:
	_refresh_prompt()


## The binding is read straight out of the InputMap, so a key the player
## rebound in the options shows up under the slot without anything else being
## told about it. The text is only there for bindings no icon exists for
func _refresh_prompt() -> void:
	var slot := Seats.slot_of(seat) if seat >= 0 else InputIcons.prompt_slot()
	var event := Settings.get_binding(USE_ACTION, slot)
	var texture := InputIcons.get_seat_action_texture(seat, USE_ACTION) if seat >= 0 \
		else InputIcons.get_event_texture(event)

	use_icon.texture = texture
	use_icon.visible = _has_item and texture != null

	hint.text = InputIcons.get_event_text(event) if event != null else ""
	hint.visible = _has_item and texture == null and not hint.text.is_empty()
