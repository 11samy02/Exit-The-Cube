class_name BurstRing
extends MeshInstance3D

## A ring thrown out from a point, growing and fading as it goes.
##
## The one shape three different things needed: the ground a leap pushes off,
## the paint a splash throws out, and the jolt that stops a cube where it stands.
## It outlives whatever made it — an item effect is gone the frame it is spent,
## and a burst that died with it would never be seen at all

## How thick the ring is against how wide, so it stays a ring rather than
## becoming a disc as it grows
const THICKNESS := 0.14

## How much of the life is spent at full brightness before the fade starts
const HOLD := 0.25

var _material: StandardMaterial3D = null
var _torus: TorusMesh = null
var _reach: float = 1.0
var _life: float = 0.5
var _spent: float = 0.0

## Seconds before it starts. Held by the ring rather than by whoever asked for
## it: an item effect is often gone the same frame it spawned these, and a wait
## running inside a freed node is a wait that never comes back
var _wait: float = 0.0


## Throws one out at that point. It hangs under the level rather than under
## whatever asked for it, so it finishes even when that is already gone
static func burst(host: Node, at: Vector3, color: Color, reach: float,
		seconds: float, upright: bool = false, delay: float = 0.0) -> BurstRing:
	var made := BurstRing.new()
	made.name = "Burst"
	made._reach = maxf(reach, 0.1)
	made._life = maxf(seconds, 0.05)
	made._wait = maxf(delay, 0.0)
	made._dress(color)
	made.visible = delay <= 0.0

	host.add_child(made)
	made.global_position = at

	if upright:
		made.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	return made


func _dress(color: Color) -> void:
	_torus = TorusMesh.new()
	_torus.rings = 24
	_torus.ring_segments = 6
	mesh = _torus

	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 3.0
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _material

	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_resize(0.0)


func _process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		visible = _wait <= 0.0
		return

	_spent += delta

	if _spent >= _life:
		queue_free()
		return

	var through := _spent / _life
	_resize(ease(through, 0.4))

	var fade := 1.0 - clampf((through - HOLD) / maxf(1.0 - HOLD, 0.01), 0.0, 1.0)
	_material.albedo_color.a = fade
	_material.emission_energy_multiplier = 3.0 * fade


## Grows the ring outwards. The tube keeps a share of the radius rather than a
## size of its own, so a small burst is not a fat doughnut
func _resize(through: float) -> void:
	var outer := maxf(_reach * through, 0.05)
	_torus.outer_radius = outer
	_torus.inner_radius = outer * (1.0 - THICKNESS)
