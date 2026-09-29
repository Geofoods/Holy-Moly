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

## The scale the snail transforms up to for the boss fight. Everything keyed to
## the fight's size - the collision body, the aura, the spit spawn offset, the
## lane the loot sails into - is derived from this, so this is the one knob.
const TRANSFORM_SCALE := 11.0
const EnemyDamage := preload("res://scripts/enemy.gd")
const EnemySpawn := preload("res://scripts/enemy_spawn.gd")
const SNAIL_GLOW_TEXTURE := preload("res://costume3 (1).svg")
const AURA_COLORS := [Color(0.72, 0.25, 1.0, 0.65), Color(0.82, 0.48, 1.0, 0.32)]
const SNAIL_GLOW_COLOR := Color(0.62, 0.22, 1.0, 1.0)
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

const BOSS_MAX_HEALTH := 500.0
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
	preload("res://scenes/slimeenemy.tscn"),
]
const BOSS_PROJECTILE_SCENE := preload("res://area_2d.tscn")
## Loot drops into the fight: a loose Drill or Holy Water the player grabs on the
## move. These used to be chests, which meant stopping to open one while the
## snail was still firing.
const LootDrop := preload("res://scripts/loot_drop.gd")
const BOSS_LOOT_SPAWN_INTERVAL := 12.0
## The first one waits longer than the rest, so the fight opens with the snail
## and not with loot dropping in on top of the player.
const BOSS_LOOT_FIRST_SPAWN_DELAY := 8.0
## Landed just ahead of the player rather than straight down on their head, so it
## is something to move for instead of something that lands on them.
const BOSS_LOOT_DROP_OFFSET := Vector2(110.0, -500.0)
## The end of the boss laser goes off like a bomb.
const BOSS_LASER_IMPACT_SCENE := preload("res://Retro Explosion.tscn")
const BOSS_LASER_IMPACT_SCALE := 1.0
## The snail is a RigidBody2D driven entirely by script, so a bomb landing on its
## shell or an add walking into it must never shove it off script. Bombs, chests,
## coins and debris all sit on the same collision layer as the ground, so the
## layer mask cannot tell them apart - instead every loose body in the arena is
## put on a collision exception with the snail, which leaves the ground solid.
const BOSS_IMMUNE_SWEEP_INTERVAL := 0.1
## Pull back for the large boss, then keep the encounter moving right like an autoscroller.
const BOSS_CAM_ZOOM := Vector2(0.32, 0.32)
const BOSS_CAM_ZOOM_IN_TIME := 2.5
const BOSS_BRIGHTNESS_TRANSITION_TIME := 2.5
const BOSS_CAM_ZOOM_OUT_TIME := 0.8
const BOSS_AUTO_SCROLL_SPEED := 48.0
const BOSS_AUTO_SCROLL_TRACK_SPEED := 260.0
const BOSS_AUTO_SCROLL_SNAIL_SCREEN_RATIO := 0.18
const BOSS_AUTO_SCROLL_PLAYER_SCREEN_RATIO := 0.82
const BOSS_AUTO_SCROLL_VERTICAL_OFFSET := -300.0
const BOSS_AUTO_SCROLL_VERTICAL_FOLLOW := 4.0

var _boss_minion_spawn_timer := 0.0
const TileBreakSFX := preload("res://scripts/tile_break_sfx.gd")

var _original_sprite_scale := Vector2.ONE
var _transform_ground_y := 0.0
var _aura_sprites: Array[Sprite2D] = []
var _transformation_light: PointLight2D = null
var _transformed := false
var _boss_active := false
var _boss_dying := false
var _boss_health := BOSS_MAX_HEALTH
var _boss_spit_timer := 0.0
var _boss_laser_timer := 0.0
var _boss_laser_active := false
var _boss_laser_lines: Array[Line2D] = []
var _boss_aura_shield: Line2D = null
var _boss_break_timer := 0.0
var _boss_loot_spawn_timer := 0.0
var _boss_immune_timer := 0.0
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
var _boss_auto_camera: Camera2D = null
var _boss_return_camera: Camera2D = null
var _boss_auto_camera_last_snail_x := 0.0
var _boss_ambient_modulate: CanvasModulate = null
var _boss_restore_ambient_color := Color.WHITE
var _boss_vignette_rect: ColorRect = null
var _boss_restore_vignette_material: Material = null
var _boss_vignette_material: ShaderMaterial = null
var _boss_brightness_tween: Tween = null

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

	# Keep the fight advancing right; the player can still fall behind or catch up.
	var direction := 1.0
	_sprite.flip_h = (direction > 0.0) == sprite_faces_left
	linear_velocity.x = BOSS_AUTO_SCROLL_SPEED
	if _boss_auto_camera == null or not is_instance_valid(_boss_auto_camera):
		linear_velocity.x = 0.0
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

	_boss_loot_spawn_timer -= delta
	if _boss_loot_spawn_timer <= 0.0:
		_boss_loot_spawn_timer = BOSS_LOOT_SPAWN_INTERVAL
		_spawn_boss_loot()

	# Bombs and adds can be thrown or spawned at any moment, so this is re-checked
	# through the fight rather than only once when the fight begins.
	_boss_immune_timer -= delta
	if _boss_immune_timer <= 0.0:
		_boss_immune_timer = BOSS_IMMUNE_SWEEP_INTERVAL
		_ignore_loose_body_pushes()

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

func _process(delta: float) -> void:
	if _label:
		_label.visible = _mole_overlapping and not _dialogue_open and not _hushed
	_update_facing()
	_update_transformation_aura()
	if _boss_active and not _boss_dying:
		_update_boss_autoscroll_camera(delta)

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
	_add_transformation_light(duration)
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

## The snail pulls visible copies of the mole's glow toward itself while keeping
## the mole's own light intact, making the growth feel like a gradual siphon.
func _siphon_player_aura(duration: float) -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return
	var mole_sprite := mole.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if mole_sprite == null:
		return

	var echo_count := 12
	var interval := duration / float(echo_count)
	for i in echo_count:
		if not is_instance_valid(mole) or not is_instance_valid(mole_sprite) or not is_inside_tree():
			return
		_emit_aura_echo(mole_sprite, interval * 2.5)
		if i < echo_count - 1:
			await get_tree().create_timer(interval).timeout

func _add_transformation_light(duration: float) -> void:
	if _sprite == null or _transformation_light != null:
		return
	_transformation_light = PointLight2D.new()
	_transformation_light.name = "TransformationLight"
	_transformation_light.position = _sprite.position
	_transformation_light.texture = SNAIL_GLOW_TEXTURE
	_transformation_light.texture_scale = 1.4
	_transformation_light.color = SNAIL_GLOW_COLOR
	_transformation_light.energy = 1.0
	_transformation_light.range_item_cull_mask = 1023
	_transformation_light.shadow_enabled = true
	_transformation_light.shadow_color = Color(0.05, 0.01, 0.09, 1.0)
	_transformation_light.shadow_filter = 2
	_transformation_light.shadow_filter_smooth = 4.0
	_transformation_light.shadow_item_cull_mask = 1
	add_child(_transformation_light)

	var texture := _current_sprite_texture()
	if texture == null:
		return
	var half_size := texture.get_size() * 0.5
	var occluder_shape := OccluderPolygon2D.new()
	occluder_shape.polygon = PackedVector2Array([
		Vector2(-half_size.x * 0.45, -half_size.y * 0.5),
		Vector2(half_size.x * 0.1, -half_size.y * 0.5),
		Vector2(half_size.x * 0.45, -half_size.y * 0.2),
		Vector2(half_size.x * 0.5, half_size.y * 0.1),
		Vector2(half_size.x * 0.3, half_size.y * 0.42),
		Vector2(-half_size.x * 0.35, half_size.y * 0.45),
		Vector2(-half_size.x * 0.5, half_size.y * 0.15),
		Vector2(-half_size.x * 0.5, -half_size.y * 0.2),
	])
	var occluder := LightOccluder2D.new()
	occluder.name = "TransformationLightOccluder"
	occluder.occluder = occluder_shape
	occluder.occluder_light_mask = 1
	_sprite.add_child(occluder)

	var light_tween := create_tween()
	light_tween.set_parallel(true)
	light_tween.tween_property(_transformation_light, "texture_scale", 4.2, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	light_tween.tween_property(_transformation_light, "energy", 1.35, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
	_boss_loot_spawn_timer = BOSS_LOOT_FIRST_SPAWN_DELAY
	_boss_immune_timer = 0.0
	linear_velocity = Vector2.ZERO
	sleeping = false
	gravity_scale = 1.0
	collision_layer = 4
	collision_mask = 1
	lock_rotation = true
	_boss_base_scale = _sprite.scale
	_resize_boss_body()
	_add_boss_hurtbox()
	_add_boss_aura_shield()
	_create_boss_health_bar()
	_brighten_boss_arena()
	_start_boss_camera_zoom()
	SFX.play("explosion", global_position, -8.0, 0.2, 0.8)

## Returns the camera currently showing the fight (which becomes the autoscroller camera).
func _boss_camera() -> Camera2D:
	if not is_inside_tree():
		return null
	return get_viewport().get_camera_2d() as Camera2D

func _stop_boss_camera_zoom() -> void:
	if _boss_cam_zoom_tween != null and _boss_cam_zoom_tween.is_valid():
		_boss_cam_zoom_tween.kill()
	_boss_cam_zoom_tween = null

func _tween_boss_camera_zoom(camera: Camera2D, target: Vector2, duration: float, target_offset: Vector2) -> void:
	_stop_boss_camera_zoom()
	_boss_cam_zoom_tween = camera.create_tween()
	_boss_cam_zoom_tween.set_parallel(true)
	_boss_cam_zoom_tween.tween_property(camera, "zoom", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_boss_cam_zoom_tween.tween_property(camera, "offset", target_offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _start_boss_camera_zoom() -> void:
	var current_camera := _boss_camera()
	if current_camera == null:
		return
	_boss_return_camera = current_camera
	_boss_cam_restore_zoom = current_camera.zoom
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return

	_boss_auto_camera = Camera2D.new()
	_boss_auto_camera.name = "SnailBossAutoscrollCamera"
	_boss_auto_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_boss_auto_camera.zoom = current_camera.zoom
	_boss_auto_camera.offset = Vector2.ZERO
	_boss_auto_camera.global_position = current_camera.global_position
	_boss_auto_camera_last_snail_x = global_position.x
	scene_root.add_child(_boss_auto_camera)
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	var target_offset := Vector2.ZERO
	if mole != null and is_instance_valid(mole):
		var target_camera_x := _boss_camera_target_x(_boss_auto_camera, mole, BOSS_CAM_ZOOM.x)
		target_offset.x = (target_camera_x - _boss_auto_camera.global_position.x) * BOSS_CAM_ZOOM.x
	current_camera.enabled = false
	_boss_auto_camera.make_current()
	_tween_boss_camera_zoom(_boss_auto_camera, BOSS_CAM_ZOOM, BOSS_CAM_ZOOM_IN_TIME, target_offset)

func _update_boss_autoscroll_camera(delta: float) -> void:
	if _boss_auto_camera == null or not is_instance_valid(_boss_auto_camera):
		return
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return

	var snail_delta_x := maxf(global_position.x - _boss_auto_camera_last_snail_x, 0.0)
	_boss_auto_camera_last_snail_x = global_position.x
	var desired_x := _boss_camera_target_x(_boss_auto_camera, mole)
	var tracking_step := maxf(desired_x - _boss_auto_camera.global_position.x, 0.0)
	var midpoint_y := (global_position.y + mole.global_position.y) * 0.5
	var target_y := midpoint_y + BOSS_AUTO_SCROLL_VERTICAL_OFFSET
	_boss_auto_camera.global_position.y = lerpf(
		_boss_auto_camera.global_position.y, target_y,
		clampf(BOSS_AUTO_SCROLL_VERTICAL_FOLLOW * delta, 0.0, 1.0))
	var camera_step := minf(snail_delta_x, tracking_step)
	_boss_auto_camera.global_position.x += camera_step
	if _boss_cam_zoom_tween == null or not _boss_cam_zoom_tween.is_valid():
		var target_offset_x := (_boss_camera_target_x(_boss_auto_camera, mole) - _boss_auto_camera.global_position.x) * _boss_auto_camera.zoom.x
		_boss_auto_camera.offset.x = move_toward(
			_boss_auto_camera.offset.x, target_offset_x, BOSS_AUTO_SCROLL_SPEED * _boss_auto_camera.zoom.x * delta)

func _boss_camera_target_x(camera: Camera2D, mole: Node2D, zoom_x: float = -1.0) -> float:
	var viewport_width: float = camera.get_viewport_rect().size.x
	var effective_zoom := zoom_x if zoom_x > 0.0 else camera.zoom.x
	var world_view_width := viewport_width / maxf(effective_zoom, 0.01)
	var snail_left_target := global_position.x + world_view_width * (0.5 - BOSS_AUTO_SCROLL_SNAIL_SCREEN_RATIO)
	var mole_right_target := mole.global_position.x - world_view_width * (BOSS_AUTO_SCROLL_PLAYER_SCREEN_RATIO - 0.5)
	return maxf(snail_left_target, mole_right_target) - camera.offset.x / maxf(effective_zoom, 0.01)

func _brighten_boss_arena() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_boss_ambient_modulate = scene.get_node_or_null("AmbientModulate") as CanvasModulate
	_boss_brightness_tween = create_tween()
	_boss_brightness_tween.set_parallel(true)
	if _boss_ambient_modulate != null:
		_boss_restore_ambient_color = _boss_ambient_modulate.color
		_boss_brightness_tween.tween_property(
			_boss_ambient_modulate, "color", Color(0.9, 0.88, 0.94, 1.0),
			BOSS_BRIGHTNESS_TRANSITION_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	_boss_vignette_rect = scene.get_node_or_null("VignetteLayer/VignetteRect") as ColorRect
	if _boss_vignette_rect != null:
		var original_material := _boss_vignette_rect.material as ShaderMaterial
		if original_material != null:
			_boss_restore_vignette_material = _boss_vignette_rect.material
			_boss_vignette_material = original_material.duplicate() as ShaderMaterial
			_boss_vignette_rect.material = _boss_vignette_material
			var original_darkness: float = float(original_material.get_shader_parameter("darkness"))
			_boss_brightness_tween.tween_method(
				_set_boss_vignette_darkness, original_darkness, 0.12,
				BOSS_BRIGHTNESS_TRANSITION_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _set_boss_vignette_darkness(darkness: float) -> void:
	if _boss_vignette_material != null and is_instance_valid(_boss_vignette_material):
		_boss_vignette_material.set_shader_parameter("darkness", darkness)

func _restore_boss_ambient() -> void:
	if _boss_brightness_tween != null and _boss_brightness_tween.is_valid():
		_boss_brightness_tween.kill()
	_boss_brightness_tween = null
	if _boss_ambient_modulate != null and is_instance_valid(_boss_ambient_modulate):
		var ambient_tween := _boss_ambient_modulate.create_tween()
		ambient_tween.tween_property(_boss_ambient_modulate, "color", _boss_restore_ambient_color, 0.7)
	_boss_ambient_modulate = null
	if _boss_vignette_rect != null and is_instance_valid(_boss_vignette_rect):
		_boss_vignette_rect.material = _boss_restore_vignette_material
	_boss_vignette_rect = null
	_boss_restore_vignette_material = null

func _restore_boss_camera_zoom() -> void:
	_stop_boss_camera_zoom()
	if _boss_auto_camera == null or not is_instance_valid(_boss_auto_camera):
		return
	var final_position := _boss_auto_camera.global_position
	_boss_auto_camera.enabled = false
	_boss_auto_camera.queue_free()
	_boss_auto_camera = null
	if _boss_return_camera != null and is_instance_valid(_boss_return_camera):

		_boss_return_camera.global_position = final_position
		_boss_return_camera.zoom = _boss_cam_restore_zoom
		_boss_return_camera.enabled = true
		_boss_return_camera.make_current()
	_boss_return_camera = null

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

func _add_boss_aura_shield() -> void:
	if _sprite == null:
		return
	var texture := _current_sprite_texture()
	if texture == null:
		return

	var radius := texture.get_size() * 0.62
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for ring_index in 2:
		var ring := Line2D.new()
		ring.name = "BossAuraShield" if ring_index == 0 else "BossAuraShieldInner"
		ring.width = 14.0 if ring_index == 0 else 8.0
		ring.default_color = Color(0.76, 0.28, 1.0, 0.85) if ring_index == 0 else Color(0.94, 0.68, 1.0, 0.75)
		ring.z_index = 5
		ring.z_as_relative = false
		ring.joint_mode = Line2D.LINE_JOINT_ROUND
		ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ring.end_cap_mode = Line2D.LINE_CAP_ROUND
		ring.material = additive
		ring.rotation = 0.22 if ring_index == 1 else 0.0
		ring.scale = Vector2.ONE
		var ring_radius := radius * (0.62 if ring_index == 1 else 1.0)
		for i in range(49):
			var angle := TAU * float(i) / 48.0
			ring.add_point(Vector2(cos(angle) * ring_radius.x, sin(angle) * ring_radius.y))
		_sprite.add_child(ring)
		var pulse := ring.create_tween().set_loops()
		pulse.tween_property(ring, "modulate:a", 0.38, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(ring, "modulate:a", 0.9, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var rotation_pulse := ring.create_tween().set_loops()
		rotation_pulse.tween_property(ring, "rotation", TAU if ring_index == 0 else -TAU, 5.0).as_relative()
		var scale_pulse := ring.create_tween().set_loops()
		scale_pulse.tween_property(ring, "scale", Vector2(1.07, 1.07), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		scale_pulse.tween_property(ring, "scale", Vector2(0.94, 0.94), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var width_pulse := ring.create_tween().set_loops()
		width_pulse.tween_property(ring, "width", 20.0 if ring_index == 0 else 12.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		width_pulse.tween_property(ring, "width", 11.0 if ring_index == 0 else 6.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if ring_index == 0:
			_boss_aura_shield = ring

func _on_boss_hurtbox_area_entered(area: Area2D) -> void:
	if not _boss_active or _boss_dying:
		return
	var attacker := area.get_parent()
	if attacker == null:
		return
	if "is_swinging" in attacker and attacker.is_swinging:
		_flash_boss_aura_shield()
	elif attacker.is_in_group("bullet") and attacker.has_method("deflect"):
		attacker.deflect(global_position)
		_flash_boss_aura_shield()

func _flash_boss_aura_shield() -> void:
	if _boss_aura_shield == null or not is_instance_valid(_boss_aura_shield):
		return
	_boss_aura_shield.default_color = Color(1.0, 0.88, 1.0, 1.0)
	var flash := _boss_aura_shield.create_tween()
	flash.tween_property(_boss_aura_shield, "default_color", Color(0.76, 0.28, 1.0, 0.85), 0.25)

## Normal weapon and ability damage is absorbed by the aura shield.
func take_damage(_amount: float, _direction: Vector2 = Vector2.ZERO) -> void:
	return

## The drill is the saw-like attack that can pierce the aura shield.
func take_saw_damage(amount: float, _direction: Vector2 = Vector2.ZERO) -> void:
	_apply_boss_damage(amount)

## Bombs are not a swing for the shield to soak up: a blast that goes off against
## the shell hurts the snail the way the drill does.
func take_explosion_damage(amount: float, _direction: Vector2 = Vector2.ZERO) -> void:
	_apply_boss_damage(amount)

## Asked by the ice bomb before it freezes anything: a frozen snail only makes
## sense while the fight is actually running.
func can_be_frozen() -> bool:
	return _boss_active and not _boss_dying

func _apply_boss_damage(amount: float) -> void:
	if not _boss_active or _boss_dying or amount <= 0.0:
		return
	_boss_health = maxf(_boss_health - amount, 0.0)
	_flash_boss_aura_shield()
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
	_boss_health_layer.layer = 127
	get_parent().add_child(_boss_health_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -BOSS_HEALTH_ROOT_WIDTH * 0.5
	root.offset_top = 18.0
	root.offset_right = BOSS_HEALTH_ROOT_WIDTH * 0.5
	root.offset_bottom = 18.0 + BOSS_HEALTH_ROOT_HEIGHT
	root.custom_minimum_size = Vector2(BOSS_HEALTH_ROOT_WIDTH, BOSS_HEALTH_ROOT_HEIGHT)
	root.z_index = 100
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_health_layer.add_child(root)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.05, 0.9)
	style.border_color = Color(0.42, 0.28, 0.14, 1.0)
	style.set_border_width_all(2)
	var name_panel := Panel.new()
	name_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
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
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.12, 1.0))
	title.add_theme_constant_override("outline_size", 3)
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
	# Same burst-in the arena waves use: the minion is frozen, shrunk and
	# untouchable until it has risen out of the dirt, so it can never trade a hit
	# with the player while it is still materialising.
	EnemySpawn.play(minion)
	SFX.play("enemy_fire", to_global(spawn_offset), -8.0, 0.15, 0.85)

## Drops a Drill or Holy Water into the arena for the player to grab on the move.
func _spawn_boss_loot() -> void:
	if not _boss_active or _boss_dying:
		return
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return
	var drop_at: Vector2 = mole.global_position + BOSS_LOOT_DROP_OFFSET
	LootDrop.spawn_random(parent, drop_at)
	SFX.play("coin", drop_at, -12.0, 0.12, 0.9)

func _fire_boss_laser(mole: Node2D) -> void:
	if _boss_laser_active or not _boss_active or _boss_dying or not is_instance_valid(mole):
		return
	_boss_laser_active = true

	# Lock direction during the warning so the player has time to dodge.
	var laser_start := _sprite.global_position
	var laser_direction := (mole.global_position - laser_start).normalized()
	if laser_direction == Vector2.ZERO:
		laser_direction = Vector2.DOWN
	# The beam burns through dirt but stops at bedrock, and that stopping point is
	# where its impact goes off.
	var laser_end := _trace_boss_laser(laser_start, laser_direction, laser_start + laser_direction * BOSS_LASER_LENGTH)
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
	_spawn_boss_laser_impact(laser_end)

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
			var sample: Vector2 = center + perpendicular * float(offset)
			var cell := tilemap.local_to_map(tilemap.to_local(sample))
			if tilemap.get_cell_source_id(0, cell) == -1:
				continue
			var tile_data := tilemap.get_cell_tile_data(0, cell)
			if tile_data != null and (tile_data.get_custom_data("bedrock") as bool):
				continue
			TileBreakSFX.break_tile(tilemap, cell, get_parent())

## Where the beam stops: the first bedrock it runs into, or its full length when
## it never finds any. Mirrors the corrupted heart's laser, so both boss beams
## bite into the same kind of wall.
func _trace_boss_laser(start: Vector2, direction: Vector2, finish: Vector2) -> Vector2:
	var tilemap := get_parent().get_node_or_null("TileMap") as TileMap
	if tilemap == null:
		return finish
	var distance := start.distance_to(finish)
	var sample_count := maxi(1, int(ceil(distance / BOSS_LASER_TILE_SAMPLE_SPACING)))
	for i in range(1, sample_count + 1):
		var progress := minf(float(i) * BOSS_LASER_TILE_SAMPLE_SPACING, distance)
		var sample := start + direction * progress
		var cell := tilemap.local_to_map(tilemap.to_local(sample))
		var tile_data := tilemap.get_cell_tile_data(0, cell)
		if tile_data != null and (tile_data.get_custom_data("bedrock") as bool):
			return sample
	return finish

## The beam's end goes off like a bomb. Without this the only blast the laser
## left behind came from the blocks it happened to shatter on the way, so whether
## the impact read at all depended on where it was aimed.
func _spawn_boss_laser_impact(world_pos: Vector2) -> void:
	var explosion = BOSS_LASER_IMPACT_SCENE.instantiate()
	explosion.global_position = world_pos
	explosion.scale = Vector2.ONE * BOSS_LASER_IMPACT_SCALE
	get_parent().add_child(explosion)
	explosion.emitting = true
	SFX.play("explosion", world_pos, -3.0, 0.1)
	var mole := get_tree().get_first_node_in_group("mole")
	if is_instance_valid(mole) and mole.has_method("screen_shake"):
		mole.call("screen_shake", 18.0, 0.4)

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

## Stops bombs, adds and other loose props from shoving the snail around while it
## is being driven along by script. Collision exceptions are checked before the
## layer and mask rules, so this can exclude a bomb without also excluding the
## ground the snail is standing on - which a mask change could not do, because
## bombs and tiles share a layer.
##
## Only the level's direct children are swept, because everything the player
## throws and everything the fight spawns is parented straight to the level. The
## player is deliberately left alone: it should still be blocked by the shell.
func _ignore_loose_body_pushes() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var tilemap := parent.get_node_or_null("TileMap")
	var mole := get_tree().get_first_node_in_group("mole")
	for child in parent.get_children():
		if child == self or child == tilemap or child == mole:
			continue
		# Static bodies cannot impart momentum, so there is nothing to ignore.
		if not (child is PhysicsBody2D) or (child is StaticBody2D):
			continue
		add_collision_exception_with(child as PhysicsBody2D)

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
	_restore_boss_ambient()
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
