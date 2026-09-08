extends Control

@export var target_scene: String = "res://scenes/level1.tscn"

@onready var _area: Area2D = $Area2D

var _mole_nearby := false
var _transitioning := false

func _ready() -> void:
	_area.body_entered.connect(_on_area_body_entered)
	_area.body_exited.connect(_on_area_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if _mole_nearby and not _transitioning and event.is_action_pressed("interact"):
		_transition()

func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = true

func _on_area_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = false

func _transition() -> void:
	if target_scene.is_empty():
		return
	_transitioning = true
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(target_scene)