extends RigidBody2D

@export var prompt_text := "PRESS E TO INTERACT"
@export var npc_name := "Snail"
@export var portrait_texture: Texture2D = null
@export_multiline var dialogue_text := ""
@export_multiline var post_dialogue_text := ""
@export var condition_wave_path := NodePath("")
@export var unlock_ability := ""
@export var unlock_text := ""
@export var face_player := true
## Some story snails visibly transform after their dialogue is dismissed.
@export var transform_after_dialogue := false
## Starts a boss fight after the transformation finishes; used by the level 10 snail.
@export var boss_after_dialogue := false
## The artwork faces left at flip_h = false, so flipping points it right.
@export var sprite_faces_left := true

const TRANSFORM_SCALE := 7.0
const EnemyDamage := preload("res://scripts/enemy.gd")
const AURA_COLORS := [Color(0.72, 0.25, 1.0, 0.65), Color(0.82, 0.48, 1.0, 0.32)]
const AURA_SCALE_FACTORS := [1.18, 1.38]
const TRANSFORM_DURATION := 16.0
const BOSS_TRANSFORM_DURATION := 3.2
const BOSS_HEALTH_BAR_WIDTH := 592.0
const BOSS_HEALTH_BAR_HEIGHT := 48.0
const BOSS_HEALTH_BAR_INSET := 14.0
const BOSS_HEALTH_FILL_INSET := 3.0
const BOSS_HEALTH_BAR_INNER := BOSS_HEALTH_BAR_WIDTH - BOSS_HEALTH_FILL_INSET * 2.0
const BOSS_HEALTH_PANEL_WIDTH := BOSS_HEALTH_BAR_WIDTH + BOSS_HEALTH_BAR_INSET * 2.0
const BOSS_HEALTH_PANEL_HEIGHT := BOSS_HEALTH_BAR_HEIGHT + BOSS_HEALTH_BAR_INSET * 2.0
const BOSS_HEALTH_NAME_HEIGHT := 46.0
const BOSS_HEALTH_NAME_GAP := 12.0
const BOSS_HEALTH_ROOT_WIDTH := BOSS_HEALTH_PANEL_WIDTH
const BOSS_HEALTH_ROOT_HEIGHT := BOSS_HEALTH_NAME_HEIGHT + BOSS_HEALTH_NAME_GAP + BOSS_HEALTH_PANEL_HEIGHT
const BOSS_HEALTH_FONT := preload("res://Baby Doll.otf")

const BOSS_MAX_HEALTH := 1000.0
const BOSS_CHASE_SPEED := 50.0
const BOSS_SPIT_INTERVAL := 2.4
const BOSS_PROJECTILE_SPEED := 620.0
const BOSS_LASER_COOLDOWN := 9.0
const BOSS_LASER_CHARGE_TIME := 1.5
const BOSS_LASER_STRIKE_DURATION := 1.25
const BOSS_LASER_LENGTH := 3000.0
const BOSS_LASER_WIDTH := 136.0
const BOSS_LASER_TILE_SAMPLE_SPACING := 38.0
const BOSS_LASER_DAMAGE := 2.0
const BOSS_TILE_BREAK_INTERVAL := 0.22
const BOSS_MINION_SPAWN_INTERVAL := Vector2(5.0, 8.0)
const BOSS_MINION_MAX_ALIVE := 4
const BOSS_MINION_SCENES: Array[PackedScene] = [
	preload("res://scenes/antenemy.tscn"),
	preload("res://scenes/beetleenemy.tscn"),
	preload("res://scenes/goblinenemy.tscn"),
	preload("res://scenes/slimeenemy.tscn"),
]
const BOSS_PROJECTILE_SCENE := preload("res://area_2d.tscn")
## The boss is enormous and summons adds, so the view pulls back for the fight.
const BOSS_CAM_ZOOM := Vector2(0.42, 0.42)
const BOSS_CAM_ZOOM_IN_TIME := 1.1
const BOSS_CAM_ZOOM_OUT_TIME := 0.8

var _boss_minion_spawn_timer := 0.0
const TileBreakSFX := preload("res://scripts/tile_break_sfx.gd")

var _original_sprite_scale := Vector2.ONE
var _transform_ground_y := 0.0
var _aura_sprites: Array[Sprite2D] = []
var _transformed := false
var _boss_active := false
var _boss_dying := false
var _boss_health := BOSS_MAX_HEALTH
var _boss_spit_timer := 0.0
var _boss_laser_timer := 0.0
var _boss_laser_active := false
var _boss_laser_lines: Array[Line2D] = []
var _boss_break_timer := 0.0
var _boss_contact_timer := 0.0
var _boss_projectile_count := 0
var _boss_hurtbox: Area2D = null
var _boss_player_contact: Area2D = null
var _boss_health_layer: CanvasLayer = null
var _boss_health_fill: ColorRect = null
var _boss_hit_tween: Tween = null
var _boss_base_scale := Vector2.ONE
var _boss_cam_zoom_tween: Tween = null
var _boss_cam_restore_zoom := Vector2(0.65, 0.65)

const ITEM_GET := preload("res://scripts/item_get_animation.gd")
## Melee weapons have no artwork of their own, so - like the weapon the mole
## actually carries - the fanfare tints the shovel icon with the weapon colour.
const MELEE_ICON := preload("res://sprites/shovel.png")
## Roughly the dialogue box's slide-away, so the fanfare lands once it is gone.
const FANFARE_DELAY := 0.35

var _mole_overlapping := false
var _dialogue_open := false
var _condition_met := false
var _label: Label = null
var _dialogue_box: CanvasLayer = null
var _sprite: AnimatedSprite2D = null
var _player: Node2D = null
## Set once this NPC has said everything that matters - it has already handed
## over its tool - so it stops prompting and stops listening for interact.
var _hushed := false

## The reward earned by the last dialogue, held back until the box has slid
## away so the fanfare is not talking over the text that announced it.
var _reward_message := ""
var _reward_icon: Texture2D = null
var _reward_tint := Color.WHITE
var _banner_text := ""

signal dialogue_closed

func _ready() -> void:
	var zone := get_node_or_null("Area2D") as Area2D
	if zone:
		zone.body_entered.connect(_on_body_entered)
		zone.body_exited.connect(_on_body_exited)
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite:
		_original_sprite_scale = _sprite.scale
		var sprite_texture := _current_sprite_texture()
		if sprite_texture:
			_transform_ground_y = _sprite.position.y + sprite_texture.get_size().y * _original_sprite_scale.y * 0.5
		else:
			_transform_ground_y = _sprite.position.y
	_label = get_node_or_null("Area2D/Prompt") as Label
	if _label:
		if prompt_text != "":
			_label.text = prompt_text
		_label.visible = false
		_label.z_index = 100
		_label.z_as_relative = false
	_hushed = _refresh_hushed()
	_setup_condition()
	if boss_after_dialogue:
		_boss_health = BOSS_MAX_HEALTH

func _physics_process(delta: float) -> void:
	if not _boss_active or _boss_dying:
		return
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return

	var direction := signf(mole.global_position.x - global_position.x)
	if direction == 0.0:
		direction = -1.0 if _sprite.flip_h else 1.0
	_sprite.flip_h = (direction > 0.0) == sprite_faces_left
	if direction != 0.0:
		linear_velocity.x = direction * BOSS_CHASE_SPEED
	linear_velocity.y = minf(linear_velocity.y, 900.0)

	_boss_break_timer -= delta
	if _boss_break_timer <= 0.0:
		_boss_break_timer = BOSS_TILE_BREAK_INTERVAL
		_break_blocks_ahead(direction)

	if not _boss_laser_active:
		_boss_spit_timer -= delta
		if _boss_spit_timer <= 0.0:
			_boss_spit_timer = BOSS_SPIT_INTERVAL
			_spit_boss_projectile(mole)

		_boss_laser_timer -= delta
		if _boss_laser_timer <= 0.0:
			_boss_laser_timer = BOSS_LASER_COOLDOWN
			_fire_boss_laser(mole)

	_boss_minion_spawn_timer -= delta
	if _boss_minion_spawn_timer <= 0.0:
		_spawn_boss_minion()
		_boss_minion_spawn_timer = randf_range(BOSS_MINION_SPAWN_INTERVAL.x, BOSS_MINION_SPAWN_INTERVAL.y)

	_boss_contact_timer = maxf(0.0, _boss_contact_timer - delta)
	if _boss_contact_timer <= 0.0 and _boss_player_contact != null and _boss_player_contact.overlaps_body(mole):
		_boss_contact_timer = 0.9
		mole.call("take_damage", 1.0, global_position, true)

## An NPC is done talking once the one thing it exists to hand over is already
## in the mole's hands. Anything with no unlock to give talks forever.
func _refresh_hushed() -> bool:
	if unlock_ability == "":
		return false
	var shop := get_tree().get_root().get_node_or_null("/root/Shop")
	return shop != null and shop.has_method("owns") and shop.owns(unlock_ability)

func _setup_condition() -> void:
	if condition_wave_path.is_empty():
		return
	var wm: Node = get_node_or_null(condition_wave_path)
	if wm != null and wm.has_signal("cleared"):
		wm.cleared.connect(_on_condition_met)

func _on_condition_met() -> void:
	_condition_met = true
	if post_dialogue_text != "" and dialogue_text != post_dialogue_text:
		dialogue_text = post_dialogue_text

func _process(_delta: float) -> void:
	if _label:
		_label.visible = _mole_overlapping and not _dialogue_open and not _hushed
	_update_facing()
	_update_transformation_aura()

## Flip the sprite only - the body, collision shapes and Area2D are untouched.
func _update_facing() -> void:
	if _boss_active or not face_player or _sprite == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("mole") as Node2D
		if _player == null:
			return
	var dx := _player.global_position.x - global_position.x
	if absf(dx) < 4.0:
		return
	_sprite.flip_h = (dx > 0.0) == sprite_faces_left

func _unhandled_input(event: InputEvent) -> void:
	if not _mole_overlapping or _dialogue_open or _hushed or dialogue_text.is_empty():
		return
	if event.is_action_pressed("interact"):
		_open_dialogue()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_overlapping = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_overlapping = false

func show_dialogue() -> void:
	if _dialogue_open:
		return
	# Hushed: there is nothing to show, but the caller (the arena camera) is
	# waiting to hear the box close, so answer it or the sequence would stall.
	if _hushed:
		dialogue_closed.emit.call_deferred()
		return
	_open_dialogue()

func _open_dialogue() -> void:
	_dialogue_open = true
	_dialogue_box = preload("res://scenes/dialogue_box.tscn").instantiate()
	_dialogue_box.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_dialogue_box)
	_dialogue_box.next_pressed.connect(_on_dialogue_done)
	_dialogue_box.set_portrait(portrait_texture)
	_dialogue_box.set_npc_name(npc_name)
	_apply_portrait_blink()
	_dialogue_box.show_text(dialogue_text, 0, 0, true, false)

## Mirror the NPC's own blink cycle onto the dialogue portrait, if it has one.
func _apply_portrait_blink() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim := "blink"
	var rest := 0
	var lo := 1.0
	var hi := 3.0
	if "blink_animation" in sprite:
		anim = sprite.blink_animation
		rest = sprite.rest_frame
		lo = sprite.min_interval
		hi = sprite.max_interval
	if not sprite.sprite_frames.has_animation(anim):
		return
	var frames: Array = []
	for i in sprite.sprite_frames.get_frame_count(anim):
		frames.append(sprite.sprite_frames.get_frame_texture(anim, i))
	if frames.size() < 2:
		return
	_dialogue_box.set_portrait_animation(frames, lo, hi, rest, sprite.sprite_frames.get_animation_speed(anim))

func _on_dialogue_done() -> void:
	_start_transformation()
	_grant_unlock()
	# This story encounter becomes a boss, not an interactable NPC, after its scene.
	_hushed = true if boss_after_dialogue else _refresh_hushed()
	if _dialogue_box == null or not is_instance_valid(_dialogue_box):
		_dialogue_box = null
		_dialogue_open = false
		dialogue_closed.emit()
		_show_reward()
		return
	var box := _dialogue_box
	_dialogue_box = null
	box.hide_box()
	# process_always = true, so the reward still plays out if the game is paused
	# underneath it (the arena starts panning back the moment this emits).
	get_tree().create_timer(FANFARE_DELAY).timeout.connect(func():
		if is_instance_valid(box):
			box.queue_free()
		_show_reward()
	)
	_dialogue_open = false
	dialogue_closed.emit()

func _start_transformation() -> void:
	if not transform_after_dialogue or _transformed or _sprite == null:
		return
	_transformed = true

	var duration := BOSS_TRANSFORM_DURATION if boss_after_dialogue else TRANSFORM_DURATION
	_siphon_player_aura(duration)
	for i in AURA_COLORS.size():
		var aura := Sprite2D.new()
		aura.texture = _current_sprite_texture()
		aura.position = _sprite.position
		aura.scale = _original_sprite_scale * 1.35
		aura.modulate = Color(AURA_COLORS[i].r, AURA_COLORS[i].g, AURA_COLORS[i].b, 0.0)
		aura.z_index = _sprite.z_index - 1
		aura.flip_h = _sprite.flip_h
		var aura_material := CanvasItemMaterial.new()
		aura_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		aura.material = aura_material
		add_child(aura)
		move_child(aura, _sprite.get_index())
		_aura_sprites.append(aura)

		var aura_tween := create_tween()
		aura_tween.set_parallel(true)
		aura_tween.tween_property(aura, "scale", _original_sprite_scale * TRANSFORM_SCALE * AURA_SCALE_FACTORS[i], duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		aura_tween.tween_property(aura, "modulate:a", AURA_COLORS[i].a, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var grow_tween := create_tween()
	var target_scale := _original_sprite_scale * TRANSFORM_SCALE
	if boss_after_dialogue:
		grow_tween.tween_property(_sprite, "scale", target_scale, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		grow_tween.tween_callback(_begin_boss_fight)
	else:
		grow_tween.tween_property(_sprite, "scale", target_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The snail pulls visible copies of the mole's glow toward itself while the
## mole's own light fades, making the growth feel like a gradual siphon.
func _siphon_player_aura(duration: float) -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return
	var mole_sprite := mole.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if mole_sprite == null:
		return

	var mole_light := mole.get_node_or_null("MoleLight") as PointLight2D
	if mole_light != null:
		var light_tween := mole.create_tween()
		light_tween.tween_property(mole_light, "energy", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	var echo_count := 12
	var interval := duration / float(echo_count)
	for i in echo_count:
		if not is_instance_valid(mole) or not is_instance_valid(mole_sprite) or not is_inside_tree():
			return
		_emit_aura_echo(mole_sprite, interval * 2.5)
		if i < echo_count - 1:
			await get_tree().create_timer(interval).timeout

func _emit_aura_echo(source: AnimatedSprite2D, travel_time: float) -> void:
	if source.sprite_frames == null or _sprite == null:
		return
	var texture := source.sprite_frames.get_frame_texture(source.animation, source.frame)
	if texture == null:
		return
	var echo := Sprite2D.new()
	echo.texture = texture
	echo.flip_h = source.flip_h
	echo.rotation = source.global_rotation
	echo.global_scale = source.global_scale * 0.8
	echo.modulate = Color(0.82, 0.42, 1.0, 0.7)
	echo.z_index = 20
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	echo.material = additive
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(echo)
	echo.global_position = source.global_position

	var tween := echo.create_tween()
	tween.set_parallel(true)
	tween.tween_property(echo, "global_position", global_position + Vector2(0.0, -24.0), travel_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(echo, "global_scale", echo.global_scale * 0.3, travel_time)
	tween.tween_property(echo, "modulate:a", 0.0, travel_time)
	tween.chain().tween_callback(echo.queue_free)

func _begin_boss_fight() -> void:
	if not boss_after_dialogue or not is_inside_tree() or _boss_dying:
		return
	_boss_active = true
	_boss_health = BOSS_MAX_HEALTH
	if _label != null:
		_label.visible = false
	var interaction_area := get_node_or_null("Area2D") as Area2D
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", false)
		interaction_area.set_deferred("monitorable", false)
	_boss_spit_timer = 1.0
	_boss_laser_timer = 5.0
	_boss_laser_active = false
	_boss_minion_spawn_timer = 3.0
	_boss_break_timer = 0.0
	linear_velocity = Vector2.ZERO
	sleeping = false
	gravity_scale = 1.0
	collision_layer = 4
	collision_mask = 1
	lock_rotation = true
	_boss_base_scale = _sprite.scale
	_resize_boss_body()
	_add_boss_hurtbox()
	_create_boss_health_bar()
	_start_boss_camera_zoom()
	SFX.play("explosion", global_position, -8.0, 0.2, 0.8)

## Tweens are bound to the camera, not this node, so the zoom survives our own death.
func _boss_camera() -> Camera2D:
	if not is_inside_tree():
		return null
	return get_viewport().get_camera_2d() as Camera2D

func _stop_boss_camera_zoom() -> void:
	if _boss_cam_zoom_tween != null and _boss_cam_zoom_tween.is_valid():
		_boss_cam_zoom_tween.kill()
	_boss_cam_zoom_tween = null

func _tween_boss_camera_zoom(camera: Camera2D, target: Vector2, duration: float) -> void:
	_stop_boss_camera_zoom()
	_boss_cam_zoom_tween = camera.create_tween()
	_boss_cam_zoom_tween.tween_property(camera, "zoom", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _start_boss_camera_zoom() -> void:
	var camera := _boss_camera()
	if camera == null:
		return
	if _boss_cam_zoom_tween == null:
		_boss_cam_restore_zoom = camera.zoom
	_tween_boss_camera_zoom(camera, BOSS_CAM_ZOOM, BOSS_CAM_ZOOM_IN_TIME)

func _restore_boss_camera_zoom() -> void:
	var camera := _boss_camera()
	if camera == null:
		return
	_tween_boss_camera_zoom(camera, _boss_cam_restore_zoom, BOSS_CAM_ZOOM_OUT_TIME)

func _resize_boss_body() -> void:
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape == null:
		return
	var body_rect := body_shape.shape as RectangleShape2D
	if body_rect == null:
		return
	body_rect = body_rect.duplicate() as RectangleShape2D
	body_rect.size = _boss_body_size()
	body_shape.shape = body_rect
	body_shape.position = Vector2(0.0, _transform_ground_y - body_rect.size.y * 0.5)

func _add_boss_hurtbox() -> void:
	_boss_hurtbox = Area2D.new()
	_boss_hurtbox.name = "BossHurtbox"
	_boss_hurtbox.collision_layer = 1
	_boss_hurtbox.collision_mask = 1
	_boss_hurtbox.monitoring = true
	_boss_hurtbox.monitorable = true
	_boss_hurtbox.add_to_group("enemy_hurtbox")
	add_child(_boss_hurtbox)
	var shape := CollisionShape2D.new()
	shape.set_meta("snail_boss_hurt_shape", true)
	var rect := RectangleShape2D.new()
	var boss_size := _boss_body_size()
	rect.size = boss_size
	shape.shape = rect
	shape.position = Vector2(0.0, _transform_ground_y - boss_size.y * 0.5)
	_boss_hurtbox.add_child(shape)
	_boss_hurtbox.area_entered.connect(_on_boss_hurtbox_area_entered)

	_boss_player_contact = Area2D.new()
	_boss_player_contact.name = "BossPlayerContact"
	_boss_player_contact.collision_layer = 0
	_boss_player_contact.collision_mask = 1
	_boss_player_contact.monitoring = true
	_boss_player_contact.monitorable = false
	add_child(_boss_player_contact)
	var contact_shape := CollisionShape2D.new()
	var contact_rect := RectangleShape2D.new()
	contact_rect.size = boss_size
	contact_shape.shape = contact_rect
	contact_shape.position = shape.position
	_boss_player_contact.add_child(contact_shape)

func _on_boss_hurtbox_area_entered(area: Area2D) -> void:
	if not _boss_active or _boss_dying:
		return
	var attacker := area.get_parent()
	if attacker == null:
		return
	if "is_swinging" in attacker and attacker.is_swinging and attacker.has_method("get_damage"):
		var direction: Vector2 = (global_position - attacker.global_position).normalized()
		take_damage(float(attacker.get_damage()), direction)
	elif attacker.is_in_group("bullet") and attacker.has_method("deflect"):
		attacker.deflect(global_position)

func take_damage(amount: float, _direction: Vector2 = Vector2.ZERO) -> void:
	if not _boss_active or _boss_dying or amount <= 0.0:
		return
	_boss_health = maxf(_boss_health - amount, 0.0)
	EnemyDamage.spawn_damage_number(self, amount, get_global_mouse_position(), true)
	SFX.play("enemy_hit", global_position)
	if _boss_hit_tween and _boss_hit_tween.is_valid():
		_boss_hit_tween.kill()
	_boss_hit_tween = create_tween()
	_boss_hit_tween.tween_property(_sprite, "scale:y", _boss_base_scale.y * 0.93, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_boss_hit_tween.tween_property(_sprite, "scale:y", _boss_base_scale.y, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_boss_health_bar()
	var mole := get_tree().get_first_node_in_group("mole")
	if mole != null and mole.has_method("screen_shake"):
		mole.screen_shake(8.0, 0.16)
	if _boss_health <= 0.0:
		_defeat_boss()

func _create_boss_health_bar() -> void:
	_boss_health_layer = CanvasLayer.new()
	_boss_health_layer.name = "SnailBossHealthBar"
	_boss_health_layer.layer = 40
	get_parent().add_child(_boss_health_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -BOSS_HEALTH_ROOT_WIDTH * 0.5
	root.offset_top = 18.0
	root.offset_right = BOSS_HEALTH_ROOT_WIDTH * 0.5
	root.offset_bottom = 18.0 + BOSS_HEALTH_ROOT_HEIGHT
	root.custom_minimum_size = Vector2(BOSS_HEALTH_ROOT_WIDTH, BOSS_HEALTH_ROOT_HEIGHT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_health_layer.add_child(root)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.05, 0.9)
	style.border_color = Color(0.42, 0.28, 0.14, 1.0)
	style.set_border_width_all(2)
	var name_panel := Panel.new()
	name_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_panel.offset_left = 0.0
	name_panel.offset_top = 0.0
	name_panel.offset_right = 0.0
	name_panel.offset_bottom = BOSS_HEALTH_NAME_HEIGHT
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_theme_stylebox_override("panel", style)
	root.add_child(name_panel)
	var title := Label.new()
	title.text = "Corrupted Snail"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.offset_left = 0.0
	title.offset_top = 0.0
	title.offset_right = 0.0
	title.offset_bottom = 0.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = false
	title.add_theme_font_override("font", BOSS_HEALTH_FONT)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.92, 0.72, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_child(title)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0.0
	panel.offset_top = BOSS_HEALTH_NAME_HEIGHT + BOSS_HEALTH_NAME_GAP
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.custom_minimum_size = Vector2(BOSS_HEALTH_PANEL_WIDTH, BOSS_HEALTH_PANEL_HEIGHT)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = BOSS_HEALTH_BAR_INSET
	bg.offset_top = BOSS_HEALTH_BAR_INSET
	bg.offset_right = -BOSS_HEALTH_BAR_INSET
	bg.offset_bottom = -BOSS_HEALTH_BAR_INSET
	bg.color = Color(0.12, 0.08, 0.05, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	_boss_health_fill = ColorRect.new()
	_boss_health_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_health_fill.offset_left = BOSS_HEALTH_FILL_INSET
	_boss_health_fill.offset_top = BOSS_HEALTH_FILL_INSET
	_boss_health_fill.offset_right = -BOSS_HEALTH_FILL_INSET
	_boss_health_fill.offset_bottom = -BOSS_HEALTH_FILL_INSET
	_boss_health_fill.color = Color(0.85, 0.25, 0.25, 1.0)
	_boss_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_boss_health_fill)
	_update_boss_health_bar()

func _update_boss_health_bar() -> void:
	if _boss_health_fill == null:
		return
	var ratio := clampf(_boss_health / BOSS_MAX_HEALTH, 0.0, 1.0)
	_boss_health_fill.offset_right = -(BOSS_HEALTH_FILL_INSET + BOSS_HEALTH_BAR_INNER * (1.0 - ratio))
	_boss_health_fill.color = Color(0.85, 0.25, 0.25, 1.0) if ratio > 0.35 else Color(0.95, 0.6, 0.15, 1.0)

func _spawn_boss_minion() -> void:
	if not _boss_active or _boss_dying or BOSS_MINION_SCENES.is_empty():
		return
	if get_tree().get_nodes_in_group("snail_boss_minion").size() >= BOSS_MINION_MAX_ALIVE:
		return

	var parent := get_parent() as Node2D
	if parent == null:
		return
	var scene: PackedScene = BOSS_MINION_SCENES.pick_random()
	var minion := scene.instantiate() as Node2D
	if minion == null:
		return
	minion.add_to_group("snail_boss_minion")

	# Release each random enemy from the front of the shell, at the same spot as
	# the snail's spit, so it drops into the arena like it was coughed out.
	var direction := 1.0 if _sprite.flip_h else -1.0
	var texture := _current_sprite_texture()
	var texture_size := texture.get_size() if texture != null else Vector2(585.0, 442.0)
	var spawn_offset := _sprite.position + Vector2(
		direction * texture_size.x * _boss_base_scale.x * 0.32,
		-texture_size.y * _boss_base_scale.y * 0.06
	)
	minion.position = parent.to_local(to_global(spawn_offset))
	parent.add_child(minion)
	SFX.play("enemy_fire", to_global(spawn_offset), -8.0, 0.15, 0.85)

func _fire_boss_laser(mole: Node2D) -> void:
	if _boss_laser_active or not _boss_active or _boss_dying or not is_instance_valid(mole):
		return
	_boss_laser_active = true

	# Lock direction during the warning so the player has time to dodge.
	var laser_start := _sprite.global_position
	var laser_direction := (mole.global_position - laser_start).normalized()
	if laser_direction == Vector2.ZERO:
		laser_direction = Vector2.DOWN
	var laser_end := laser_start + laser_direction * BOSS_LASER_LENGTH
	var telegraph := _create_boss_laser_lines(laser_start, laser_end, true)
	_boss_laser_lines = telegraph
	for line in telegraph:
		if not is_instance_valid(line):
			continue
		var alpha_tween := line.create_tween().set_loops(8)
		alpha_tween.tween_property(line, "modulate:a", 0.2, 0.1)
		alpha_tween.tween_property(line, "modulate:a", 1.0, 0.1)
		var base_width := line.width
		var width_tween := line.create_tween().set_loops(8)
		width_tween.tween_property(line, "width", base_width * 0.75, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		width_tween.tween_property(line, "width", base_width * 1.3, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	SFX.play("enemy_fire", laser_start, -2.0, 0.2)
	if mole.has_method("screen_shake"):
		mole.call("screen_shake", 5.0, 0.18)

	await get_tree().create_timer(BOSS_LASER_CHARGE_TIME).timeout
	if not is_inside_tree() or not _boss_active or _boss_dying:
		_clear_boss_laser_lines(telegraph)
		_boss_laser_lines.clear()
		if is_inside_tree():
			_boss_laser_active = false
			_boss_laser_timer = BOSS_LASER_COOLDOWN
		return

	_clear_boss_laser_lines(telegraph)
	var beam := _create_boss_laser_lines(laser_start, laser_end, false)
	_boss_laser_lines = beam
	_animate_boss_laser(beam)
	SFX.play("explosion", laser_start, -3.0, 0.12)
	if is_instance_valid(mole) and mole.has_method("screen_shake"):
		mole.call("screen_shake", 16.0, BOSS_LASER_STRIKE_DURATION)
	_damage_mole_in_boss_laser(mole, laser_start, laser_end)
	_break_blocks_along_boss_laser(laser_start, laser_end)

	var laser_time_left := BOSS_LASER_STRIKE_DURATION
	while laser_time_left > 0.0:
		var damage_interval := minf(0.1, laser_time_left)
		await get_tree().create_timer(damage_interval).timeout
		laser_time_left -= damage_interval
		_damage_mole_in_boss_laser(mole, laser_start, laser_end)
	_clear_boss_laser_lines(beam)
	_boss_laser_lines.clear()
	if is_inside_tree():
		_boss_laser_active = false
		_boss_laser_timer = BOSS_LASER_COOLDOWN

func _create_boss_laser_lines(start: Vector2, finish: Vector2, telegraph: bool) -> Array[Line2D]:
	var lines: Array[Line2D] = []
	var widths: Array[float]
	var colors: Array[Color]
	if telegraph:
		widths = [82.0, 38.0]
		colors = [Color(0.34, 0.02, 0.72, 0.48), Color(0.82, 0.35, 1.0, 0.85)]
	else:
		widths = [BOSS_LASER_WIDTH + 72.0, BOSS_LASER_WIDTH + 28.0, BOSS_LASER_WIDTH, 30.0]
		colors = [Color(0.28, 0.01, 0.58, 0.38), Color(0.62, 0.06, 1.0, 0.7), Color(0.88, 0.42, 1.0, 0.98), Color(0.98, 0.82, 1.0, 1.0)]

	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return lines
	for i in widths.size():
		var line := Line2D.new()
		line.width = widths[i]
		line.default_color = colors[i]
		line.z_index = 25
		line.z_as_relative = false
		line.add_point(scene_root.to_local(start))
		line.add_point(scene_root.to_local(finish))
		scene_root.add_child(line)
		lines.append(line)
	return lines

func _animate_boss_laser(lines: Array[Line2D]) -> void:
	for line in lines:
		if not is_instance_valid(line):
			continue
		var base_width := line.width
		var tween := line.create_tween().set_loops()
		tween.tween_property(line, "width", base_width * 1.2, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(line, "width", base_width * 0.88, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(line, "width", base_width, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _clear_boss_laser_lines(lines: Array[Line2D]) -> void:
	for line in lines:
		if is_instance_valid(line):
			line.queue_free()

func _damage_mole_in_boss_laser(mole: Node2D, start: Vector2, finish: Vector2) -> void:
	if not is_instance_valid(mole) or not mole.has_method("take_damage"):
		return
	var segment := finish - start
	if segment.length_squared() <= 0.0:
		return
	var progress := clampf((mole.global_position - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	var closest := start + segment * progress
	if mole.global_position.distance_to(closest) <= BOSS_LASER_WIDTH * 0.5 + 28.0:
		mole.call("take_damage", BOSS_LASER_DAMAGE, start, true, true)

func _break_blocks_along_boss_laser(start: Vector2, finish: Vector2) -> void:
	var tilemap := get_parent().get_node_or_null("TileMap") as TileMap
	if tilemap == null:
		return
	var segment := finish - start
	var distance := segment.length()
	if distance <= 0.0:
		return
	var direction := segment / distance
	var perpendicular := Vector2(-direction.y, direction.x)
	var sample_count := maxi(1, int(ceil(distance / BOSS_LASER_TILE_SAMPLE_SPACING)))
	for i in range(sample_count + 1):
		var center := start + direction * minf(float(i) * BOSS_LASER_TILE_SAMPLE_SPACING, distance)
		for offset in [-BOSS_LASER_WIDTH * 0.5, -BOSS_LASER_WIDTH * 0.25, 0.0, BOSS_LASER_WIDTH * 0.25, BOSS_LASER_WIDTH * 0.5]:
			var sample := center + perpendicular * offset
			var cell := tilemap.local_to_map(tilemap.to_local(sample))
			if tilemap.get_cell_source_id(0, cell) == -1:
				continue
			var tile_data := tilemap.get_cell_tile_data(0, cell)
			if tile_data != null and (tile_data.get_custom_data("bedrock") as bool):
				continue
			TileBreakSFX.break_tile(tilemap, cell, get_parent())

func _spit_boss_projectile(mole: Node2D) -> void:
	var aim := (mole.global_position - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT if not _sprite.flip_h else Vector2.LEFT
	var texture := _current_sprite_texture()
	var texture_size := texture.get_size() if texture != null else Vector2(585.0, 442.0)
	var visual_scale := _boss_base_scale if _boss_active else _sprite.scale
	var mouth_offset := _sprite.position + Vector2(
		(signf(aim.x) if aim.x != 0.0 else (1.0 if not _sprite.flip_h else -1.0)) * texture_size.x * visual_scale.x * 0.32,
		-texture_size.y * visual_scale.y * 0.06
	)
	var spawn_pos := to_global(mouth_offset)
	var spread := deg_to_rad(14.0)
	var angles: Array[float] = [0.0]
	_boss_projectile_count += 1
	if _boss_projectile_count % 4 == 0:
		angles = [-spread, 0.0, spread]
	for angle in angles:
		var direction := aim.rotated(angle)
		var projectile := BOSS_PROJECTILE_SCENE.instantiate() as Area2D
		get_parent().add_child(projectile)
		projectile.global_position = spawn_pos
		projectile.setup(direction * BOSS_PROJECTILE_SPEED)
		projectile.rotation = direction.angle()
	SFX.play("enemy_fire", spawn_pos, -4.0, 0.2, 0.8)

func _boss_body_size() -> Vector2:
	var texture := _current_sprite_texture()
	if texture == null:
		return Vector2(460.0, 350.0)
	var visual_scale := _boss_base_scale if _boss_active else _sprite.scale
	return texture.get_size() * visual_scale * Vector2(0.78, 0.84)

func _break_blocks_ahead(direction: float) -> void:
	var tilemap := get_parent().get_node_or_null("TileMap") as TileMap
	if tilemap == null:
		return
	var boss_size := _boss_body_size()
	var x_front := global_position.x + direction * (boss_size.x * 0.5 + 35.0)
	var y_top := global_position.y + _transform_ground_y - boss_size.y + 35.0
	var y_bottom := global_position.y + _transform_ground_y - 20.0
	var start := tilemap.local_to_map(tilemap.to_local(Vector2(x_front - 34.0, y_top)))
	var finish := tilemap.local_to_map(tilemap.to_local(Vector2(x_front + 34.0, y_bottom)))
	for x in range(mini(start.x, finish.x), maxi(start.x, finish.x) + 1):
		for y in range(mini(start.y, finish.y), maxi(start.y, finish.y) + 1):
			var cell := Vector2i(x, y)
			if tilemap.get_cell_source_id(0, cell) != -1:
				TileBreakSFX.break_tile(tilemap, cell, get_parent(), true)
			elif tilemap.get_layers_count() > 1 and tilemap.get_cell_source_id(1, cell) != -1:
				TileBreakSFX.break_decoration_tile(tilemap, cell, get_parent())

func _defeat_boss() -> void:
	_boss_dying = true
	_boss_active = false
	_clear_boss_laser_lines(_boss_laser_lines)
	_boss_laser_lines.clear()
	_boss_laser_active = false
	set_physics_process(false)
	linear_velocity = Vector2.ZERO
	gravity_scale = 0.0
	_restore_boss_camera_zoom()
	if _boss_hurtbox != null:
		_boss_hurtbox.set_deferred("monitoring", false)
		_boss_hurtbox.set_deferred("monitorable", false)
		for shape in _boss_hurtbox.get_children():
			if shape is CollisionShape2D:
				(shape as CollisionShape2D).set_deferred("disabled", true)
	if _boss_player_contact != null:
		_boss_player_contact.set_deferred("monitoring", false)
		_boss_player_contact.set_deferred("monitorable", false)
		for shape in _boss_player_contact.get_children():
			if shape is CollisionShape2D:
				(shape as CollisionShape2D).set_deferred("disabled", true)
	var interaction_area := get_node_or_null("Area2D") as Area2D
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", false)
		interaction_area.set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	if _boss_health_layer != null:
		var fade := create_tween()
		fade.tween_property(_boss_health_layer, "modulate:a", 0.0, 0.6)
		fade.tween_callback(_boss_health_layer.queue_free)
		_boss_health_layer = null
	SFX.play("enemy_death", global_position)
	if _sprite != null and is_instance_valid(_sprite):
		EnemyDamage.spawn_death_fragments(self, _sprite, Vector2.ZERO, maxf(scale.x * _sprite.scale.x, 0.0), 2.0, true)
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 64
	burst.lifetime = 0.8
	burst.explosiveness = 1.0
	burst.direction = Vector2.ZERO
	burst.spread = 180.0
	burst.initial_velocity_min = 100.0
	burst.initial_velocity_max = 460.0
	burst.gravity = Vector2(0.0, 260.0)
	burst.scale_amount_min = 5.0
	burst.scale_amount_max = 15.0
	burst.color = Color(0.78, 0.35, 1.0, 1.0)
	burst.z_index = 8
	get_parent().add_child(burst)
	burst.global_position = global_position
	get_tree().create_timer(burst.lifetime + 0.2).timeout.connect(burst.queue_free)
	Shop.drop_coins(global_position, 40, 10)
	var defeat := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	defeat.tween_property(_sprite, "scale", _sprite.scale * 0.75, 0.25)
	defeat.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	defeat.tween_callback(queue_free)

func _update_transformation_aura() -> void:
	if not _transformed or _sprite == null:
		return
	var texture := _current_sprite_texture()
	if texture:
		_sprite.position.y = _transform_ground_y - texture.get_size().y * _sprite.scale.y * 0.5
	for aura in _aura_sprites:
		if not is_instance_valid(aura):
			continue
		aura.texture = texture
		aura.position.x = _sprite.position.x
		aura.position.y = _transform_ground_y - texture.get_size().y * aura.scale.y * 0.5 if texture else _sprite.position.y
		aura.flip_h = _sprite.flip_h

func _current_sprite_texture() -> Texture2D:
	if _sprite == null or _sprite.sprite_frames == null:
		return null
	return _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)

func _grant_unlock() -> void:
	if unlock_ability == "":
		return
	if not condition_wave_path.is_empty() and not _condition_met:
		return
	var shop := get_tree().get_root().get_node_or_null("/root/Shop")
	if shop == null or not shop.has_method("give"):
		return
	shop.give(unlock_ability)
	if shop.has_method("equip"):
		shop.equip(unlock_ability)
	_prepare_reward()

## Decides how the reward is presented: a tool with artwork of its own gets the
## full "get" fanfare, anything else (story abilities) keeps the plain banner.
func _prepare_reward() -> void:
	var shop := get_tree().get_root().get_node_or_null("/root/Shop")
	var weapon: WeaponData = null
	if shop != null and shop.has_method("get_weapon"):
		weapon = shop.get_weapon(unlock_ability)
	if weapon != null and weapon.weapon_type == WeaponData.Type.MELEE:
		_reward_message = "%s Collected!" % weapon.display_name
		_reward_icon = MELEE_ICON
		_reward_tint = weapon.icon_color
		return
	_banner_text = unlock_text if unlock_text != "" else unlock_ability.to_upper()

func _show_reward() -> void:
	if _reward_message != "":
		var fanfare: CanvasLayer = ITEM_GET.new()
		fanfare.configure(_reward_message, _reward_icon, _reward_tint)
		get_tree().root.add_child(fanfare)
	elif _banner_text != "":
		_show_unlock_banner(_banner_text)

func _show_unlock_banner(label_text: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "UnlockBanner"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 200.0
	label.offset_bottom = 270.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55, 1))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var font := load("res://Baby Doll.otf") as Font
	if font:
		label.add_theme_font_override("font", font)
	label.text = "%s UNLOCKED!" % label_text
	layer.add_child(label)
	get_tree().root.add_child(layer)
	var tween := layer.create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)
