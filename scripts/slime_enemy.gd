extends CharacterBody2D

const GRAVITY := 1960.0
const DETECT_RANGE := 300.0
const JUMP_VELOCITY := -900.0
const JUMP_HORIZONTAL := 700.0
const MAX_HEALTH := 1.0


var health := MAX_HEALTH
var target_mole: Node2D = null
var was_on_floor := true
var has_landed := false
var _stun_timer := 0.0
var _mole_in_contact := false

@onready var hurtbox: Area2D = $Area2D
@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_body_entered)
	hurtbox.body_exited.connect(_on_body_exited)
	hurtbox.add_to_group("enemy_hurtbox")

func _physics_process(delta: float) -> void:
	_find_target()

	if _stun_timer > 0.0:
		_stun_timer -= delta
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		was_on_floor = is_on_floor()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_on_floor() and not was_on_floor:
		_land()

	move_and_slide()
	was_on_floor = is_on_floor()

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

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole") and not _mole_in_contact:
		_mole_in_contact = true
		body.take_damage(1, global_position, true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_in_contact = false

func _on_hurtbox_area_entered(area: Area2D) -> void:
	var parent: Node = area.get_parent()
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
	ScoreManager.add_kill(1, global_position)
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.8, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_break_apart)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)

func _break_apart() -> void:
	visual.visible = false

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
