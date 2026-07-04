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
const DIRT_PARTICLE_LIFETIME = 0.45
const DIRT_PARTICLE_AMOUNT = 18


var mole_hole_scene := preload("res://scenes/molehole.tscn")
var mole_hole_instance: Node2D = null
var bomb_scene := preload("res://bomb.tscn")
var drill_scene := preload("res://drill.tscn")
var was_on_floor := true
var is_sideways_jump := false
var is_digging := false
var is_tunneling := false
var tunnel_direction := 1.0
var invulnerable := false
var speed_boost_active := false
var shield_active := false
var hurt_anim_time_left := 0.0
var air_time := 0.0
var launched_from_jump := false
var _dig_dash_weapon_was_visible := false

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

	if not InputMap.has_action("dig_slash"):
		InputMap.add_action("dig_slash")
		var ev_click = InputEventMouseButton.new()
		ev_click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("dig_slash", ev_click)

	_setup_inventory_actions()
	Inventory.initialize()
	Inventory.selected_slot_changed.connect(_on_selected_slot_changed)
	if has_node("Weapon"):
		$Weapon.hide()
	_setup_held_item_sprites()

func _setup_inventory_actions() -> void:
	var keys := [KEY_1, KEY_2, KEY_3]
	var actions := ["inventory_1", "inventory_2", "inventory_3"]
	for i in 3:
		if not InputMap.has_action(actions[i]):
			InputMap.add_action(actions[i])
			var ev = InputEventKey.new()
			ev.keycode = keys[i]
			InputMap.action_add_event(actions[i], ev)

const HOLD_ITEM_ORBIT_RADIUS := 60.0
const HOLD_ITEM_SCALE := 0.8

func _setup_held_item_sprites() -> void:
	var bomb_tex := preload("res://scenes/bomb.webp")
	var bomb_sprite := Sprite2D.new()
	bomb_sprite.name = "HeldBomb"
	bomb_sprite.texture = bomb_tex
	bomb_sprite.scale = Vector2(HOLD_ITEM_SCALE, HOLD_ITEM_SCALE)
	bomb_sprite.z_index = 2
	bomb_sprite.hide()
	add_child(bomb_sprite)

	var drill_tex := preload("res://drill.webp")
	var drill_sprite := Sprite2D.new()
	drill_sprite.name = "HeldDrill"
	drill_sprite.texture = drill_tex
	drill_sprite.scale = Vector2(HOLD_ITEM_SCALE, HOLD_ITEM_SCALE)
	drill_sprite.z_index = 2
	drill_sprite.hide()
	add_child(drill_sprite)

func _process(_delta: float) -> void:
	var slot := Inventory.selected_slot
	if slot < 0 or slot >= Inventory.slots.size():
		return
	var item: ItemData = Inventory.slots[slot]
	if item == null:
		return
	var sprite_name := ""
	if item.item_name == "Bomb":
		sprite_name = "HeldBomb"
	elif item.item_name == "Drill":
		sprite_name = "HeldDrill"
	if sprite_name == "":
		return
	var sprite := get_node_or_null(sprite_name)
	if not sprite or not sprite.visible:
		return
	var mouse_dir := (get_global_mouse_position() - global_position).normalized()
	if mouse_dir == Vector2.ZERO:
		mouse_dir = Vector2.RIGHT
	sprite.position = mouse_dir * HOLD_ITEM_ORBIT_RADIUS
	sprite.rotation = mouse_dir.angle()

func _on_selected_slot_changed(slot: int) -> void:
	_update_held_item()

func _update_held_item() -> void:
	if is_digging or is_tunneling:
		return

	var slot := Inventory.selected_slot

	if has_node("Weapon"):
		$Weapon.visible = (slot == 0 and Inventory.slots[0] != null)

	var item: ItemData = Inventory.slots[slot] if slot >= 0 and slot < Inventory.slots.size() else null
	if has_node("HeldBomb"):
		$HeldBomb.visible = (item != null and item.item_name == "Bomb")
	if has_node("HeldDrill"):
		$HeldDrill.visible = (item != null and item.item_name == "Drill")

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

	_handle_inventory_input()

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
					var tm := collider as TileMap
					var tile_pos = tm.local_to_map(tm.to_local(collision.get_position()))
					var source_id := tm.get_cell_source_id(0, tile_pos)
					if source_id == -1:
						continue
					var sfx = load("res://scripts/tile_break_sfx.gd")
					sfx.break_tile(collider, tile_pos, get_parent())
					spawn_dirt_particles(collision.get_position())
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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var slot := Inventory.selected_slot
		var item: ItemData = Inventory.slots[slot] if slot >= 0 and slot < Inventory.slots.size() else null
		if item == null:
			return
		match item.item_name:
			"Bomb":
				_throw_bomb()
				get_viewport().set_input_as_handled()
			"Drill":
				_deploy_drill()
				get_viewport().set_input_as_handled()

func _handle_inventory_input() -> void:
	if Input.is_action_just_pressed("inventory_1"):
		_toggle_slot(0)
	elif Input.is_action_just_pressed("inventory_2"):
		_toggle_slot(1)
	elif Input.is_action_just_pressed("inventory_3"):
		_toggle_slot(2)

func _toggle_slot(slot: int) -> void:
	var item: ItemData = Inventory.slots[slot] if slot < Inventory.slots.size() else null
	if item == null:
		return

	if item.item_name == "Health Potion":
		if health < 6:
			Inventory.use_item(slot)
			heal(1)
		return
	elif item.item_name == "Speed Boots":
		if not speed_boost_active:
			Inventory.use_item(slot)
			_activate_speed_boost()
		return
	elif item.item_name == "Shield":
		if not shield_active:
			Inventory.use_item(slot)
			_activate_shield()
		return

	if Inventory.selected_slot == slot:
		Inventory.selected_slot = -1
	else:
		Inventory.selected_slot = slot

func _deploy_drill() -> void:
	if not Inventory.use_item(Inventory.selected_slot):
		return
	Inventory.selected_slot = -1
	var drill = drill_scene.instantiate()
	get_parent().add_child(drill)
	drill.global_position = global_position + Vector2(0, -40)
	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - global_position).normalized()
	drill.setup(dir)

func _throw_bomb() -> void:
	if not Inventory.use_item(Inventory.selected_slot):
		return
	Inventory.selected_slot = -1
	var bomb = bomb_scene.instantiate()
	get_parent().add_child(bomb)
	bomb.global_position = global_position + Vector2(0, -40)
	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - global_position).normalized()
	bomb.linear_velocity = dir * 600.0
	bomb.arm()

func heal(amount: float) -> bool:
	if health >= 6:
		return false
	health += amount
	return true

func _activate_speed_boost() -> void:
	speed_boost_active = true
	$AnimatedSprite2D.modulate = Color(0.6, 0.8, 1, 1)
	await get_tree().create_timer(5.0).timeout
	speed_boost_active = false
	$AnimatedSprite2D.modulate = Color.WHITE

func _activate_shield() -> void:
	shield_active = true
	modulate = Color(0.8, 1, 0.8, 1)
	await get_tree().create_timer(5.0).timeout
	shield_active = false
	modulate = Color.WHITE

func _update_camera_position(delta: float) -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var target_global := global_position.lerp(get_global_mouse_position(), CAMERA_MOUSE_INFLUENCE)
	var target_local := to_local(target_global)
	var follow_weight := clampf(CAMERA_FOLLOW_SPEED * delta, 0.0, 1.0)
	camera.position = camera.position.lerp(target_local, follow_weight)

func spawn_dirt_particles(world_position: Vector2) -> void:
	var dirt := GPUParticles2D.new()
	var material := ParticleProcessMaterial.new()
	dirt.global_position = world_position
	dirt.one_shot = true
	dirt.explosiveness = 1.0
	dirt.amount = DIRT_PARTICLE_AMOUNT
	dirt.lifetime = DIRT_PARTICLE_LIFETIME
	dirt.process_material = material
	dirt.z_index = 5
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 70.0
	material.gravity = Vector3(0.0, 980.0, 0.0)
	material.initial_velocity_min = 140.0
	material.initial_velocity_max = 260.0
	material.scale_min = 4.0
	material.scale_max = 8.0
	material.color = Color(0.45, 0.30, 0.16, 1.0)
	get_tree().current_scene.add_child(dirt)
	dirt.emitting = true
	get_tree().create_timer(DIRT_PARTICLE_LIFETIME + 0.2).timeout.connect(dirt.queue_free)


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

func deflect_pause() -> void:
	$AnimatedSprite2D.modulate = Color(3.0, 3.0, 3.5, 1.0)
	var sprite_tween := create_tween()
	sprite_tween.tween_property($AnimatedSprite2D, "modulate", Color(1.5, 1.5, 1.8, 1.0), 0.1).set_trans(Tween.TRANS_QUAD)
	sprite_tween.tween_property($AnimatedSprite2D, "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_OUT)

	var base_scale: Vector2 = $AnimatedSprite2D.scale
	var punch_scale := base_scale * Vector2(1.2, 0.85)
	var scale_tween := create_tween()
	scale_tween.tween_property($AnimatedSprite2D, "scale", punch_scale, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property($AnimatedSprite2D, "scale", base_scale, 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	Engine.time_scale = 0.05
	await get_tree().create_timer(0.1 * 0.05).timeout
	Engine.time_scale = 1.0

	var camera := get_node_or_null("Camera2D") as Camera2D
	if not camera:
		return
	var original_zoom := Vector2(1.5, 1.5)
	var punch_zoom := Vector2(1.75, 1.75)
	var zoom_tween := create_tween()
	zoom_tween.tween_property(camera, "zoom", punch_zoom, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	zoom_tween.tween_interval(0.15)
	zoom_tween.tween_property(camera, "zoom", original_zoom, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func start_dig_dash() -> void:
	is_digging = true
	_dig_dash_weapon_was_visible = false
	if has_node("Weapon"):
		_dig_dash_weapon_was_visible = $Weapon.visible
		$Weapon.hide()
	$AnimatedSprite2D.play("dig")

	tunnel_direction = -1.0 if $AnimatedSprite2D.flip_h else 1.0

	await $AnimatedSprite2D.animation_finished

	if not is_digging:
		return

	is_digging = false
	is_tunneling = true
	$AnimatedSprite2D.play("tunnel")

	var tunnel_elapsed := 0.0
	while tunnel_elapsed < TUNNEL_DURATION:
		await get_tree().process_frame
		if not is_tunneling:
			return
		tunnel_elapsed += get_process_delta_time()
		if Input.is_action_just_pressed("dig_slash"):
			_dash_cancel_into_attack()
			return

	if not is_tunneling:
		return

	_end_dig_dash()

func _dash_cancel_into_attack() -> void:
	is_tunneling = false
	velocity.x = tunnel_direction * SPEED * 0.5
	velocity.y = -200.0
	if has_node("Weapon"):
		$Weapon.show()
		if $Weapon.has_method("dig_slash"):
			$Weapon.dig_slash()
	screen_shake(18.0, 0.3)
	spawn_dirt_particles(global_position)
	$AnimatedSprite2D.play("jumpbold")

func _end_dig_dash() -> void:
	is_tunneling = false
	velocity.x = 0
	velocity.y = JUMP_VELOCITY
	if has_node("Weapon") and _dig_dash_weapon_was_visible:
		$Weapon.show()
	$AnimatedSprite2D.play("jumpbold")
