extends CharacterBody2D

const GRAVITY := 980.0
const DETECT_RANGE := 300.0
const JUMP_VELOCITY := -450.0
const JUMP_HORIZONTAL := 350.0
const MAX_HEALTH := 6.0
const POISON_DURATION := 4.0
const POISON_DAMAGE_INTERVAL := 0.5
const POISON_TILE_INTERVAL := 1.0
const POISON_RADIUS := 150.0
const TILE_BREAK_RADIUS := 2
const BODY_COLOR := Color(0.15, 0.7, 0.15, 1.0)

var health := MAX_HEALTH
var target_mole: Node2D = null
var was_on_floor := true
var poison_timer := 0.0
var poison_damage_tick := 0.0
var poison_tile_tick := 0.0
var has_landed := false

var _tilemap: TileMap = null
var _tile_break_script: GDScript = null

@onready var hurtbox: Area2D = $Area2D
@onready var poison_sprite: Sprite2D = $Poison

func _ready() -> void:
	_create_body_visual()
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_body_entered)
	hurtbox.add_to_group("enemy_hurtbox")
	poison_sprite.modulate.a = 0.0
	_tilemap = get_parent().get_node_or_null("TileMap") as TileMap
	_tile_break_script = load("res://scripts/tile_break_sfx.gd")

func _create_body_visual() -> void:
	var img := Image.create(54, 43, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx := 27.0
	var cy := 21.0
	var rx := 24.0
	var ry := 18.0
	for x in 54:
		for y in 43:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			if dx * dx / (rx * rx) + dy * dy / (ry * ry) <= 1.0:
				img.set_pixel(x, y, BODY_COLOR)
	var tex := ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(2, 2)
	sprite.position = Vector2(-20, -5)
	add_child(sprite)
	move_child(sprite, 0)

func _physics_process(delta: float) -> void:
	_find_target()

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_on_floor() and not was_on_floor:
		_land()

	move_and_slide()
	was_on_floor = is_on_floor()

	if poison_timer > 0.0:
		poison_timer -= delta
		poison_damage_tick -= delta
		poison_tile_tick -= delta
		_process_poison()
		if poison_timer <= 0.0:
			var tw := create_tween()
			tw.tween_property(poison_sprite, "modulate:a", 0.0, 0.3)
		return

	if not is_on_floor():
		return

	if target_mole:
		var dist := global_position.distance_squared_to(target_mole.global_position)
		if dist < DETECT_RANGE * DETECT_RANGE:
			_jump_toward_target()

func _find_target() -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
		if target_mole:
			add_collision_exception_with(target_mole)

func _jump_toward_target() -> void:
	var dir: float = sign(target_mole.global_position.x - global_position.x)
	velocity.y = JUMP_VELOCITY
	velocity.x = dir * JUMP_HORIZONTAL
	has_landed = false

func _land() -> void:
	if has_landed:
		return
	has_landed = true
	poison_timer = POISON_DURATION
	poison_damage_tick = 0.0
	poison_tile_tick = 0.0
	poison_sprite.modulate.a = 0.6
	poison_sprite.scale = Vector2(0.31, 0.31)

	var tw := create_tween()
	tw.tween_property(poison_sprite, "scale", Vector2(0.93, 0.93), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process_poison() -> void:
	if poison_damage_tick <= 0.0:
		poison_damage_tick = POISON_DAMAGE_INTERVAL
		if target_mole and is_instance_valid(target_mole):
			var dist := global_position.distance_to(target_mole.global_position)
			if dist <= POISON_RADIUS and target_mole.has_method("take_damage"):
				target_mole.take_damage(0.5, global_position, true)

	if poison_tile_tick <= 0.0:
		poison_tile_tick = POISON_TILE_INTERVAL
		if _tilemap:
			var center := _tilemap.local_to_map(_tilemap.to_local(global_position))
			for dx in range(-TILE_BREAK_RADIUS, TILE_BREAK_RADIUS + 1):
				for dy in range(-TILE_BREAK_RADIUS, TILE_BREAK_RADIUS + 1):
					var tp := Vector2i(center.x + dx, center.y + dy)
					_tile_break_script.break_tile(_tilemap, tp, get_parent())

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		body.take_damage(1, global_position, true)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	var parent: Node = area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		take_damage(1)

func take_damage(amount: float) -> void:
	if health <= 0:
		return
	health -= amount
	queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2, 1, 1, 1), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	if health <= 0:
		die()

func _draw() -> void:
	if health <= 0 or health >= MAX_HEALTH:
		return
	var bar_w := 48.0
	var bar_h := 5.0
	var offset := Vector2(-bar_w / 2, -70)
	var ratio := health / MAX_HEALTH
	draw_rect(Rect2(offset, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.15, 0.9))
	var fill := Color(0.3 + 0.7 * ratio, 0.8, 0.3, 0.95)
	draw_rect(Rect2(offset, Vector2(bar_w * ratio, bar_h)), fill)

func die() -> void:
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(poison_sprite, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
