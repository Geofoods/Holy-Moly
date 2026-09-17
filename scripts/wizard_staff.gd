extends Node2D

const BOLT_SCENE := preload("res://scenes/magic_bolt.tscn")

const CRYSTAL := Color(0.7, 0.35, 1.0)
const WOOD := Color(0.42, 0.26, 0.12)
const WOOD_DARK := Color(0.28, 0.16, 0.08)
const WOOD_LIGHT := Color(0.55, 0.36, 0.16)

var _cooldown := 0.0
var _flash_left := 0.0
var _glow_phase := 0.0

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_glow_phase += delta

	if not visible:
		return

	var target := get_global_mouse_position()
	var dir := target - global_position
	if dir.length() < 1.0:
		return
	rotation = dir.angle()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire()

func _fire() -> void:
	if _cooldown > 0.0:
		return
	var w := Shop.get_ranged()
	if w == null:
		return
	_cooldown = w.cooldown
	_flash_left = 0.12

	var world := get_parent().get_parent()
	var spread := [-0.14, 0.0, 0.14] if Shop.has_triple_shot() else [0.0]
	for a in spread:
		var bolt = BOLT_SCENE.instantiate()
		world.add_child(bolt)
		bolt.global_position = to_global(Vector2(120, 0).rotated(a))
		bolt.setup(w, Vector2.RIGHT.rotated(rotation + a))

	SFX.play("swing", global_position, -8.0, 0.1, 2.0)
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_glow_phase * 6.0)

	if _flash_left > 0.0:
		draw_line(Vector2(120, 0), Vector2(190, 0), Color(0.85, 0.6, 1.0, 0.9), 5.0)
		draw_circle(Vector2(120, 0), 15.0, Color(1.0, 0.9, 1.0, 0.7))
		draw_circle(Vector2(120, 0), randf_range(4.0, 10.0), Color(1.0, 1.0, 1.0, 0.9))

	draw_line(Vector2(0, 0), Vector2(20, 0), WOOD_DARK, 9.0)
	draw_line(Vector2(20, 0), Vector2(120, 0), WOOD, 7.0)
	draw_line(Vector2(20, 0), Vector2(120, 0), WOOD_LIGHT, 3.0)

	draw_line(Vector2(0, 0), Vector2(-14, 8), WOOD_DARK, 6.0)
	draw_circle(Vector2(-6, 4), 4.0, WOOD_LIGHT)
	draw_circle(Vector2(32, 0), 5.0, Color(0.75, 0.6, 0.3))
	draw_circle(Vector2(32, 0), 3.0, Color(0.9, 0.8, 0.5))

	var aura := CRYSTAL
	aura.a = 0.25 + pulse * 0.25
	var aura_radius := 16.0 + pulse * 6.0
	draw_circle(Vector2(120, 0), aura_radius, aura)
	aura.a = 0.5
	draw_circle(Vector2(120, 0), 11.0, aura)

	var points := PackedVector2Array([
		Vector2(120, 0),
		Vector2(112, -9),
		Vector2(120, -18),
		Vector2(128, -9),
	])
	draw_colored_polygon(points, Color(0.82, 0.5, 1.0))
	var points2 := PackedVector2Array([
		Vector2(120, 0),
		Vector2(128, 9),
		Vector2(120, 18),
		Vector2(112, 9),
	])
	draw_colored_polygon(points2, Color(0.62, 0.32, 0.95))

	draw_circle(Vector2(120, 0), 7.0, Color(1.0, 0.96, 1.0, 0.95))
	var spark_angle := _glow_phase * 3.0
	for i in 2:
		var pos := Vector2(120, 0) + Vector2(20 + pulse * 6.0, 0).rotated(spark_angle + i * PI)
		draw_circle(pos, 2.5, Color(1.0, 0.85, 1.0, 0.8))