extends Area2D

const LIFETIME = 3.0
const DEFLECT_SPEED_MULT = 1.4

var velocity := Vector2.ZERO
var deflected := false

func setup(vel: Vector2) -> void:
	velocity = vel

func _ready() -> void:
	add_to_group("bullet")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	SFX.play("enemy_fire", global_position)

func _physics_process(delta: float) -> void:
	position += velocity * delta

func deflect(target_pos: Vector2) -> void:
	deflected = true
	var dir := (target_pos - global_position).normalized()
	velocity = dir * velocity.length() * DEFLECT_SPEED_MULT
	var visual := get_node_or_null("Visual") as ColorRect
	if visual:
		visual.color = Color(0.6, 0.9, 1.0, 1.0)

func _on_body_entered(body: Node) -> void:
	if deflected:
		if body.has_method("die"):
			body.die()
			queue_free()
		elif body is StaticBody2D:
			queue_free()
	else:
		if body.is_in_group("mole"):
			if body.has_method("take_damage"):
				body.take_damage(0.5, global_position, true, true)
			queue_free()
		elif body is StaticBody2D:
			queue_free()

func _on_area_entered(area: Area2D) -> void:
	if deflected and area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy.has_method("die"):
			enemy.die()
		queue_free()
