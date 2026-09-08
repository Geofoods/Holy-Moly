extends Node2D

var is_swinging := false
const SWING_ARC := 2.4
const WINDUP_DURATION := 0.15
const SWING_DURATION := 0.3
const WINDUP_PULLBACK := 0.2
var hit_enemies := []
var _mouse_held := false

const GHOST_COUNT := 16
const GHOST_SPAWN_INTERVAL := 0.02
const GHOST_HOLD_DURATION := 0.08
const GHOST_FADE_DURATION := 0.55
const GHOST_SCALE := 1.5
const GHOST_ALPHA := 0.5
const GHOST_TIP_DISTANCE := 200.0
const GHOST_Z_INDEX := 6

@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_col: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var _ghosts: Array[Sprite2D] = []
var _ghost_tweens: Dictionary = {}
var _ghost_accum := 0.0
var _ghost_index := 0

const HIGHLIGHT_MINEABLE := Color(0.15, 1.0, 0.35, 1.0)
const HIGHLIGHT_UNMINEABLE := Color(1.0, 0.15, 0.15, 1.0)
const HIGHLIGHT_AIR := Color(1.0, 1.0, 1.0, 1.0)
const HIGHLIGHT_WIDTH := 6.0
const HIGHLIGHT_MIN_ALPHA := 0.35
const HIGHLIGHT_FLASH_TIME := 0.35

enum BlockState { AIR, MINEABLE, UNMINEABLE }

var tile_highlight: Sprite2D
var _highlight_tween: Tween = null

func _ready() -> void:
	_tilemap_refresh()
	_setup_tile_highlight()
	_setup_ghosts()

func _setup_ghosts() -> void:
	var world := get_parent().get_parent()
	for i in GHOST_COUNT:
		var ghost := Sprite2D.new()
		ghost.name = "SwingGhost%d" % i
		ghost.texture = sprite.texture
		ghost.centered = true
		ghost.modulate = Color(1.0, 1.0, 1.0, 0.0)
		ghost.z_index = GHOST_Z_INDEX
		ghost.z_as_relative = false
		world.add_child(ghost)
		_ghosts.append(ghost)

func _tilemap_refresh() -> TileMap:
	var tilemap := get_parent().get_parent().get_node_or_null("TileMap") as TileMap
	return tilemap

func _setup_tile_highlight() -> void:
	var tilemap := _tilemap_refresh()
	if not tilemap:
		return
	var world := get_parent().get_parent()
	var tile_world := Vector2(tilemap.tile_set.tile_size) * tilemap.scale
	var tex_size := Vector2i(maxi(1, roundi(tile_world.x)), maxi(1, roundi(tile_world.y)))
	var border := maxi(2, roundi(HIGHLIGHT_WIDTH))
	var image := Image.create(tex_size.x, tex_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in tex_size.y:
		for x in tex_size.x:
			if x < border or x >= tex_size.x - border or y < border or y >= tex_size.y - border:
				image.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(image)
	tile_highlight = Sprite2D.new()
	tile_highlight.name = "TileHighlight"
	tile_highlight.texture = tex
	tile_highlight.centered = true
	tile_highlight.z_index = 0
	tile_highlight.z_as_relative = false
	tile_highlight.modulate = Color.WHITE
	world.add_child(tile_highlight)
	tile_highlight.hide()

	_highlight_tween = create_tween().set_loops()
	_highlight_tween.tween_property(tile_highlight, "modulate:a", HIGHLIGHT_MIN_ALPHA, HIGHLIGHT_FLASH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(tile_highlight, "modulate:a", 1.0, HIGHLIGHT_FLASH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_tile_highlight() -> void:
	if not visible or is_swinging:
		if tile_highlight:
			tile_highlight.hide()
		return
	if not tile_highlight:
		return
	var tilemap := _tilemap_refresh()
	if not tilemap:
		tile_highlight.hide()
		return
	var mouse_global := _aim_pos()
	var tile_pos := tilemap.local_to_map(tilemap.to_local(mouse_global))
	var col := _highlight_color(tilemap, tile_pos)
	tile_highlight.modulate.r = col.r
	tile_highlight.modulate.g = col.g
	tile_highlight.modulate.b = col.b
	tile_highlight.global_position = tilemap.to_global(tilemap.map_to_local(tile_pos))
	tile_highlight.show()

func _highlight_color(tilemap: TileMap, tile_pos: Vector2i) -> Color:
	match _block_state(tilemap, tile_pos):
		BlockState.AIR:
			return HIGHLIGHT_AIR
		BlockState.UNMINEABLE:
			return HIGHLIGHT_UNMINEABLE
		_:
			return HIGHLIGHT_MINEABLE

func _block_state(tilemap: TileMap, tile_pos: Vector2i) -> int:
	var source_id := tilemap.get_cell_source_id(0, tile_pos)
	var has_decoration := tilemap.get_layers_count() >= 2 and tilemap.get_cell_source_id(1, tile_pos) != -1
	if source_id == -1 and not has_decoration:
		return BlockState.AIR
	if source_id != -1:
		var tile_data := tilemap.get_cell_tile_data(0, tile_pos)
		if tile_data and tile_data.get_custom_data("bedrock"):
			return BlockState.UNMINEABLE
	return BlockState.MINEABLE

func _aim_pos() -> Vector2:
	return get_global_mouse_position()

func _process(delta: float) -> void:
	_update_tile_highlight()

	if is_swinging:
		_capture_ghost(delta)
		return

	var dir := (_aim_pos() - global_position).normalized()
	rotation = atan2(dir.y, dir.x)

	sprite.flip_h = false
	if dir.x < 0:
		sprite.flip_v = true
		sprite.rotation_degrees = -45.0
		hitbox.rotation_degrees = -45.0
	else:
		sprite.flip_v = false
		sprite.rotation_degrees = 45.0
		hitbox.rotation_degrees = 45.0

	if _mouse_held:
		_do_attack()

func _capture_ghost(delta: float) -> void:
	_ghost_accum += delta
	if _ghost_accum < GHOST_SPAWN_INTERVAL:
		return
	_ghost_accum = 0.0

	var tip := sprite.global_position + Vector2(GHOST_TIP_DISTANCE, 0.0).rotated(sprite.global_rotation)
	_spawn_one_ghost(sprite.global_position)
	_spawn_one_ghost(tip)

func _spawn_one_ghost(pos: Vector2) -> void:
	var ghost := _ghosts[_ghost_index]
	_ghost_index = (_ghost_index + 1) % _ghosts.size()

	ghost.global_position = pos
	ghost.global_rotation = sprite.global_rotation
	ghost.scale = sprite.scale * GHOST_SCALE
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.offset = sprite.offset
	ghost.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)

	var prev = _ghost_tweens.get(ghost)
	if prev is Tween and prev.is_valid():
		prev.kill()
	var tween := create_tween()
	tween.tween_interval(GHOST_HOLD_DURATION)
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_DURATION).set_ease(Tween.EASE_OUT)
	_ghost_tweens[ghost] = tween

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_held = true
			_do_attack()
		else:
			_mouse_held = false

func _do_attack() -> void:
	if not visible:
		return
	_break_tile_at_mouse()
	if not is_swinging:
		swing()

func swing() -> void:
	SFX.play("swing", global_position)
	is_swinging = true
	hitbox.monitoring = true
	hit_enemies = []

	hitbox.area_entered.connect(_on_hitbox_area_entered)

	if _is_aerial():
		_swing_aerial(rotation)
	else:
		_swing_ground(rotation)

func _is_aerial() -> bool:
	var mole := get_parent() as CharacterBody2D
	return mole != null and not mole.is_on_floor()

func _swing_ground(aim: float) -> void:
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

func _swing_aerial(aim: float) -> void:
	rotation = aim
	var spin_to := aim + TAU
	if cos(aim) < 0:
		spin_to = aim - TAU
	var tween := create_tween()
	tween.tween_property(self, "rotation", spin_to, SWING_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_end_swing)

func _end_swing() -> void:
	is_swinging = false
	hitbox.monitoring = false
	hitbox.area_entered.disconnect(_on_hitbox_area_entered)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("opened_chest"):
		area.call("break_as_block")
		return
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy not in hit_enemies:
			hit_enemies.append(enemy)
			SFX.play("enemy_hit", enemy.global_position)
			var mole = get_parent()
			if mole.has_method("screen_shake"):
				mole.screen_shake(8.0, 0.15)
			if enemy is CharacterBody2D:
				var knockback_dir = (enemy.global_position - mole.global_position).normalized()
				enemy.velocity = knockback_dir * 600.0
				enemy.velocity.y = -250.0

func dig_slash() -> void:
	if is_swinging:
		return
	SFX.play("swing", global_position)
	is_swinging = true
	visible = true
	hitbox.monitoring = true
	hit_enemies = []

	hitbox.area_entered.connect(_on_hitbox_area_entered)

	var dir := (_aim_pos() - global_position).normalized()
	var aim := atan2(dir.y, dir.x)
	var arc := SWING_ARC * 1.4
	var start_angle := aim - arc / 2.0
	var end_angle := aim + arc / 2.0

	if cos(aim) < 0:
		start_angle = aim + arc / 2.0
		end_angle = aim - arc / 2.0

	rotation = start_angle

	var tween := create_tween()
	tween.tween_property(self, "rotation", end_angle, SWING_DURATION * 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_end_swing)

func _break_tile_at_mouse() -> void:
	var world := get_parent().get_parent()
	var mouse_global = _aim_pos()
	var sfx = load("res://scripts/tile_break_sfx.gd")
	if sfx.break_opened_chest_at_point(world, mouse_global):
		return
	var tilemap := world.get_node_or_null("TileMap") as TileMap
	if not tilemap:
		return
	var tile_pos = tilemap.local_to_map(tilemap.to_local(mouse_global))
	var source_id := tilemap.get_cell_source_id(0, tile_pos)
	var broke_tile := false
	if source_id != -1:
		sfx.break_tile(tilemap, tile_pos, world)
		broke_tile = true
	elif tilemap.get_layers_count() >= 2 and tilemap.get_cell_source_id(1, tile_pos) != -1:
		sfx.break_decoration_tile(tilemap, tile_pos, world)
		broke_tile = true
	if broke_tile:
		var mole = get_parent()
		if mole and mole.has_method("spawn_dirt_particles"):
			var tile_world = tilemap.to_global(tilemap.map_to_local(tile_pos))
			mole.spawn_dirt_particles(tile_world)
