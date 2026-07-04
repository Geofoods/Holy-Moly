extends CharacterBody2D

const SPEED = 350.0
const JUMP_VELOCITY = -800.0
const ACCELERATION = 1800.0
const FRICTION = 1800.0
const AIR_FRICTION = 800.0
const TUNNEL_SPEED = 1200.0
const TUNNEL_DURATION = 0.4
const HURT_GROUND_DURATION = 0.25
const HURT_AIR_DURATION = 0.35
const KNOCKBACK_X = 260.0
const MIDAIR_SPRITE_DELAY = 0.25
const CAMERA_FOLLOW_SPEED = 10.0
const CAMERA_MOUSE_INFLUENCE = 0.2


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
var hurt_anim_time_left := 0.0
var air_time := 0.0
var launched_from_jump := false

var health: float = 6.0:
	set(value):
		var old_health := health
		health = clamp(value, 0, 6)
		if is_inside_tree():
			if health > 0:
				var heart_node = get_parent().get_node_or_null("CanvasLayer/heart")
				if heart_node:
					var heart_anim = heart_node.get_node_or_null("AnimatedSprite2D")
					if heart_anim:
						heart_anim.play(str(int(health)) + "hp")
					if health < old_health:
						_animate_heart_damage(heart_node)
			else:
				set_physics_process(false)
				var transition := preload("res://scenes/scene_transition.tscn").instantiate()
				get_tree().root.add_child(transition)
				transition.change_to("res://scenes/game_over.tscn")

var tilemap: TileMap = null
var _heart_base_scale := Vector2.ONE

func _animate_heart_damage(heart_node: Node2D) -> void:
	if _heart_base_scale == Vector2.ONE:
		_heart_base_scale = heart_node.scale
	var tween := create_tween()
	tween.tween_property(heart_node, "scale", _heart_base_scale * 0.75, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(heart_node, "scale", _heart_base_scale * 1.1, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(heart_node, "scale", _heart_base_scale, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _ready() -> void:
	await get_tree().process_frame
	self.health = health
	add_to_group("mole")
	tilemap = get_parent().get_node_or_null("TileMap")
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
		_update_camera_position(delta)
		return
	elif is_tunneling:
		velocity.x = tunnel_direction * TUNNEL_SPEED
		move_and_slide()
		if tilemap:
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				if collider is TileMap:
					var tile_pos = collider.local_to_map(collider.to_local(collision.get_position()))
					collider.erase_cell(0, tile_pos)
					if dirt_spray:
						dirt_spray.restart()
						dirt_spray.emitting = true
		was_on_floor = is_on_floor()
		_update_camera_position(delta)
		return

	if Input.is_action_just_pressed("dig_dash") and is_on_floor():
		start_dig_dash()
		_update_camera_position(delta)
		return

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		spawn_mole_hole()
		var direction_at_jump := Input.get_axis("ui_left", "ui_right")
		is_sideways_jump = direction_at_jump != 0
		air_time = 1.0
		launched_from_jump = true

	# Landing detection — was in air, now on floor
	if is_on_floor() and not was_on_floor:
		remove_mole_hole()
		is_sideways_jump = false
		air_time = 0.0
		launched_from_jump = false

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
	if not is_on_floor() and not launched_from_jump:
		air_time += delta

	# Check for enemy contact via physics collisions
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is CharacterBody2D and collider.has_method("die"):
			take_damage(1, collider.global_position, true)
			break

	update_depth_display()
	_update_camera_position(delta)

	# Animation
	if hurt_anim_time_left > 0.0:
		hurt_anim_time_left = maxf(0.0, hurt_anim_time_left - delta)
		$AnimatedSprite2D.flip_v = false
		$AnimatedSprite2D.rotation = lerp_angle($AnimatedSprite2D.rotation, 0.0, 0.25)
		if is_on_floor() or (not launched_from_jump and air_time <= MIDAIR_SPRITE_DELAY):
			$AnimatedSprite2D.play("hurtground")
		else:
			$AnimatedSprite2D.play("hurt")
	elif not is_on_floor() and (launched_from_jump or air_time > MIDAIR_SPRITE_DELAY):
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

func _update_camera_position(delta: float) -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var target_global := global_position.lerp(get_global_mouse_position(), CAMERA_MOUSE_INFLUENCE)
	var target_local := to_local(target_global)
	var follow_weight := clampf(CAMERA_FOLLOW_SPEED * delta, 0.0, 1.0)
	camera.position = camera.position.lerp(target_local, follow_weight)


func spawn_mole_hole() -> void:
	remove_mole_hole()
	mole_hole_instance = mole_hole_scene.instantiate()
	mole_hole_instance.global_position = global_position
	get_parent().add_child(mole_hole_instance)


func remove_mole_hole() -> void:
	if mole_hole_instance and is_instance_valid(mole_hole_instance):
		mole_hole_instance.queue_free()
		mole_hole_instance = null

func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, has_source: bool = false, is_projectile: bool = false) -> void:
	if invulnerable or health <= 0:
		return
	health -= amount
	invulnerable = true
	hurt_anim_time_left = HURT_GROUND_DURATION if is_on_floor() else HURT_AIR_DURATION
	var knockback_direction := -1.0 if $AnimatedSprite2D.flip_h else 1.0
	if has_source:
		knockback_direction = sign(global_position.x - source_position.x)
		if knockback_direction == 0.0:
			knockback_direction = -1.0 if $AnimatedSprite2D.flip_h else 1.0
	velocity.x = knockback_direction * KNOCKBACK_X
	if is_projectile:
		screen_shake(22.0, 0.4)
		hit_freeze(0.06)
	else:
		screen_shake(12.0, 0.3)
	get_tree().create_timer(1.0).timeout.connect(_end_invulnerability)

func _end_invulnerability() -> void:
	invulnerable = false

func hit_freeze(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration * 0.05).timeout
	Engine.time_scale = 1.0

func screen_shake(intensity: float, duration: float) -> void:
	var camera := get_node_or_null("Camera2D")
	if not camera:
		return
	var tween := create_tween()
	var steps := 8
	var step_time := duration / steps
	for i in steps:
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		intensity *= 0.8
		tween.tween_property(camera, "offset", offset, step_time).set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera, "offset", Vector2.ZERO, step_time).set_trans(Tween.TRANS_SINE)

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
