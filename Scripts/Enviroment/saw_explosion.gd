extends Node3D
class_name SawExplosion

## What is left of a blade the cube broke. It is spawned where the saw stood,
## runs once and takes itself off the level again

## The debris the blade is torn into
@export var chunks: GPUParticles3D

## Sparks off the motor, fast and short lived
@export var sparks: GPUParticles3D

## The cloud that hangs in the corridor afterwards, made of cubes like
## everything else in here
@export var smoke: GPUParticles3D

## The pop of light the burst throws into the corridor
@export var flash: OmniLight3D

@export var sound: AudioStreamPlayer3D

## How hard the flash starts before it fades
@export var flash_energy: float = 12.0

## Seconds the flash takes to die down
@export var flash_duration: float = 0.5

## Seconds before the wreck cleans itself up, long enough for the smoke to have
## thinned out on its own
@export var life: float = 4.0


func _ready() -> void:
	for burst: GPUParticles3D in [chunks, sparks, smoke]:
		if burst != null:
			burst.restart()

	if sound != null:
		sound.play()

	_flash()
	get_tree().create_timer(life).timeout.connect(queue_free)


func _flash() -> void:
	if flash == null:
		return

	flash.light_energy = flash_energy

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(flash, "light_energy", 0.0, flash_duration)
