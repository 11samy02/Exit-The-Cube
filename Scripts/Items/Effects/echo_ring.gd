extends MeshInstance3D
class_name EchoRing

## One wave front. It does not fly at the target, it runs the corridors there,
## so what it draws on its way is the shortest way through the maze

## The corners it travels through, from the cube to whatever it is looking for
var route: PackedVector3Array = PackedVector3Array()

## Meters per second, well over what the cube can run
var speed: float = 14.0

## Meters of the run it fades out over, at the far end of the route
var fade_distance: float = 3.0

var _material: StandardMaterial3D = null
var _glow: float = 1.0
var _travelled: float = 0.0
var _length: float = 0.0


## Sends the ring off along that route. It takes itself off the level once it
## has arrived, nobody has to keep track of it
func launch(points: PackedVector3Array, ring_speed: float, color: Color, size: float, glow: float) -> void:
	route = points
	speed = ring_speed
	_glow = glow
	_length = _route_length()

	if _length <= 0.0:
		queue_free()
		return

	var torus := TorusMesh.new()
	torus.inner_radius = size * 0.62
	torus.outer_radius = size
	torus.rings = 12
	torus.ring_segments = 6
	mesh = torus

	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = glow
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _material

	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_transform = _transform_at(0.0)


func _process(delta: float) -> void:
	if _material == null:
		return

	_travelled += speed * delta

	if _travelled >= _length:
		queue_free()
		return

	var fade := _fade()
	global_transform = _transform_at(_travelled)
	_material.albedo_color.a = fade
	_material.emission_energy_multiplier = _glow * fade


## Fades over the last stretch, a ring that pops out of existence in front of
## the key would read as a bug
func _fade() -> float:
	if fade_distance <= 0.0:
		return 1.0

	return clampf((_length - _travelled) / fade_distance, 0.0, 1.0)


## Where on the route that distance lands, and which way the wave is facing.
## The torus stands across the corridor, so its own up is the way it travels
func _transform_at(distance: float) -> Transform3D:
	var walked := 0.0

	for i in range(route.size() - 1):
		var from := route[i]
		var to := route[i + 1]
		var step := from.distance_to(to)
		if step <= 0.0001:
			continue

		if walked + step >= distance:
			var forward := (to - from) / step
			var point := from + forward * (distance - walked)
			return Transform3D(_facing(forward), point)

		walked += step

	return Transform3D(Basis(), route[route.size() - 1])


## A basis whose up axis points along the run, the torus lies flat around it
func _facing(forward: Vector3) -> Basis:
	var reference := Vector3.UP if absf(forward.y) < 0.9 else Vector3.RIGHT
	var right := reference.cross(forward).normalized()

	return Basis(right, forward, right.cross(forward))


func _route_length() -> float:
	var total := 0.0

	for i in range(route.size() - 1):
		total += route[i].distance_to(route[i + 1])

	return total
