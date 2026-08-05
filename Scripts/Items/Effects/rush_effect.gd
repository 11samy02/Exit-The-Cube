extends ItemEffect
class_name RushEffect

const RUSH_SHADER := "res://Assets/shaders/RainbowRush.gdshader"

## How much faster the player runs while the effect is up. This item already
## takes the blades out of the level for as long as it runs, so the number is
## kept well under what it used to be. It still has to be felt though: a cube
## that is only a little quicker reads as an item that does nothing but make
## the player invincible, and running is half of what this one is
@export var speed_multiplier: float = 1.4

## Full color cycles per second
@export var hue_speed: float = 2.5

## How much color is left in the cycle, 0 would leave a white cube
@export_range(0.0, 1.0) var saturation: float = 0.95

## How brightly the cube itself glows in its current color
@export var body_strength: float = 1.4

## Color of the glowing edges
@export var edge_color: Color = Color(1.0, 0.82, 0.25)

## How tightly the glow hugs the silhouette, higher means a thinner edge
@export_range(0.5, 8.0) var edge_power: float = 3.0

## How hard the edges burn
@export var edge_strength: float = 8.0

## How hard the screen edge glows while the effect runs in ego perspective,
## where the rainbow on the cube itself cannot be seen
@export var vignette_strength: float = 0.9

## Seconds before the end at which the cube starts flickering
@export var warning_time: float = 2.5

## Flickers per second while the effect runs out
@export var warning_blink_speed: float = 4.0

## How far the glow drops on a flicker, 0 would switch the cube off completely
@export_range(0.0, 1.0) var warning_low_pulse: float = 0.25

var mesh: MeshInstance3D = null
var movement: PlayerMovement = null
var death: PlayerDeath = null
var rush_material: ShaderMaterial = null
var previous_material: Material = null


func _start() -> void:
	movement = player.movement if player != null else null
	if movement != null:
		movement.set_boost(&"rush", speed_multiplier)

	death = player.death if player != null else null
	if death != null:
		death.set_guard(&"rush")

	_apply_rush_material()
	show_vignette(vignette_strength)


## The blink is only the glow going dark and bright again, hiding the cube
## outright would take the player's own position off the screen
func _tick(_delta: float) -> void:
	if rush_material == null:
		return

	var lit := warning_blink(warning_time, warning_blink_speed)
	rush_material.set_shader_parameter("pulse", 1.0 if lit else warning_low_pulse)


## Everything the effect touched is put back. On a cancelled effect the player
## is being torn down anyway, so only the shared state is restored
func _stop(cancelled: bool) -> void:
	if is_instance_valid(movement):
		movement.clear_boost(&"rush")

	if is_instance_valid(mesh):
		mesh.material_override = previous_material

	if not is_instance_valid(death):
		return

	death.clear_guard(&"rush")
	if not cancelled:
		_kill_if_still_inside_a_saw()


## Walking out of the effect while standing in a blade has to hurt, the saw
## already reported its touch and would not report it a second time
func _kill_if_still_inside_a_saw() -> void:
	if not is_instance_valid(player):
		return

	for node in get_tree().get_nodes_in_group("saw"):
		var saw := node as Area3D
		if saw == null or not saw.monitoring:
			continue

		if saw.get_overlapping_bodies().has(player):
			death.kill()
			return


## The player color script owns material_override, so the old material is kept
## and put back instead of being rebuilt from scratch
func _apply_rush_material() -> void:
	mesh = _find_mesh()
	if mesh == null:
		return

	previous_material = mesh.material_override

	rush_material = ShaderMaterial.new()
	rush_material.shader = load(RUSH_SHADER)
	rush_material.set_shader_parameter("hue_speed", hue_speed)
	rush_material.set_shader_parameter("saturation", saturation)
	rush_material.set_shader_parameter("body_strength", body_strength)
	rush_material.set_shader_parameter("edge_color", edge_color)
	rush_material.set_shader_parameter("edge_power", edge_power)
	rush_material.set_shader_parameter("edge_strength", edge_strength)
	rush_material.set_shader_parameter("pulse", 1.0)

	mesh.material_override = rush_material


func _find_mesh() -> MeshInstance3D:
	if not is_instance_valid(player):
		return null

	for child in player.get_children():
		if child is MeshInstance3D:
			return child

	return null
