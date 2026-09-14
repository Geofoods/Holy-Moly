extends Area2D

## A glob of venom spat by a Cave Snake. Deals light damage and poisons/slows
## the mole on contact. Like other bullets it can be parried back at enemies.

const SPEED := 430.0
const DEFLECTED_SPEED := 950.0
const LIFETIME := 6.0
const SPAWN_GRACE := 0.2
const VENOM_SLOW_DURATION := 4.0
const VENOM_DAMAGE := 0.5

var direction := Vector2.ZERO
var deflected := false
var source_snake: Node2D = null
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
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 1.0, 0.3, 1.0))
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex
	add_child(sprite)

	var trail := CPUParticles2D.new()
	trail.emitting = true
	trail.amount = 6
	trail.lifetime = 0.3
	trail.explosiveness = 0.0
	trail.direction = Vector2.ZERO
	trail.spread = 180.0
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 30.0
	trail.scale_amount_min = 5.0
	trail.scale_amount_max = 11.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.6, 1.0, 0.3, 0.7))
	grad.set_color(1, Color(0.3, 0.8, 0.15, 0.0))
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

func deflect(target_pos: Vector2) -> void:
	if deflected:
		return
	deflected = true
	collision_mask = 4
	if source_snake and is_instance_valid(source_snake):
		direction = (source_snake.global_position - global_position).normalized()
	else:
		direction = (target_pos - global_position).normalized()
	var sprite = get_node_or_null("Sprite")
	if sprite:
		sprite.modulate = Color(0.5, 0.8, 1.0, 1.0)

func _on_body_entered(body: Node) -> void:
	if deflected:
		if body == source_snake:
			if body.has_method("die"):
				body.die()
			queue_free()
			return
		if body.has_method("take_damage") and body != source_snake and not body.is_in_group("mole"):
			body.take_damage(5)
			queue_free()
			return
		if body is TileMap:
			queue_free()
			return
	else:
		if body.is_in_group("mole"):
			if body.has_method("take_damage"):
				body.take_damage(VENOM_DAMAGE, global_position, true, true)
			if body.has_method("apply_slow"):
				body.apply_slow(VENOM_SLOW_DURATION)
			SFX.play("hurt", global_position, -6.0, 0.9)
			queue_free()
			return
		if body is TileMap:
			queue_free()
			return

func _on_area_entered(area: Area2D) -> void:
	if not deflected:
		return
	var parent = area.get_parent()
	if parent == source_snake and parent.has_method("die"):
		parent.die()
		queue_free()