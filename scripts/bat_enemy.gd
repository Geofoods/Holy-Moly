extends CharacterBody2D

const SPEED = 150.0
const SINE_AMPLITUDE = 80.0
const SINE_FREQUENCY = 2.5
const DETECT_RANGE = 400.0
const SWOOP_SPEED = 250.0

var direction := 1.0
var sine_time := 0.0
var base_y := 0.0
var swooping := false
var target_mole: Node2D = null

@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	base_y = global_position.y
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hurtbox.add_to_group("enemy_hurtbox")

func _physics_process(delta: float) -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")

	var dist := INF
	if target_mole != null:
		dist = global_position.distance_to(target_mole.global_position)

	swooping = target_mole != null and dist < DETECT_RANGE

	if swooping and target_mole != null:
		var swoop_dir := (target_mole.global_position - global_position).normalized()
		velocity = swoop_dir * SWOOP_SPEED
		base_y = global_position.y
		sine_time = 0.0
	else:
		sine_time += delta
		velocity.x = direction * SPEED
		var target_y := base_y + sin(sine_time * SINE_FREQUENCY) * SINE_AMPLITUDE
		velocity.y = (target_y - global_position.y) / maxf(delta, 0.001)

	if is_on_wall():
		direction *= -1.0

	visual.flip_h = velocity.x < 0 if velocity.x != 0 else direction < 0

	move_and_slide()

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		body.take_damage(1, global_position, true)

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	die()

func die() -> void:
	SFX.play("enemy_death", global_position)
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
