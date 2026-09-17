extends Node2D

const BULLET_SCENE := preload("res://scenes/player_bullet.tscn")

var _cooldown := 0.0
var _muzzle_flash_left := 0.0

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_muzzle_flash_left = maxf(_muzzle_flash_left - delta, 0.0)

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
	_muzzle_flash_left = 0.08

	var world := get_parent().get_parent()
	var spread := [-0.14, 0.0, 0.14] if Shop.has_triple_shot() else [0.0]
	for a in spread:
		var bullet = BULLET_SCENE.instantiate()
		world.add_child(bullet)
		bullet.global_position = to_global(Vector2(62, 0).rotated(a))
		bullet.setup(w, Vector2.RIGHT.rotated(rotation + a))

	SFX.play("swing", global_position, -8.0, 0.1, 1.5)
	queue_redraw()

func _draw() -> void:
	var color := Color(0.35, 0.35, 0.4)
	if _muzzle_flash_left > 0.0:
		draw_line(Vector2.ZERO, Vector2(70, 0), Color(1.0, 0.9, 0.4, 0.9), 4.0)
		draw_circle(Vector2(64, 0), randf_range(3.0, 7.0), Color(1.0, 0.95, 0.6))
		return
	draw_line(Vector2(6, 6), Vector2(48, 10), color, 5.0)
	draw_line(Vector2(48, 6), Vector2(60, 10), Color(0.1, 0.1, 0.12), 6.0)
	draw_line(Vector2(18, 6), Vector2(20, 18), color, 4.0)
	draw_circle(Vector2(28, 4), 3.0, Color(0.5, 0.5, 0.6))