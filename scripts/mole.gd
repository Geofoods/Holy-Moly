extends CharacterBody2D

const SPEED = 350.0
const JUMP_VELOCITY = -800.0
const ACCELERATION = 1800.0
const FRICTION = 1800.0
const AIR_FRICTION = 800.0
const TUNNEL_SPEED = 1200.0
const TUNNEL_DURATION = 0.4


var mole_hole_scene := preload("res://scenes/molehole.tscn")
var default_trail_color := Color(0.45, 0.26, 0.13, 0.85)
var tunnel_trail_color := Color(0.6, 0.35, 0.15, 1.0)
@onready var particle_trail: GPUParticles2D = $ParticleTrail
@onready var dirt_spray: GPUParticles2D = $DirtSpray
var mole_hole_instance: Node2D = null
var was_on_floor := true
var is_sideways_jump := false
var is_digging := false
var is_tunneling := false
var tunnel_direction := 1.0
var invulnerable := false

var health: int = 6:
	set(value):
		health = clamp(value, 0, 6)
		if is_inside_tree():
			if health > 0:
				var heart_anim = get_parent().get_node_or_null("CanvasLayer/heart/AnimatedSprite2D")
				if heart_anim:
					heart_anim.play(str(health) + "hp")
			else:
				get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _ready() -> void:
	await get_tree().process_frame
	self.health = health
	add_to_group("mole")
	var ev_w = InputEventKey.new()
	ev_w.keycode = KEY_W
	InputMap.action_add_event("ui_accept", ev_w)
	
	var ev_up = InputEventKey.new()
	ev_up.keycode = KEY_UP
	InputMap.action_add_event("ui_accept", ev_up)
	
	var ev_a = InputEventKey.new()
	ev_a.keycode = KEY_A
	InputMap.action_add_event("ui_left", ev_a)
	
	var ev_d = InputEventKey.new()
	ev_d.keycode = KEY_D
	InputMap.action_add_event("ui_right", ev_d)

	if not InputMap.has_action("dig_dash"):
		InputMap.add_action("dig_dash")
		var ev_shift = InputEventKey.new()
		ev_shift.keycode = KEY_SHIFT
		InputMap.action_add_event("dig_dash", ev_shift)

const SURFACE_Y := 850.0

func update_depth_display() -> void:
	var label = get_parent().get_node_or_null("CanvasLayer/DepthLabel")
	if label:
		var depth := maxf(0.0, global_position.y - SURFACE_Y)
		label.text = "Depth: %dm" % int(depth)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_digging:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		move_and_slide()
		was_on_floor = is_on_floor()
		return
	elif is_tunneling:
		velocity.x = tunnel_direction * TUNNEL_SPEED
		move_and_slide()
		was_on_floor = is_on_floor()
		return

	if Input.is_action_just_pressed("dig_dash") and is_on_floor():
		start_dig_dash()
		return

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		spawn_mole_hole()
		var direction_at_jump := Input.get_axis("ui_left", "ui_right")
		is_sideways_jump = direction_at_jump != 0

	# Landing detection — was in air, now on floor
	if is_on_floor() and not was_on_floor:
		remove_mole_hole()
		is_sideways_jump = false

	was_on_floor = is_on_floor()

	# Movement
	var direction := Input.get_axis("ui_left", "ui_right")

	if direction:
		var accel = ACCELERATION if is_on_floor() else ACCELERATION * 0.6
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
		$AnimatedSprite2D.flip_h = direction < 0
	else:
		var friction = FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	# Upgrade to sideways jump mid-air (one-way, can't go back)
	if not is_on_floor() and not is_sideways_jump and direction != 0:
		is_sideways_jump = true

	move_and_slide()



	update_depth_display()

	# Animation
	if not is_on_floor():
		if is_sideways_jump:
			$AnimatedSprite2D.play("sidewaysjumpbold")
			$AnimatedSprite2D.flip_v = false
			var target_angle = atan2(velocity.y, abs(velocity.x))
			target_angle = clamp(target_angle, -PI / 4, PI / 4)
			if $AnimatedSprite2D.flip_h:
				target_angle = -target_angle
			$AnimatedSprite2D.rotation = lerp_angle($AnimatedSprite2D.rotation, target_angle, 0.15)
		else:
			$AnimatedSprite2D.play("jumpbold")
			$AnimatedSprite2D.flip_v = velocity.y > 0
			$AnimatedSprite2D.rotation = lerp_angle($AnimatedSprite2D.rotation, 0.0, 0.15)
	else:
		$AnimatedSprite2D.flip_v = false
		$AnimatedSprite2D.rotation = lerp_angle($AnimatedSprite2D.rotation, 0.0, 0.3)
		if direction != 0:
			$AnimatedSprite2D.play("walkbold")
		else:
			$AnimatedSprite2D.play("idlebold")


func spawn_mole_hole() -> void:
	remove_mole_hole()
	mole_hole_instance = mole_hole_scene.instantiate()
	mole_hole_instance.global_position = global_position
	get_parent().add_child(mole_hole_instance)


func remove_mole_hole() -> void:
	if mole_hole_instance and is_instance_valid(mole_hole_instance):
		mole_hole_instance.queue_free()
		mole_hole_instance = null

func take_damage(amount: int) -> void:
	if invulnerable or health <= 0:
		return
	health -= amount
	invulnerable = true
	var tween := create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate:a", 0.4, 0.1)
	get_tree().create_timer(1.0).timeout.connect(_end_invulnerability)

func _end_invulnerability() -> void:
	invulnerable = false
	var tween := create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate:a", 1.0, 0.1)

func start_dig_dash() -> void:
	is_digging = true
	if has_node("Weapon"):
		$Weapon.hide()
	$AnimatedSprite2D.play("dig")
	
	tunnel_direction = -1.0 if $AnimatedSprite2D.flip_h else 1.0
	
	await $AnimatedSprite2D.animation_finished
	
	if not is_digging:
		return
		
	is_digging = false
	is_tunneling = true
	$AnimatedSprite2D.play("tunnel")
	
	await get_tree().create_timer(TUNNEL_DURATION).timeout
	
	if not is_tunneling:
		return
		
	is_tunneling = false
	velocity.x = 0
	velocity.y = JUMP_VELOCITY
	if has_node("Weapon"):
		$Weapon.show()
	$AnimatedSprite2D.play("jumpbold")
