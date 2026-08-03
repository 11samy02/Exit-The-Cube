extends Node
class_name GameMusic

## The bed that runs under the whole game
@export var game_track: AudioStream

## Volume that bed settles at, in decibels
@export var game_volume_db: float = -14.0

## Seconds the bed takes to fade up when the game starts
@export var fade_in: float = 2.5

## Seconds a swap between the bed and an item track takes
@export var crossfade: float = 0.7

## Seconds an item track takes to fade out when it is over. Longer than the
## swap on the way in, an effect ending is not a moment that wants a cut
@export var music_fade_out: float = 1.6

## Plays the bed
@export var bed: AudioStreamPlayer

## Plays the track an item brings along, the bed ducks under it
@export var overlay: AudioStreamPlayer

## The crossfade that is currently running, only ever one
var fade: Tween = null

## The item whose track is up right now, null while the bed plays alone
var overriding_item: ItemData = null


## Any item can bring its own track, the music does not know about the cat or
## anything else, it only reads what the item carries
func _ready() -> void:
	ItemSystem.item_used.connect(_on_item_used)
	ItemSystem.effect_finished.connect(_on_effect_finished)
	ItemSystem.effects_cleared.connect(_release_music)
	GameState.elevator_entered.connect(_release_music)
	bed.finished.connect(_loop_bed)
	overlay.finished.connect(_loop_overlay)
	_start_bed()


## Creeps up from silence, music that snaps on at full volume is instantly
## recognisable as a sound file
func _start_bed() -> void:
	if game_track == null:
		return

	bed.stream = game_track
	bed.volume_db = -80.0
	bed.play()
	_swap(game_volume_db, -80.0, false, fade_in)


## Using the same item again only winds its effect back up, restarting its
## track from the top would be heard as a stutter
func _on_item_used(item: ItemData) -> void:
	if item.music == null or item == overriding_item:
		return

	overriding_item = item
	overlay.stream = item.music
	overlay.volume_db = -80.0
	overlay.play()
	_swap(-80.0, item.music_volume_db, false, crossfade)


## Only the item that took the music over may hand it back, an item without a
## track of its own must not cut the one that is playing
func _on_effect_finished(item: ItemData) -> void:
	if item != overriding_item:
		return

	var next := _next_item_with_music()
	if next == null:
		_release_music()
		return

	overriding_item = next
	overlay.stream = next.music
	overlay.play()
	_swap(-80.0, next.music_volume_db, false, crossfade)


## Fades the item track out and the bed back in. Runs when the effect is over,
## when the run ends and the moment the player steps into the elevator, the
## ride up should not be scored by an item that is still ticking down
func _release_music() -> void:
	if overriding_item == null:
		return

	overriding_item = null
	_swap(game_volume_db, -80.0, true, music_fade_out)


## Effects run side by side, so another one may still want the music. The bed
## only comes back once none of them is left
func _next_item_with_music() -> ItemData:
	for effect in ItemSystem.active_effects:
		if is_instance_valid(effect) and effect.data != null and effect.data.music != null:
			return effect.data

	return null


## Every volume change goes through here, and only one of them ever runs. The
## opening fade in is slow enough that an item used during it would otherwise
## be dragged back up by it
func _swap(bed_db: float, overlay_db: float, stop_overlay: bool, duration: float) -> void:
	if fade != null and fade.is_valid():
		fade.kill()

	fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(bed, "volume_db", bed_db, duration)
	fade.tween_property(overlay, "volume_db", overlay_db, duration)

	if stop_overlay:
		fade.chain().tween_callback(overlay.stop)


## Catches tracks that were imported without a loop point, a stream that loops
## on its own never reports itself as finished
func _loop_bed() -> void:
	bed.play()


func _loop_overlay() -> void:
	if overriding_item != null:
		overlay.play()
