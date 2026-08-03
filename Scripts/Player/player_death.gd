extends Node
class_name PlayerDeath

## Emitted when a shielded cube broke a blade instead of being cut by it. What
## handed out the shield hears its own use on this and drops right away
signal saw_broken

## The cube that bursts, it is hidden the moment the debris takes over
@export var mesh: MeshInstance3D

## Movement that gets shut off so the wreck stops sliding around
@export var movement: PlayerMovement

## Color script the debris steals the cube color from
@export var player_color: PlayerColor

## The cubes the body is torn into, thrown out into the level
@export var chunks: GPUParticles3D

## Bigger cubes off the same spot, fast enough to overtake the camera and
## swallow the view on their way out
@export var burst: GPUParticles3D

## Short pop of light so the burst reads in the dark corridors
@export var flash: OmniLight3D

@export var death_sound: AudioStreamPlayer3D

## Camera rattle that goes off with the burst
@export var screen_shake: ScreenShake

## How hard the burst hits the camera, one is a full kick
@export var shake_strength: float = 1.0

## Seconds the debris keeps flying before the map is rebuilt
@export var reload_delay: float = 1.8

## How far under the level the cube may get before it counts as gone, in meters.
## A player carried onto the top of the maze can walk off the edge of it, and
## there is nothing out there to land on: without this the attempt would fall
## forever with no way back and no way to end it
@export var fall_death_depth: float = 10.0

## True from the first hit, a second saw cannot kill the player again
var is_dead: bool = false

## What is holding the blades off right now, by whoever claimed it. Two items
## can protect the cube at the same time, and a single flag would let the one
## that ends first drop the protection the other one is still paying for: a
## heart spent on a saw would silently switch the rainbow off
var _guards: Dictionary = {}

## The claims that break a blade rather than only holding it off
var _breakers: Dictionary = {}

## True while anything at all shields the player, blades do nothing then
var is_invulnerable: bool:
	get:
		return not _guards.is_empty()

## True while a shield does not merely hold a blade off but breaks it. The saw
## reads this and takes itself out of the level instead of stalling
var breaks_saws: bool:
	get:
		return not _breakers.is_empty()

## When this cube was put into the level. A death is commented on differently
## when the cube never even got going, and the player is spawned with the map,
## so this node coming up is close enough to the start of the attempt
var _spawned_at: float = 0.0


func _ready() -> void:
	_spawned_at = Time.get_ticks_msec() / 1000.0
	_tint_debris()


## A cube that has fallen out of the level is not coming back, and nothing down
## there will ever touch it. The floor of the maze is the zero line, so anything
## this far under it has left through the side of the map
func _process(_delta: float) -> void:
	if is_dead or movement == null or movement.body == null:
		return

	if movement.body.global_position.y < -fall_death_depth:
		kill(true)


## Puts one claim on the protection up. The same source claiming again only
## refreshes its own share, so an item used twice does not have to be dropped
## twice either
func set_guard(source: StringName, breaks_blades: bool = false) -> void:
	_guards[source] = true

	if breaks_blades:
		_breakers[source] = true
	else:
		_breakers.erase(source)


## Drops that one claim. The cube stays protected for as long as anything else
## is still holding it
func clear_guard(source: StringName) -> void:
	_guards.erase(source)
	_breakers.erase(source)


## The debris is what is left of the cube, so it carries the same color
func _tint_debris() -> void:
	if player_color == null:
		return

	for particles: GPUParticles3D in [chunks, burst]:
		_tint(particles.draw_pass_1 as PrimitiveMesh)


## Recolors one debris mesh, its material is local to the player scene so this
## never bleeds into another cube
func _tint(debris_mesh: PrimitiveMesh) -> void:
	if debris_mesh == null:
		return

	var material := debris_mesh.material as StandardMaterial3D
	if material == null:
		return

	material.albedo_color = player_color.color
	material.emission = player_color.color


## Blows the cube apart, counts the death and puts a fresh map up.
##
## Forced deaths go through whatever is shielding the cube. An item holds the
## blades off, it does not put the floor back under a cube that has fallen out
## of the world, and a protected fall would simply never end
func kill(force: bool = false) -> void:
	if is_dead or (is_invulnerable and not force):
		return

	is_dead = true
	var survived := Time.get_ticks_msec() / 1000.0 - _spawned_at
	_paint_blood()
	mesh.visible = false
	movement.disable()
	chunks.restart()
	burst.restart()
	death_sound.play()
	screen_shake.shake(shake_strength)
	_flash()

	await get_tree().create_timer(reload_delay).timeout
	GameState.add_death()
	Quips.report_death(GameState.deaths, survived)
	Transition.reload_scene()


## Leaves the cube on the walls around that point, in its own color. The map
## keeps the splatter over a reload, so the next attempt runs past it again.
## Called for the burst itself and by whatever else spills the cube open
func splatter(origin: Vector3) -> void:
	var blood := get_tree().get_first_node_in_group("blood_spawner") as BloodSpawner
	if blood == null:
		return

	var color := player_color.color if player_color != null else Color.WHITE
	var body: Array[RID] = [movement.body.get_rid()]
	blood.paint(origin, color, body)


## Called by a blade that lost against the shield. The cube leaves its color on
## the spot and the shield is spent with it, one blade per heart
func break_saw(origin: Vector3) -> void:
	splatter(origin)
	saw_broken.emit()


func _paint_blood() -> void:
	splatter(mesh.global_position + Vector3.UP * 0.1)


## Fades the pop out again, the light itself lives on the player
func _flash() -> void:
	flash.light_energy = 9.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(flash, "light_energy", 0.0, 0.6)
