extends Node2D

var is_swinging := false
const SWING_ARC := 2.4
const WINDUP_DURATION := 0.15
const SWING_DURATION := 0.3
const WINDUP_PULLBACK := 0.2
var hit_enemies := []

const TRAIL_LENGTH := 8
var trail_points: Array[Vector2] = []
var trail_widths: Array[float] = []

@onready var hitbox: Area2D = $Hitbox
@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: Line2D = $Trail

func _ready() -> void:
	trail.width = 12.0
	trail.default_color = Color(1.0, 1.0, 1.0, 0.6)
	trail.gradient = Gradient.new()
	trail.gradient.set_color(0, Color(1.0, 1.0, 0.8, 0.8))
	trail.gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	trail.width_curve = Curve.new()
	trail.width_curve.add_point(Vector2(0.0, 1.0))
	trail.width_curve.add_point(Vector2(1.0, 0.0))

func _process(delta: float) -> void:
	_update_trail()

	if is_swinging:
		return
	var dir := (get_global_mouse_position() - global_position).normalized()
	rotation = atan2(dir.y, dir.x)

	if dir.x < 0:
		sprite.flip_v = true
		sprite.rotation_degrees = -45.0
		hitbox.rotation_degrees = -45.0
	else:
		sprite.flip_v = false
		sprite.rotation_degrees = 45.0
		hitbox.rotation_degrees = 45.0

func _update_trail() -> void:
	var tip_offset := 330.0
	var tip_pos := global_position + Vector2(cos(global_rotation), sin(global_rotation)) * tip_offset

	if is_swinging:
		trail_points.push_front(tip_pos)
		if trail_points.size() > TRAIL_LENGTH:
			trail_points.resize(TRAIL_LENGTH)
	else:
		if trail_points.size() > 0:
			trail_points.pop_back()

	trail.global_rotation = 0.0
	trail.global_position = Vector2.ZERO
	trail.clear_points()
	for point in trail_points:
		trail.add_point(point)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not is_swinging:
		swing()

func swing() -> void:
	is_swinging = true
	hitbox.monitoring = true
	hit_enemies = []
	trail_points.clear()

	hitbox.area_entered.connect(_on_hitbox_area_entered)

	_break_tile_at_mouse()

	var aim := rotation

	var start_angle := aim - SWING_ARC / 2.0
	var end_angle := aim + SWING_ARC / 2.0

	if cos(aim) < 0:
		start_angle = aim + SWING_ARC / 2.0
		end_angle = aim - SWING_ARC / 2.0

	var windup_angle := start_angle - (end_angle - start_angle) * WINDUP_PULLBACK
	rotation = start_angle

	var tween := create_tween()
	tween.tween_property(self, "rotation", windup_angle, WINDUP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "rotation", end_angle, SWING_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_end_swing)

func _end_swing() -> void:
	is_swinging = false
	hitbox.monitoring = false
	hitbox.area_entered.disconnect(_on_hitbox_area_entered)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy not in hit_enemies:
			hit_enemies.append(enemy)
			if enemy.has_method("die"):
				enemy.die()

func _break_tile_at_mouse() -> void:
	var tilemap = get_parent().get_parent().get_node_or_null("TileMap")
	if not tilemap:
		return
	var mouse_global = get_global_mouse_position()
	var tile_pos = tilemap.local_to_map(tilemap.to_local(mouse_global))
	tilemap.erase_cell(0, tile_pos)
