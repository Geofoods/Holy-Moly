extends CharacterBody2D

const AIR_GRAVITY = 2450.0

@export var move_speed := 45.0
@export var patrol_distance := 150.0

var _start_x: float
var _direction := -1.0
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_start_x = global_position.x
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("walk"):
		_sprite.play("walk")
	_update_facing()

func _physics_process(delta: float) -> void:
	velocity.y += AIR_GRAVITY * delta
	velocity.x = move_speed * _direction
	move_and_slide()
	if is_on_floor() and absf(global_position.x - _start_x) >= patrol_distance:
		_turn_around()

func _turn_around() -> void:
	_direction *= -1.0
	_update_facing()

func _update_facing() -> void:
	if _sprite:
		_sprite.flip_h = _direction < 0.0