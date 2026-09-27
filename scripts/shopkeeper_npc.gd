extends CharacterBody2D

## Stationary merchant mole. Stands behind a market stall (shop_stall.gd) and
## opens Shop's panel when the player presses the interact key in range.
##
## Uses the same child node names as npc_mole.gd (AnimatedSprite2D /
## InteractionArea / Prompt) so the shared mole art and the Prompt styling carry
## over unchanged, and keeps the "npc_hurtbox" convention so bombs and the
## shovel still knock him about. Unlike the villagers he never walks, so the
## ground ray and wander state machine are left out.

const AIR_GRAVITY := 2450.0
const PROMPT_HALF_WIDTH := 190.0
const PROMPT_HEIGHT := 60.0
const FONT_PATH := "res://Baby Doll.otf"
const KNOCKBACK_DURATION := 0.16
const KNOCKBACK_DAMP := 700.0
## Stops a held E key from popping the shop open again the instant it closes.
const REOPEN_COOLDOWN := 0.4

## Which Shop panel to open: "items", "weapons" or "abilities".
@export var shop_type := "items"
@export var prompt_text := "PRESS E: SHOP"
@export var npc_name := "Merchant Mole"
## Puts the prompt above the awning rather than on the mole's head.
@export var prompt_offset := Vector2(0, -205)
@export var portrait_texture: Texture2D = null
## Shown once, the first time the player talks to the merchant. Leave empty to
## skip the greeting and open the shop straight away.
@export_multiline var greeting_text := "Psst - over here, digger! Fresh bombs, a good drill, holy water if you're leaking. Everything a mole needs to get home in one piece."
## Idle barks played instead of a shop if this is false, e.g. for a flavour
## merchant that hangs around a level.
@export var sells := true

var _sprite: AnimatedSprite2D = null
var _interact_area: Area2D = null
var _prompt: Label = null
var _player: Node2D = null
var _mole_nearby := false
var _dialogue_open := false
var _dialogue_box: CanvasLayer = null
var _greeted := false
var _shop_open := false
var _reopen_timer := 0.0
var _direction := -1.0
var _knockback_velocity := Vector2.ZERO
var _knockback_timer := 0.0

func _ready() -> void:
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_interact_area = get_node_or_null("InteractionArea") as Area2D
	if _interact_area:
		_interact_area.body_entered.connect(_on_body_entered)
		_interact_area.body_exited.connect(_on_body_exited)
	Shop.shop_closed.connect(_on_shop_closed)
	_setup_prompt()
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("walk"):
		_sprite.play("walk")
	_update_facing()

func _setup_prompt() -> void:
	_prompt = get_node_or_null("Prompt") as Label
	if _prompt == null:
		return
	# top_level so the label can be positioned in screen space without the NPC's
	# scale shrinking the text to nothing.
	_prompt.top_level = true
	_prompt.z_index = 200
	_prompt.z_as_relative = false
	_prompt.light_mask = 0
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
	variation.base_font = load(FONT_PATH) as Font
	variation.variation_embolden = 1.0
	_prompt.add_theme_font_override("font", variation)

func _process(delta: float) -> void:
	if _reopen_timer > 0.0:
		_reopen_timer -= delta
	if _prompt == null:
		return
	_prompt.visible = _mole_nearby and not _dialogue_open and not _shop_open
	if not _prompt.visible:
		return
	var p := global_position + prompt_offset
	_prompt.offset_left = p.x - PROMPT_HALF_WIDTH
	_prompt.offset_right = p.x + PROMPT_HALF_WIDTH
	_prompt.offset_top = p.y
	_prompt.offset_bottom = p.y + PROMPT_HEIGHT

func _physics_process(delta: float) -> void:
	# The shop panel pauses the tree, so nothing should move while it is up.
	if get_tree().paused:
		return
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.y += AIR_GRAVITY * delta
		_knockback_velocity.x = move_toward(_knockback_velocity.x, 0.0, KNOCKBACK_DAMP * delta)
		velocity.x = _knockback_velocity.x
		_set_speed_scale(1.0)
		move_and_slide()
		return
	velocity.y += AIR_GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	_face_target(_player)
	_set_speed_scale(0.0)
	move_and_slide()

func _set_speed_scale(value: float) -> void:
	if _sprite:
		_sprite.speed_scale = value

func apply_knockback(knockback: Vector2) -> void:
	_knockback_velocity = knockback
	_knockback_timer = KNOCKBACK_DURATION

func _update_facing() -> void:
	if _sprite:
		_sprite.flip_h = _direction < 0.0

func _face_target(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dir := signf(target.global_position.x - global_position.x)
	if dir != 0.0 and dir != _direction:
		_direction = dir
		_update_facing()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = true
		_player = body as Node2D

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = false
		_player = null

func _unhandled_input(event: InputEvent) -> void:
	if not _mole_nearby or _dialogue_open or _shop_open or get_tree().paused:
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _reopen_timer > 0.0:
		return
	if not _greeted and not greeting_text.is_empty():
		_greeted = true
		# The greeting is a doorman, not a conversation: dismissing it opens the
		# shop. Later visits skip straight to the panel.
		_open_dialogue(greeting_text, _on_greeting_done)
		return
	_interact()

func _interact() -> void:
	if not sells:
		_say(greeting_text if not greeting_text.is_empty() else "...")
		return
	_open_shop()

func _open_shop() -> void:
	_reopen_timer = REOPEN_COOLDOWN
	Shop.open_shop(shop_type)
	# open_shop can decline (no current scene, a panel of this type already up),
	# and the panel pauses the tree so _process cannot hide the prompt. Only
	# report "busy" when a panel really opened, and do the hiding here.
	_shop_open = Shop.is_shop_open(shop_type)
	if not _shop_open:
		return
	if _prompt:
		_prompt.visible = false
	SFX.play_ui("ui_click", -10.0, 1.0)

func _on_shop_closed(_closed_type: String) -> void:
	_shop_open = false
	# Whatever happens next (including a scene change), never leave the stall
	# stuck behind a panel that is no longer there.
	_reopen_timer = maxf(_reopen_timer, REOPEN_COOLDOWN)

func _say(text: String) -> void:
	_open_dialogue(text, _close_dialogue)

func _open_dialogue(text: String, on_done: Callable) -> void:
	_dialogue_open = true
	_dialogue_box = preload("res://scenes/dialogue_box.tscn").instantiate()
	_dialogue_box.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_dialogue_box)
	_dialogue_box.next_pressed.connect(on_done)
	_dialogue_box.set_portrait(_portrait_texture(), modulate)
	_dialogue_box.set_npc_name(npc_name)
	_dialogue_box.show_text(text, 0, 0, true, false)

func _on_greeting_done() -> void:
	_close_dialogue()
	if not _shop_open:
		_open_shop()

func _close_dialogue() -> void:
	_dialogue_open = false
	if _dialogue_box == null or not is_instance_valid(_dialogue_box):
		_dialogue_box = null
		return
	var box := _dialogue_box
	_dialogue_box = null
	box.hide_box()
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if is_instance_valid(box):
			box.queue_free()
	)

func _portrait_texture() -> Texture2D:
	if portrait_texture:
		return portrait_texture
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("walk"):
		return _sprite.sprite_frames.get_frame_texture("walk", 0)
	return null
