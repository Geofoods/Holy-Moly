extends Area2D

const LIFETIME := 2.0
const EXPLOSION_TILE_RADIUS := 1
const TileBreakSfx = preload("res://scripts/tile_break_sfx.gd")

var velocity := Vector2.ZERO
var deflected := false
var _rotation_speed := randf_range(2.0, 5.0) * (1 if randi() % 2 == 0 else -1)
var _pulse_phase := randf() * TAU

func setup(vel: Vector2) -> void:
	velocity = vel

func _ready() -> void:
	add_to_group("bullet")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(_explode)
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	if sprite:
		sprite.play("default")

func _process(delta: float) -> void:
	_pulse_phase += delta * 8.0
	var pulse := 1.0 + sin(_pulse_phase) * 0.08
	scale = Vector2(0.3, 0.3) * pulse

func _physics_process(delta: float) -> void:
	position += velocity * delta

func deflect(target_pos: Vector2) -> void:
	deflected = true
	var dir := (target_pos - global_position).normalized()
	velocity = dir * velocity.length() * 1.4
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	if sprite:
		sprite.modulate = Color(0.6, 0.9, 1.0, 1.0)

func _on_area_entered(area: Area2D) -> void:
	if deflected and area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(5)
		elif enemy.has_method("die"):
			enemy.die()
		queue_free()

func _on_body_entered(body: Node) -> void:
	if deflected:
		if body.has_method("die"):
			body.die()
			queue_free()
			return
		elif body is StaticBody2D:
			queue_free()
			return
	if body.is_in_group("mole") and body.has_method("take_damage"):
		body.take_damage(1, global_position, true, true)
	_explode()

func _explode() -> void:
	SFX.play("explosion", global_position)
	_spawn_explosion_particles()
	_break_tiles()
	set_physics_process(false)
	set_process(false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", scale * 3.0, 0.4)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)

func _spawn_explosion_particles() -> void:
	var particles := GPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.ZERO
	material.spread = 180.0
	material.initial_velocity_min = 150.0
	material.initial_velocity_max = 350.0
	material.gravity = Vector3(0, 200, 0)
	material.scale_min = 2.0
	material.scale_max = 6.0
	material.color = Color(0.7, 0.3, 1.0, 1)
	var fade := Gradient.new()
	fade.set_color(0, Color(0.9, 0.4, 1.0, 1))
	fade.set_color(1, Color(0.5, 0.1, 0.7, 0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = fade
	material.color_ramp = grad_tex
	particles.process_material = material
	get_parent().add_child(particles)
	particles.global_position = global_position
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func _break_tiles() -> void:
	var tilemap: TileMap = get_parent().get_node_or_null("TileMap") as TileMap
	if not tilemap:
		return
	var center := tilemap.local_to_map(tilemap.to_local(global_position))
	for dx in range(-EXPLOSION_TILE_RADIUS, EXPLOSION_TILE_RADIUS + 1):
		for dy in range(-EXPLOSION_TILE_RADIUS, EXPLOSION_TILE_RADIUS + 1):
			var tp := Vector2i(center.x + dx, center.y + dy)
			TileBreakSfx.break_tile(tilemap, tp, get_parent(), true)
