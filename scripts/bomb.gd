extends Node2D

const FUSE_TIME := 3.0
const EXPLOSION_RADIUS := 200.0
const EXPLOSION_DAMAGE := 2.0
const TILE_BREAK_RADIUS := 2

@onready var sprite: Sprite2D = $Sprite2D
@onready var fuse_timer: Timer = $FuseTimer

var dead := false

func _ready() -> void:
	fuse_timer.timeout.connect(_on_fuse_timeout)
	fuse_timer.start()
	var tween := create_tween()
	tween.set_loops(0)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.1, 0.1, 1.0), 0.15)
	tween.tween_property(sprite, "modulate", Color(0.9, 0.3, 0.1, 1.0), 0.15)

func _on_fuse_timeout() -> void:
	if dead:
		return
	dead = true
	_explode()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)

func _explode() -> void:
	var mole := get_tree().get_first_node_in_group("mole")
	if mole and is_instance_valid(mole):
		var dist := global_position.distance_to(mole.global_position)
		if dist <= EXPLOSION_RADIUS and mole.has_method("take_damage"):
			mole.take_damage(EXPLOSION_DAMAGE, global_position, true)

	var tilemap: TileMap = get_parent().get_node_or_null("TileMap")
	if tilemap:
		var center_tile := tilemap.local_to_map(tilemap.to_local(global_position))
		var sfx = load("res://scripts/tile_break_sfx.gd")
		for dx in range(-TILE_BREAK_RADIUS, TILE_BREAK_RADIUS + 1):
			for dy in range(-TILE_BREAK_RADIUS, TILE_BREAK_RADIUS + 1):
				var tp := Vector2i(center_tile.x + dx, center_tile.y + dy)
				sfx.break_tile(tilemap, tp, get_parent())
