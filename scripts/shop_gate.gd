extends Area2D

var _mole_overlapping := false
var _label: Label = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_label = get_node_or_null("Prompt") as Label
	if _label:
		_label.visible = false
		_label.z_index = 50
		_label.z_as_relative = false
	queue_redraw()

func _process(_delta: float) -> void:
	if _label:
		_label.visible = _mole_overlapping and not get_tree().paused

func _input(event: InputEvent) -> void:
	if _mole_overlapping and event.is_action_pressed("interact"):
		Shop.open_shop()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_overlapping = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_overlapping = false

func _draw() -> void:
	var post := Color(0.42, 0.28, 0.16)
	var board := Color(0.55, 0.38, 0.2)
	var outline := Color(0.3, 0.2, 0.11)
	draw_rect(Rect2(Vector2(-10, 0), Vector2(18, 80)), post)
	draw_circle(Vector2(0, 80), 9.0, post)
	draw_rect(Rect2(Vector2(-54, -52), Vector2(108, 50)), board)
	draw_rect(Rect2(Vector2(-54, -52), Vector2(108, 50)), outline, false, 3.0)
	draw_circle(Vector2(0, -27), 9.0, Color(1.0, 0.82, 0.25))
	draw_circle(Vector2(0, -27), 3.0, outline)
	draw_rect(Rect2(Vector2(-30, -4), Vector2(24, 3)), outline)
	draw_rect(Rect2(Vector2(-30, -4), Vector2(3, 14)), outline)
	draw_rect(Rect2(Vector2(-9, -4), Vector2(24, 3)), outline)
	draw_rect(Rect2(Vector2(-9, -4), Vector2(3, 14)), outline)