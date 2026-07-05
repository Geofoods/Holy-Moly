extends Area2D

const LIFETIME := 4.0
const EXPLOSION_TILE_RADIUS := 1

var velocity := Vector2.ZERO

func setup(vel: Vector2) -> void:
	velocity = vel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(_explode)
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	if sprite:
		sprite.play("default")

func _physics_process(delta: float) -> void:
	position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole") and body.has_method("take_damage"):
		body.take_damage(1, global_position, true, true)
	_explode()

func _explode() -> void:
	SFX.play("explosion", global_position)
	_break_tiles()
	queue_free()

func _break_tiles() -> void:
	var tilemap: TileMap = get_parent().get_node_or_null("TileMap") as TileMap
	if not tilemap:
		return
	var sfx := load("res://scripts/tile_break_sfx.gd") as GDScript
	var center := tilemap.local_to_map(tilemap.to_local(global_position))
	for dx in range(-EXPLOSION_TILE_RADIUS, EXPLOSION_TILE_RADIUS + 1):
		for dy in range(-EXPLOSION_TILE_RADIUS, EXPLOSION_TILE_RADIUS + 1):
			var tp := Vector2i(center.x + dx, center.y + dy)
			sfx.break_tile(tilemap, tp, get_parent(), true)
