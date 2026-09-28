extends Node

## Shared helper for handing the player an item out in the open, the way a chest
## hands over its contents. The boss fights stock themselves with it: a loose
## pickup can be grabbed on the move, where a chest asks the player to stop and
## open it in the middle of a dodge.

const DROPPED_ITEM_SCENE := preload("res://scenes/dropped_item.tscn")
const DRILL := preload("res://resources/drill.tres")
const HOLY_WATER := preload("res://resources/holy_water.tres")
## The drill is the more useful of the two while something is shooting at you, so
## it is the common drop and the holy water is the treat.
const DRILL_CHANCE := 0.7

## Drops the pickup the boss fights hand out: a Drill, or Holy Water when the
## roll goes the other way.
static func spawn_random(parent: Node, world_position: Vector2) -> void:
	spawn(parent, DRILL if randf() < DRILL_CHANCE else HOLY_WATER, world_position)

## Puts a loose item into the world so it falls, bounces and floats until the
## mole walks into it.
static func spawn(parent: Node, item: ItemData, world_position: Vector2) -> void:
	if parent == null or item == null:
		return
	var dropped = DROPPED_ITEM_SCENE.instantiate()
	dropped.item_data = item
	parent.add_child(dropped)
	dropped.global_position = world_position
