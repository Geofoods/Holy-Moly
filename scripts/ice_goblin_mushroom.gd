extends "res://scripts/ice_bomb.gd"

## The Ice Goblin's frost mushroom. Flies and arms exactly like the goblin's
## exploding mushroom (body contact or fuse), but the blast is the player's
## ice bomb: a cold snap that freezes enemies, projectiles and the mole caught
## in it, and coats the surrounding blocks in a sheet of melting ice instead
## of breaking them.
##
## Radius and tile reach are tuned down from the player's ice bomb via the
## scene's exported values, so an enemy-sized blast doesn't re-terraform a
## whole screen.

func _ready() -> void:
	super()
	add_to_group("bullet")
	body_entered.connect(_on_body_entered)
	var mole := get_tree().get_first_node_in_group("mole")
	if mole:
		add_collision_exception_with(mole)
	# Chilled blue-green wash so the shared mushroom sprite reads as frost
	# rather than the goblin's explosive. The inherited fuse pulse keeps
	# re-tinting the sprite toward cold blues as it ticks down, so this only
	# sets the resting look before the fuse starts.
	sprite.modulate = Color(0.72, 0.95, 1.25, 1.0)
