extends Area2D

var _velocity := Vector2.ZERO
var _damage := 0.0
var _life := 3.0
var _color := Color(0.7, 0.35, 1.0)
var _dead := false
var _tail: Array[Vector2] = []

const TAIL_MAX := 14

func setup(w: WeaponData, dir_facing: Vector2) -> void:
	_damage = randf_range(w.min_damage, w.max_damage) * ComboManager.get_damage_multiplier()
	_velocity = dir_facing * w.projectile_speed
	_color = w.icon_color
	rotation = dir_facing.angle()

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_tail.append(position)
	if _tail.size() > TAIL_MAX:
		_tail.pop_front()
	position += _velocity * delta
	queue_redraw()
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _dead:
		return
	if area.is_in_group("enemy_hurtbox"):
		var enemy := area.get_parent()
		if enemy and enemy.has_method("take_damage"):
			_dead = true
			enemy.take_damage(_damage)
			_explode()

func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body is TileMap:
		_dead = true
		_break_tile(body as TileMap)
		_explode()
	elif body.is_in_group("mole"):
		return

func _break_tile(tilemap: TileMap) -> void:
	var sfx := preload("res://scripts/tile_break_sfx.gd")
	var tile_pos := tilemap.local_to_map(tilemap.to_local(global_position))
	var parent := tilemap.get_parent()
	if tilemap.get_cell_source_id(0, tile_pos) != -1:
		sfx.break_tile(tilemap, tile_pos, parent)
	else:
		sfx.break_decoration_tile(tilemap, tile_pos, parent)
	sfx.break_opened_chests_near(parent, global_position)

func _explode() -> void:
	SFX.play("swing", global_position, -10.0, 0.1, 2.2)
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 18
	burst.lifetime = 0.5
	burst.direction = Vector2.ZERO
	burst.spread = 180.0
	burst.initial_velocity_min = 80.0
	burst.initial_velocity_max = 260.0
	burst.gravity = Vector2(0, 300)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 6.0
	var grad := Gradient.new()
	var fade := _color
	fade.a = 0.0
	grad.set_color(0, _color)
	grad.set_color(1, fade)
	burst.color_ramp = grad
	burst.z_index = 5
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)
	queue_free()

func _draw() -> void:
	var denom := float(TAIL_MAX - 1)
	for i in _tail.size():
		var t := float(i) / denom
		var c := _color
		c.a = 0.35 * t
		draw_circle(_tail[i] - position, lerpf(2.5, 8.0, t), c)
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.4))
	draw_circle(Vector2.ZERO, 8.0, _color)
	draw_circle(Vector2(-2, 0), 3.5, Color(1.0, 1.0, 1.0, 0.95))