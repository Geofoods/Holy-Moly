extends CharacterBody2D

## Bounce Mushroom: thrown into the air, it plops onto the floor, then acts as a
## springy pad. The mole (and enemies) bounce high off it. Fades away after a while.

const GRAVITY := 900.0
const BOUNCE_VELOCITY := -1650.0
const ENEMY_BOUNCE_VELOCITY := -1300.0
const LIFETIME := 20.0
const ACTIVATE_DELAY := 0.9

var _time := 0.0
var _active := false

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(60, 14)
	shape.shape = box
	shape.position = Vector2(0, 4)
	add_child(shape)

	var area := Area2D.new()
	_attach_contact(area)
	add_child(area)
	var area_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 55.0
	area_shape.shape = circle
	area_shape.position = Vector2(0, -4)
	area.add_child(area_shape)

	var mole := get_tree().get_first_node_in_group("mole")
	if mole:
		add_collision_exception_with(mole)

func _attach_contact(area: Area2D) -> void:
	area.body_entered.connect(_on_area_body_entered)

func _physics_process(delta: float) -> void:
	_time += delta
	if not _active:
		velocity.y += GRAVITY * delta
		move_and_slide()
		if is_on_floor() and _time > ACTIVATE_DELAY:
			_activate()
		if _time > ACTIVATE_DELAY + 0.3:
			_activate()
		queue_redraw()
		return

	if _time >= LIFETIME:
		_wilt()
		return
	queue_redraw()

func _activate() -> void:
	_active = true
	velocity = Vector2.ZERO

func _on_area_body_entered(body: Node) -> void:
	if not _active or body == null or not is_instance_valid(body):
		return
	if body.is_in_group("mole"):
		var b := body as CharacterBody2D
		if b.velocity.y > 40.0 or _was_falling(b):
			b.velocity = Vector2(b.velocity.x * 0.3, BOUNCE_VELOCITY)
			_squish_anim(Color(1.0, 0.85, 0.8, 1.0))
			SFX.play("jump", global_position, -4.0, 0.1, 1.3)
	elif "_stun_timer" in body:
		if body.velocity.y > 40.0:
			body.velocity = Vector2(body.velocity.x * 0.3, ENEMY_BOUNCE_VELOCITY)
			body._stun_timer = maxf(body._stun_timer, 0.2)
			_squish_anim(Color(0.8, 0.7, 0.8, 1.0))

func _was_falling(b: CharacterBody2D) -> bool:
	return not b.is_on_floor()

func _squish_anim(tint: Color) -> void:
	modulate = tint
	scale = Vector2(0.85, 1.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 0.9), 0.1)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)
	tw.parallel().tween_property(self, "modulate", Color.WHITE, 0.15)

func _wilt() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(self, "scale", Vector2(1.2, 0.3), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
	set_physics_process(false)

func _draw() -> void:
	draw_circle(Vector2(0, -12), 26.0, Color(0.9, 0.25, 0.2, 1.0))
	draw_circle(Vector2(-9, -20), 9.0, Color(1.0, 0.95, 0.85, 1.0))
	draw_circle(Vector2(9, -16), 7.0, Color(1.0, 0.95, 0.85, 1.0))
	draw_rect(Rect2(-9, -6, 18, 12), Color(0.93, 0.93, 0.82, 1.0))
	draw_rect(Rect2(-11, 2, 22, 8), Color(0.85, 0.3, 0.2, 1.0))