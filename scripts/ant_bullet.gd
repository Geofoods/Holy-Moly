extends Area2D

const SPEED := 500
const DEFLECTED_SPEED := 1000
const SLOW_DURATION := 3.0
const LIFETIME := 8.0
const SPAWN_GRACE := 0.25
## Pellet-sized pop, so the ground burst reads as a spark rather than a blast.
const GROUND_BLAST_POWER := 0.5

var direction := Vector2.ZERO
var deflected := false
var source_ant: Node2D = null
var _elapsed := 0.0
var _active := false

func _ready() -> void:
	add_to_group("bullet")
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_build_visual()

func _build_visual() -> void:
	var trail := CPUParticles2D.new()
	trail.emitting = true
	trail.amount = 6
	trail.lifetime = 0.3
	trail.explosiveness = 0.0
	trail.direction = Vector2.ZERO
	trail.spread = 180.0
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 30.0
	trail.scale_amount_min = 6.0
	trail.scale_amount_max = 12.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.5, 0.0, 0.7))
	grad.set_color(1, Color(1.0, 0.3, 0.0, 0.0))
	trail.color_ramp = grad
	add_child(trail)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _active and _elapsed >= SPAWN_GRACE:
		_active = true
		collision_mask = 1
		monitoring = true
	if _elapsed >= LIFETIME:
		queue_free()
		return
	var spd := DEFLECTED_SPEED if deflected else SPEED
	global_position += direction * spd * delta
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func deflect(target_pos: Vector2) -> void:
	if deflected:
		return
	deflected = true
	collision_mask = 4
	if source_ant and is_instance_valid(source_ant):
		direction = (source_ant.global_position - global_position).normalized()
	else:
		direction = (target_pos - global_position).normalized()
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.modulate = Color(0.5, 0.8, 1.0, 1.0)

func _on_body_entered(body: Node) -> void:
	if deflected:
		if body == source_ant:
			if body.has_method("die"):
				body.die()
			queue_free()
			return
		if body.has_method("take_damage") and body != source_ant and not body.is_in_group("mole"):
			body.take_damage(5)
			queue_free()
			return
		if body is TileMap:
			_pop()
			return
	else:
		if body.is_in_group("mole"):
			if body.has_method("apply_slow"):
				body.apply_slow(SLOW_DURATION)
			queue_free()
			return
		if body is TileMap:
			_pop()
			return

func _on_area_entered(area: Area2D) -> void:
	if not deflected:
		return
	var parent = area.get_parent()
	if parent == source_ant and parent.has_method("die"):
		parent.die()
		queue_free()

## Dying on impact with the world: a small burst of fire at the impact point
## plus a quiet explosion cue, then the pellet is gone.
func _pop() -> void:
	_spawn_ground_blast(global_position)
	queue_free()

func _spawn_ground_blast(world_pos: Vector2) -> void:
	var power := GROUND_BLAST_POWER
	SFX.play("explosion", world_pos, -16.0, 0.25)
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = int(28 * power)
	particles.lifetime = 0.6
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.initial_velocity_min = 130.0 * power
	particles.initial_velocity_max = 430.0 * power
	particles.gravity = Vector2(0, 420)
	particles.damping_min = 120.0
	particles.damping_max = 260.0
	particles.scale_amount_min = 4.0 * power
	particles.scale_amount_max = 8.0 * power
	particles.color = Color(1.0, 0.55, 0.15, 1.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	gradient.set_color(1, Color(0.45, 0.12, 0.04, 0.0))
	particles.color_ramp = gradient
	get_parent().add_child(particles)
	particles.global_position = world_pos
	get_tree().create_timer(particles.lifetime + 0.4).timeout.connect(particles.queue_free)
