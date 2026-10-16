extends Area2D

var _velocity := Vector2.ZERO
var _damage := 0.0
var _life := 2.0
var _color := Color.WHITE
var _dead := false

func setup(w: WeaponData, dir_facing: Vector2) -> void:
	_damage = randf_range(w.min_damage, w.max_damage)
	_velocity = dir_facing * w.projectile_speed
	_color = w.icon_color
	rotation = dir_facing.angle()

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += _velocity * delta
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
			enemy.take_damage(_damage * ComboManager.get_damage_multiplier(enemy), _velocity.normalized())
			queue_free()

func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body is TileMap:
		_dead = true
		_break_tile(body as TileMap)
		_hit_impact()
	elif body.is_in_group("mole"):
		return
	else:
		return

func _break_tile(tilemap: TileMap) -> void:
	var sfx := preload("res://scripts/tile_break_sfx.gd")
	var tile_pos := _impact_cell(tilemap)
	var parent := tilemap.get_parent()
	if tilemap.get_cell_source_id(0, tile_pos) != -1:
		sfx.break_tile(tilemap, tile_pos, parent)
	else:
		sfx.break_decoration_tile(tilemap, tile_pos, parent)
	sfx.break_opened_chests_near(parent, global_position)

# The tile collision polygons are far larger than the tiles themselves, so the
# body_entered signal fires the instant the bullet grazes a wall - often while
# its centre is still in the open cell in front of it. Mapping that centre would
# erase empty space, so step along the flight path to find the block actually hit.
func _impact_cell(tilemap: TileMap) -> Vector2i:
	var centre := tilemap.local_to_map(tilemap.to_local(global_position))
	if tilemap.get_cell_source_id(0, centre) != -1:
		return centre
	var dir := _velocity.normalized()
	if dir == Vector2.ZERO:
		return centre
	var step := 40.0
	if tilemap.tile_set != null:
		var ts := float(tilemap.tile_set.tile_size.x)
		if ts > 0.0:
			step = ts * 0.5
	var point := global_position
	for i in 8:
		point += dir * step
		var cell := tilemap.local_to_map(tilemap.to_local(point))
		if tilemap.get_cell_source_id(0, cell) != -1:
			return cell
	return centre

func _hit_impact() -> void:
	SFX.play("swing", global_position, -10.0, 0.1, 1.6)
	var flash := ColorRect.new()
	flash.size = Vector2(6, 6)
	flash.rotation = randf_range(0.0, TAU)
	flash.color = _color
	flash.modulate.a = 0.9
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(flash)
	flash.global_position = global_position - flash.size * 0.5
	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector2(3, 3), 0.15)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.15)
	tw.tween_callback(flash.queue_free)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.4))
	draw_circle(Vector2(2, 0), 5.0, _color)
	draw_circle(Vector2(2, 0), 3.0, Color.WHITE)