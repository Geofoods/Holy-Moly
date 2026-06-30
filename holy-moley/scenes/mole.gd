extends CharacterBody2D
const SPEED = 300.0
const JUMP_VELOCITY = -800
# Preload your MoleHole scene (adjust the path to match your project)
var mole_hole_scene := preload("res://scenes/molehole.tscn")
var mole_hole_instance: Node2D = null
var was_on_floor := true
func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		spawn_mole_hole()
	# Landing detection — was in air, now on floor
	if is_on_floor() and not was_on_floor:
		remove_mole_hole()
	was_on_floor = is_on_floor()
	# Movement
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		$AnimatedSprite2D.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()
	# Animation
	if not is_on_floor():
		if direction != 0:
			$AnimatedSprite2D.play("sidewaysjump")
		else:
			$AnimatedSprite2D.play("jump")
	elif direction != 0:
		$AnimatedSprite2D.play("walk")
	else:
		$AnimatedSprite2D.play("idle")
func spawn_mole_hole() -> void:
	remove_mole_hole()  # clean up any existing one first
	mole_hole_instance = mole_hole_scene.instantiate()
	mole_hole_instance.global_position = global_position
	get_parent().add_child(mole_hole_instance)
func remove_mole_hole() -> void:
	if mole_hole_instance and is_instance_valid(mole_hole_instance):
		mole_hole_instance.queue_free()
		mole_hole_instance = null
