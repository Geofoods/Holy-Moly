extends CharacterBody2D

const AIR_GRAVITY = 2450.0
const PROMPT_HALF_WIDTH := 170.0
const PROMPT_HEIGHT := 60.0
const JUMP_VELOCITY := -1400.0
const JUMP_ELEVATION_THRESHOLD := 1.0
const JUMP_X_RANGE := 1000.0
const JUMP_COOLDOWN := 0.4
const MIN_FOLLOW_DISTANCE := 80.0

@export var move_speed := 45.0
@export var min_walk_time := 1.0
@export var max_walk_time := 3.5
@export var min_pause_time := 0.4
@export var max_pause_time := 1.5
@export var edge_probe := Vector2(300, 300)
@export var stationary := false
@export var follow_player := false
@export var follow_speed := 700.0
@export var follow_offset := 90.0

@export var prompt_text := "PRESS E"
@export_multiline var dialogue_text := ""
@export_multiline var dialogue_text_2 := ""
@export var npc_name := "Mole"
@export var portrait_texture: Texture2D = null
@export var prompt_offset := Vector2(0, -90)

var _sprite: AnimatedSprite2D = null
var _edge_ray: RayCast2D = null
var _interact_area: Area2D = null
var _prompt: Label = null
var _direction := -1.0
var _is_paused := false
var _state_timer := 0.0
var _mole_nearby := false
var _player: Node2D = null
var _dialogue_open := false
var _dialogue_box: CanvasLayer = null
var _greeting_triggered := false
var _second_triggered := false
var _jump_cooldown := 0.0

func _ready() -> void:
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_edge_ray = get_node_or_null("EdgeRay") as RayCast2D
	_interact_area = get_node_or_null("InteractionArea") as Area2D
	if _interact_area:
		_interact_area.body_entered.connect(_on_body_entered)
		_interact_area.body_exited.connect(_on_body_exited)
	_prompt = get_node_or_null("Prompt") as Label
	if _prompt:
		_prompt.top_level = true
		_prompt.z_index = 100
		_prompt.z_as_relative = false
		_prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_prompt.offset_left = 0.0
		_prompt.offset_top = 0.0
		_prompt.offset_right = 0.0
		_prompt.offset_bottom = 0.0
		if prompt_text != "":
			_prompt.text = prompt_text
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.visible = false
		var variation := FontVariation.new()
		variation.base_font = load("res://Baby Doll.otf") as Font
		variation.variation_embolden = 1.0
		_prompt.add_theme_font_override("font", variation)
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("walk"):
		_sprite.play("walk")
	_set_random_timer(min_walk_time, max_walk_time)
	_update_facing()

func _process(_delta: float) -> void:
	if _prompt:
		_prompt.visible = _mole_nearby and not _dialogue_open and dialogue_text != ""
		if _prompt.visible:
			var p := global_position + prompt_offset
			_prompt.offset_left = p.x - PROMPT_HALF_WIDTH
			_prompt.offset_right = p.x + PROMPT_HALF_WIDTH
			_prompt.offset_top = p.y
			_prompt.offset_bottom = p.y + PROMPT_HEIGHT

func _set_random_timer(min_time: float, max_time: float) -> void:
	_state_timer = randf_range(min_time, max_time)

func _physics_process(delta: float) -> void:
	velocity.y += AIR_GRAVITY * delta
	if _dialogue_open:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		_face_player()
		if _sprite:
			_sprite.speed_scale = 0.0
		move_and_slide()
		return
	if stationary:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if _sprite:
			_sprite.speed_scale = 0.0
		var player := get_tree().get_first_node_in_group("mole") as Node2D
		if player:
			_face_target(player)
		move_and_slide()
		return
	if follow_player:
		var wanted := _follow_player(delta)
		if _jump_cooldown > 0.0:
			_jump_cooldown -= delta
		var player := get_tree().get_first_node_in_group("mole") as Node2D
		var should_jump := _should_follow_jump(player)
		if should_jump:
			velocity.y = JUMP_VELOCITY
			_jump_cooldown = JUMP_COOLDOWN
			if _sprite:
				_sprite.speed_scale = 1.0
		move_and_slide()
		if not should_jump and wanted != 0.0 and is_on_wall() and is_on_floor():
			velocity.x = 0.0
			if _sprite:
				_sprite.speed_scale = 0.0
		return
	_state_timer -= delta
	if is_on_floor():
		if _is_paused:
			if _state_timer <= 0.0:
				_start_walking()
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		else:
			if _edge_ahead():
				_turn_around()
			if _state_timer <= 0.0:
				_start_pause()
			velocity.x = move_speed * _direction
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	move_and_slide()

func _edge_ahead() -> bool:
	if not _edge_ray:
		return false
	_edge_ray.force_raycast_update()
	return not _edge_ray.is_colliding()

func _follow_player(delta: float) -> float:
	var player := get_tree().get_first_node_in_group("mole") as Node2D
	if player == null or not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		return 0.0
	_face_target(player)
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var face := -1.0 if sprite and sprite.flip_h else 1.0
	if global_position.x != player.global_position.x \
			and absf(global_position.x - player.global_position.x) < MIN_FOLLOW_DISTANCE:
		var back_dir := -1.0 if global_position.x < player.global_position.x else 1.0
		velocity.x = move_toward(velocity.x, follow_speed * back_dir, 600.0 * delta)
		if _sprite:
			_sprite.speed_scale = 1.0
		return back_dir

	var target_x := player.global_position.x - face * follow_offset
	var dist := target_x - global_position.x
	var wanted := signf(dist)
	if absf(dist) > 8.0:
		var approach_speed := follow_speed * minf(1.0, absf(dist) / 96.0)
		velocity.x = move_toward(velocity.x, approach_speed * wanted, 600.0 * delta)
	else:
		wanted = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	if _sprite:
		_sprite.speed_scale = 1.0 if wanted != 0.0 else 0.0
	return wanted

func _should_follow_jump(player: Node2D) -> bool:
	if _jump_cooldown > 0.0 or not is_on_floor():
		return false
	if player == null or not is_instance_valid(player):
		return false
	var rel := player.global_position - global_position
	if rel.y > -JUMP_ELEVATION_THRESHOLD:
		return false
	if absf(rel.x) > JUMP_X_RANGE:
		return false
	return true

func _start_walking() -> void:
	_is_paused = false
	_set_random_timer(min_walk_time, max_walk_time)
	if randf() < 0.5:
		_turn_around()
	_update_animation()

func _start_pause() -> void:
	_is_paused = true
	_set_random_timer(min_pause_time, max_pause_time)
	_update_animation()

func _turn_around() -> void:
	_direction *= -1.0
	_update_facing()

func _update_facing() -> void:
	if _sprite:
		_sprite.flip_h = _direction < 0.0
	if _edge_ray:
		_edge_ray.target_position = Vector2(edge_probe.x * _direction, edge_probe.y)

func _update_animation() -> void:
	if not _sprite:
		return
	_sprite.speed_scale = 1.0 if not _is_paused else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not _mole_nearby or _dialogue_open or dialogue_text.is_empty():
		return
	if event.is_action_pressed("interact"):
		_open_dialogue()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = true
		_player = body as Node2D

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = false
		_player = null

func on_greeting_area_entered(body: Node) -> void:
	if _greeting_triggered or _dialogue_open:
		return
	if not body.is_in_group("mole"):
		return
	_greeting_triggered = true
	_open_dialogue(dialogue_text)

func on_secondary_area_entered(body: Node) -> void:
	if _second_triggered or _dialogue_open:
		return
	if not body.is_in_group("mole"):
		return
	if dialogue_text_2.is_empty():
		return
	_second_triggered = true
	_open_dialogue(dialogue_text_2)

func _face_player() -> void:
	_face_target(_player)

func _face_target(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dir := signf(target.global_position.x - global_position.x)
	if dir != 0.0 and dir != _direction:
		_direction = dir
		_update_facing()

func _open_dialogue(text: String = "") -> void:
	_dialogue_open = true
	_dialogue_box = preload("res://scenes/dialogue_box.tscn").instantiate()
	_dialogue_box.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_dialogue_box)
	_dialogue_box.next_pressed.connect(_on_dialogue_done)
	_dialogue_box.set_portrait(_portrait_texture(), modulate)
	_dialogue_box.set_npc_name(npc_name)
	_dialogue_box.show_text(text if not text.is_empty() else dialogue_text, 0, 0, true, false)

func _portrait_texture() -> Texture2D:
	if portrait_texture:
		return portrait_texture
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("walk"):
		return _sprite.sprite_frames.get_frame_texture("walk", 0)
	return null

func _on_dialogue_done() -> void:
	_update_animation()
	if _dialogue_box == null or not is_instance_valid(_dialogue_box):
		_dialogue_box = null
		_dialogue_open = false
		return
	var box := _dialogue_box
	_dialogue_box = null
	box.hide_box()
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(box):
			box.queue_free()
	)
	_dialogue_open = false
