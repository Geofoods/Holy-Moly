extends CharacterBody2D
const SPEED = 120.0
const GRAVITY = 980.0
const DETECT_RANGE_X = 500.0
const DETECT_RANGE_Y = 80.0
const FIRE_INTERVAL = 1.6
const BULLET_SPEED = 500.0
const MUZZLE_OFFSET = Vector2(96.0, -47.0)

var direction := 1.0
var facing := 1.0
var fire_timer := FIRE_INTERVAL * 0.5
var target_mole: Node2D = null

var bullet_scene := preload("res://scenes/bullet.tscn")

@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var ray_right: RayCast2D = $RayRight
@onready var ray_left: RayCast2D = $RayLeft
@onready var visual: CanvasItem = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hurtbox.add_to_group("enemy_hurtbox")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	velocity.x = direction * SPEED

	# Reverse at walls or edges
	if is_on_wall():
		direction *= -1.0
	elif is_on_floor():
		if direction > 0 and ray_right.is_colliding() == false:
			direction *= -1.0
		elif direction < 0 and ray_left.is_colliding() == false:
			direction *= -1.0

	facing = direction
	_update_targeting(delta)

	visual.scale.x = abs(visual.scale.x) * sign(facing)

	move_and_slide()

func _update_targeting(delta: float) -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")

	fire_timer -= delta

	if target_mole == null:
		return

	var offset: Vector2 = target_mole.global_position - global_position
	var in_range: bool = abs(offset.x) < DETECT_RANGE_X and abs(offset.y) < DETECT_RANGE_Y

	if in_range:
		if offset.x != 0.0:
			facing = sign(offset.x)
		if fire_timer <= 0.0:
			fire_timer = FIRE_INTERVAL
			_fire_at(target_mole)

func _fire_at(target: Node2D) -> void:
	var muzzle: Vector2 = global_position + Vector2(MUZZLE_OFFSET.x * facing, MUZZLE_OFFSET.y)
	var fire_dir: float = sign(target.global_position.x - muzzle.x)
	if fire_dir == 0.0:
		fire_dir = facing

	var bullet := bullet_scene.instantiate()
	bullet.global_position = muzzle
	bullet.setup(Vector2(fire_dir, 0.0) * BULLET_SPEED)
	get_parent().add_child(bullet)

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		body.take_damage(1, global_position, true)

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	die()

func die() -> void:
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.05)
	tween.tween_property(visual, "modulate", Color(0.7, 0.2, 1.0), 0.05)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
