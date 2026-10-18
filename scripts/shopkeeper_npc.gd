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
const TapInteract := preload("res://scripts/tap_interact.gd")
## Stops a held E key from popping the shop open again the instant it closes.
const REOPEN_COOLDOWN := 0.4
## How long he keeps flapping his mouth once a dialogue opens, in seconds.
## After this he goes back to idle even if the box is still up.
const TALK_DURATION := 4.2
## The stall art, used to carve a close-up of the shopkeeper for the shop
## panel's top-left portrait.
const SHOP_ART: Texture2D = preload("res://sprites/shopt.png")
## Region of the idle frame (see shopt.png) around the shopkeeper's head. The
## full frame is the whole stall; this narrows it to Gilbert himself.
const SHOP_PORTRAIT_REGION := Rect2(165, 258, 270, 125)

## Which Shop panel to open. "all" is the unified general store, where the
## merchant stocks every weapon, ability and item; the narrower "items",
## "weapons" and "abilities" panels remain available if a stall ever needs one.
@export var shop_type := "all"
@export var prompt_text := "PRESS E: SHOP"
@export var npc_name := "Goblin Gilbert"
## Puts the prompt above the awning rather than on the mole's head.
@export var prompt_offset := Vector2(0, -290)
@export var portrait_texture: Texture2D = null
## Shown once, the first time the player talks to the merchant. Leave empty to
## skip the greeting and open the shop straight away.
@export_multiline var greeting_text := "Psst - over here, digger! Fresh bombs, a good drill, holy water if you're leaking. Everything a mole needs to get home in one piece."
## Shown once the shop closes after the player has bought something, so Gilbert
## can pitch his buy-back service. Only fires for a purchase made at his own
## stall (see _on_shop_purchased). Leave empty to skip the thank-you entirely.
@export_multiline var purchase_thanks_text := "Thank you for buying from me! By the way, I can also buy items from you as well for coins so if you don't want something, I'll take it off your hands!"
## Short line the merchant speaks in the shop panel's speech bubble while the
## player browses his stock. Leave empty to use the panel's default greeting.
@export_multiline var shop_greeting_text := "Fresh stock in, digger. Take a look!"
## Fallback line the merchant speaks each time the player buys something from him
## while the shop panel is still open, used for any item the panel has no
## item-specific line for (see BUY_LINES in shop_ui.gd). The longer
## purchase_thanks_text still plays once the panel closes.
@export_multiline var shop_thanks_text := "Pleasure doing business, digger!"
## Short line the merchant speaks in the shop panel's speech bubble when the
## player opens the sell tab, pitching his buy-back service. Leave empty to use
## the panel's default pitch.
@export_multiline var shop_sell_pitch_text := "Loot to unload? I pay half of what it's worth, digger."
## Fallback line the merchant speaks each time he buys a piece of the mole's loot
## back, used for any item the panel has no item-specific line for (see
## SELL_LINES in shop_ui.gd). Leave empty to use the panel's default thank-you.
@export_multiline var shop_sell_text := "Sold! Always glad to take that off your hands."
## Quest revealed alongside the purchase thank-you, by id. Gilbert's line pitches
## his buy-back service, so it opens the selling quest. Empty means the merchant
## has no follow-up quest.
@export var unlocks_after_purchase := ""
## Idle barks played instead of a shop if this is false, e.g. for a flavour
## merchant that hangs around a level.
@export var sells := true
## Quest revealed the first time the player talks to the merchant, by id. The
## unlock is granted the moment the talk starts, so the banner lands while his
## greeting is up. Empty means the merchant has nothing to do with the quest log.
## Goblin Gilbert points the player at the shop, so his first greeting opens the
## shopping quest.
@export var unlocks_quest := ""

var _sprite: AnimatedSprite2D = null
var _interact_area: Area2D = null
var _prompt: Label = null
var _mole_nearby := false
var _dialogue_open := false
var _dialogue_box: CanvasLayer = null
var _greeted := false
var _shop_open := false
## Set when a purchase lands while this merchant's own stall is open; consumed
## once the shop closes to play the buy-back pitch.
var _bought_something := false
var _reopen_timer := 0.0
var _talk_timer := 0.0
var _settled := false

func _ready() -> void:
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	TapInteract.register(_sprite)
	_interact_area = get_node_or_null("InteractionArea") as Area2D
	if _interact_area:
		_interact_area.body_entered.connect(_on_body_entered)
		_interact_area.body_exited.connect(_on_body_exited)
	Shop.shop_closed.connect(_on_shop_closed)
	Shop.purchased.connect(_on_shop_purchased)
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
	# Pressing on the stall works like the interact key - a click on desktop, a
	# tap on mobile (taps arrive as emulated mouse clicks).
	var pressed_on_me := TapInteract.is_press_on(event, _sprite)
	if pressed_on_me:
		# The press is spent on the merchant even when nothing can open (out of
		# reach, a panel already up): pressing an NPC never swings a shovel at it.
		TapInteract.consume(event, self)
	if not _mole_nearby or _dialogue_open or _shop_open or get_tree().paused:
		return
	if not event.is_action_pressed("interact") and not pressed_on_me:
		return
	get_viewport().set_input_as_handled()
	if _reopen_timer > 0.0:
		return
	_unlock_quest()
	if not _greeted and not greeting_text.is_empty():
		_greeted = true
		# The greeting is a doorman, not a conversation: dismissing it opens the
		# shop. Later visits skip straight to the panel.
		_open_dialogue(greeting_text, _on_greeting_done)
		return
	_interact()

## Hands over this merchant's quest the first time he is talked to. Idempotent,
## so every later visit is a quiet no-op.
func _unlock_quest() -> void:
	if not unlocks_quest.is_empty():
		Quests.unlock(unlocks_quest)

func _interact() -> void:
	if not sells:
		_say(greeting_text if not greeting_text.is_empty() else "...")
		return
	_open_shop()

func _open_shop() -> void:
	_reopen_timer = REOPEN_COOLDOWN
	# Hand the panel who is minding the stall, so it can show his face top-left
	# and speak his greetings and thank-yous as the player buys and sells.
	Shop.open_shop(shop_type, {
		"name": npc_name,
		"portrait": _shop_portrait_texture(),
		"greeting": shop_greeting_text,
		"thanks": shop_thanks_text,
		"sell_pitch": shop_sell_pitch_text,
		"sell": shop_sell_text,
	})
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
	# The panel is gone and the tree unpaused by now, so the thank-you can take
	# the stage. Only a purchase made at this stall sets the flag.
	if _bought_something:
		_bought_something = false
		if not purchase_thanks_text.is_empty():
			if not unlocks_after_purchase.is_empty():
				Quests.unlock(unlocks_after_purchase)
			_say(purchase_thanks_text)

## A purchase landed. Ignore anything bought away from this stall (another
## merchant, the pause-menu shop) so Gilbert only pitches once he has really
## sold something himself.
func _on_shop_purchased() -> void:
	if _shop_open:
		_bought_something = true

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
	get_tree().create_timer(0.35).timeout.connect(_free_dialogue_box.bind(weakref(box)))

func _free_dialogue_box(box_ref: WeakRef) -> void:
	var box := box_ref.get_ref() as CanvasLayer
	if box:
		box.queue_free()

func _portrait_texture() -> Texture2D:
	if portrait_texture:
		return portrait_texture
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("idle"):
		return _sprite.sprite_frames.get_frame_texture("idle", 0)
	return null

## A close-up of the shopkeeper's head for the shop panel's top-left portrait,
## carved out of the idle stall frame so it shows Gilbert rather than the stall.
func _shop_portrait_texture() -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = SHOP_ART
	atlas.region = SHOP_PORTRAIT_REGION
	return atlas
