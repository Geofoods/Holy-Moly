extends Area2D

@export var prompt_text := "PRESS E TO INTERACT"
@export var portrait_texture: Texture2D = null
@export_multiline var dialogue_text := ""

var _mole_overlapping := false
var _dialogue_open := false
var _label: Label = null
var _dialogue_box: CanvasLayer = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_label = get_node_or_null("Prompt") as Label
	if _label:
		if prompt_text != "":
			_label.text = prompt_text
		_label.visible = false
		_label.z_index = 100
		_label.z_as_relative = false

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

func _open_dialogue() -> void:
	_dialogue_open = true
	_dialogue_box = preload("res://scenes/dialogue_box.tscn").instantiate()
	_dialogue_box.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_dialogue_box)
	_dialogue_box.next_pressed.connect(_on_dialogue_done)
	_dialogue_box.set_portrait(portrait_texture)
	_dialogue_box.show_text(dialogue_text, 0, 0, true, false)

func _on_dialogue_done() -> void:
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