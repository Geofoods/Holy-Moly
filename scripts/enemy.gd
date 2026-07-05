extends CharacterBody2D

signal died

const SPEED = 160.0
const CLIMB_SPEED = 140.0
const GRAVITY = 1960.0
const CLIMB_DURATION = 0.6
const DETECT_RANGE := 300.0
const CLIMB_CHANCE = 0.4
const MAX_HEALTH := 3.0
const SHOOT_INTERVAL := 5.0

var direction := 1.0
var target_mole: Node2D = null
var is_climbing := false
var climb_timer := 0.0
var health := MAX_HEALTH
var _move_sfx_timer := 0.0
var _shoot_timer := SHOOT_INTERVAL
var _stun_timer := 0.0
const MOVE_SFX_INTERVAL := 0.4
var ant_bullet_scene := preload("res://scenes/ant_bullet.tscn")
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var visual: AnimatedSprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hurtbox.add_to_group("enemy_hurtbox")
	visual.z_index = 1
	visual.play()

func _physics_process(delta: float) -> void:
	_find_target()

	if _stun_timer > 0.0:
		_stun_timer -= delta
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		_update_visual_direction()
		return

	if is_climbing:
		climb_timer -= delta
		velocity.y = -CLIMB_SPEED
		velocity.x = direction * SPEED * 0.3
		if climb_timer <= 0.0 or is_on_ceiling():
			is_climbing = false
		move_and_slide()
		_update_visual_direction()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = direction * SPEED

	if is_on_wall():
		if randf() < CLIMB_CHANCE:
			is_climbing = true
			climb_timer = CLIMB_DURATION
		else:
			direction *= -1

	move_and_slide()
	_update_visual_direction()
	_play_move_sound(delta)
	_update_shooting(delta)

func _update_shooting(delta: float) -> void:
	if health <= 0:
		return
	var mole = get_tree().get_first_node_in_group("mole")
	if not mole or not is_instance_valid(mole):
		return
	var dist := global_position.distance_to(mole.global_position)
	if dist > 1000.0 or dist < 120.0:
		return
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = SHOOT_INTERVAL
		_shoot_bullet(mole)

func _shoot_bullet(target: Node2D) -> void:
	SFX.play("enemy_fire", global_position, -4.0, 0.2)
	SFX.play("parry_activate", global_position, -14.0, 0.6)
	var bullet = ant_bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector2(0, -20)
	bullet.direction = (target.global_position - global_position).normalized()
	bullet.source_ant = self

func _play_move_sound(delta: float) -> void:
	if health <= 0 or velocity.x == 0.0:
		return
	_move_sfx_timer -= delta
	if _move_sfx_timer <= 0.0:
		_move_sfx_timer = MOVE_SFX_INTERVAL
		SFX.play("land", global_position, -18.0, 0.4)

func _update_visual_direction() -> void:
	var dir = sign(velocity.x) if velocity.x != 0.0 else direction
	visual.scale.x = -abs(visual.scale.x) * sign(dir)

func _find_target() -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
		if target_mole:
			add_collision_exception_with(target_mole)
	elif global_position.distance_squared_to(target_mole.global_position) > DETECT_RANGE * DETECT_RANGE:
		target_mole = null

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		body.take_damage(1, global_position, true)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area == hitbox or not area.monitoring:
		return
	var parent = area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		var mole = get_tree().get_first_node_in_group("mole")
		if mole:
			var dir = (global_position - mole.global_position).normalized()
			velocity = dir * 600.0 + Vector2(0, -250)
			_stun_timer = 0.25
		take_damage(1)

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
	var offset := Vector2(-bar_w / 2, -70)
	var ratio := health / MAX_HEALTH

	draw_rect(Rect2(offset, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.15, 0.9))
	var fill := Color(1.0 * (1.0 - ratio) + 0.2 * ratio, 0.2 * (1.0 - ratio) + 0.8 * ratio, 0.2, 0.95)
	draw_rect(Rect2(offset, Vector2(bar_w * ratio, bar_h)), fill)

func die() -> void:
	died.emit()
	SFX.play("enemy_death", global_position)
	ComboManager.increment()
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
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
