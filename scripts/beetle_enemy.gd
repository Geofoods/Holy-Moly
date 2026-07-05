extends CharacterBody2D

enum State { PATROL, RUSHING, COOLDOWN }

const PATROL_SPEED := 60.0
const RUSH_SPEED := 550.0
const GRAVITY := 980.0
const DETECT_RANGE := 350.0
const RUSH_DURATION := 1.2
const COOLDOWN_DURATION := 2.5
const MAX_HEALTH := 4.0

var state := State.PATROL
var direction := 1.0
var target_mole: Node2D = null
var rush_timer := 0.0
var cooldown_timer := 0.0
var health := MAX_HEALTH
var was_on_floor := true
@onready var hurtbox: Area2D = $Area2D
@onready var visual: AnimatedSprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_body_entered)
	hurtbox.add_to_group("enemy_hurtbox")
	visual.z_index = 1
	visual.play()

func _physics_process(delta: float) -> void:
	_find_target()

	match state:
		State.PATROL:
			_patrol(delta)
		State.RUSHING:
			_rush(delta)
		State.COOLDOWN:
			_cooldown(delta)

	move_and_slide()
	_update_visual_direction()

	if state == State.RUSHING:
		_break_tiles_on_collision()

	was_on_floor = is_on_floor()

func _patrol(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = direction * PATROL_SPEED

	if is_on_wall():
		direction *= -1

	if target_mole:
		var dist: float = global_position.distance_squared_to(target_mole.global_position)
		if dist < DETECT_RANGE * DETECT_RANGE:
			_start_rush()

func _rush(_delta: float) -> void:
	velocity.y = 0.0

	var dir: float = sign(target_mole.global_position.x - global_position.x) if target_mole else direction
	velocity.x = dir * RUSH_SPEED

	rush_timer -= _delta
	if rush_timer <= 0.0:
		state = State.COOLDOWN
		cooldown_timer = COOLDOWN_DURATION

func _cooldown(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = move_toward(velocity.x, 0.0, PATROL_SPEED * delta)

	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		state = State.PATROL

func _start_rush() -> void:
	state = State.RUSHING
	rush_timer = RUSH_DURATION
	direction = sign(target_mole.global_position.x - global_position.x)

func _break_tiles_on_collision() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is TileMap:
			var tilemap := collider as TileMap
			var tile_pos := tilemap.local_to_map(tilemap.to_local(collision.get_position()))
			var sfx = load("res://scripts/tile_break_sfx.gd")
			if tilemap.get_cell_source_id(0, tile_pos) != -1:
				sfx.break_tile(tilemap, tile_pos, get_parent())
			else:
				sfx.break_decoration_tile(tilemap, tile_pos, get_parent())

func _update_visual_direction() -> void:
	var dir: float = sign(velocity.x) if velocity.x != 0.0 else direction
	visual.scale.x = -abs(visual.scale.x) * sign(dir)

func _find_target() -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
		if target_mole:
			add_collision_exception_with(target_mole)
	elif global_position.distance_squared_to(target_mole.global_position) > DETECT_RANGE * DETECT_RANGE * 4:
		target_mole = null

func _on_hurtbox_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		take_damage(1)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		body.take_damage(1, global_position, true)

func take_damage(amount: float) -> void:
	if health <= 0:
		return
	health -= amount
	SFX.play("enemy_hit", global_position)
	queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2, 1, 1, 1), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	if health <= 0:
		die()

func _draw() -> void:
	if health <= 0 or health >= MAX_HEALTH:
		return
	var bar_w := 96.0
	var bar_h := 12.0
	var offset := Vector2(-bar_w / 2, -80)
	var ratio := health / MAX_HEALTH

	draw_rect(Rect2(offset, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.15, 0.9))
	var fill := Color(1.0 * (1.0 - ratio) + 0.2 * ratio, 0.2 * (1.0 - ratio) + 0.8 * ratio, 0.2, 0.95)
	draw_rect(Rect2(offset, Vector2(bar_w * ratio, bar_h)), fill)

func die() -> void:
	SFX.play("enemy_death", global_position)
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.8, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_break_apart)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)

func _break_apart() -> void:
	visual.visible = false

	var frame_tex := visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
	var atlas := frame_tex as AtlasTexture
	var source_tex := atlas.atlas if atlas else frame_tex
	var source_region := atlas.region if atlas else Rect2(Vector2.ZERO, frame_tex.get_size())

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
