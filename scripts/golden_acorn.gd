extends Area2D

signal collected

var level_path := ""

var _taken := false
var _base_y := 0.0
var _time := 0.0

func _ready() -> void:
	add_to_group("acorn")
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	position.y = _base_y + sin(_time * 3.0) * 6.0
	rotation = sin(_time * 2.0) * 0.12

func _draw() -> void:
	draw_circle(Vector2.ZERO, 44.0, Color(1.0, 0.9, 0.4, 0.18))
	draw_circle(Vector2(0, 5), 21.0, Color(0.72, 0.48, 0.16))
	draw_circle(Vector2(-6, 0), 8.0, Color(1.0, 0.82, 0.38))
	draw_circle(Vector2(0, -15), 11.0, Color(0.35, 0.22, 0.09))
	draw_line(Vector2(0, -24), Vector2(0, -32), Color(0.3, 0.18, 0.07), 3.0)
	draw_arc(Vector2.ZERO, 30.0, -0.5, 0.9, 16, Color(1.0, 0.95, 0.6, 0.7), 2.0)

func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("mole"):
		return
	_taken = true
	Shop.add_coins(5)
	Progress.mark_acorn(level_path)
	collected.emit()
	SFX.play_ui("item_pickup", -4.0, 1.4)
	_show_popup()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)

func _show_popup() -> void:
	var label := Label.new()
	label.text = "GOLDEN ACORN +5"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	label.z_index = 50
	var scene = get_tree().current_scene
	if scene == null:
		return
	scene.add_child(label)
	label.global_position = global_position + Vector2(-70, -110)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 46.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)