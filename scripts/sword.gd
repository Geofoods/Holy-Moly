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

var is_parrying := false
var parry_time_left := 0.0
var parry_cooldown := 0.0
const PARRY_DURATION := 1.25
const PARRY_COOLDOWN := 3.0

var deflect_sounds: Array[AudioStream] = []
var original_shape_pos := Vector2.ZERO
var original_shape: Shape2D = null
var parry_shape: CircleShape2D = null

@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_col: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: Line2D = $Trail

var tile_highlight: Sprite2D

func _ready() -> void:
	_tilemap_refresh()
	_setup_tile_highlight()
	trail.width = 12.0
	trail.default_color = Color(1.0, 1.0, 1.0, 0.6)
	trail.gradient = Gradient.new()
	trail.gradient.set_color(0, Color(1.0, 1.0, 0.8, 0.8))
	trail.gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	trail.width_curve = Curve.new()
	trail.width_curve.add_point(Vector2(0.0, 1.0))
	trail.width_curve.add_point(Vector2(1.0, 0.0))
	original_shape_pos = hitbox_col.position
	original_shape = hitbox_col.shape
	parry_shape = CircleShape2D.new()
	parry_shape.radius = 220.0
	for i in range(1, 4):
		deflect_sounds.append(load("res://sounds/deflect_%d.ogg" % i))

func _tilemap_refresh() -> TileMap:
	var tilemap := get_parent().get_parent().get_node_or_null("TileMap") as TileMap
	return tilemap

func _setup_tile_highlight() -> void:
	if not _tilemap_refresh():
		return
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.WHITE)
	var tex := ImageTexture.create_from_image(image)
	tile_highlight = Sprite2D.new()
	tile_highlight.name = "TileHighlight"
	tile_highlight.texture = tex
	tile_highlight.modulate = Color(1.0, 0.9, 0.5, 0.25)
	tile_highlight.scale = Vector2(80, 80)
	tile_highlight.centered = true
	tile_highlight.z_index = 100
	tile_highlight.z_as_relative = false
	get_parent().get_parent().add_child(tile_highlight)
	tile_highlight.hide()

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
	var mouse_global := get_global_mouse_position()
	var tile_pos := tilemap.local_to_map(tilemap.to_local(mouse_global))
	var source_id := tilemap.get_cell_source_id(0, tile_pos)
	var has_decoration := tilemap.get_layers_count() >= 2 and tilemap.get_cell_source_id(1, tile_pos) != -1
	if source_id == -1 and not has_decoration:
		tile_highlight.hide()
		return
	tile_highlight.global_position = tilemap.to_global(tilemap.map_to_local(tile_pos))
	tile_highlight.show()

func _process(delta: float) -> void:
	_update_trail()
	_update_parry(delta)
	_update_tile_highlight()

	if is_swinging:
		return

	var dir := (get_global_mouse_position() - global_position).normalized()
	rotation = atan2(dir.y, dir.x)

	if is_parrying:
		if dir.x < 0:
			sprite.flip_v = false
			sprite.flip_h = true
			sprite.rotation_degrees = 45.0
			hitbox.rotation_degrees = 45.0
		else:
			sprite.flip_v = true
			sprite.flip_h = true
			sprite.rotation_degrees = -45.0
			hitbox.rotation_degrees = -45.0
	else:
		sprite.flip_h = false
		if dir.x < 0:
			sprite.flip_v = true
			sprite.rotation_degrees = -45.0
			hitbox.rotation_degrees = -45.0
		else:
			sprite.flip_v = false
			sprite.rotation_degrees = 45.0
			hitbox.rotation_degrees = 45.0

func _update_parry(delta: float) -> void:
	if parry_cooldown > 0.0:
		parry_cooldown -= delta

	if is_parrying:
		parry_time_left -= delta
		if parry_time_left <= 0.0:
			_end_parry()

	_update_parry_indicator()

func _update_trail() -> void:
	var tip_offset := 330.0
	var dir := Vector2(cos(sprite.global_rotation), sin(sprite.global_rotation))
	var tip_pos := sprite.global_position + dir * tip_offset

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
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not is_swinging and not is_parrying:
			swing()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not is_swinging and not is_parrying and parry_cooldown <= 0.0:
			_start_parry()

func _start_parry() -> void:
	SFX.play("parry_activate", global_position)
	is_parrying = true
	parry_time_left = PARRY_DURATION
	hitbox.monitoring = true
	hitbox_col.position = Vector2(180, 0)
	hitbox_col.shape = parry_shape
	hitbox.area_entered.connect(_on_parry_area_entered)
	hitbox.body_entered.connect(_on_parry_body_entered)
	sprite.modulate = Color(0.6, 0.85, 1.0, 1.0)

func _end_parry() -> void:
	is_parrying = false
	parry_time_left = 0.0
	parry_cooldown = PARRY_COOLDOWN
	hitbox.monitoring = false
	hitbox_col.position = original_shape_pos
	hitbox_col.shape = original_shape
	if hitbox.area_entered.is_connected(_on_parry_area_entered):
		hitbox.area_entered.disconnect(_on_parry_area_entered)
	if hitbox.body_entered.is_connected(_on_parry_body_entered):
		hitbox.body_entered.disconnect(_on_parry_body_entered)
	sprite.modulate = Color.WHITE
	sprite.flip_h = false

func _on_parry_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and is_parrying:
		if "deflected" in area and not area.deflected:
			_deflect_bullet(area)

func _on_parry_body_entered(body: Node) -> void:
	if body.is_in_group("bullet") and is_parrying:
		if "deflected" in body and not body.deflected:
			_deflect_bullet(body)

func swing() -> void:
	SFX.play("swing", global_position)
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
			SFX.play("enemy_hit", enemy.global_position)

func _deflect_bullet(bullet: Node) -> void:
	var target_pos := get_global_mouse_position()
	bullet.deflect(target_pos)
	_play_deflect_sound()
	_spawn_deflect_shine(bullet.global_position)
	var mole = get_parent()
	if mole.has_method("deflect_pause"):
		mole.deflect_pause()

func _play_deflect_sound() -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = deflect_sounds[randi() % deflect_sounds.size()]
	player.volume_db = -4.0
	player.pitch_scale = randf_range(0.9, 1.1)
	get_parent().get_parent().add_child(player)
	player.global_position = global_position
	player.play()
	player.finished.connect(player.queue_free)

func _spawn_deflect_shine(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.45
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 250.0
	particles.initial_velocity_max = 500.0
	particles.gravity = Vector2.ZERO
	particles.damping_min = 350.0
	particles.damping_max = 500.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = Color(0.85, 0.92, 1.0, 1.0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(0.5, 0.75, 1.0, 0.0))
	particles.color_ramp = fade
	get_parent().get_parent().add_child(particles)
	particles.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func _get_or_create_indicator() -> Control:
	var canvas_layer = get_parent().get_parent().get_node_or_null("CanvasLayer")
	if not canvas_layer:
		return null
	var indicator = canvas_layer.get_node_or_null("ParryIndicator")
	if indicator:
		return indicator

	indicator = Control.new()
	indicator.name = "ParryIndicator"
	indicator.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	indicator.position = Vector2(20, -60)
	indicator.size = Vector2(120, 40)

	var bg := ColorRect.new()
	bg.name = "BG"
	bg.size = Vector2(120, 16)
	bg.position = Vector2(0, 20)
	bg.color = Color(0.15, 0.15, 0.2, 0.8)
	indicator.add_child(bg)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.size = Vector2(120, 16)
	fill.position = Vector2(0, 20)
	fill.color = Color(0.4, 0.75, 1.0, 0.9)
	indicator.add_child(fill)

	var label := Label.new()
	label.name = "Label"
	label.text = "PARRY [RMB]"
	label.position = Vector2(0, 0)
	var font = load("res://Baby Doll.otf")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1.0))
	indicator.add_child(label)

	canvas_layer.add_child(indicator)
	return indicator

func _update_parry_indicator() -> void:
	var indicator := _get_or_create_indicator()
	if not indicator:
		return
	var fill := indicator.get_node("Fill") as ColorRect
	var label := indicator.get_node("Label") as Label
	if is_parrying:
		var ratio := parry_time_left / PARRY_DURATION
		fill.size.x = 120.0 * ratio
		fill.color = Color(0.3, 0.85, 1.0, 0.9)
		label.text = "PARRY ACTIVE"
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0, 1.0))
	elif parry_cooldown > 0.0:
		var ratio := 1.0 - (parry_cooldown / PARRY_COOLDOWN)
		fill.size.x = 120.0 * ratio
		fill.color = Color(0.5, 0.5, 0.6, 0.7)
		label.text = "COOLDOWN"
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1.0))
	else:
		fill.size.x = 120.0
		fill.color = Color(0.4, 0.75, 1.0, 0.9)
		label.text = "PARRY [RMB]"
		label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1.0))

func dig_slash() -> void:
	if is_swinging or is_parrying:
		return
	SFX.play("swing", global_position)
	is_swinging = true
	visible = true
	hitbox.monitoring = true
	hit_enemies = []
	trail_points.clear()

	hitbox.area_entered.connect(_on_hitbox_area_entered)

	_break_tile_at_mouse()

	var dir := (get_global_mouse_position() - global_position).normalized()
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
	var tilemap := get_parent().get_parent().get_node_or_null("TileMap") as TileMap
	if not tilemap:
		return
	var mouse_global = get_global_mouse_position()
	var tile_pos = tilemap.local_to_map(tilemap.to_local(mouse_global))
	var sfx = load("res://scripts/tile_break_sfx.gd")
	var source_id := tilemap.get_cell_source_id(0, tile_pos)
	var broke_tile := false
	if source_id != -1:
		sfx.break_tile(tilemap, tile_pos, get_parent().get_parent())
		broke_tile = true
	elif tilemap.get_layers_count() >= 2 and tilemap.get_cell_source_id(1, tile_pos) != -1:
		sfx.break_decoration_tile(tilemap, tile_pos, get_parent().get_parent())
		broke_tile = true
	if broke_tile:
		var mole = get_parent()
		if mole and mole.has_method("spawn_dirt_particles"):
			var tile_world = tilemap.to_global(tilemap.map_to_local(tile_pos))
			mole.spawn_dirt_particles(tile_world)
