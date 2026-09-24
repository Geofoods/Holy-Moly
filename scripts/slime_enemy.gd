extends CharacterBody2D

const GRAVITY := 1960.0
const DETECT_RANGE := 300.0
const JUMP_VELOCITY := -900.0
const JUMP_HORIZONTAL := 700.0
const HOP_VELOCITY := -460.0
const MAX_HEALTH := 10.0
const BIG_HEALTH := 26.0
const BIG_SCALE_MULT := 1.6
const BIG_CHANCE := 0.25

const EnemyDamage := preload("res://scripts/enemy.gd")
const SlimeScene := preload("res://scenes/slimeenemy.tscn")


@export var can_be_big := true

var health := MAX_HEALTH
var max_health := MAX_HEALTH
var is_big := false
var splits_on_death := false
var target_mole: Node2D = null
var was_on_floor := true
var has_landed := false
var _stun_timer := 0.0
var _mole_in_contact := false

@onready var hurtbox: Area2D = $Area2D
@onready var visual: Sprite2D = $Visual
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
var _health_bar: Node2D = null

func _ready() -> void:
	if can_be_big and randf() < BIG_CHANCE:
		is_big = true
		splits_on_death = true
		scale *= BIG_SCALE_MULT
		max_health = BIG_HEALTH
	health = max_health
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_body_entered)
	hurtbox.body_exited.connect(_on_body_exited)
	hurtbox.add_to_group("enemy_hurtbox")
	notifier.screen_entered.connect(_check_on_screen_hop)
	visual.z_index = 1
	_setup_health_bar()

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

func _check_on_screen_hop() -> void:
	if is_on_floor():
		velocity.y = HOP_VELOCITY
		SFX.play("jump", global_position, -12.0, 0.3)

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
	var parent = area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		var mole = get_tree().get_first_node_in_group("mole")
		if mole:
			var dir = (global_position - mole.global_position).normalized()
			velocity = dir * 600.0 + Vector2(0, -250)
			_stun_timer = 0.25
		take_damage(parent.get_damage())

## Direction the last hit pushed this enemy, so its death fragments are blown
## the same way (see spawn_death_fragments in enemy.gd).
var hit_direction := Vector2.ZERO

func take_damage(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	if direction != Vector2.ZERO:
		hit_direction = direction.normalized()
	if health <= 0:
		return
	health -= amount
	EnemyDamage.spawn_damage_number(self, amount)
	if _health_bar:
		_health_bar.queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2, 1, 1, 1), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	if health <= 0:
		die()

func _setup_health_bar() -> void:
	_health_bar = Node2D.new()
	_health_bar.name = "HealthBar"
	_health_bar.z_index = 10
	_health_bar.draw.connect(_draw_health_bar)
	add_child(_health_bar)

func _draw_health_bar() -> void:
	if health <= 0 or health >= max_health:
		return
	if not is_instance_valid(_health_bar):
		return
	var bar_w := 48.0
	var bar_h := 5.0
	var offset := Vector2(-bar_w / 2, -100)
	var ratio := health / max_health
	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.15, 0.9))
	var fill := Color(0.3 + 0.7 * ratio, 0.8, 0.3, 0.95)
	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w * ratio, bar_h)), fill)

func die() -> void:
	SFX.play("enemy_death", global_position)
	ComboManager.increment()
	Shop.drop_coins(global_position, randi_range(1, 2))
	if splits_on_death:
		_spawn_split_slimes()
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.8, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_break_apart)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)

func _spawn_split_slimes() -> void:
	for i in 2:
		var child: CharacterBody2D = SlimeScene.instantiate()
		child.can_be_big = false
		var offset_x := 30.0 if i == 0 else -30.0
		child.global_position = global_position + Vector2(offset_x, -16.0)
		child.velocity = Vector2(offset_x * 2.0, HOP_VELOCITY)
		get_parent().call_deferred("add_child", child)

func _break_apart() -> void:
	EnemyDamage.spawn_death_fragments(self, visual, hit_direction, scale.x)
