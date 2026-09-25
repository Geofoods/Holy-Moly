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
## The artwork faces left at flip_h = false, so flipping points it right.
@export var sprite_faces_left := true

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
	_label = get_node_or_null("Area2D/Prompt") as Label
	if _label:
		if prompt_text != "":
			_label.text = prompt_text
		_label.visible = false
		_label.z_index = 100
		_label.z_as_relative = false
	_setup_condition()

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
		_label.visible = _mole_overlapping and not _dialogue_open
	_update_facing()

## Flip the sprite only - the body, collision shapes and Area2D are untouched.
func _update_facing() -> void:
	if not face_player or _sprite == null:
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
	if not _mole_overlapping or _dialogue_open or dialogue_text.is_empty():
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
	_grant_unlock()
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
