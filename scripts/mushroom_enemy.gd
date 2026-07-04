extends CharacterBody2D

const GRAVITY = 980.0
const DETECT_RANGE = 250.0
const FUSE_TIME = 1.5
const EXPLOSION_RADIUS = 200.0
const EXPLOSION_DAMAGE = 2.0
const TILE_BREAK_RADIUS = 2

var fuse_active := false
var fuse_timer := 0.0
var dead := false

@onready var visual: Sprite2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox
@onready var detect_zone: Area2D = $DetectZone

func _ready() -> void:
	hurtbox.add_to_group("enemy_hurtbox")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	detect_zone.body_entered.connect(_on_detect_zone_body_entered)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	velocity.x = 0
	move_and_slide()

	if fuse_active:
		fuse_timer -= delta
		if fuse_timer <= 0.0:
			die()

func _on_detect_zone_body_entered(body: Node) -> void:
	if dead:
		return
	if body.is_in_group("mole") and not fuse_active:
		_start_fuse()

func _start_fuse() -> void:
	fuse_active = true
	fuse_timer = FUSE_TIME
	var tween := create_tween()
	tween.set_loops(0)
	tween.tween_property(visual, "modulate", Color(1.0, 0.1, 0.1, 1.0), 0.15)
	tween.tween_property(visual, "modulate", Color(0.9, 0.3, 0.1, 1.0), 0.15)

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

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	if dead:
		return
	die()

func die() -> void:
	if dead:
		return
	dead = true
	fuse_active = false
	SFX.play("explosion", global_position)
	_explode()
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)
	detect_zone.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
