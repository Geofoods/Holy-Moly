extends CharacterBody2D

const SPEED = 700.0
const JUMP_VELOCITY = -1400.0
const JUMP_CUT_MULTIPLIER = 0.4
const ACCELERATION = 3600.0
const FRICTION = 3600.0
const AIR_FRICTION = 1600.0
const TUNNEL_SPEED = 2400.0
const FAST_FALL_SPEED = 1200.0
const TUNNEL_DURATION = 0.2
const HURT_GROUND_DURATION = 0.25
const HURT_AIR_DURATION = 0.35
const KNOCKBACK_X = 260.0
const MIDAIR_SPRITE_DELAY = 0.15
const CAMERA_FOLLOW_SPEED = 10.0
const CAMERA_MOUSE_INFLUENCE = 0.08
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
var _coyote_timer := 0.0
var _jump_held := false
var _stuck_timer := 0.0
var _last_position := Vector2.ZERO
var _stuck_label: Label = null
const STUCK_THRESHOLD := 4.0

var slow_timer := 0.0
var _slow_ui: Control = null
var _slow_bar: ColorRect = null
var _slow_label: Label = null

var death_override: Callable = Callable()

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
				if death_override.is_valid():
					death_override.call()
					return
				Inventory.current_level_path = get_tree().current_scene.scene_file_path
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
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.zoom = Vector2(1.5, 1.5)
	tilemap = get_parent().get_node_or_null("TileMap")
	LevelMusic.start()
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
	Inventory.selected_slot = 0
	_setup_held_item_sprites()
	_reverb = AudioServer.get_bus_effect(0, 0) as AudioEffectReverb
	_setup_level_reverb()
	_setup_stuck_label()
	_setup_slow_ui()

func _setup_stuck_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	_stuck_label = Label.new()
	_stuck_label.anchor_right = 1.0
	_stuck_label.offset_right = -130.0
	_stuck_label.offset_top = 30.0
	_stuck_label.offset_left = -380.0
	_stuck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stuck_label.add_theme_font_size_override("font_size", 16)
	_stuck_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 0.9))
	_stuck_label.visible = false
	canvas.add_child(_stuck_label)

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
var _reverb: AudioEffectReverb = null

func update_depth_display() -> void:
	var depth := maxf(0.0, global_position.y - SURFACE_Y)
	var label = get_parent().get_node_or_null("CanvasLayer/DepthLabel")
	if label:
		label.text = "Depth: %dm" % int(depth)

func _setup_level_reverb() -> void:
	if not _reverb:
		return
	var path := get_tree().current_scene.scene_file_path
	var info := LevelData.get_info(path)
	var level := info.get("number", 1) as int
	var t := clampf((level - 1) / 8.0, 0.0, 1.0)
	_reverb.wet = t * 0.5
	_reverb.room_size = 0.1 + t * 0.7

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta * 1.5
		if Input.is_action_pressed("ui_down"):
			velocity.y = minf(velocity.y, FAST_FALL_SPEED)

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
			var sfx = load("res://scripts/tile_break_sfx.gd")
			var broken_tiles: Array[Vector2i] = []
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				if collider is TileMap:
					var tm := collider as TileMap
					var contact: Vector2 = collision.get_position()
					var nudged: Vector2 = contact + collision.get_normal() * -8.0
					var tile_pos: Vector2i = tm.local_to_map(tm.to_local(nudged))
					if tile_pos not in broken_tiles:
						broken_tiles.append(tile_pos)
						if tm.get_cell_source_id(0, tile_pos) != -1:
							sfx.break_tile(tm, tile_pos, get_parent())
						else:
							sfx.break_decoration_tile(tm, tile_pos, get_parent())
						spawn_dirt_particles(contact)
				elif sfx.break_opened_chest_from_node(collider):
					spawn_dirt_particles(collision.get_position())
			var front_pos: Vector2 = global_position + Vector2(tunnel_direction * 40.0, 0.0)
			var front_tile: Vector2i = tilemap.local_to_map(tilemap.to_local(front_pos))
			if front_tile not in broken_tiles and tilemap.get_cell_source_id(0, front_tile) != -1:
				sfx.break_tile(tilemap, front_tile, get_parent())
				spawn_dirt_particles(tilemap.to_global(tilemap.map_to_local(front_tile)))
		was_on_floor = is_on_floor()
		_update_camera_position(delta)
		return

	if Input.is_action_just_pressed("dig_dash") and is_on_floor():
		start_dig_dash()
		_update_camera_position(delta)
		return

	if is_on_floor():
		_coyote_timer = ComboManager.get_coyote_time()
	else:
		_coyote_timer -= delta

	var can_jump := is_on_floor() or _coyote_timer > 0.0
	if Input.is_action_just_pressed("ui_accept") and can_jump:
		velocity.y = JUMP_VELOCITY
		_jump_held = true
		_coyote_timer = 0.0
		SFX.play("jump", global_position, -12.0)
		spawn_mole_hole()
		var direction_at_jump := Input.get_axis("ui_left", "ui_right")
		is_sideways_jump = direction_at_jump != 0
		air_time = 1.0
		launched_from_jump = true

	if Input.is_action_just_released("ui_accept"):
		_jump_held = false
		if velocity.y < 0:
			velocity.y *= JUMP_CUT_MULTIPLIER

	if is_on_floor() and not was_on_floor:
		SFX.play("land", global_position, -10.0)
		_spawn_land_dust()
		remove_mole_hole()
		is_sideways_jump = false
		air_time = 0.0
		launched_from_jump = false
		_jump_held = false

	was_on_floor = is_on_floor()

	var direction := Input.get_axis("ui_left", "ui_right")
	var effective_speed := SPEED * ComboManager.get_speed_multiplier()
	if speed_boost_active:
		effective_speed *= 1.4
	if slow_timer > 0.0:
		effective_speed *= 0.4

	if direction:
		var accel = ACCELERATION if is_on_floor() else ACCELERATION * 0.6
		velocity.x = move_toward(velocity.x, direction * effective_speed, accel * delta)
		$AnimatedSprite2D.flip_h = direction < 0
	else:
		var friction = FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	if not is_on_floor() and not is_sideways_jump and direction != 0:
		is_sideways_jump = true

	move_and_slide()
	if not is_on_floor() and not launched_from_jump:
		air_time += delta

	_check_stuck(delta)
	_update_slow(delta)

	update_depth_display()
	_update_camera_position(delta)

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
			"Holy Water", "Health Potion":
				if health < 6:
					Inventory.use_item(slot)
					heal(1)
				Inventory.selected_slot = -1
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

	if item.item_name == "Health Potion" or item.item_name == "Holy Water":
		if health < 6:
			Inventory.use_item(slot)
			heal(1)
			return
		else:
			if Inventory.selected_slot == slot:
				Inventory.selected_slot = -1
			else:
				Inventory.selected_slot = slot
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
	SFX.play("heal", global_position)
	_spawn_potion_mist()
	return true

func _spawn_potion_mist() -> void:
	var mist := CPUParticles2D.new()
	mist.emitting = true
	mist.one_shot = false
	mist.amount = 24
	mist.lifetime = 0.8
	mist.explosiveness = 0.0
	mist.direction = Vector2(0, -1)
	mist.spread = 60.0
	mist.initial_velocity_min = 40.0
	mist.initial_velocity_max = 100.0
	mist.gravity = Vector2(0, -30)
	mist.damping_min = 20.0
	mist.damping_max = 40.0
	mist.scale_amount_min = 6.0
	mist.scale_amount_max = 14.0
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist.emission_rect_extents = Vector2(30, 40)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.3, 0.55, 1.0, 0.7))
	grad.set_color(1, Color(0.2, 0.4, 0.9, 0.0))
	mist.color_ramp = grad
	mist.z_index = 10
	add_child(mist)
	mist.position = Vector2(0, -20)

	var splash := CPUParticles2D.new()
	splash.emitting = true
	splash.one_shot = true
	splash.amount = 16
	splash.lifetime = 0.5
	splash.explosiveness = 1.0
	splash.direction = Vector2.ZERO
	splash.spread = 180.0
	splash.initial_velocity_min = 60.0
	splash.initial_velocity_max = 160.0
	splash.gravity = Vector2(0, 200)
	splash.scale_amount_min = 3.0
	splash.scale_amount_max = 8.0
	var splash_grad := Gradient.new()
	splash_grad.set_color(0, Color(0.4, 0.7, 1.0, 0.9))
	splash_grad.set_color(1, Color(0.15, 0.3, 0.8, 0.0))
	splash.color_ramp = splash_grad
	splash.z_index = 10
	add_child(splash)
	splash.position = Vector2(0, -30)

	get_tree().create_timer(1.2).timeout.connect(func(): mist.emitting = false)
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(mist): mist.queue_free()
		if is_instance_valid(splash): splash.queue_free()
	)

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
	if health <= 0:
		SFX.play("death", global_position)
	else:
		SFX.play("hurt", global_position)
	invulnerable = true
	_damage_flash()
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

func _damage_flash() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 90
	add_child(canvas_layer)
	var flash := ColorRect.new()
	flash.color = Color(0.8, 0.05, 0.05, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(canvas_layer.queue_free)

func _spawn_land_dust() -> void:
	var dust := CPUParticles2D.new()
	dust.emitting = true
	dust.one_shot = true
	dust.amount = 10
	dust.lifetime = 0.35
	dust.explosiveness = 1.0
	dust.direction = Vector2(0, -1)
	dust.spread = 70.0
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 80.0
	dust.gravity = Vector2(0, 200)
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 7.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.4, 0.25, 0.6))
	grad.set_color(1, Color(0.45, 0.3, 0.16, 0.0))
	dust.color_ramp = grad
	dust.z_index = 5
	get_parent().add_child(dust)
	dust.global_position = global_position + Vector2(0, 10)
	get_tree().create_timer(0.8).timeout.connect(dust.queue_free)

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
	SFX.play("dig_dash", global_position)
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

func _check_stuck(delta: float) -> void:
	var has_input := Input.get_axis("ui_left", "ui_right") != 0 or Input.is_action_pressed("ui_accept")
	var moved := global_position.distance_squared_to(_last_position) > 4.0
	if has_input and not moved and not is_digging and not is_tunneling:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_position = global_position

	if _stuck_label:
		if _stuck_timer >= 1.0:
			var remaining := ceili(STUCK_THRESHOLD - _stuck_timer)
			_stuck_label.text = "Stuck? Breaking free in %ds..." % remaining
			_stuck_label.visible = true
		else:
			_stuck_label.visible = false

	if _stuck_timer >= STUCK_THRESHOLD and tilemap:
		_stuck_timer = 0.0
		_break_surrounding_tiles()

func _break_surrounding_tiles() -> void:
	var sfx = load("res://scripts/tile_break_sfx.gd")
	var mole_tile := tilemap.local_to_map(tilemap.to_local(global_position))
	var offsets := [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]
	var broke_any := false
	for off in offsets:
		var tile_pos: Vector2i = mole_tile + off
		if tilemap.get_cell_source_id(0, tile_pos) != -1:
			sfx.break_tile(tilemap, tile_pos, get_parent())
			broke_any = true
	if broke_any:
		spawn_dirt_particles(global_position)
		screen_shake(6.0, 0.15)

func apply_slow(duration: float) -> void:
	slow_timer = maxf(slow_timer, duration)
	if _slow_ui:
		_slow_ui.visible = true

func _update_slow(delta: float) -> void:
	if slow_timer <= 0.0:
		return
	slow_timer -= delta
	if slow_timer <= 0.0:
		slow_timer = 0.0
		if _slow_ui:
			_slow_ui.visible = false
	elif _slow_ui and _slow_ui.visible:
		_slow_label.text = "SLOWED %.1fs" % slow_timer
		var ratio := slow_timer / 3.0
		_slow_bar.anchor_right = ratio

func _setup_slow_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 95
	add_child(canvas)

	_slow_ui = Control.new()
	_slow_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slow_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slow_ui.visible = false
	canvas.add_child(_slow_ui)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_right = -20
	panel.offset_top = -40
	panel.offset_bottom = 40
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	_slow_ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	_slow_label = Label.new()
	_slow_label.text = "SLOWED 3.0s"
	_slow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font := load("res://Baby Doll.otf") as Font
	_slow_label.add_theme_font_override("font", font)
	_slow_label.add_theme_font_size_override("font_size", 24)
	_slow_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0, 1.0))
	_slow_label.add_theme_constant_override("outline_size", 3)
	_slow_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	vbox.add_child(_slow_label)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(160, 14)
	bar_bg.color = Color(0.2, 0.2, 0.2, 0.9)
	vbox.add_child(bar_bg)

	_slow_bar = ColorRect.new()
	_slow_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slow_bar.color = Color(1.0, 0.5, 0.0, 0.9)
	bar_bg.add_child(_slow_bar)

func show_inventory_full_message() -> void:
	var canvas := get_parent().get_node_or_null("CanvasLayer")
	if not canvas:
		return
	
	var existing = canvas.get_node_or_null("InventoryFullLabel")
	if existing:
		existing.queue_free()
		
	var label := Label.new()
	label.name = "InventoryFullLabel"
	label.text = "Inventory Full!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1, 1.0))
	label.add_theme_font_size_override("font_size", 32)
	var font := load("res://Baby Doll.otf") as Font
	if font:
		label.add_theme_font_override("font", font)
	
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.offset_left = -150
	label.offset_right = 150
	label.offset_top = -20
	label.offset_bottom = 20
	
	canvas.add_child(label)
	
	var tween := create_tween()
	label.scale = Vector2(0.8, 0.8)
	label.pivot_offset = Vector2(150, 20)
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
