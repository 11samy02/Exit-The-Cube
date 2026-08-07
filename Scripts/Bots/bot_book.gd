@tool
extends Resource
class_name BotBook

## Everything about the CPU players that is not one rung of the ladder. One
## file, edited in the inspector rather than in a script

@export_group("Ladder")

## The rungs, in the order the party screen offers them
@export var skills: Array[BotSkill] = []

## Which rung a fresh party screen comes up on
@export var default_skill: int = 1

@export_group("Room")

## How many cubes one round on this machine may hold, humans and bots together
@export var max_players: int = 12

@export_group("Names")

## What the bots are called on the board, in order. A round with more bots than
## names counts on past the end of the list
@export var names: PackedStringArray = PackedStringArray([
	"CPU ALPHA", "CPU BRAVO", "CPU CHARLIE", "CPU DELTA",
	"CPU ECHO", "CPU FOXTROT", "CPU GOLF", "CPU HOTEL",
	"CPU INDIA", "CPU JULIET", "CPU KILO", "CPU LIMA",
])
