class_name PlayerGhost
extends Node3D

## How this cube looks to everybody else in a local race.
##
## Online the other players are drawings: a position arrives and a transparent
## box is put there. Here they are real bodies in the same maze, but a race is
## still meant to read the same way — you are running your own maze and the
## others are shapes going past in it, not cubes you could bump into.
##
## So the solid mesh is put on a layer only its own camera looks at, and this
## goes on a layer only the others look at. It hangs under the player, so
## following it is not something anything has to do

## How see through the double is
const ALPHA := 0.22

## How hard it glows, so a ghost still reads in a corridor no light reaches
const EMISSION := 1.4

var _mesh: MeshInstance3D = null
var _label: PlayerTag = null
var _cube: Player = null


## Built by the spawner rather than living in the player scene: nothing outside a
## local race has any use for it, and a campaign should not carry a second mesh
## per cube around for nothing
static func attach_to(cube: Player) -> PlayerGhost:
	var made := PlayerGhost.new()
	made.name = "Ghost"
	made._cube = cube
	cube.add_child(made)
	return made


func _ready() -> void:
	var color := Match.color_of(_cube.account())
	var bit := SeatView.ghost_bit_of(_cube)

	_mesh = MeshInstance3D.new()
	_mesh.mesh = _box()
	_mesh.material_override = _material(color)
	_mesh.layers = bit
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

	_label = PlayerTag.attach_to(_cube)


## The double is hidden with the cube it doubles, so a dead player is gone from
## everybody's half of the window and not only from their own
func _process(_delta: float) -> void:
	var solid := _cube.get_node_or_null("mesh") as MeshInstance3D
	if solid == null:
		return

	_mesh.visible = solid.visible
	_label.visible = solid.visible


## The same size the cube is, so a ghost is where the player really is rather
## than a box roughly around them
func _box() -> BoxMesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.19
	return box


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, ALPHA)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = EMISSION
	return material
