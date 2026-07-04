extends RigidBody2D

const FUSE_TIME := 2.5

@export var explosion_radius := 200.0
@export var explosion_damage := 2.0
@export var tile_break_radius := 2

var dead := false
var fuse_active := false
var fuse_elapsed := 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	linear_velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if not fuse_active:
		return
	fuse_elapsed += delta
	var pulse := 0.5 + sin(fuse_elapsed * 20.0) * 0.5
	sprite.modulate = Color(1.0, 0.6 + pulse * 0.3, pulse * 0.3, 1.0)
	if fuse_elapsed >= FUSE_TIME:
		_explode()

func arm() -> void:
	fuse_active = true

func _explode() -> void:
	if dead:
		return
	dead = true
	var mole := get_tree().get_first_node_in_group("mole")
	if mole and is_instance_valid(mole):
		var dist := global_position.distance_to(mole.global_position)
		if dist <= explosion_radius and mole.has_method("take_damage"):
			mole.take_damage(explosion_damage, global_position, true)

	var tilemap: TileMap = get_parent().get_node_or_null("TileMap")
	if tilemap:
		var center_tile := tilemap.local_to_map(tilemap.to_local(global_position))
		var sfx = load("res://scripts/tile_break_sfx.gd")
		for dx in range(-tile_break_radius, tile_break_radius + 1):
			for dy in range(-tile_break_radius, tile_break_radius + 1):
				var tp := Vector2i(center_tile.x + dx, center_tile.y + dy)
				sfx.break_tile(tilemap, tp, get_parent())

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
