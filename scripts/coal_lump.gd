extends RigidBody2D

## Coal Lump: a throwable lump of coal that bounces off walls and knocks the
## first enemy it hits flying. Disappears after a few bounces.

const BOUNCES := 4
const LIFETIME := 5.0
const HIT_DAMAGE := 6.0
const HIT_KNOCKBACK := 900.0

var _bounces := 0
var _time := 0.0

func _ready() -> void:
	linear_velocity = Vector2.ZERO
	contact_monitor = true
	max_contacts_reported = 8
	collision_layer = 1
	collision_mask = 3
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.7
	pm.friction = 0.2
	physics_material_override = pm
	body_entered.connect(_on_body_entered)
	gravity_scale = 1.0

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)

	var mole = get_tree().get_first_node_in_group("mole")
	if mole and mole is CollisionObject2D:
		add_collision_exception_with(mole)

## Called by the mole when thrown; coal doesn't need a fuse.
func arm() -> void:
	pass

func _process(delta: float) -> void:
	_time += delta
	if _time > LIFETIME:
		_fizzle()
		return
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.is_in_group("mole"):
		return
	if body.has_method("take_damage"):
		_hit_enemy(body)
	elif body.has_method("die"):
		_hit_enemy(body)
	else:
		_bounces += 1
		if _bounces >= BOUNCES:
			_fizzle()

func _hit_enemy(enemy: Node) -> void:
	SFX.play("enemy_hit", global_position)
	if enemy.has_method("take_damage"):
		enemy.take_damage(HIT_DAMAGE)
	var dir := ((enemy as Node2D).global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	dir = Vector2(signf(dir.x), -0.35).normalized()
	if enemy is CharacterBody2D:
		(enemy as CharacterBody2D).velocity = dir * HIT_KNOCKBACK
	if "_stun_timer" in enemy:
		enemy._stun_timer = maxf(enemy._stun_timer, 0.35)
	_fizzle()

func _fizzle() -> void:
	var puff := CPUParticles2D.new()
	puff.emitting = true
	puff.one_shot = true
	puff.amount = 14
	puff.lifetime = 0.4
	puff.explosiveness = 1.0
	puff.direction = Vector2.ZERO
	puff.spread = 180.0
	puff.initial_velocity_min = 60.0
	puff.initial_velocity_max = 180.0
	puff.scale_amount_min = 4.0
	puff.scale_amount_max = 9.0
	puff.color = Color(0.25, 0.22, 0.2, 0.9)
	puff.z_index = 4
	var scene := get_parent()
	if scene:
		scene.add_child(puff)
		puff.global_position = global_position
		get_tree().create_timer(0.6).timeout.connect(puff.queue_free)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.18, 0.16, 1.0))
	draw_circle(Vector2(-6, -7), 7.0, Color(0.35, 0.32, 0.28, 1.0))
	draw_circle(Vector2(7, 2), 5.0, Color(0.3, 0.27, 0.24, 1.0))
	draw_circle(Vector2(-3, 8), 4.0, Color(0.15, 0.13, 0.12, 1.0))