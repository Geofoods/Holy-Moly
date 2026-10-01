extends "res://scripts/goblin_enemy.gd"

## The goblin's cold-weather cousin. Same alert, mushroom-lobbing brain as the
## regular goblin, but its mushroom is charged with frost: the blast freezes
## every block in its radius into a slick sheet of ice (and freezes anything
## standing in it) instead of digging a crater.

const FROST_MUSHROOM_SCENE := preload("res://ice_goblin_mushroom.tscn")

## Icy wash over the shared goblin sprite, so it reads as frozen the moment it
## walks on screen without needing new art. The regular goblin's hit-flash
## tweens the whole node's modulate, not the visual's, so this tint survives
## being hit.
const ICE_TINT := Color(0.62, 0.86, 1.18, 1.0)

func _ready() -> void:
	super()
	mushroom_scene = FROST_MUSHROOM_SCENE
	visual.modulate = ICE_TINT

## Shatter-hint on death: a puff of ice shards rides along with the usual
## goblin break-apart, so it dies like something frozen rather than merely
## recoloured.
func _break_apart() -> void:
	var shards := CPUParticles2D.new()
	shards.emitting = true
	shards.one_shot = true
	shards.amount = 14
	shards.lifetime = 0.6
	shards.explosiveness = 0.85
	shards.direction = Vector2.ZERO
	shards.spread = 180.0
	shards.initial_velocity_min = 140.0
	shards.initial_velocity_max = 280.0
	shards.gravity = Vector2(0, 500)
	shards.scale_amount_min = 4.0
	shards.scale_amount_max = 8.0
	shards.color = Color(0.88, 0.95, 1.0, 0.95)
	get_parent().add_child(shards)
	shards.global_position = global_position + Vector2(0, -40)
	get_tree().create_timer(1.2).timeout.connect(shards.queue_free)
	super()
