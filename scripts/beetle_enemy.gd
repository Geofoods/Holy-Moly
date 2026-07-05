extends CharacterBody2D

enum State { PATROL, CHARGING, RUSHING, COOLDOWN }

const PATROL_SPEED := 120.0
const RUSH_SPEED := 1100.0
const GRAVITY := 1960.0
const DETECT_RANGE := 350.0
const CHARGE_UP_DURATION := 1.5
const RUSH_DURATION := 0.6
const COOLDOWN_DURATION := 1.25
const MAX_HEALTH := 4.0
const TURN_COOLDOWN := 0.35

var state := State.PATROL
var direction := 1.0
var target_mole: Node2D = null
var charge_timer := 0.0
var rush_timer := 0.0
var cooldown_timer := 0.0
var health := MAX_HEALTH
var was_on_floor := true
var _charge_tween: Tween = null
var _move_sfx_timer := 0.0
const MOVE_SFX_INTERVAL := 0.35
var _charge_sfx_timer := 0.0
var _stun_timer := 0.0
var _turn_cooldown_timer := 0.0
var _mole_in_contact := false
@onready var hurtbox: Area2D = $Area2D
@onready var visual: AnimatedSprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_body_entered)
	hurtbox.body_exited.connect(_on_body_exited)
	hurtbox.add_to_group("enemy_hurtbox")
	visual.z_index = 1
	visual.play()

func _physics_process(delta: float) -> void:
	_find_target()
	_turn_cooldown_timer -= delta

	if _stun_timer > 0.0:
		_stun_timer -= delta
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		_update_visual_direction()
		return

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHARGING:
			_charge_up(delta)
		State.RUSHING:
			_rush(delta)
		State.COOLDOWN:
			_cooldown(delta)

	move_and_slide()
	_update_visual_direction()
	_play_move_sound(delta)

	if state == State.RUSHING:
		_break_tiles_on_collision()

	was_on_floor = is_on_floor()

func _patrol(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = direction * PATROL_SPEED

	if is_on_wall() and _turn_cooldown_timer <= 0.0:
		direction *= -1
		_turn_cooldown_timer = TURN_COOLDOWN

	if target_mole:
		var dist: float = global_position.distance_squared_to(target_mole.global_position)
		if dist < DETECT_RANGE * DETECT_RANGE and _has_line_of_sight(target_mole):
			_start_charge()

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

func _charge_up(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0

	charge_timer -= delta
	visual.offset.x = randf_range(-3.0, 3.0)
	visual.offset.y = randf_range(-1.5, 1.5)

	_charge_sfx_timer -= delta
	if _charge_sfx_timer <= 0.0:
		var progress := 1.0 - (charge_timer / CHARGE_UP_DURATION)
		var interval := lerpf(0.3, 0.08, progress)
		var pitch := lerpf(0.8, 1.6, progress)
		_charge_sfx_timer = interval
		SFX.play("bomb_tick", global_position, -12.0, pitch)

	if charge_timer <= 0.0:
		visual.offset = Vector2.ZERO
		if _charge_tween and _charge_tween.is_valid():
			_charge_tween.kill()
		modulate = Color.WHITE
		state = State.RUSHING
		rush_timer = RUSH_DURATION
		SFX.play("dig_dash", global_position, -6.0, 0.1)

func _start_charge() -> void:
	state = State.CHARGING
	charge_timer = CHARGE_UP_DURATION
	_charge_sfx_timer = 0.0
	direction = sign(target_mole.global_position.x - global_position.x)
	velocity.x = 0.0

	if _charge_tween and _charge_tween.is_valid():
		_charge_tween.kill()
	_charge_tween = create_tween()
	_charge_tween.set_loops(0)
	_charge_tween.tween_property(self, "modulate", Color(1.8, 0.3, 0.3, 1), 0.08)
	_charge_tween.tween_property(self, "modulate", Color(1.0, 0.6, 0.6, 1), 0.08)

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

func _play_move_sound(delta: float) -> void:
	if health <= 0 or velocity.x == 0.0:
		return
	_move_sfx_timer -= delta
	if _move_sfx_timer <= 0.0:
		if state == State.RUSHING:
			_move_sfx_timer = 0.15
			SFX.play("land", global_position, -10.0, 0.2)
		else:
			_move_sfx_timer = MOVE_SFX_INTERVAL
			SFX.play("land", global_position, -16.0, 0.5)

func _update_visual_direction() -> void:
	var dir: float = sign(velocity.x) if velocity.x != 0.0 else direction
	visual.scale.x = -abs(visual.scale.x) * sign(dir)

func _has_line_of_sight(target: Node2D) -> bool:
	if abs(target.global_position.y - global_position.y) > 80.0:
		return false
	var ray_end := Vector2(target.global_position.x, global_position.y)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, ray_end, 1)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.collider == target or result.collider == target.get_parent()

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
		var mole = get_tree().get_first_node_in_group("mole")
		if mole:
			var dir = (global_position - mole.global_position).normalized()
			velocity = dir * 600.0 + Vector2(0, -250)
			_stun_timer = 0.25
		take_damage(1)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole") and not _mole_in_contact:
		_mole_in_contact = true
		body.take_damage(1, global_position, true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_in_contact = false

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
	if _charge_tween and _charge_tween.is_valid():
		_charge_tween.kill()
	visual.offset = Vector2.ZERO
	SFX.play("enemy_death", global_position)
	ComboManager.increment()
	ScoreManager.add_kill(2, global_position)
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
