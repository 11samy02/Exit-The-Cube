extends Node
class_name FootprintTrail

## A cube that walks through a mark takes the paint with it and puts it back down
## step by step until its underside is clean again. The prints stay on the level
## like the marks do, so the floor tells where the attempts before this one went

## The shader a single print is drawn with
@export var print_shader: Shader

## The Node the trail spawns under, it is emptied before the prints go back up
@export var holder: Node3D

## The marks are asked what color is standing under the cube
@export var blood_spawner: BloodSpawner

## How many prints stay on the floor. Past this the first steps are walked out
## of the level again
@export var max_prints: int = 90

## Meters between two prints
@export var step_distance: float = 0.75

## How many steps one walk through a mark is good for. The paint runs out over
## them, the last print is barely there
@export var steps_per_pickup: int = 12

## Size of a single print in meters
@export var print_size: float = 0.5

## How far a print sits beside the line the cube walked, left and right in turn
@export var side_offset: float = 0.15

## How far a print sits off the floor, enough to stay out of it
@export var surface_offset: float = 0.02

## How much color the oldest print still up has left
@export_range(0.0, 1.0) var oldest_alpha: float = 0.35

var rng := RandomNumberGenerator.new()

## The quad every print is stamped on, one square for all of them
var _print_mesh := QuadMesh.new()

## All prints of the level in one MultiMesh, so the trail is a single draw call
var _trail: MultiMeshInstance3D = null

var _player: CharacterBody3D = null

## The paint still on the underside of the cube and how many steps of it are
## left, an alpha of zero meaning the cube walks clean
var _carried := Color(0, 0, 0, 0)
var _steps_left: int = 0

## Meters walked since the last print went down
var _walked: float = 0.0

## Which side the next print steps out to
var _side: float = 1.0

var _last_position := Vector3.ZERO


func _ready() -> void:
	rng.randomize()
	Settings.splash_changed.connect(spawn_prints)
	spawn_prints()


## Watched from here instead of from the cube, so nothing has to be wired into
## the player scene and a level without a trail simply has no trail
func _physics_process(_delta: float) -> void:
	if not _is_enabled() or not _find_player():
		return

	var position := _player.global_position
	if not _player.is_on_floor():
		_last_position = position
		return

	_pick_up(position)
	_walk(position)
	_last_position = position


## Puts the prints of the attempts before this one back down, called once the
## map stands and again whenever the splatter setting moves
func spawn_prints() -> void:
	var kept := _prints_kept()
	DeathMarks.max_prints = kept
	_clear()

	if not _is_enabled() or kept <= 0:
		return

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = _print_mesh
	multi_mesh.instance_count = kept

	_trail = MultiMeshInstance3D.new()
	_trail.multimesh = multi_mesh
	_trail.material_override = _print_material()
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	holder.add_child(_trail)
	_refill()


## Writes the stored prints into the trail. The MultiMesh is built once at its
## full length and the slots nobody stepped in yet are collapsed to nothing, so
## a new print is a couple of writes instead of a rebuilt node
func _refill() -> void:
	if _trail == null:
		return

	var prints := DeathMarks.prints
	var multi_mesh := _trail.multimesh

	for i in range(multi_mesh.instance_count):
		if i >= prints.size():
			multi_mesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue

		var entry: Dictionary = prints[i]
		multi_mesh.set_instance_transform(i, entry["transform"])
		multi_mesh.set_instance_color(i, _aged(entry["color"], i, prints.size()))


## Steps the cube took while it still had paint on it. The distance is counted
## instead of the animation, a print every so many meters keeps its spacing
## however fast the cube is going
func _walk(position: Vector3) -> void:
	_walked += Vector2(position.x - _last_position.x, position.z - _last_position.z).length()

	while _walked >= step_distance:
		_walked -= step_distance

		if _steps_left <= 0:
			continue

		_stamp(position)
		_steps_left -= 1
		_side = -_side


## Wet paint under the cube reloads it, walking through the same mark again
## fills it back up
func _pick_up(position: Vector3) -> void:
	if blood_spawner == null:
		return

	var ink := blood_spawner.color_at(position)
	if ink.a <= 0.0:
		return

	_carried = ink
	_steps_left = steps_per_pickup


## Lays one print on whatever the cube is standing on. The floor is asked for
## its height instead of the cube, which is somewhere in the middle of its hop
func _stamp(position: Vector3) -> void:
	var ignore: Array[RID] = [_player.get_rid()]
	var space := holder.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.3, position + Vector3.DOWN * 1.6)
	query.collide_with_areas = false
	query.exclude = ignore

	var hit := space.intersect_ray(query)
	if hit.is_empty() or not (hit.collider is GridMap):
		return

	var paint := float(_steps_left) / float(maxi(steps_per_pickup, 1))
	var entry := {
		"transform": _print_transform(hit.position, hit.normal, position),
		"color": Color(_carried.r, _carried.g, _carried.b, paint),
	}

	DeathMarks.add_print(entry)
	_refill()


## The print is turned into the direction the cube is walking and set out to one
## side of that line, so a trail reads as steps and not as a painted stripe
func _print_transform(point: Vector3, surface: Vector3, position: Vector3) -> Transform3D:
	var normal := surface.normalized()
	var heading := position - _last_position
	var forward := heading.slide(normal)
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD.slide(normal)

	forward = forward.normalized()
	var right := forward.cross(normal).normalized()
	var size := print_size * rng.randf_range(0.85, 1.15)
	var basis := Basis(right * size, forward * size, normal)

	return Transform3D(basis, point + normal * surface_offset + right * side_offset * _side)


## One material for the whole trail, a print carries its own color as instance
## data instead of asking for a material of its own
func _print_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = print_shader
	return material


## The paint left on the print, dried down by how far back the print is
func _aged(color: Color, index: int, count: int) -> Color:
	if count <= 1:
		return color

	var age := lerpf(oldest_alpha, 1.0, float(index) / float(count - 1))
	return Color(color.r, color.g, color.b, color.a * age)


## Nothing is put down while the splatter is switched off in the options, a
## trail out of marks that are not drawn would come from nowhere
func _is_enabled() -> bool:
	return print_shader != null and holder != null and Settings.splash_quality > Settings.SPLASH_OFF


## How long a trail the splatter setting lets lie. It rides on the same table as
## the marks, a level that keeps few deaths has no business keeping many steps
func _prints_kept() -> int:
	var quality := clampi(Settings.splash_quality, 0, BloodSpawner.QUALITY_DEATHS.size() - 1)
	return roundi(max_prints * BloodSpawner.QUALITY_DEATHS[quality])


## The cube is replaced on every attempt, so it is looked up again whenever the
## one from before is gone. A fresh cube walks clean
func _find_player() -> bool:
	if _player != null and is_instance_valid(_player):
		return true

	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		return false

	_last_position = _player.global_position
	_walked = 0.0
	_carried = Color(0, 0, 0, 0)
	_steps_left = 0
	return true


func _clear() -> void:
	if _trail != null and is_instance_valid(_trail):
		_trail.queue_free()

	_trail = null
