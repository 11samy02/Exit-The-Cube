extends Node
class_name BloodSpawner

## The six sides of a cell, a face is a side with nothing behind it
const SIDES: Array[Vector3i] = [
	Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT,
	Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
]

## How often a sight check may step past something that is not the map before
## it gives up and lets the face through
const SIGHT_ATTEMPTS := 4

## How far off the aimed at face a sight check may land and still count as clear
const SIGHT_TOLERANCE := 0.35

## How much of a mark counts as wet paint underfoot. The outline wanders, so
## picking the color up over the whole ball would hand it out beside the mark
const PICKUP_REACH := 0.75

## What the splatter setting in the graphics options does to the ink, one entry
## per quality from off to high.
##
## The first is how many deaths stay up. The second is only a brake, a mark
## needs well under the lowest budget unless the burst happened in a hall.
##
## The third is what the eye actually notices. At 0 the paint lies flat: no
## relief, so no glint either, no thrown droplets and no swell over the surface.
## From 1 it is the full look, and past 1 the outline gets a second finer octave
## torn into it on top of more droplets
const QUALITY_DEATHS: Array[float] = [0.0, 0.4, 1.0, 1.6]
const QUALITY_FACES: Array[float] = [0.0, 0.55, 1.0, 1.4]
const QUALITY_DETAIL: Array[float] = [0.0, 0.0, 1.0, 1.6]

## The shader the ink is drawn with. Every death builds its own material off it
## and gets the settings below written into that one
@export var ink_shader: Shader

## The Node every mark spawns under, it is emptied before the marks go back up
@export var holder: Node3D

## How many deaths stay on the map at once. The newest one is always fresh, the
## ones before it dry down step by step toward Oldest Alpha. 0 keeps the level
## clean of ink.
##
## This is the count at the Medium splatter setting, the graphics options scale
## it: Low shows fewer, High more, Off none at all
@export var visible_deaths: int = 10

@export_group("Spread")

## Radius of the whole mark in meters, measured from the point the cube burst
## in. This is the size of the one shape every painted face shows a part of, not
## the size of a single splash
@export var ink_radius: float = 1.5

## How much the size may wander from one death to the next. 0 makes every mark
## the same size, 0.5 lets one come out half as big and the next half again as
## big. Nothing else has to be told about it, a mark carries the size it was
## sprayed at for as long as it is up
@export_range(0.0, 0.9) var radius_variation: float = 0.32

## Extra meters of map that are still checked for surfaces past that radius. The
## outline wanders and single blobs land clear of the pool, this is the room they
## are given. Too little cuts those blobs off in the middle
@export var reach_margin: float = 1.4

## Ceiling on the faces one death may paint. A burst in an open hall would
## otherwise cover half the level and cost accordingly. The faces nearest the
## burst are kept, so the cut runs along the outside of the mark.
##
## Like the count above this is the Medium value, the splatter setting in the
## graphics options scales it
@export var max_faces: int = 128

## How far a painted face sits off the surface it belongs to, in meters. Enough
## to stay out of it, little enough not to float over it
@export var surface_offset: float = 0.02

## Seconds the fresh ink takes to run out from the burst to its full size
@export var spread_duration: float = 0.4

## How much color the oldest mark still up has left. 1 keeps every death as loud
## as the newest one, 0 leaves the oldest as a black stain
@export_range(0.0, 1.0) var oldest_alpha: float = 0.35

@export_group("Shape")

## How hard the outline is pushed around. 0 leaves a clean ball of paint, 1
## tears it into a ragged splash
@export_range(0.0, 1.0) var edge_noise: float = 0.42

## How far the ink is pulled downward, as if it had run before it dried. 0 keeps
## the shape centered on the burst, higher hangs it down the wall
@export_range(0.0, 0.8) var sag: float = 0.3

## Single blobs thrown clear of the main pool. They only show up where a surface
## happens to pass through them, so not every one of them lands
@export_range(0, 12) var droplets: int = 6

@export_group("Body")

## How thick the paint reads, in meters. Nothing is actually raised off the
## wall, this is only the height the light is bent over, but it is what makes a
## mark look poured on instead of printed on
@export_range(0.0, 0.3) var ink_thickness: float = 0.07

## Width of the rounded bead running along the outline, in meters. Narrow gives
## a sharp lip with a hard glint on it, wide gives a soft mound. The strongest
## handle on the character of the paint
@export_range(0.02, 1.5) var bead_width: float = 0.18

## A slow swell over the surface, the paint did not dry as a level sheet. 0
## makes it glass. This feeds the height the relief is built from, so turning it
## up is body, not grain
@export_range(0.0, 1.0) var surface_detail: float = 0.25

## How fine that swell is. Low is a lazy wave across the whole mark, high packs
## it into grain and starts to flicker in the highlights
@export_range(0.5, 20.0) var detail_scale: float = 3.0

## Multiplies the whole relief. Past 1 the paint reads thicker than it is, the
## quickest way to more or less body without touching anything else
@export_range(0.0, 8.0) var bump_strength: float = 1.6

@export_group("Shading")

## The direction the ink lights itself from, on top of whatever the level does.
## Without it the body of the paint goes flat in a corridor with no lamp in it
@export var shade_direction: Vector3 = Vector3(0.35, 1.0, 0.25)

## How deep that light cuts. 0 lights the ink evenly and flat, 1 drives the
## sides facing away from it all the way down to black
@export_range(0.0, 1.0) var shade_depth: float = 0.55

## Strength of the wet glint sitting on the bead. It only lands where the paint
## curves, over the flat middle there is nothing for it to catch
@export_range(0.0, 4.0) var gloss: float = 0.7

## How tight that glint is. Low smears it around the mound, high pulls it into a
## small hard spot
@export_range(2.0, 128.0) var gloss_sharpness: float = 40.0

@export_group("Color")

## How much brighter the thin outline burns than the middle of the pool
@export_range(0.0, 6.0) var rim_boost: float = 1.8

## How hard the ink glows in its own color, this is what the bloom of the level
## picks up
@export_range(0.0, 4.0) var emission_strength: float = 0.85

## How far a fully dried mark is pulled toward black. 0 keeps the oldest deaths
## as bright as the fresh one
@export_range(0.0, 1.0) var aged_darkness: float = 0.7

var rng := RandomNumberGenerator.new()

## The face every quad is cut from, one unit square scaled by its own transform
var _face_mesh := QuadMesh.new()

## One MultiMeshInstance3D per death, oldest first. A death is a single draw
## call that way, however many faces it ended up painting
var _marks: Array[MultiMeshInstance3D] = []


## Nothing here draws a mark the same way twice, so the generator is opened on
## its own value. The graphics options are watched from here as well, a splatter
## setting that only shows after the next death would read as broken
func _ready() -> void:
	rng.randomize()
	Settings.splash_changed.connect(spawn_marks)


## Puts the ink of the attempts before this one back up, called once the map
## stands and again whenever the splatter setting moves. The limit goes over to
## the store first, what is over it has already been forgotten there
func spawn_marks() -> void:
	var shown := _deaths_shown()
	DeathMarks.max_marks = shown
	_clear()

	if ink_shader == null or holder == null or shown <= 0:
		return

	var marks := DeathMarks.marks
	for i in range(maxi(0, marks.size() - shown), marks.size()):
		_spawn_mark(marks[i], false)

	_refresh_age()


## The color of the ink standing at that point, fully transparent where there is
## none. A mark is measured as the ball it was built around, the noise on its
## outline is not worth chasing for a cube that only wants to step in it
func color_at(position: Vector3) -> Color:
	var marks := DeathMarks.marks
	var first := maxi(0, marks.size() - _deaths_shown())

	for i in range(marks.size() - 1, first - 1, -1):
		var mark: Dictionary = marks[i]
		if position.distance_to(mark["center"]) <= mark["radius"] * PICKUP_REACH:
			return mark["color"]

	return Color(0, 0, 0, 0)


## Paints one death onto the map around it and remembers it, called by the cube
## that just burst. The cube hands its own body over, the checks start inside it
## and would otherwise be stopped by it
func paint(origin: Vector3, color: Color, exclude: Array[RID] = []) -> void:
	if ink_shader == null or holder == null or _deaths_shown() <= 0:
		return

	var radius := ink_radius * rng.randf_range(1.0 - radius_variation, 1.0 + radius_variation)
	var faces := _find_faces(origin, radius, exclude)
	if faces.is_empty():
		return

	var mark := {
		"color": color,
		"center": origin,
		"radius": radius,
		"seed": rng.randf() * 100.0,
		"faces": faces,
	}

	DeathMarks.add(mark)
	_spawn_mark(mark, true)
	_drop_oldest()
	_refresh_age()


## Collects every surface of the map the ink could land on. The cells are read
## straight off the GridMap instead of being searched with rays, so the ink
## covers whole faces and leaves no gaps between them
func _find_faces(origin: Vector3, radius: float, exclude: Array[RID]) -> Array[Transform3D]:
	var faces: Array[Transform3D] = []
	var grid := _find_grid(origin, radius, exclude)
	if grid == null:
		return faces

	var cell_size: float = grid.cell_size.x
	var reach := radius + reach_margin
	var span := ceili((reach + cell_size) / cell_size)
	var middle := grid.local_to_map(grid.to_local(origin))
	var candidates: Array[Dictionary] = []

	for x in range(-span, span + 1):
		for y in range(-span, span + 1):
			for z in range(-span, span + 1):
				var cell := middle + Vector3i(x, y, z)
				if grid.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM:
					continue

				var cell_center := grid.to_global(grid.map_to_local(cell))
				if cell_center.distance_to(origin) > reach + cell_size:
					continue

				for side in SIDES:
					if grid.get_cell_item(cell + side) != GridMap.INVALID_CELL_ITEM:
						continue

					var normal := (grid.to_global(grid.map_to_local(cell) + Vector3(side)) - cell_center).normalized()
					var center := cell_center + normal * cell_size * 0.5
					if normal.dot(origin - center) <= 0.0:
						continue

					var distance := _distance_to_face(origin, center, normal, cell_size)
					if distance > reach:
						continue

					candidates.append({"center": center, "normal": normal, "distance": distance})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	var space := holder.get_world_3d().direct_space_state

	for candidate in candidates.slice(0, _face_budget()):
		if _is_in_sight(origin, candidate["center"], candidate["normal"], space, exclude):
			faces.append(_face_transform(candidate["center"], candidate["normal"], cell_size))

	return faces


## Distance from the burst to the nearest point of that face, not to the middle
## of it. A face is a whole cell across, measuring to its middle drops faces the
## ink still reaches a corner of and cuts the mark off along a straight edge
func _distance_to_face(origin: Vector3, center: Vector3, normal: Vector3, cell_size: float) -> float:
	var half := cell_size * 0.5
	var offset := origin - center
	var flat := offset - normal * offset.dot(normal)
	var nearest := Vector3(
		clampf(flat.x, -half, half),
		clampf(flat.y, -half, half),
		clampf(flat.z, -half, half))

	return offset.distance_to(nearest)


## The map the burst happened in, found by dropping one ray onto it. Everything
## after that is read off the grid itself
func _find_grid(origin: Vector3, radius: float, exclude: Array[RID]) -> GridMap:
	var space := holder.get_world_3d().direct_space_state

	for direction in [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * (radius + reach_margin))
		query.collide_with_areas = false
		query.exclude = exclude

		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit.collider is GridMap:
			return hit.collider as GridMap

	return null


## Lays a quad over one face of one cell, the size of the face itself
func _face_transform(center: Vector3, normal: Vector3, cell_size: float) -> Transform3D:
	var up := Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD
	var right := up.cross(normal).normalized()
	var basis := Basis(right * cell_size, normal.cross(right) * cell_size, normal)

	return Transform3D(basis, center + normal * surface_offset)


## Keeps the ink on the surfaces the burst could actually see, without it the
## paint soaks through a wall and shows up in the corridor behind it.
##
## Only the map itself blocks the view. A saw or an item standing in the way is
## somewhere else on the next attempt and would leave a hole in the mark that
## nothing in the level explains, so those are stepped over
func _is_in_sight(origin: Vector3, center: Vector3, normal: Vector3, space: PhysicsDirectSpaceState3D, exclude: Array[RID]) -> bool:
	var ignore := exclude.duplicate()

	for attempt in SIGHT_ATTEMPTS:
		var query := PhysicsRayQueryParameters3D.create(origin, center + normal * 0.1)
		query.collide_with_areas = false
		query.exclude = ignore

		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true

		if hit.collider is GridMap:
			return hit.position.distance_to(center) < SIGHT_TOLERANCE

		ignore.append(hit.rid)

	return true


## Builds one death as a single MultiMesh, every painted face is one instance
## of it. The shape itself lives in the material, so the faces only have to be
## in the right places
func _spawn_mark(mark: Dictionary, spread: bool) -> void:
	var faces: Array = mark["faces"]

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = _face_mesh
	multi_mesh.instance_count = faces.size()

	for i in range(faces.size()):
		multi_mesh.set_instance_transform(i, faces[i])

	var node := MultiMeshInstance3D.new()
	node.multimesh = multi_mesh
	node.material_override = _ink_material(mark, spread)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	holder.add_child(node)
	_marks.append(node)

	if spread:
		_spread(node.material_override)


## One material per death, it carries the shape the faces read out of it. Only
## what makes this mark this one is set here, the look comes from the node
func _ink_material(mark: Dictionary, spread: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ink_shader
	material.set_shader_parameter("ink_color", mark["color"])
	material.set_shader_parameter("ink_center", mark["center"])
	material.set_shader_parameter("ink_radius", mark["radius"])
	material.set_shader_parameter("ink_seed", mark["seed"])
	material.set_shader_parameter("ink_fade", 1.0)
	material.set_shader_parameter("ink_grow", 0.25 if spread else 1.0)
	_apply_look(material)
	return material


## Everything every mark on the level shares, straight off the settings on this
## node. A mark is built from them once, changing one shows on the next death
func _apply_look(material: ShaderMaterial) -> void:
	var detail := QUALITY_DETAIL[_quality()]

	material.set_shader_parameter("edge_noise", edge_noise)
	material.set_shader_parameter("sag", sag)
	material.set_shader_parameter("droplets", roundi(droplets * detail))
	material.set_shader_parameter("ink_thickness", ink_thickness)
	material.set_shader_parameter("bead_width", bead_width)
	material.set_shader_parameter("surface_detail", surface_detail * detail)
	material.set_shader_parameter("detail_scale", detail_scale)
	material.set_shader_parameter("edge_detail", maxf(detail - 1.0, 0.0))
	material.set_shader_parameter("bump_strength", bump_strength * minf(detail, 1.0))
	material.set_shader_parameter("shade_direction", shade_direction)
	material.set_shader_parameter("shade_depth", shade_depth)
	material.set_shader_parameter("gloss", gloss)
	material.set_shader_parameter("gloss_sharpness", gloss_sharpness)
	material.set_shader_parameter("rim_boost", rim_boost)
	material.set_shader_parameter("emission_strength", emission_strength)
	material.set_shader_parameter("aged_darkness", aged_darkness)


## Runs the fresh ink out over the surfaces instead of having it stand there
## finished, the shape grows out of the point the cube burst in
func _spread(material: ShaderMaterial) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_set_grow.bind(material), 0.25, 1.0, spread_duration)


func _set_grow(value: float, material: ShaderMaterial) -> void:
	material.set_shader_parameter("ink_grow", value)


## Dries every mark by how far back it is, so the map reads as a history and
## not as one big mess
func _refresh_age() -> void:
	for i in range(_marks.size()):
		var material := _marks[i].material_override as ShaderMaterial
		material.set_shader_parameter("ink_fade", _age_alpha(i))


func _age_alpha(index: int) -> float:
	if _marks.size() <= 1:
		return 1.0

	return lerpf(oldest_alpha, 1.0, float(index) / float(_marks.size() - 1))


## How many deaths the splatter setting lets stand at once, off leaves none
func _deaths_shown() -> int:
	return roundi(visible_deaths * QUALITY_DEATHS[_quality()])


## How much of the map one death may cover, in faces
func _face_budget() -> int:
	return roundi(max_faces * QUALITY_FACES[_quality()])


## Clamped, a config file written by another version cannot index past the table
func _quality() -> int:
	return clampi(Settings.splash_quality, 0, QUALITY_DEATHS.size() - 1)


## Takes the marks that ran past the limit off the map again, the store has
## already forgotten them
func _drop_oldest() -> void:
	while _marks.size() > _deaths_shown():
		_marks.pop_front().queue_free()


func _clear() -> void:
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()

	_marks.clear()
