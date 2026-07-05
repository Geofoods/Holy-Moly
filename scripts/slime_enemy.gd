extends CharacterBody2D

const GRAVITY := 1960.0
const DETECT_RANGE := 300.0
const JUMP_VELOCITY := -900.0
const JUMP_HORIZONTAL := 700.0
const MAX_HEALTH := 1.0
const POISON_DURATION := 2.0
const POISON_DAMAGE_INTERVAL := 0.25
const POISON_TILE_INTERVAL := 0.5
const POISON_RADIUS := 150.0
const TILE_BREAK_RADIUS := 2

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
@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_body_entered)
	hurtbox.add_to_group("enemy_hurtbox")
	poison_sprite.modulate.a = 0.0
	_tilemap = get_parent().get_node_or_null("TileMap") as TileMap
	_tile_break_script = load("res://scripts/tile_break_sfx.gd")

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
		if dist < DETECT_RANGE * DETECT_RANGE and _has_line_of_sight(target_mole):
			_jump_toward_target()

func _has_line_of_sight(target: Node2D) -> bool:
	if abs(target.global_position.y - global_position.y) > 120.0:
		return false
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	if result.position.distance_to(target.global_position) < 40.0:
		return true
	return false

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
	SFX.play("jump", global_position, -14.0, 0.3)

func _land() -> void:
	if has_landed:
		return
	has_landed = true
	SFX.play("land", global_position, -10.0, 0.4)
	poison_timer = POISON_DURATION
	poison_damage_tick = 0.0
	poison_tile_tick = 0.0
	poison_sprite.modulate.a = 0.6
	poison_sprite.scale = Vector2(0.1, 0.1)

	var tw := create_tween()
	tw.tween_property(poison_sprite, "scale", Vector2(0.31, 0.31), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	SFX.play("enemy_death", global_position)
	ComboManager.increment()
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.8, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_break_apart)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)

func _break_apart() -> void:
	visual.visible = false
	poison_sprite.visible = false

	var source_tex := visual.texture
	var source_region := Rect2(Vector2.ZERO, source_tex.get_size())

	var w := source_region.size.x
	var h := source_region.size.y
	var ox := source_region.position.x
	var oy := source_region.position.y

	var cols := 4
	var rows := 2
	var pw := w / cols
	var ph := h / rows
	var center_offset := Vector2(w * 0.5, h * 0.5)

	for col in cols:
		for row in rows:
			var local_center := Vector2(col * pw + pw * 0.5, row * ph + ph * 0.5) - center_offset
			var sub_rect := Rect2(ox + col * pw, oy + row * ph, pw, ph)

			var piece := Sprite2D.new()
			piece.texture = source_tex
			piece.region_enabled = true
			piece.region_rect = sub_rect
			piece.scale = visual.scale * 0.5
			piece.position = visual.position + local_center
			add_child(piece)

			var angle := randf_range(0.0, TAU)
			var speed := randf_range(150.0, 350.0)
			var vel := Vector2.RIGHT.rotated(angle) * speed

			var pt := create_tween()
			pt.tween_property(piece, "position", piece.position + vel, 0.5).set_ease(Tween.EASE_OUT)
			pt.parallel().tween_property(piece, "rotation", randf_range(-4.0, 4.0), 0.5).set_ease(Tween.EASE_OUT)
			pt.parallel().tween_property(piece, "modulate", Color(1, 1, 1, 0), 0.5).set_ease(Tween.EASE_IN)
			pt.tween_callback(piece.queue_free)
