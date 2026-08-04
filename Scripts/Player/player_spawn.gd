extends Node
class_name PlayerSpawn

## Builds the cube out of a swarm of debris at the start of a level, the exact
## opposite of what the death does to it. Everything in here is skipped when the
## player switched the animation off in the options

## The cube that materialises, hidden until the swarm has closed in
@export var mesh: MeshInstance3D

## Movement that is held back until the cube stands on the floor
@export var movement: PlayerMovement

## Animation that would fight this script over the mesh pose, off until landing
@export var animator: PlayerAnimator

## Color script the swarm and the dust steal the cube color from
@export var player_color: PlayerColor

## Death that is switched off for the drop, a blade under the spawn point would
## otherwise kill a cube that cannot move yet
@export var death: PlayerDeath

## Debris that flies in from all sides and puts the cube together
@export var swarm: GPUParticles3D

## Kicked up the moment the cube hits the floor
@export var dust: GPUParticles3D

## Pop of light the mesh is switched on behind
@export var light: OmniLight3D

@export var spawn_sound: AudioStreamPlayer3D

## Camera rig that is turned towards open space before anything is shown
@export var camera_rig: PlayerCamera

## Camera kick on the landing
@export var screen_shake: ScreenShake

## Seconds the swarm flies before the cube snaps into place
@export var gather_duration: float = 0.55

## Seconds the cube takes to grow out of nothing
@export var form_duration: float = 0.35

## Turns the cube spins while it forms
@export var form_spins: float = 2.0

## Brightest the light gets while the swarm closes in
@export var light_energy: float = 7.0

## How hard the landing hits the camera, one is a full kick
@export var landing_shake: float = 0.35

## The cube is handed over anyway once the drop took this long, a spawn point
## over a hole would otherwise leave the player frozen forever
@export var fall_timeout: float = 3.0

## True while the cube is still being built, the input is dead for as long
var is_spawning: bool = false


func _ready() -> void:
	if Settings.spawn_animation:
		_hold()

	_run()


## Puts the cube back after a death that did not tear the level down, which is
## how a round that has to keep running handles one. The body is carried back to
## where it came in and the whole entrance is played again from there, so a
## respawn looks like a spawn rather than a cube blinking back into a corridor
func respawn() -> void:
	var spawner := get_tree().get_first_node_in_group("player_spawner") as PlayerSpawner
	var body := movement.body

	if spawner != null and not spawner.spawn_points.is_empty():
		body.global_position = spawner.cell_to_world(spawner.spawn_points[0])

	body.velocity = Vector3.ZERO
	mesh.scale = Vector3.ONE

	var field := get_tree().get_first_node_in_group(PaintField.GROUP) as PaintField
	if field != null:
		field.forget_last_cell()

	if Settings.spawn_animation:
		_hold()
	else:
		mesh.visible = true
		movement.input_enabled = true
		movement.set_physics_process(true)
		animator.set_process(true)

	_run()


## Takes the cube out of the level before anything can be seen of it, the body
## keeps hanging in the air until the swarm has delivered it
func _hold() -> void:
	is_spawning = true
	mesh.visible = false
	movement.input_enabled = false
	movement.set_physics_process(false)
	animator.set_process(false)
	death.set_guard(&"spawn")
	_tint(swarm)
	_tint(dust)


## The whole entrance in order. The two physics frames of waiting are not
## optional: the spawner places the player right after it added it to the tree,
## and the GridMap only hands its walls to the physics server a step later. Ask
## any earlier and the camera is told the maze is empty. The view is turned
## either way, a level that starts with the camera in a wall is no better
## without the animation
func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return

	camera_rig.aim_at_clearest()

	if not is_spawning:
		return

	swarm.restart()
	spawn_sound.play()
	_glow()

	await get_tree().create_timer(gather_duration).timeout
	if not is_inside_tree():
		return

	await _form()
	movement.set_physics_process(true)

	await _fall()
	if not is_inside_tree():
		return

	movement.input_enabled = true
	death.clear_guard(&"spawn")
	is_spawning = false
	await _impact()
	animator.set_process(true)


## Grows the cube out of the point the debris ran into, spinning down to a stop
func _form() -> void:
	mesh.visible = true
	mesh.scale = Vector3.ZERO
	mesh.rotation = Vector3(0.0, TAU * form_spins, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "scale", Vector3.ONE, form_duration).set_trans(Tween.TRANS_BACK)
	tween.tween_property(mesh, "rotation", Vector3.ZERO, form_duration).set_trans(Tween.TRANS_EXPO)
	await tween.finished


## Waits for the drop onto the floor. The timeout is what keeps a spawn point
## with nothing under it from holding the run hostage
func _fall() -> void:
	var waited := 0.0
	while waited < fall_timeout:
		await get_tree().physics_frame
		if not is_inside_tree():
			return

		waited += get_physics_process_delta_time()
		if movement.body.is_on_floor():
			return


## Squash on touchdown, the dust and the camera go off with it
func _impact() -> void:
	dust.restart()
	screen_shake.shake(landing_shake)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "scale", Vector3(1.35, 0.55, 1.35), 0.07).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)
	await tween.finished


## Swells while the debris is on its way in and is gone again right after the
## cube took its place
func _glow() -> void:
	light.light_color = player_color.color
	light.light_energy = 0.0

	var tween := create_tween()
	tween.tween_property(light, "light_energy", light_energy, gather_duration).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(light, "light_energy", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)


## The debris is what the cube is built from, so it carries the same color. The
## material is local to the player scene, this never bleeds into another cube
func _tint(particles: GPUParticles3D) -> void:
	var debris_mesh := particles.draw_pass_1 as PrimitiveMesh
	if debris_mesh == null:
		return

	var material := debris_mesh.material as StandardMaterial3D
	if material == null:
		return

	material.albedo_color = player_color.color
	material.emission = player_color.color
