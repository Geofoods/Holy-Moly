extends CharacterBody2D

const SPEED = 700.0
const JUMP_VELOCITY = -1400.0
const JUMP_CUT_MULTIPLIER = 0.4
const ACCELERATION = 3600.0
const FRICTION = 3600.0
const AIR_FRICTION = 1600.0
const TUNNEL_SPEED = 2400.0
const FAST_FALL_SPEED = 1200.0
const AIR_GRAVITY = 2450.0
const TUNNEL_DURATION = 0.2
const HURT_GROUND_DURATION = 0.25
const HURT_AIR_DURATION = 0.35
const KNOCKBACK_X = 260.0
const MIDAIR_SPRITE_DELAY = 0.15
const CAMERA_FOLLOW_SPEED = 8.0
const CAMERA_FOLLOW_SPEED_FAST = 14.0
const CAMERA_MOUSE_INFLUENCE = 0.16
const CAMERA_LOOKAHEAD = 0.18
const CAMERA_LOOKAHEAD_MAX = 240.0
const DIRT_PARTICLE_LIFETIME = 0.45
const DIRT_PARTICLE_AMOUNT = 18
const DASH_ABILITY_DAMAGE := 10.0
const DASH_KNOCKBACK := 900.0
const DASH_HIT_RADIUS := 95.0
const GROUND_POUND_SPEED := 1800.0
const GROUND_POUND_BOUNCE := -500.0
const GROUND_POUND_MIN_FALL := 80.0
const GROUND_POUND_MAX_FALL := 640.0
const GROUND_POUND_BASE_RADIUS := 0
const GROUND_POUND_MAX_RADIUS := 2
const GROUND_POUND_BASE_HIT_RADIUS := 120.0
const GROUND_POUND_MAX_HIT_RADIUS := 200.0
const GROUND_POUND_BASE_DAMAGE := 8.0
const GROUND_POUND_MAX_DAMAGE := 36.0
const GROUND_POUND_KNOCKBACK := 800.0
const WALL_JUMP_VELOCITY := -1250.0
const WALL_JUMP_PUSHBACK := 620.0
const WALL_JUMP_LOCK_TIME := 0.14
const WALL_SLIDE_MAX_FALL := 420.0
const WALL_COYOTE_TIME := 0.12
const GRAPPLE_MAX_RANGE := 540.0
const GRAPPLE_PULL_SPEED := 1500.0
const GRAPPLE_ACCEL := 4200.0
const GRAPPLE_LATCH_DIST := 42.0
const GRAPPLE_ROPE_COLOR := Color(0.85, 0.65, 0.3, 1.0)
const GRAPPLE_ROPE_WIDTH := 6.0
const GRAPPLE_ITEM := preload("res://resources/grappling_hook.tres")
const DEBRIS_LAYER_BIT := 2
const TileBreakSFX := preload("res://scripts/tile_break_sfx.gd")

@export var can_break := true

var mole_hole_scene := preload("res://scenes/molehole.tscn")
var mole_hole_instance: Node2D = null
var bomb_scene := preload("res://bomb.tscn")
var ice_bomb_scene := preload("res://ice_bomb.tscn")
var drill_scene := preload("res://drill.tscn")
const GoldenBomb := preload("res://scripts/golden_bomb.gd")
const SparkBomb := preload("res://scripts/spark_bomb.gd")
const Mine := preload("res://scripts/mine.gd")
const StinkBomb := preload("res://scripts/stink_bomb.gd")
const Flare := preload("res://scripts/flare.gd")
const CoalLump := preload("res://scripts/coal_lump.gd")
const VacuumJelly := preload("res://scripts/vacuum_jelly.gd")
const BounceMushroom := preload("res://scripts/bounce_mushroom.gd")
const ShinyLure := preload("res://scripts/shiny_lure.gd")
const CompassCharm := preload("res://scripts/compass_charm.gd")
const EnemyDamage := preload("res://scripts/enemy.gd")
var was_on_floor := true
var is_sideways_jump := false
var is_digging := false
var is_tunneling := false
var is_ground_pounding := false
var _ground_pound_start_y := 0.0
var _ground_pound_power := 0.0
var tunnel_direction := 1.0
var _dash_hit_enemies: Dictionary = {}
var tunnel_gloves_active := false
var shelled_backpack_active := false
var climbing_talons_active := false
var lantern_charm_active := false
var rebound_hook_active := false
var wax_cache_active := false
var earthquake_boots_active := false
var mol_dozer_active := false
var _mole_light: PointLight2D = null
var _mole_light_base_energy := 1.0
var _mole_light_base_scale := 1.0
var _mol_dozer_hit: Dictionary = {}
var invulnerable := false
var _dash_invulnerable := false
var speed_boost_active := false
var shield_active := false
var hurt_anim_time_left := 0.0
var air_time := 0.0
var launched_from_jump := false
var _dig_dash_weapon_was_visible := false
var using_ranged := false
var _coyote_timer := 0.0
var _jump_held := false
var _wall_jump_lock_timer := 0.0
var _wall_coyote_timer := 0.0
var _wall_coyote_dir := 0.0
var slow_timer := 0.0
var _slow_ui: Control = null
var _slow_bar: ColorRect = null
var _slow_label: Label = null
var _normal_collision_mask := 0

var grapple_active := false
var grapple_anchor := Vector2.ZERO
var _grapple_rope: Line2D = null
var _grapple_anchor_sprite: Sprite2D = null

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
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
var _heart_base_scale := Vector2.ONE

func _animate_heart_damage(heart_node: Node2D) -> void:
	if _heart_base_scale == Vector2.ONE:
		_heart_base_scale = heart_node.scale
	var tween := create_tween()
	tween.tween_property(heart_node, "scale", _heart_base_scale * 0.75, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(heart_node, "scale", _heart_base_scale * 1.1, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(heart_node, "scale", _heart_base_scale, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _ready() -> void:
	# Register key bindings up front so input works from the very first frame
	# (before the awaited frame below), rather than being dead for a frame.
	_setup_input_actions()
	_normal_collision_mask = collision_mask
	_restore_level_position()
	await get_tree().process_frame
	self.health = health
	add_to_group("mole")
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.zoom = Vector2(0.65, 0.65)
	_camera = camera
	_depth_label = get_parent().get_node_or_null("CanvasLayer/DepthLabel") as Label
	tilemap = get_parent().get_node_or_null("TileMap")
	_mole_light = get_node_or_null("MoleLight")
	if _mole_light:
		_mole_light_base_energy = _mole_light.energy
		_mole_light_base_scale = _mole_light.texture_scale
	LevelMusic.start()
	Inventory.initialize()
	_grant_grapple_hook()
	Inventory.selected_slot_changed.connect(_on_selected_slot_changed)
	Inventory.selected_slot = 0
	_setup_held_item_sprites()
	_setup_grapple_visuals()
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, AudioEffectReverb.new())
	_reverb = AudioServer.get_bus_effect(0, 0) as AudioEffectReverb
	_setup_level_reverb()
	_setup_slow_ui()
	if not can_break and has_node("Weapon"):
		$Weapon.hide()
	_setup_ranged_weapon()
	_refresh_weapon_visibility()
	Shop.loadout_changed.connect(_refresh_weapon_visibility)

## Restores the position the mole had when it last left this level, if any, so
## re-entering a level drops the player back where they exited.
func _restore_level_position() -> void:
	var cs := get_tree().current_scene
	if cs == null:
		return
	var saved = Inventory.get_level_return_position(cs.scene_file_path)
	if saved is Vector2:
		global_position = saved as Vector2
		var cam := get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.reset_smoothing()

## Registers all keyboard/mouse bindings. Runs once per session (the InputMap is
## global and persists across level changes). Keys are bound by physical_keycode
## (physical key position) instead of keycode, so WASD/E/1-3 work on non-US
## keyboard layouts (AZERTY, QWERTZ, ...) where the same physical key produces a
## different character.
func _setup_input_actions() -> void:

	if not InputMap.has_action("swap_weapon"):
		InputMap.add_action("swap_weapon")
		var ev_q = InputEventKey.new()
		ev_q.physical_keycode = KEY_Q
		InputMap.action_add_event("swap_weapon", ev_q)

	if InputMap.has_action("dig_dash"):
		return

	var ev_w = InputEventKey.new()
	ev_w.physical_keycode = KEY_W
	InputMap.action_add_event("ui_accept", ev_w)

	var ev_up = InputEventKey.new()
	ev_up.physical_keycode = KEY_UP
	InputMap.action_add_event("ui_accept", ev_up)

	var ev_a = InputEventKey.new()
	ev_a.physical_keycode = KEY_A
	InputMap.action_add_event("ui_left", ev_a)

	var ev_d = InputEventKey.new()
	ev_d.physical_keycode = KEY_D
	InputMap.action_add_event("ui_right", ev_d)

	InputMap.add_action("dig_dash")
	var ev_shift = InputEventKey.new()
	ev_shift.physical_keycode = KEY_SHIFT
	InputMap.action_add_event("dig_dash", ev_shift)

	if not InputMap.has_action("dig_slash"):
		InputMap.add_action("dig_slash")
		var ev_click = InputEventMouseButton.new()
		ev_click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("dig_slash", ev_click)

	_setup_inventory_actions()

func _setup_inventory_actions() -> void:
	var keys := [KEY_1, KEY_2, KEY_3, KEY_4]
	var actions := ["inventory_1", "inventory_2", "inventory_3", "inventory_4"]
	for i in 4:
		if not InputMap.has_action(actions[i]):
			InputMap.add_action(actions[i])
			var ev = InputEventKey.new()
			ev.physical_keycode = keys[i]
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
	_held_sprites["HeldBomb"] = bomb_sprite

	var drill_tex := preload("res://drill.webp")
	var drill_sprite := Sprite2D.new()
	drill_sprite.name = "HeldDrill"
	drill_sprite.texture = drill_tex
	drill_sprite.scale = Vector2(HOLD_ITEM_SCALE, HOLD_ITEM_SCALE)
	drill_sprite.z_index = 2
	drill_sprite.hide()
	add_child(drill_sprite)
	_held_sprites["HeldDrill"] = drill_sprite

	var ice_sprite := Sprite2D.new()
	ice_sprite.name = "HeldIceBomb"
	ice_sprite.texture = bomb_tex
	ice_sprite.scale = Vector2(HOLD_ITEM_SCALE, HOLD_ITEM_SCALE)
	ice_sprite.modulate = Color(0.65, 0.85, 1.15, 1.0)
	ice_sprite.z_index = 2
	ice_sprite.hide()
	add_child(ice_sprite)
	_held_sprites["HeldIceBomb"] = ice_sprite

func _aim_pos() -> Vector2:
	return get_global_mouse_position()

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
	elif item.item_name == "Ice Bomb":
		sprite_name = "HeldIceBomb"
	elif item.item_name == "Golden Bomb" or item.item_name == "Mine" or item.item_name == "Coal Lump" \
			or item.item_name == "Stink Bomb" or item.item_name == "Flare" or item.item_name == "Spark Bomb":
		sprite_name = "HeldBomb"
	elif item.item_name == "Drill":
		sprite_name = "HeldDrill"
	if sprite_name == "":
		return
	var sprite: Sprite2D = _held_sprites.get(sprite_name)
	if not sprite or not sprite.visible:
		return
	match item.item_name:
		"Golden Bomb":
			sprite.modulate = Color(1.0, 0.82, 0.25, 1.0)
		"Mine":
			sprite.modulate = Color(0.62, 0.62, 0.68, 1.0)
		"Coal Lump":
			sprite.modulate = Color(0.3, 0.27, 0.24, 1.0)
		"Stink Bomb":
			sprite.modulate = Color(0.45, 0.85, 0.35, 1.0)
		"Flare":
			sprite.modulate = Color(1.0, 0.55, 0.2, 1.0)
		"Spark Bomb":
			sprite.modulate = Color(0.65, 0.85, 1.15, 1.0)
		_:
			sprite.modulate = Color.WHITE
	var mouse_dir := (_aim_pos() - global_position).normalized()
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
		$Weapon.visible = (slot == 0 and Inventory.slots[0] != null) and can_break and not using_ranged
	if has_node("RangedWeapon"):
		$RangedWeapon.visible = using_ranged and Shop.has_ranged_weapon()

	var item: ItemData = Inventory.slots[slot] if slot >= 0 and slot < Inventory.slots.size() else null
	if has_node("HeldBomb"):
		$HeldBomb.visible = (item != null and item.item_name in ["Bomb", "Golden Bomb", "Mine", "Coal Lump", "Stink Bomb", "Flare", "Spark Bomb"])
	if has_node("HeldIceBomb"):
		$HeldIceBomb.visible = (item != null and item.item_name == "Ice Bomb")
	if has_node("HeldDrill"):
		$HeldDrill.visible = (item != null and item.item_name == "Drill")

func _setup_ranged_weapon() -> void:
	if has_node("RangedWeapon"):
		return
	var ranged_script: Script = preload("res://scripts/ranged_weapon.gd")
	var w := Shop.get_ranged()
	if w and w.id == "wizard_staff":
		ranged_script = preload("res://scripts/wizard_staff.gd")
	var rw: Node2D = ranged_script.new()
	rw.name = "RangedWeapon"
	rw.position = Vector2(0, -40)
	rw.z_index = 1
	add_child(rw)
	rw.visible = false

func _refresh_weapon_visibility() -> void:
	if is_digging or is_tunneling:
		return
	_ensure_ranged_weapon_script()
	_update_held_item()

func _ensure_ranged_weapon_script() -> void:
	var w := Shop.get_ranged()
	if w == null:
		return
	var desired: Script = preload("res://scripts/ranged_weapon.gd")
	if w.id == "wizard_staff":
		desired = preload("res://scripts/wizard_staff.gd")
	var node := get_node_or_null("RangedWeapon")
	if node and node.get_script() == desired:
		return
	if node:
		node.name = "RangedWeapon_old"
		node.queue_free()
	_setup_ranged_weapon()

const SURFACE_Y := 850.0
var _reverb: AudioEffectReverb = null
var _camera: Camera2D = null
var _depth_label: Label = null
var _last_depth := -1
var _held_sprites: Dictionary = {}
var _tunnel_broken_tiles: Array[Vector2i] = []
var _dirt_ramp: GradientTexture1D = null
var _dash_strike_scan_cooldown := 0.0

func update_depth_display() -> void:
	var depth := maxi(0, int(maxf(0.0, global_position.y - SURFACE_Y)))
	if _depth_label and depth != _last_depth:
		_last_depth = depth
		_depth_label.text = "Depth: %dm" % depth

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
	collision_mask = _normal_collision_mask
	if is_digging or is_tunneling or is_ground_pounding:
		collision_mask &= ~DEBRIS_LAYER_BIT

	if not grapple_active and not is_on_floor():
		velocity.y += AIR_GRAVITY * delta
		if Input.is_action_pressed("ui_down"):
			velocity.y = minf(velocity.y, FAST_FALL_SPEED)

	_handle_inventory_input()

	_handle_grapple(delta)
	if grapple_active:
		_sprite.play("jumpbold")
		_sprite.flip_v = velocity.y > 0
		_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, 0.15)
		update_depth_display()
		_update_camera_position(delta)
		return

	if is_digging:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		move_and_slide()
		was_on_floor = is_on_floor()
		_update_camera_position(delta)
		return
	elif is_tunneling:
		velocity.x = tunnel_direction * TUNNEL_SPEED
		move_and_slide()
		_dash_ability_strike()
		if tilemap:
			var broken_tiles := _tunnel_broken_tiles
			broken_tiles.clear()
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
							TileBreakSFX.break_tile(tm, tile_pos, get_parent())
						else:
							TileBreakSFX.break_decoration_tile(tm, tile_pos, get_parent())
						spawn_dirt_particles(contact)
				elif TileBreakSFX.break_opened_chest_from_node(collider):
					spawn_dirt_particles(collision.get_position())
			var front_pos: Vector2 = global_position + Vector2(tunnel_direction * 40.0, 0.0)
			var front_tile: Vector2i = tilemap.local_to_map(tilemap.to_local(front_pos))
			if front_tile not in broken_tiles and tilemap.get_cell_source_id(0, front_tile) != -1:
				TileBreakSFX.break_tile(tilemap, front_tile, get_parent())
				spawn_dirt_particles(tilemap.to_global(tilemap.map_to_local(front_tile)))
			if tunnel_gloves_active:
				for extra_dy in [-1, 1]:
					var side := Vector2i(front_tile.x, front_tile.y + extra_dy)
					if side not in broken_tiles and tilemap.get_cell_source_id(0, side) != -1:
						TileBreakSFX.break_tile(tilemap, side, get_parent())
						spawn_dirt_particles(tilemap.to_global(tilemap.map_to_local(side)))
		was_on_floor = is_on_floor()
		_update_camera_position(delta)
		return

	if is_ground_pounding:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.y = minf(velocity.y + AIR_GRAVITY * delta * 1.5, GROUND_POUND_SPEED)
		move_and_slide()
		was_on_floor = is_on_floor()
		if is_on_floor():
			_complete_ground_pound()
		_update_camera_position(delta)
		return

	if Input.is_action_just_pressed("dig_dash") and can_break:
		if is_on_floor():
			start_dig_dash()
		else:
			start_ground_pound()
		_update_camera_position(delta)
		return

	if is_on_floor():
		_coyote_timer = ComboManager.get_coyote_time()
	else:
		_coyote_timer -= delta

	var direction := Input.get_axis("ui_left", "ui_right")

	if Shop.has_wall_jump():
		_wall_jump_lock_timer = maxf(0.0, _wall_jump_lock_timer - delta)
		if is_on_floor():
			_wall_coyote_timer = 0.0
		elif is_on_wall() and _wall_jump_lock_timer <= 0.0:
			var toward_wall := -signf(get_wall_normal().x)
			if signf(direction) == toward_wall:
				_wall_coyote_timer = WALL_COYOTE_TIME
				_wall_coyote_dir = toward_wall
				if velocity.y > 0.0 and velocity.y > WALL_SLIDE_MAX_FALL:
					velocity.y = WALL_SLIDE_MAX_FALL
		else:
			_wall_coyote_timer = maxf(0.0, _wall_coyote_timer - delta)

	var can_jump := is_on_floor() or _coyote_timer > 0.0
	var can_wall_jump := Shop.has_wall_jump() and not can_jump \
			and _wall_jump_lock_timer <= 0.0 and _wall_coyote_timer > 0.0
	if climbing_talons_active and is_on_wall() and direction != 0 \
			and signf(direction) == -signf(get_wall_normal().x) and velocity.y > 0.0:
		velocity.y = 0.0
	if Input.is_action_just_pressed("ui_accept") and can_wall_jump:
		velocity.y = WALL_JUMP_VELOCITY
		velocity.x = -_wall_coyote_dir * WALL_JUMP_PUSHBACK
		_jump_held = true
		_wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
		_wall_coyote_timer = 0.0
		SFX.play("jump", global_position, -12.0, 0.25)
		is_sideways_jump = true
		air_time = 1.0
		launched_from_jump = true
	elif Input.is_action_just_pressed("ui_accept") and can_jump:
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

	var effective_speed := SPEED * ComboManager.get_speed_multiplier()
	if speed_boost_active:
		effective_speed *= 1.4
	if slow_timer > 0.0:
		effective_speed *= 0.4

	if direction:
		var accel = ACCELERATION if is_on_floor() else ACCELERATION * 0.6
		velocity.x = move_toward(velocity.x, direction * effective_speed, accel * delta)
		_sprite.flip_h = direction < 0
	else:
		var friction = FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	if not is_on_floor() and not is_sideways_jump and direction != 0:
		is_sideways_jump = true

	move_and_slide()
	_push_rocks()
	if mol_dozer_active:
		_dozer_ram()
	if not is_on_floor() and not launched_from_jump:
		air_time += delta

	_update_slow(delta)

	update_depth_display()
	_update_camera_position(delta)

	if hurt_anim_time_left > 0.0:
		hurt_anim_time_left = maxf(0.0, hurt_anim_time_left - delta)
		_sprite.flip_v = false
		_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, 0.25)
		if is_on_floor() or (not launched_from_jump and air_time <= MIDAIR_SPRITE_DELAY):
			_sprite.play("hurtground")
		else:
			_sprite.play("hurt")
	elif not is_on_floor() and (launched_from_jump or air_time > MIDAIR_SPRITE_DELAY):
		if is_sideways_jump:
			_sprite.play("sidewaysjumpbold")
			_sprite.flip_v = false
			var target_angle = atan2(velocity.y, abs(velocity.x))
			target_angle = clamp(target_angle, -PI / 4, PI / 4)
			if _sprite.flip_h:
				target_angle = -target_angle
			_sprite.rotation = lerp_angle(_sprite.rotation, target_angle, 0.15)
		else:
			_sprite.play("jumpbold")
			_sprite.flip_v = velocity.y > 0
			_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, 0.15)
	else:
		_sprite.flip_v = false
		_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, 0.3)
		if direction != 0:
			_sprite.play("walkbold")
		else:
			_sprite.play("idlebold")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("swap_weapon") and not event.echo:
		if Shop.has_ranged_weapon():
			using_ranged = not using_ranged
			_refresh_weapon_visibility()
			SFX.play_ui("ui_click", -12.0, 1.2)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var slot := Inventory.selected_slot
		var item: ItemData = Inventory.slots[slot] if slot >= 0 and slot < Inventory.slots.size() else null
		if item == null:
			return
		if not can_break and (item.item_name == "Bomb" or item.item_name == "Ice Bomb" or item.item_name == "Drill" \
				or item.item_name == "Golden Bomb" or item.item_name == "Mine"):
			return
		match item.item_name:
			"Bomb":
				_throw_bomb()
				get_viewport().set_input_as_handled()
			"Ice Bomb":
				_throw_ice_bomb()
				get_viewport().set_input_as_handled()
			"Drill":
				_deploy_drill()
				get_viewport().set_input_as_handled()
			"Golden Bomb":
				_launch_custom(GoldenBomb)
				get_viewport().set_input_as_handled()
			"Spark Bomb":
				_launch_custom(SparkBomb)
				get_viewport().set_input_as_handled()
			"Mine":
				_launch_custom(Mine)
				get_viewport().set_input_as_handled()
			"Stink Bomb":
				_launch_custom(StinkBomb)
				get_viewport().set_input_as_handled()
			"Flare":
				_launch_custom(Flare)
				get_viewport().set_input_as_handled()
			"Coal Lump":
				_launch_custom(CoalLump)
				get_viewport().set_input_as_handled()
			"Vacuum Jelly":
				Inventory.use_item(slot)
				_use_vacuum()
				get_viewport().set_input_as_handled()
			"Shop Token":
				Inventory.use_item(slot)
				_use_shop_token()
				get_viewport().set_input_as_handled()
			"Bounce Mushroom":
				Inventory.use_item(slot)
				_deploy_mushroom()
				get_viewport().set_input_as_handled()
			"Shiny Lure":
				Inventory.use_item(slot)
				_deploy_lure()
				get_viewport().set_input_as_handled()
			"Compass Charm":
				Inventory.use_item(slot)
				_deploy_compass()
				get_viewport().set_input_as_handled()
			"Grub Stick":
				Inventory.use_item(slot)
				_swing_grub_stick()
				get_viewport().set_input_as_handled()
			"Grappling Hook":
				get_viewport().set_input_as_handled()
			"Holy Water", "Health Potion", "Miner's Rations":
				if health < 6:
					Inventory.use_item(slot)
					heal(1)
				Inventory.selected_slot = -1
				get_viewport().set_input_as_handled()
			"Potted Honeycomb":
				if health < 6:
					Inventory.use_item(slot)
					heal(2)
				Inventory.selected_slot = -1
				get_viewport().set_input_as_handled()

func _handle_inventory_input() -> void:
	if Input.is_action_just_pressed("inventory_1"):
		_toggle_slot(0)
	elif Input.is_action_just_pressed("inventory_2"):
		_toggle_slot(1)
	elif Input.is_action_just_pressed("inventory_3"):
		_toggle_slot(2)
	elif Input.is_action_just_pressed("inventory_4"):
		_toggle_slot(3)

func _toggle_slot(slot: int) -> void:
	var item: ItemData = Inventory.slots[slot] if slot < Inventory.slots.size() else null
	if item == null:
		return

	if item.item_name == "Health Potion" or item.item_name == "Holy Water" or item.item_name == "Miner's Rations":
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
	elif item.item_name == "Potted Honeycomb":
		if health < 6:
			Inventory.use_item(slot)
			heal(2)
			return
		else:
			if Inventory.selected_slot == slot:
				Inventory.selected_slot = -1
			else:
				Inventory.selected_slot = slot
			return
	elif item.item_name == "Vacuum Jelly":
		Inventory.use_item(slot)
		_use_vacuum()
		return
	elif item.item_name == "Shop Token":
		Inventory.use_item(slot)
		_use_shop_token()
		return
	elif item.item_name == "Bounce Mushroom":
		Inventory.use_item(slot)
		_deploy_mushroom()
		return
	elif item.item_name == "Shiny Lure":
		Inventory.use_item(slot)
		_deploy_lure()
		return
	elif item.item_name == "Compass Charm":
		Inventory.use_item(slot)
		_deploy_compass()
		return
	elif item.item_name == "Grub Stick":
		Inventory.use_item(slot)
		_swing_grub_stick()
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
	elif item.item_name == "Lantern Charm":
		_activate_lantern(slot)
		return
	elif item.item_name == "Wax Cache":
		_activate_wax(slot)
		return
	elif _is_buff_item(item):
		if not get(_buff_flag(item.item_name)):
			Inventory.use_item(slot)
			_start_buff(_buff_flag(item.item_name), _buff_duration(item.item_name), item.item_name)
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
	var dir := (_aim_pos() - global_position).normalized()
	drill.setup(dir)

func _throw_bomb() -> void:
	if not Inventory.use_item(Inventory.selected_slot):
		return
	Inventory.selected_slot = -1
	var bomb = bomb_scene.instantiate()
	get_parent().add_child(bomb)
	bomb.global_position = global_position + Vector2(0, -40)
	var dir := (_aim_pos() - global_position).normalized()
	bomb.linear_velocity = dir * 600.0
	bomb.arm()

func _throw_ice_bomb() -> void:
	if not Inventory.use_item(Inventory.selected_slot):
		return
	Inventory.selected_slot = -1
	var bomb = ice_bomb_scene.instantiate()
	get_parent().add_child(bomb)
	bomb.global_position = global_position + Vector2(0, -40)
	var dir := (_aim_pos() - global_position).normalized()
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
	_sprite.modulate = Color(0.6, 0.8, 1, 1)
	await get_tree().create_timer(5.0).timeout
	speed_boost_active = false
	_sprite.modulate = Color.WHITE

func _activate_shield() -> void:
	shield_active = true
	modulate = Color(0.8, 1, 0.8, 1)
	await get_tree().create_timer(5.0).timeout
	shield_active = false
	modulate = Color.WHITE

func _update_camera_position(delta: float) -> void:
	var camera := _camera
	if camera == null:
		return
	var target_global := global_position + (_aim_pos() - global_position) * CAMERA_MOUSE_INFLUENCE

	var lookahead := velocity * CAMERA_LOOKAHEAD
	if is_digging or is_tunneling or is_ground_pounding:
		lookahead *= 0.35
	if lookahead.length() > CAMERA_LOOKAHEAD_MAX:
		lookahead = lookahead.normalized() * CAMERA_LOOKAHEAD_MAX
	target_global += lookahead

	var target_local := to_local(target_global)
	var speed_ratio := minf(velocity.length() / 1500.0, 1.0)
	var follow_speed := lerpf(CAMERA_FOLLOW_SPEED, CAMERA_FOLLOW_SPEED_FAST, speed_ratio)
	var follow_weight := clampf(follow_speed * delta, 0.0, 1.0)
	camera.position = camera.position.lerp(target_local, follow_weight)

## Shared particle material: tunneling spawns dirt every tile, so avoid
## rebuilding the ParticleProcessMaterial (and its ramp) on each burst.
static var _dirt_material: ParticleProcessMaterial = null

func spawn_dirt_particles(world_position: Vector2) -> void:
	if _dirt_ramp == null:
		var fade_gradient := Gradient.new()
		fade_gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		fade_gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_dirt_ramp = GradientTexture1D.new()
		_dirt_ramp.gradient = fade_gradient
	if _dirt_material == null:
		_dirt_material = ParticleProcessMaterial.new()
		_dirt_material.direction = Vector3(0.0, -1.0, 0.0)
		_dirt_material.spread = 70.0
		_dirt_material.gravity = Vector3(0.0, 980.0, 0.0)
		_dirt_material.initial_velocity_min = 140.0
		_dirt_material.initial_velocity_max = 260.0
		_dirt_material.scale_min = 4.0
		_dirt_material.scale_max = 8.0
		_dirt_material.color = Color(0.45, 0.30, 0.16, 1.0)
		_dirt_material.color_ramp = _dirt_ramp
	var dirt := GPUParticles2D.new()
	dirt.global_position = world_position
	dirt.one_shot = true
	dirt.explosiveness = 1.0
	dirt.amount = DIRT_PARTICLE_AMOUNT
	dirt.lifetime = DIRT_PARTICLE_LIFETIME
	dirt.process_material = _dirt_material
	dirt.z_index = 5
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
		var hole := mole_hole_instance
		mole_hole_instance = null
		var tween := hole.create_tween()
		tween.tween_property(hole, "modulate", Color(1, 1, 1, 0), 0.35)
		tween.tween_callback(hole.queue_free)

func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, has_source: bool = false, is_projectile: bool = false) -> void:
	if invulnerable or _dash_invulnerable or health <= 0:
		return
	if health - amount <= 0.0 and _consume_honeycombs():
		Shop.drop_coins(global_position + Vector2(0, -40), 3, 2)
		_spawn_buff_label("HONEYCOMB SAVES YOU!")
		amount = health - 1.0
	health -= amount
	if health <= 0:
		SFX.play("death", global_position)
	else:
		SFX.play("hurt", global_position)
	invulnerable = true
	_damage_flash()
	hurt_anim_time_left = HURT_GROUND_DURATION if is_on_floor() else HURT_AIR_DURATION
	var knockback_direction := -1.0 if _sprite.flip_h else 1.0
	if has_source:
		knockback_direction = sign(global_position.x - source_position.x)
		if knockback_direction == 0.0:
			knockback_direction = -1.0 if _sprite.flip_h else 1.0
	if not shelled_backpack_active:
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
	var camera := _camera
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

func _dash_ability_strike() -> void:
	if not Shop.has_dash_ability():
		return
	_dash_strike_scan_cooldown -= get_physics_process_delta_time()
	if _dash_strike_scan_cooldown > 0.0:
		return
	_dash_strike_scan_cooldown = 0.2
	var front := global_position + Vector2(tunnel_direction * DASH_HIT_RADIUS, 0.0)
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy == null or not is_instance_valid(enemy):
			continue
		if _dash_hit_enemies.get(enemy, false):
			continue
		if front.distance_to(enemy.global_position) > DASH_HIT_RADIUS:
			continue
		_dash_hit_enemies[enemy] = true
		var dmg := DASH_ABILITY_DAMAGE * ComboManager.get_damage_multiplier()
		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
			EnemyDamage.spawn_damage_number(enemy, dmg)
			SFX.play("enemy_hit", enemy.global_position)
			spawn_dirt_particles(enemy.global_position)
		_apply_knockback(enemy, Vector2(tunnel_direction * DASH_KNOCKBACK, -300.0))

func _apply_knockback(enemy: Node, knock_velocity: Vector2) -> void:
	if enemy is CharacterBody2D:
		(enemy as CharacterBody2D).velocity = knock_velocity
	if "_stun_timer" in enemy:
		enemy._stun_timer = maxf(enemy._stun_timer, 0.35)
	else:
		var push_dir := knock_velocity.normalized()
		if push_dir == Vector2.ZERO:
			push_dir = Vector2.RIGHT
		var push := create_tween()
		push.tween_property(enemy, "position", enemy.position + push_dir * 70.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _grant_grapple_hook() -> void:
	if not Shop.has_grappling_hook():
		return
	for slot in Inventory.slots:
		if slot != null and slot.item_name == "Grappling Hook":
			return
	Inventory.add_item_at(GRAPPLE_ITEM, 1)

func _setup_grapple_visuals() -> void:
	_grapple_rope = Line2D.new()
	_grapple_rope.name = "GrappleRope"
	_grapple_rope.width = GRAPPLE_ROPE_WIDTH
	_grapple_rope.default_color = GRAPPLE_ROPE_COLOR
	_grapple_rope.z_index = 5
	_grapple_rope.visible = false
	add_child(_grapple_rope)

	_grapple_anchor_sprite = Sprite2D.new()
	_grapple_anchor_sprite.name = "GrappleAnchor"
	_grapple_anchor_sprite.z_index = 5
	_grapple_anchor_sprite.visible = false
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := 9.5
	for y in 20:
		for x in 20:
			var dx := float(x) - c
			var dy := float(y) - c
			if dx * dx + dy * dy <= c * c:
				img.set_pixel(x, y, Color(1.0, 0.8, 0.35, 0.95))
	_grapple_anchor_sprite.texture = ImageTexture.create_from_image(img)
	add_child(_grapple_anchor_sprite)

func _handle_grapple(delta: float) -> void:
	var slot := Inventory.selected_slot
	var tool_ready: bool = slot >= 0 and slot < Inventory.slots.size() \
			and Inventory.slots[slot] != null and Inventory.slots[slot].item_name == "Grappling Hook"
	if not tool_ready:
		if grapple_active:
			_end_grapple()
		return
	if Input.is_action_just_pressed("dig_slash"):
		if is_digging or is_tunneling or is_ground_pounding:
			return
		if not grapple_active:
			_try_start_grapple()
		return
	if grapple_active and Input.is_action_just_released("dig_slash"):
		_end_grapple()
	if not grapple_active:
		return

	var to_anchor := grapple_anchor - global_position
	if to_anchor.length() <= GRAPPLE_LATCH_DIST:
		_end_grapple()
		velocity *= 0.3
		return

	if not _grapple_rope_clear():
		_end_grapple()
		return

	var desired := to_anchor.normalized() * GRAPPLE_PULL_SPEED
	velocity = velocity.move_toward(desired, GRAPPLE_ACCEL * delta)
	move_and_slide()
	was_on_floor = is_on_floor()
	_update_grapple_visuals()

func _try_start_grapple() -> void:
	var space_state := get_world_2d().direct_space_state
	var from := global_position
	var aim_dir := _aim_pos() - from
	if aim_dir.length_squared() < 16.0:
		return
	aim_dir = aim_dir.normalized()
	var to := from + aim_dir * GRAPPLE_MAX_RANGE
	var query := PhysicsRayQueryParameters2D.create(from, to, _normal_collision_mask)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		if rebound_hook_active:
			_rebound_pull_coin(aim_dir, from)
		return
	grapple_anchor = result.position
	grapple_active = true
	_update_grapple_visuals()
	SFX.play("swing", global_position, -6.0, 0.4)

func _grapple_rope_clear() -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, grapple_anchor, _normal_collision_mask)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	return not result.is_empty() and result.position.distance_to(grapple_anchor) <= 8.0

func _update_grapple_visuals() -> void:
	if _grapple_rope == null or _grapple_anchor_sprite == null:
		return
	_grapple_rope.points = PackedVector2Array([to_local(grapple_anchor), Vector2.ZERO])
	_grapple_rope.visible = grapple_active
	_grapple_anchor_sprite.global_position = grapple_anchor
	_grapple_anchor_sprite.visible = grapple_active

func _end_grapple() -> void:
	if not grapple_active:
		return
	grapple_active = false
	_grapple_rope.visible = false
	_grapple_anchor_sprite.visible = false

func start_ground_pound() -> void:
	is_ground_pounding = true
	_dash_invulnerable = Shop.has_dash_ability()
	_ground_pound_start_y = global_position.y
	velocity.y = GROUND_POUND_SPEED
	velocity.x = 0.0
	_sprite.play("jumpbold")
	_sprite.flip_v = true
	_sprite.rotation = 0.0
	SFX.play("dig_dash", global_position)
	spawn_dirt_particles(global_position)

func _complete_ground_pound() -> void:
	is_ground_pounding = false
	_dash_invulnerable = false
	SFX.play("land", global_position)
	var fall_px := global_position.y - _ground_pound_start_y
	_ground_pound_power = clampf((fall_px - GROUND_POUND_MIN_FALL) / (GROUND_POUND_MAX_FALL - GROUND_POUND_MIN_FALL), 0.0, 1.0)
	screen_shake(lerpf(12.0, 32.0, _ground_pound_power), 0.3)
	spawn_dirt_particles(global_position)
	_break_tiles_in_radius()
	if Shop.has_dash_ability():
		_ground_pound_strike()
	velocity.y = GROUND_POUND_BOUNCE
	_sprite.flip_v = false

func _break_tiles_in_radius() -> void:
	if not tilemap:
		return
	var radius: int = roundi(lerpf(GROUND_POUND_BASE_RADIUS, GROUND_POUND_MAX_RADIUS, _ground_pound_power))
	if shelled_backpack_active or earthquake_boots_active:
		radius += 1
	var center_tile := tilemap.local_to_map(tilemap.to_local(global_position))
	for dx in range(-radius, radius + 1):
		for dy in range(0, radius + 1):
			var tp := Vector2i(center_tile.x + dx, center_tile.y + dy)
			if tilemap.get_cell_source_id(0, tp) != -1:
				TileBreakSFX.break_tile(tilemap, tp, get_parent())
			elif tilemap.get_cell_source_id(1, tp) != -1:
				TileBreakSFX.break_decoration_tile(tilemap, tp, get_parent())
	var chest_radius := lerpf(GROUND_POUND_BASE_HIT_RADIUS, GROUND_POUND_MAX_HIT_RADIUS, _ground_pound_power)
	TileBreakSFX.break_opened_chests_near(get_parent(), global_position, chest_radius)

func _ground_pound_strike() -> void:
	var boosted := shelled_backpack_active or earthquake_boots_active
	var hit_radius := lerpf(GROUND_POUND_BASE_HIT_RADIUS, GROUND_POUND_MAX_HIT_RADIUS, _ground_pound_power)
	var strike_damage := lerpf(GROUND_POUND_BASE_DAMAGE, GROUND_POUND_MAX_DAMAGE, _ground_pound_power)
	if boosted:
		hit_radius *= 1.35
		strike_damage *= 1.5
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > hit_radius:
			continue
		var dmg := strike_damage * ComboManager.get_damage_multiplier()
		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
			EnemyDamage.spawn_damage_number(enemy, dmg)
			SFX.play("enemy_hit", enemy.global_position)
			spawn_dirt_particles(enemy.global_position)
		var dir: Vector2 = (enemy as Node2D).global_position - global_position
		dir = dir.normalized()
		if dir == Vector2.ZERO:
			dir = Vector2(1.0, -0.5).normalized()
		_apply_knockback(enemy, dir * GROUND_POUND_KNOCKBACK + Vector2(0, -350.0))
		if earthquake_boots_active and "_stun_timer" in enemy:
			enemy._stun_timer = maxf(enemy._stun_timer, 0.9)

func start_dig_dash() -> void:
	SFX.play("dig_dash", global_position)
	is_digging = true
	_dash_invulnerable = Shop.has_dash_ability()
	_dig_dash_weapon_was_visible = false
	if has_node("Weapon"):
		_dig_dash_weapon_was_visible = $Weapon.visible
		$Weapon.hide()
	_sprite.play("dig")

	tunnel_direction = -1.0 if _sprite.flip_h else 1.0

	await _sprite.animation_finished

	if not is_digging:
		return

	is_digging = false
	is_tunneling = true
	_sprite.play("tunnel")

	var tunnel_elapsed := 0.0
	var tunnel_total := TUNNEL_DURATION * (1.5 if tunnel_gloves_active else 1.0)
	while tunnel_elapsed < tunnel_total:
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
	_dash_invulnerable = false
	_dash_hit_enemies.clear()
	velocity.x = tunnel_direction * SPEED * 0.5
	velocity.y = -200.0
	if using_ranged:
		return
	if has_node("Weapon"):
		$Weapon.show()
		if $Weapon.has_method("dig_slash"):
			$Weapon.dig_slash()
	screen_shake(18.0, 0.3)
	spawn_dirt_particles(global_position)
	_sprite.play("jumpbold")

func _end_dig_dash() -> void:
	is_tunneling = false
	_dash_invulnerable = false
	_dash_hit_enemies.clear()
	velocity.x = 0
	velocity.y = JUMP_VELOCITY
	if has_node("Weapon") and _dig_dash_weapon_was_visible:
		$Weapon.show()
	_sprite.play("jumpbold")

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

func _launch_custom(script: Script) -> void:
	if not Inventory.use_item(Inventory.selected_slot):
		return
	Inventory.selected_slot = -1
	var obj: RigidBody2D = script.new()
	get_parent().add_child(obj)
	obj.global_position = global_position + Vector2(0, -40)
	var dir := (_aim_pos() - global_position).normalized()
	obj.linear_velocity = dir * 600.0
	obj.arm()

func _use_vacuum() -> void:
	Inventory.selected_slot = -1
	var vac: Node2D = VacuumJelly.new()
	get_parent().add_child(vac)
	vac.global_position = global_position

func _use_shop_token() -> void:
	Inventory.selected_slot = -1
	Shop.open_shop()

func _deploy_mushroom() -> void:
	Inventory.selected_slot = -1
	var shroom: CharacterBody2D = BounceMushroom.new()
	get_parent().add_child(shroom)
	var dir := (_aim_pos() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	shroom.global_position = global_position + dir * 90.0 + Vector2(0, -140)
	shroom.velocity = dir * 420.0

func _deploy_lure() -> void:
	Inventory.selected_slot = -1
	var lure: Node2D = ShinyLure.new()
	get_parent().add_child(lure)
	lure.global_position = global_position + Vector2(0, -30)

func _deploy_compass() -> void:
	Inventory.selected_slot = -1
	var compass: Node2D = CompassCharm.new()
	get_parent().add_child(compass)
	compass.global_position = global_position + Vector2(0, -90)

func _swing_grub_stick() -> void:
	Inventory.selected_slot = -1
	_spawn_buff_label("GRUB WHACK!")
	SFX.play("enemy_hit", global_position, -8.0, 0.1, 1.4)
	var face := -1.0 if _sprite.flip_h else 1.0
	var origin := global_position + Vector2(0, -35)
	var hit := false
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy == null or not is_instance_valid(enemy):
			continue
		var rel: Vector2 = enemy.global_position - origin
		if rel.length() > 125.0:
			continue
		if rel.x != 0.0 and signf(rel.x) != face:
			continue
		hit = true
		if enemy.has_method("take_damage"):
			enemy.take_damage(8.0)
		var dir := Vector2(face, -0.35).normalized()
		if enemy is CharacterBody2D:
			(enemy as CharacterBody2D).velocity = dir * 700.0
		if "_stun_timer" in enemy:
			enemy._stun_timer = maxf(enemy._stun_timer, 0.35)
		SFX.play("enemy_hit", enemy.global_position)
	_spawn_grub_swish(face, hit)
	if not hit:
		heal(1)

func _spawn_grub_swish(face: float, hit: bool) -> void:
	var arc := Line2D.new()
	arc.width = 10.0
	arc.default_color = Color(0.6, 0.75, 0.35, 0.9) if hit else Color(0.85, 0.8, 0.6, 0.8)
	arc.z_index = 6
	arc.antialiased = true
	var pts := PackedVector2Array()
	for i in 7:
		var ang := lerpf(-1.5, 1.5, float(i) / 6.0)
		var dirv := Vector2(cos(ang), sin(ang) * 0.7)
		if face < 0.0:
			dirv.x = -dirv.x
		pts.append(dirv * 85.0 + Vector2(0, -35))
	arc.points = pts
	var scene := get_tree().current_scene
	scene.add_child(arc)
	arc.global_position = global_position
	var tw := arc.create_tween()
	tw.tween_property(arc, "modulate:a", 0.0, 0.22)
	tw.tween_callback(arc.queue_free)

func _is_buff_item(item: ItemData) -> bool:
	match item.item_name:
		"Tunnel Gloves", "Shelled Backpack", "Climbing Talons", "Rebound Hook", "Earthquake Boots", "Mol-dozer Ram":
			return true
	return false

func _buff_flag(item_name: String) -> String:
	match item_name:
		"Tunnel Gloves":
			return "tunnel_gloves_active"
		"Shelled Backpack":
			return "shelled_backpack_active"
		"Climbing Talons":
			return "climbing_talons_active"
		"Rebound Hook":
			return "rebound_hook_active"
		"Earthquake Boots":
			return "earthquake_boots_active"
		"Mol-dozer Ram":
			return "mol_dozer_active"
	return ""

func _buff_duration(item_name: String) -> float:
	match item_name:
		"Tunnel Gloves":
			return 60.0
		"Shelled Backpack", "Earthquake Boots":
			return 30.0
		"Climbing Talons":
			return 10.0
		"Rebound Hook":
			return 60.0
		"Mol-dozer Ram":
			return 15.0
	return 20.0

func _start_buff(flag: String, duration: float, label_text: String) -> void:
	if get(flag):
		return
	set(flag, true)
	if flag == "mol_dozer_active":
		_mol_dozer_hit.clear()
	_spawn_buff_label("%s +%.0fs" % [label_text, duration])
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		set(flag, false)

func _activate_lantern(slot: int) -> void:
	if lantern_charm_active:
		return
	if not Inventory.use_item(slot):
		return
	Inventory.selected_slot = -1
	lantern_charm_active = true
	_spawn_buff_label("LANTERN CHARM +60s")
	if _mole_light:
		_mole_light.energy = maxf(_mole_light_base_energy * 1.8, _mole_light.energy + 0.8)
		_mole_light.texture_scale = _mole_light_base_scale + 2.0
	await get_tree().create_timer(60.0).timeout
	if is_instance_valid(self):
		lantern_charm_active = false
		if _mole_light:
			_mole_light.energy = _mole_light_base_energy
			_mole_light.texture_scale = _mole_light_base_scale

func _activate_wax(slot: int) -> void:
	if wax_cache_active:
		return
	if not Inventory.use_item(slot):
		return
	Inventory.selected_slot = -1
	wax_cache_active = true
	Inventory.refund_chance = 0.25
	_spawn_buff_label("WAX CACHE +60s")
	await get_tree().create_timer(60.0).timeout
	if is_instance_valid(self):
		wax_cache_active = false
		Inventory.refund_chance = 0.0

func _spawn_buff_label(text: String) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 55
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	scene.add_child(label)
	label.global_position = global_position + Vector2(-110, -170)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 34.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.chain().tween_callback(label.queue_free)

func _dozer_ram() -> void:
	var face := -1.0 if _sprite.flip_h else 1.0
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider == null or collider.is_in_group("mole") or collider.is_in_group("pushable"):
			continue
		if not collider.has_method("take_damage") and not collider.has_method("die"):
			continue
		if _mol_dozer_hit.get(collider, false):
			continue
		_mol_dozer_hit[collider] = true
		if collider.has_method("take_damage"):
			collider.take_damage(12.0)
		if collider is CharacterBody2D:
			(collider as CharacterBody2D).velocity = Vector2(face * 850.0, -300.0)
		if "_stun_timer" in collider:
			collider._stun_timer = maxf(collider._stun_timer, 0.4)
		SFX.play("enemy_hit", collider.global_position)
		spawn_dirt_particles(collider.global_position)

func _rebound_pull_coin(aim_dir: Vector2, from: Vector2) -> void:
	var best: Node = null
	var best_dist := INF
	for c in get_tree().get_nodes_in_group("coin"):
		if not is_instance_valid(c):
			continue
		var coin_pos: Vector2 = (c as Node2D).global_position
		var to_c := coin_pos - from
		var lenv := to_c.length()
		if lenv > 360.0 or lenv <= 0.0:
			continue
		if to_c.normalized().dot(aim_dir) < 0.7:
			continue
		if lenv < best_dist:
			best_dist = lenv
			best = c
	if best:
		var b := best as RigidBody2D
		b.sleeping = false
		b.linear_velocity = (global_position - best.global_position).normalized() * 1800.0
		SFX.play("coin", best.global_position, -12.0, 0.1, 1.5)

func _consume_honeycombs() -> bool:
	for i in Inventory.MAX_SLOTS:
		if Inventory.slots[i] != null and Inventory.slots[i].item_name == "Potted Honeycomb":
			if Inventory.use_item(i):
				return true
			break
	return false

func _push_rocks() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider != null and collider.is_in_group("pushable") and collider.has_method("push"):
			var dir_x := -signf(collision.get_normal().x)
			if dir_x != 0.0:
				collider.push(Vector2(dir_x, 0.0))
