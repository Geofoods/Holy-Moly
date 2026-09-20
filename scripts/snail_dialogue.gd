extends RigidBody2D

@export var prompt_text := "PRESS E TO INTERACT"
@export var portrait_texture: Texture2D = null
@export_multiline var dialogue_text := ""
@export_multiline var post_dialogue_text := ""
@export var condition_wave_path := NodePath("")
@export var unlock_ability := ""
@export var unlock_text := ""

var _mole_overlapping := false
var _dialogue_open := false
var _condition_met := false
var _label: Label = null
var _dialogue_box: CanvasLayer = null

signal dialogue_closed

func _ready() -> void:
	var zone := get_node_or_null("Area2D") as Area2D
	if zone:
		zone.body_entered.connect(_on_body_entered)
		zone.body_exited.connect(_on_body_exited)
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
	_dialogue_box.show_text(dialogue_text, 0, 0, true, false)

func _on_dialogue_done() -> void:
	_grant_unlock()
	if _dialogue_box == null or not is_instance_valid(_dialogue_box):
		_dialogue_box = null
		_dialogue_open = false
		dialogue_closed.emit()
		return
	var box := _dialogue_box
	_dialogue_box = null
	box.hide_box()
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(box):
			box.queue_free()
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
	_show_unlock_banner(unlock_text if unlock_text != "" else unlock_ability.to_upper())

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
