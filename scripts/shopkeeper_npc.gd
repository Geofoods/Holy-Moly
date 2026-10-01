extends CharacterBody2D

## Stationary merchant. The stall and shopkeeper are one sprite (shopt.png):
## "idle" normally, "talking" while his dialogue box is up. Opens Shop's panel
## when the player presses the interact key in range.
##
## Uses the same child node names as npc_mole.gd (AnimatedSprite2D /
## InteractionArea / Prompt) so the Prompt styling carries over unchanged, and
## keeps the "npc_hurtbox" convention so bombs and the shovel still register
## hits (apply_knockback ignores them). Unlike the villagers he never walks, so the ground ray and wander
## state machine are left out. He never turns to face the player either - the
## art has "SHOP!" lettered on it, which would read backwards if flipped.

const AIR_GRAVITY := 2450.0
const PROMPT_HALF_WIDTH := 190.0
const PROMPT_HEIGHT := 60.0
const FONT_PATH := "res://Baby Doll.otf"
## Stops a held E key from popping the shop open again the instant it closes.
const REOPEN_COOLDOWN := 0.4
## How long he keeps flapping his mouth once a dialogue opens, in seconds.
## After this he goes back to idle even if the box is still up.
const TALK_DURATION := 4.2

## Which Shop panel to open: "items", "weapons" or "abilities".
@export var shop_type := "items"
@export var prompt_text := "PRESS E: SHOP"
@export var npc_name := "Goblin Gilbert"
## Puts the prompt above the awning rather than on the mole's head.
@export var prompt_offset := Vector2(0, -290)
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
var _mole_nearby := false
var _dialogue_open := false
var _dialogue_box: CanvasLayer = null
var _greeted := false
var _shop_open := false
var _reopen_timer := 0.0
var _talk_timer := 0.0
var _settled := false

func _ready() -> void:
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_interact_area = get_node_or_null("InteractionArea") as Area2D
	if _interact_area:
		_interact_area.body_entered.connect(_on_body_entered)
		_interact_area.body_exited.connect(_on_body_exited)
	Shop.shop_closed.connect(_on_shop_closed)
	_setup_prompt()
	_update_animation()

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
	if _talk_timer > 0.0:
		_talk_timer -= delta
	_update_animation()
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
	if get_tree().paused or _settled:
		return
	# Drop onto the floor once, then stop moving for good. He still collides with
	# layer 1, which the mole is on, so a body that kept calling move_and_slide
	# would get shoved aside whenever the player walked into him.
	velocity.y += AIR_GRAVITY * delta
	velocity.x = 0.0
	move_and_slide()
	if is_on_floor():
		_settled = true
		velocity = Vector2.ZERO

func _update_animation() -> void:
	if _sprite == null:
		return
	var talking := _dialogue_open and _talk_timer > 0.0
	var anim: StringName = &"talking" if talking else &"idle"
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
	_sync_portrait()

## Mirrors the sprite's current frame into the dialogue portrait, so the face in
## the talk box moves with the one in the world. The portrait is sized by the
## texture, not by this node's scale, so it stays the same size in the box.
func _sync_portrait() -> void:
	if portrait_texture or _dialogue_box == null or not is_instance_valid(_dialogue_box):
		return
	_dialogue_box.portrait.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)

## Bombs and the shovel still call this through the "npc_hurtbox" group, but
## the stall is bolted down, so hits don't move him.
func apply_knockback(_knockback: Vector2) -> void:
	pass

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = false

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
	_talk_timer = TALK_DURATION
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
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("idle"):
		return _sprite.sprite_frames.get_frame_texture("idle", 0)
	return null
