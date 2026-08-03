extends Node
class_name PlayerColor

## The mesh that gets the random color
@export var mesh: MeshInstance3D

## Saturation of the generated color
@export var saturation: float = 0.7

## Brightness of the generated color
@export var value: float = 0.95

## How strongly the cube glows in its own color
@export var emission_strength: float = 0.4

@export var metallic: float = 0.15
@export var roughness: float = 0.45

## The color this cube was spawned with, for other systems to match
var color: Color


func _ready() -> void:
	color = Color.from_hsv(randf(), saturation, value)
	mesh.material_override = _build_material()


## A fresh material per player, so two cubes never share their color
func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_strength
	return material
