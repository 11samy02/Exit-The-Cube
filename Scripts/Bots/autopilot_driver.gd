class_name AutopilotDriver
extends Node

## What takes a campaign level off the player and plays it out for them.
##
## The cube is not swapped for a CPU one. It is the same cube the player was
## holding a moment ago, in the same corridor, carrying the same key — only the
## hands on it change: a brain writes where it walks instead of the input map,
## and the same brain turns the camera, so what is on screen is somebody playing
## rather than a body sliding around a maze on its own.
##
## And it is playing for real. Nothing here holds the blades off: the cube it
## drives is as easy to cut in half as the one the player was driving, and a CPU
## that walks into a saw bursts like anybody else. What was promised is that the
## level gets finished, not that it gets finished on the first attempt — a death
## rebuilds the map the way it always does and the CPU is put back on the cube
## when it comes up, so it keeps trying until it is out.
##
## A guard was tried first and it was wrong twice over. It read to the blades as
## a shield, so they stopped dead in the corridor instead of killing — a CPU
## walking through a saw with nothing in its hands. And a blade parked against an
## untouchable cube never moved on, so the brain fled something that would never
## leave and stood in the same corridor for the rest of the level

## How often the cube is asked whether it is getting anywhere.
##
## What is asked is how many corridor cells still lie between it and the thing it
## is going for, and the answer only counts as progress when it is the shortest
## that attempt has managed. Ground covered is the wrong question: the way a brain
## fails at a blade it will not walk past is to walk off, come back, and walk off
## again, which covers a great deal of ground and gets nowhere at all
const PROGRESS_EVERY := 3.0

## This many in a row with nothing to show and the cube starts cutting it finer
## around the blades, and this is how much of its margin it keeps.
##
## The first and gentlest of the three answers to getting nowhere. A wide margin
## is what makes the early mazes flawless and what shuts the late ones solid —
## forty patrols and every corridor spoken for on every beat — so rather than
## picking one number that is wrong at one end of the campaign or the other, the
## cube starts careful and gives some of it back only where careful is not moving
const SQUEEZE_AFTER := 3
const SQUEEZE_TO := 0.85

## And this many with nothing to show takes it down to the last of it, the margin
## that is only just wider than the two blades touching.
##
## Two steps rather than one because the far end of it is genuinely fine and
## genuinely uncomfortable, and there is no reason to spend it on a corridor a
## smaller give would have opened. What it buys is the geometry nothing else
## can: a blade circling one block leaves gaps two metres wide and a moment
## long, and a cube that will not cut it that fine has no way past at all
const SQUEEZE_HARD_AFTER := 5

## This many in a row with nothing to show is a corridor the brain will not walk
## into, and it is told to run it instead. That is what a person does at a patrol
## that never quite clears, and it is as dangerous for the cube as it sounds —
## which is the point, it is a run and not a free pass.
##
## Patient on purpose. The rung this drives stands still whenever standing still
## is what gets it through, and half a minute of that at the mouth of a corridor
## swept by something twice its speed is not a cube that is stuck, it is a cube
## waiting for the only gap it is going to get. Sending it in early is sending it
## in to die
const DASH_AFTER := 8
const DASH_FOR := 1.8

## And this many with nothing to show is not a corridor problem. A cube carried
## onto the top of the maze by a leap, or wedged where the corridors say it cannot
## be, has nothing to run at — so the attempt is written off the way any other bad
## attempt is, and the next one starts from the entrance
const GIVE_UP_AFTER := 14

## Seconds the view takes to come round onto a fresh heading.
##
## Long on purpose. The brain changes its mind several times a second — it leans
## around a blade, it holds a beat at a corner, it takes a step back — and a view
## that answered each of those would spend the level swinging. What is wanted is
## the direction the cube is travelling in over the last second or so, which is
## what this comes out as, and the turn rate on the rig then caps how fast even
## that may move the picture
const HEADING_EASE := 0.7

## How much of the top speed the cube has to be asking for before the view
## follows it. Under that it is squeezing past something rather than going
## somewhere, and the camera stays where it was
const HEADING_FLOOR := 0.35

## The cube being driven
var cube: Player = null

var _skill: BotSkill = null
var _brain: BotBrain = null

## Where the view is being turned to, which trails what the feet are doing
var _heading := Vector3.ZERO

## What the cube is walking to, the closest it has come to it in corridor cells,
## how long until the next look, and how many looks in a row came back with no
## improvement at all
var _going_for := Vector2i(-1, -1)
var _best_steps: int = -1
var _progress_left: float = PROGRESS_EVERY
var _stalled_looks: int = 0


## Built onto the cube the same way a bot's brain is, rather than living in the
## player scene: a campaign cube nobody is driving is the rule and this is the
## exception
static func attach_to(player: Player, skill: BotSkill) -> AutopilotDriver:
	var made := AutopilotDriver.new()
	made.name = "Autopilot"
	made.cube = player
	made._skill = skill
	player.add_child(made)
	return made


func _ready() -> void:
	cube.movement.driven = true
	cube.camera_rig.driven = true
	_heading = _flat(-cube.camera_rig.pivot.global_transform.basis.z).normalized()
	_brain = BotBrain.attach_to(cube, _skill, GameState.deaths)

	GameState.elevator_entered.connect(hand_back)


## Turns the view after the feet. Done here rather than in the brain because the
## brain drives bots nobody looks through, and a camera is the one thing this
## cube has that those do not
func _process(delta: float) -> void:
	var drive := _flat(cube.movement.drive)

	if drive.length() >= HEADING_FLOOR:
		_heading = _heading.move_toward(drive.normalized(), delta / HEADING_EASE)

	cube.camera_rig.look_along(_heading, delta)
	_watch_for_progress(delta)


## Watches whether the attempt is still going anywhere, and escalates when it is
## not: first a run at whatever is in the way, then writing the attempt off.
##
## A cube that is dead or still being put together has not stopped, it simply has
## not started, so the clock on it is held rather than run
func _watch_for_progress(delta: float) -> void:
	if cube.death.is_dead or cube.spawn.is_spawning:
		_progress_left = PROGRESS_EVERY
		return

	_progress_left -= delta
	if _progress_left > 0.0:
		return

	_progress_left = PROGRESS_EVERY

	var squad := BotSquad.find(get_tree())
	var target := _objective(squad)
	var steps := _steps_to(squad, target)

	if target != _going_for:
		_going_for = target
		_best_steps = steps
		_stalled_looks = 0
		return

	if steps >= 0 and (_best_steps < 0 or steps < _best_steps):
		_best_steps = steps
		_stalled_looks = 0

		if is_instance_valid(_brain):
			_brain.squeeze(1.0)

		return

	_stalled_looks += 1

	if _stalled_looks >= GIVE_UP_AFTER:
		cube.death.kill(true)
	elif not is_instance_valid(_brain):
		return
	elif _stalled_looks >= DASH_AFTER:
		_brain.dash(DASH_FOR)
	elif _stalled_looks >= SQUEEZE_HARD_AFTER:
		_brain.squeeze(0.0)
	elif _stalled_looks >= SQUEEZE_AFTER:
		_brain.squeeze(SQUEEZE_TO)


## The cell the whole attempt is aimed at: the key while the cube is without one,
## the corridor in front of the way out once it carries it
func _objective(squad: BotSquad) -> Vector2i:
	if squad == null:
		return Vector2i(-1, -1)

	return squad.exit_cell() if GameState.has_key else squad.key_cell()


## Corridor cells between the cube and that cell, -1 when there is no answer yet.
## The level already walked out from both landmarks and keeps the sweep, so this
## costs a lookup rather than a search
func _steps_to(squad: BotSquad, target: Vector2i) -> int:
	if squad == null or squad.map_generator == null or target.x < 0:
		return -1

	var grid := squad.map_generator.grid_map
	var at := grid.local_to_map(grid.to_local(cube.global_position))
	return squad.map_generator.distance_in_field(squad.field_from(target), Vector2i(at.x, at.z))


## Gives the cube and the view back. The doors are shut and the cabin is on its
## way by the time this runs, so there is nothing left to drive — and the ride
## out belongs to whoever sat and watched it be earned
func hand_back() -> void:
	if not is_instance_valid(cube):
		queue_free()
		return

	cube.movement.driven = false
	cube.movement.drive = Vector3.ZERO
	cube.camera_rig.driven = false

	if is_instance_valid(_brain):
		_brain.queue_free()

	queue_free()


## The maze is flat and so is everything that is walked or looked along in it
func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
