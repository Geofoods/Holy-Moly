extends Area2D

const LIFETIME = 3.0
const TILE_BREAK_RADIUS = 2
const TileBreakSfx = preload("res://scripts/tile_break_sfx.gd")

var velocity := Vector2.ZERO

func setup(vel: Vector2) -> void:
	velocity = vel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(_explode)

func _physics_process(delta: float) -> void:
	position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		return
	if body is StaticBody2D or body is TileMap:
		_explode()
	elif body.has_method("die"):
		body.die()
		_explode()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy := area.get_parent()
		if enemy and is_instance_valid(enemy) and enemy.has_method("die"):
			enemy.die()
			_explode()

func _explode() -> void:
	SFX.play("explosion", global_position)
	var tilemap: TileMap = get_parent().get_node_or_null("TileMap")
	if tilemap:
		var center_tile := tilemap.local_to_map(tilemap.to_local(global_position))
		for dx in range(-TILE_BREAK_RADIUS, TILE_BREAK_RADIUS + 1):
			for dy in range(-TILE_BREAK_RADIUS, TILE_BREAK_RADIUS + 1):
				var tp := Vector2i(center_tile.x + dx, center_tile.y + dy)
				if tilemap.get_cell_source_id(0, tp) != -1:
					TileBreakSfx.break_tile(tilemap, tp, get_parent())
				else:
					TileBreakSfx.break_decoration_tile(tilemap, tp, get_parent())
	queue_free()
