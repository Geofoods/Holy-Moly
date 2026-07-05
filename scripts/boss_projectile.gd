extends Area2D

const LIFETIME := 4.0
const EXPLOSION_TILE_RADIUS := 1

var velocity := Vector2.ZERO
var _rotation_speed := randf_range(2.0, 5.0) * (1 if randi() % 2 == 0 else -1)
var _pulse_phase := randf() * TAU

func setup(vel: Vector2) -> void:
	velocity = vel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(_explode)
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	if sprite:
		sprite.play("default")

func _process(delta: float) -> void:
	rotation += _rotation_speed * delta
	_pulse_phase += delta * 4.0
	var pulse := 1.0 + sin(_pulse_phase) * 0.08
	scale = Vector2(0.3, 0.3) * pulse

func _physics_process(delta: float) -> void:
	position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole") and body.has_method("take_damage"):
		body.take_damage(1, global_position, true, true)
	_explode()

func _explode() -> void:
	SFX.play("explosion", global_position)
	_spawn_explosion_particles()
	_break_tiles()
	queue_free()

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
	var grad_tex := GradientTexture2D.new()
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
	var sfx := load("res://scripts/tile_break_sfx.gd") as GDScript
	var center := tilemap.local_to_map(tilemap.to_local(global_position))
	for dx in range(-EXPLOSION_TILE_RADIUS, EXPLOSION_TILE_RADIUS + 1):
		for dy in range(-EXPLOSION_TILE_RADIUS, EXPLOSION_TILE_RADIUS + 1):
			var tp := Vector2i(center.x + dx, center.y + dy)
			sfx.break_tile(tilemap, tp, get_parent(), true)
