extends CharacterBody2D

const MAX_HEALTH := 320.0
const PAN_DURATION := 0.75

const HOVER_SPEED := 170.0
const BOB_AMPLITUDE := 45.0
const BOB_FREQ := 3.0
const STING_SPEED := 1100.0
const STING_TELEGRAPH := 0.6
const STING_COOLDOWN := 4.0
const STING_RECOVER := 0.8
const STING_RANGE := 950.0

const SPIT_INTERVAL := 3.0
const PROJECTILE_SPEED := 520.0

const HORNET_SPAWN_INTERVAL := 9.0
const MAX_HORNETS := 3

const TILE_BREAK_INTERVAL := 0.32
const RAM_BREAK_INTERVAL := 0.08

const GRACE_X := 150.0

const EnemyDamage := preload("res://scripts/enemy.gd")

const INTRO_LINES := [
	"buzzzz... you think you can waltz into MY hive?",
	"every other bug down here cowers when they hear my wings.",
	"stingers up, little mole. my children are hungry!",
]

enum State { HOVER, TELEGRAPH, STING, RECOVER }

var health := MAX_HEALTH
var _boss_active := false
var _cutscene_playing := false
var _state := State.HOVER
var _state_timer := 0.0
var _spit_cooldown := 0.0
var _hornet_timer := 0.0
var _sting_cooldown := 0.0
var _sting_dir := Vector2.RIGHT
var _drift_dir := 1.0
var _bob_phase := 0.0

var _cutscene_mole: Node = null
var _cutscene_cam: Camera2D = null
var _cutscene_stage := -1
var _cutscene_time := 0.0
var _cutscene_start_pos := Vector2.ZERO
var _cutscene_target_pos := Vector2.ZERO
var _cutscene_start_cam_pos := Vector2.ZERO

var _dialogue_box: CanvasLayer = null
var _dialogue_line_index := 0
var _dialogue_finished := false

var _ancestor_wall: StaticBody2D = null

var _tilemap: TileMap = null
var _tile_break_script: GDScript = null
var _break_timer := 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var trigger: Area2D = $CutsceneTrigger
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox

var _projectile_scene: PackedScene = null
var _hornet_scene: PackedScene = null
var _mole_in_contact := false

var _health_bar_layer: CanvasLayer = null
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null
var _health_bar_label: Label = null
var _health_bar_name: Label = null
var _health_bar_tween: Tween = null
var _displayed_health: float = 0.0

const INDICATOR_SCREEN_MARGIN := 70.0
var _indicator_layer: CanvasLayer = null
var _indicator_arrow: Polygon2D = null

func _ready() -> void:
	_build_sprite_frames()
	anim.play("fly")
	trigger.body_entered.connect(_on_trigger_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.body_exited.connect(_on_hitbox_body_exited)
	hurtbox.add_to_group("enemy_hurtbox")
	_projectile_scene = preload("res://area_2d.tscn")
	_hornet_scene = preload("res://scenes/hornet_enemy.tscn")
	_ancestor_wall = get_parent().get_node_or_null("StaticBody2D") as StaticBody2D
	_tilemap = get_parent().get_node_or_null("TileMap") as TileMap
	_tile_break_script = load("res://scripts/tile_break_sfx.gd")
	_spit_cooldown = 2.0

func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("fly")
	frames.add_animation("sting")
	frames.set_animation_loop("fly", true)
	frames.set_animation_loop("sting", true)
	var placeholder := load("res://sprites/queen_bee_placeholder.png") as Texture2D
	if placeholder:
		frames.add_frame("fly", placeholder)
		frames.add_frame("sting", placeholder)
		frames.set_animation_speed("fly", 1.0)
		frames.set_animation_speed("sting", 1.0)
		anim.sprite_frames = frames
		return
	for i in 2:
		var wing_up := i == 0
		frames.add_frame("fly", _make_bee_texture(wing_up, false))
		frames.add_frame("fly", _make_bee_texture(wing_up, true))
		frames.set_animation_speed("fly", 14.0)
		frames.add_frame("sting", _make_bee_texture(false, true))
		frames.set_animation_speed("sting", 1.0)
	anim.sprite_frames = frames

func _make_bee_texture(stinger_out: bool, wing_up: bool) -> Texture2D:
	var size := 200
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var body_center := Vector2(size * 0.5, size * 0.55)
	# Body
	_fill_ellipse(img, body_center, Vector2(58, 68), Color(0.95, 0.76, 0.1, 1.0))
	# Black stripes
	for i in 3:
		var sy := body_center.y - 34.0 + i * 22.0
		_fill_ellipse(img, Vector2(body_center.x, sy), Vector2(58, 7), Color(0.12, 0.08, 0.05, 1.0))
	# Head (right side)
	_fill_ellipse(img, body_center + Vector2(78, -14), Vector2(30, 34), Color(0.2, 0.13, 0.07, 1.0))
	# Eye
	_fill_ellipse(img, body_center + Vector2(90, -16), Vector2(9, 12), Color(1, 0.98, 0.85, 1.0))
	# Crown (queen!)
	_crown_fill(img, body_center + Vector2(76, -60))
	# Stinger (left side)
	if stinger_out:
		_fill_ellipse(img, body_center - Vector2(92, 18), Vector2(30, 10), Color(0.15, 0.1, 0.08, 1.0))
	# Wings (top)
	var wing_color := Color(0.85, 0.92, 1.0, 0.55)
	var wing_center := body_center + Vector2(-2, -58)
	var wing_dy := -16.0 if wing_up else 8.0
	_fill_ellipse(img, wing_center + Vector2(10, wing_dy), Vector2(46, 26), wing_color)
	_fill_ellipse(img, wing_center + Vector2(-34, wing_dy - 6), Vector2(36, 20), Color(0.95, 0.97, 1.0, 0.4))

	return ImageTexture.create_from_image(img)

func _crown_fill(img: Image, center: Vector2) -> void:
	var gold := Color(1.0, 0.82, 0.2, 1.0)
	var dark := Color(0.55, 0.32, 0.05, 1.0)
	var x0 := int(center.x - 20)
	var x1 := int(center.x + 20)
	for y in range(int(center.y), int(center.y + 8)):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, gold)
	for spike in [-14, 0, 14]:
		for dy in range(-8, 1):
			var px := int(center.x + spike)
			var py := int(center.y + dy)
			img.set_pixel(px, py, dark if dy > -6 else gold)

func _fill_ellipse(img: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	for y in range(int(center.y - radius.y), int(center.y + radius.y) + 1):
		for x in range(int(center.x - radius.x), int(center.x + radius.x) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var nx := (float(x) - center.x) / radius.x
			var ny := (float(y) - center.y) / radius.y
			if nx * nx + ny * ny <= 1.25:
				img.set_pixel(x, y, color)

func _create_health_bar() -> void:
	_health_bar_layer = CanvasLayer.new()
	_health_bar_layer.name = "BossHealthBar"
	get_parent().add_child(_health_bar_layer)

	var font: Font = load("res://Baby Doll.otf")
	var screen := get_viewport().get_visible_rect().size

	var panel := Panel.new()
	panel.size = Vector2(420, 44)
	panel.position = Vector2(screen.x / 2.0 - 210, -50)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.95, 0.75, 0.1, 1)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	_health_bar_layer.add_child(panel)

	_health_bar_name = Label.new()
	_health_bar_name.text = "THE QUEEN BEE"
	_health_bar_name.size = Vector2(420, 20)
	_health_bar_name.position = Vector2(screen.x / 2.0 - 210, -72)
	_health_bar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_bar_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_bar_name.add_theme_font_override("font", font)
	_health_bar_name.add_theme_font_size_override("font_size", 14)
	_health_bar_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1))
	_health_bar_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_health_bar_name.add_theme_constant_override("outline_size", 2)
	_health_bar_layer.add_child(_health_bar_name)

	_health_bar_bg = ColorRect.new()
	_health_bar_bg.size = Vector2(400, 18)
	_health_bar_bg.position = Vector2(10, 12)
	_health_bar_bg.color = Color(0.12, 0.12, 0.15, 0.9)
	_health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_health_bar_bg)

	_health_bar_fill = ColorRect.new()
	_health_bar_fill.size = Vector2(400, 18)
	_health_bar_fill.position = Vector2(10, 12)
	_health_bar_fill.color = Color(0.95, 0.75, 0.1, 1)
	_health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_health_bar_fill)

	_health_bar_label = Label.new()
	_health_bar_label.size = Vector2(400, 18)
	_health_bar_label.position = Vector2(10, 12)
	_health_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_bar_label.add_theme_font_override("font", font)
	_health_bar_label.add_theme_font_size_override("font_size", 11)
	_health_bar_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_health_bar_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_health_bar_label.add_theme_constant_override("outline_size", 1)
	panel.add_child(_health_bar_label)

	_displayed_health = health
	_update_health_bar_instant()

	var slide_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	slide_tween.tween_property(panel, "position:y", 10.0, 0.5)
	slide_tween.parallel().tween_property(_health_bar_name, "position:y", -26.0, 0.5)

func _update_health_bar_instant() -> void:
	var ratio := _displayed_health / MAX_HEALTH
	_health_bar_fill.size.x = 400.0 * ratio
	_health_bar_fill.color = _health_color(ratio)
	_health_bar_label.text = "%d / %d" % [int(_displayed_health), int(MAX_HEALTH)]

func _health_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.9, 0.7, 0.15, 1).lerp(Color(0.95, 0.85, 0.3, 1), (1.0 - ratio) * 2.0)
	elif ratio > 0.25:
		return Color(0.95, 0.85, 0.3, 1).lerp(Color(0.9, 0.3, 0.2, 1), (0.5 - ratio) * 4.0)
	else:
		return Color(0.9, 0.3, 0.2, 1)

func _animate_health_bar() -> void:
	if _health_bar_tween and _health_bar_tween.is_valid():
		_health_bar_tween.kill()
	_health_bar_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	var target_ratio := health / MAX_HEALTH
	var start_width := _health_bar_fill.size.x
	var target_width := 400.0 * target_ratio
	_health_bar_tween.tween_method(
		func(w: float):
			_health_bar_fill.size.x = w
			var r := w / 400.0
			_health_bar_fill.color = _health_color(r)
			_health_bar_label.text = "%d / %d" % [int(r * MAX_HEALTH), int(MAX_HEALTH)],
		start_width, target_width, 0.3
	)

func _destroy_health_bar() -> void:
	if _health_bar_tween and _health_bar_tween.is_valid():
		_health_bar_tween.kill()
	if not _health_bar_layer:
		return
	var panel := _health_bar_layer.get_child(0) as Control
	var death_tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	death_tween.tween_property(_health_bar_fill, "size:x", 0.0, 0.8)
	death_tween.parallel().tween_method(
		func(a: float): panel.modulate.a = a; _health_bar_name.modulate.a = a; _health_bar_label.modulate.a = a,
		1.0, 0.0, 0.8
	)
	death_tween.tween_callback(func():
		_health_bar_layer.queue_free()
		_health_bar_layer = null
	)

func _create_offscreen_indicator() -> void:
	_indicator_layer = CanvasLayer.new()
	_indicator_layer.name = "BossOffscreenIndicator"
	_indicator_layer.layer = 95
	get_parent().add_child(_indicator_layer)

	_indicator_arrow = Polygon2D.new()
	_indicator_arrow.polygon = PackedVector2Array([
		Vector2(0, -24),
		Vector2(18, 16),
		Vector2(0, 6),
		Vector2(-18, 16),
	])
	_indicator_arrow.color = Color(0.95, 0.75, 0.1, 0.95)
	_indicator_arrow.visible = false
	_indicator_layer.add_child(_indicator_arrow)

	var pulse_tween := create_tween().set_loops()
	pulse_tween.tween_property(_indicator_arrow, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(_indicator_arrow, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_offscreen_indicator() -> void:
	if not _indicator_arrow:
		return
	var camera := get_viewport().get_camera_2d()
	if not camera:
		_indicator_arrow.visible = false
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var screen_pos: Vector2 = (anim.global_position - camera.global_position) * camera.zoom + viewport_size / 2.0
	var margin := INDICATOR_SCREEN_MARGIN

	if screen_pos.x >= margin and screen_pos.x <= viewport_size.x - margin and screen_pos.y >= margin and screen_pos.y <= viewport_size.y - margin:
		_indicator_arrow.visible = false
		return

	_indicator_arrow.visible = true

	var center := viewport_size / 2.0
	var dir := screen_pos - center
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	dir = dir.normalized()

	var half := center - Vector2(margin, margin)
	var scale_x: float = half.x / abs(dir.x) if dir.x != 0.0 else INF
	var scale_y: float = half.y / abs(dir.y) if dir.y != 0.0 else INF
	var clamp_scale: float = min(scale_x, scale_y)

	_indicator_arrow.position = center + dir * clamp_scale
	_indicator_arrow.rotation = dir.angle() + PI / 2.0

func _destroy_offscreen_indicator() -> void:
	if _indicator_layer and is_instance_valid(_indicator_layer):
		_indicator_layer.queue_free()
	_indicator_layer = null
	_indicator_arrow = null

func _process(delta: float) -> void:
	if _cutscene_stage < 0:
		return

	_cutscene_time += delta

	match _cutscene_stage:
		0:
			var t := minf(_cutscene_time / PAN_DURATION, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			_cutscene_cam.global_position = _cutscene_start_pos.lerp(_cutscene_target_pos, t)
			if t >= 1.0:
				_cutscene_stage = 1
				_cutscene_time = 0.0
				_start_intro_dialogue()
		1:
			if _dialogue_finished:
				_cutscene_stage = 2
				_cutscene_time = 0.0
				_cutscene_start_pos = _cutscene_cam.global_position
				_cutscene_target_pos = _cutscene_start_cam_pos
		2:
			var t2 := minf(_cutscene_time / PAN_DURATION, 1.0)
			t2 = t2 * t2 * (3.0 - 2.0 * t2)
			_cutscene_cam.global_position = _cutscene_start_pos.lerp(_cutscene_target_pos, t2)
			if t2 >= 1.0:
				_end_cutscene()

func _physics_process(delta: float) -> void:
	if not _boss_active:
		return

	_spit_cooldown -= delta
	if _spit_cooldown <= 0.0:
		_spit()
		_spit_cooldown = SPIT_INTERVAL

	_hornet_timer -= delta
	if _hornet_timer <= 0.0:
		_spawn_hornets()
		_hornet_timer = HORNET_SPAWN_INTERVAL

	_sting_cooldown -= delta
	match _state:
		State.HOVER:
			_do_hover(delta)
		State.TELEGRAPH:
			_do_telegraph(delta)
		State.STING:
			_do_sting(delta)
		State.RECOVER:
			_do_recover(delta)

	_break_timer -= delta
	if _break_timer <= 0.0:
		_break_timer = RAM_BREAK_INTERVAL if _state == State.STING else TILE_BREAK_INTERVAL
		_break_tiles_in_path(_state == State.STING)

	_update_visual_direction()
	move_and_slide()
	_update_offscreen_indicator()

func _do_hover(delta: float) -> void:
	if _state != State.HOVER:
		return
	_bob_phase += delta * BOB_FREQ
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole:
		var to_x: float = mole.global_position.x - global_position.x
		if absf(to_x) > 220.0:
			_drift_dir = signf(to_x)
		var dest_y := mole.global_position.y - 140.0
		var chase_y := clampf(dest_y - global_position.y, -170.0, 170.0)
		velocity.y = move_toward(velocity.y, chase_y + sin(_bob_phase) * BOB_AMPLITUDE, HOVER_SPEED * 1.8 * delta)
	else:
		velocity.y = sin(_bob_phase) * BOB_AMPLITUDE
	velocity.x = move_toward(velocity.x, _drift_dir * HOVER_SPEED, HOVER_SPEED * 1.5 * delta)

	if mole and _sting_cooldown <= 0.0 and global_position.distance_to(mole.global_position) < STING_RANGE:
		_enter_telegraph()

func _enter_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_timer = STING_TELEGRAPH
	anim.play("sting")
	SFX.play("swing", global_position, -6.0, 0.3)

func _do_telegraph(delta: float) -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole:
		_sting_dir = (mole.global_position - global_position).normalized()
	anim.offset.x = sin(_state_timer * 70.0) * 5.0
	_state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, HOVER_SPEED * 2.0 * delta)
	velocity.y = move_toward(velocity.y, 0.0, HOVER_SPEED * 2.0 * delta)
	if _state_timer <= 0.0:
		anim.offset.x = 0.0
		_enter_sting()

func _enter_sting() -> void:
	_state = State.STING
	_state_timer = 1.5
	velocity = _sting_dir * STING_SPEED
	SFX.play("swing", global_position, -2.0, 0.2)

func _do_sting(delta: float) -> void:
	_state_timer -= delta
	if is_on_wall() or is_on_floor() or is_on_ceiling() or _state_timer <= 0.0:
		_enter_recover()

func _enter_recover() -> void:
	_state = State.RECOVER
	_state_timer = STING_RECOVER
	velocity *= 0.15
	anim.play("fly")

func _do_recover(delta: float) -> void:
	_state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, HOVER_SPEED * delta)
	if is_on_floor():
		velocity.y = -400.0
	else:
		velocity.y = move_toward(velocity.y, 120.0, 900.0 * delta)
	if _state_timer <= 0.0:
		_state = State.HOVER
		_sting_cooldown = STING_COOLDOWN

func _update_visual_direction() -> void:
	if _state == State.TELEGRAPH:
		anim.flip_h = _sting_dir.x < 0.0
	elif absf(velocity.x) > 10.0:
		anim.flip_h = velocity.x < 0.0

func _break_tiles_in_path(ram: bool) -> void:
	if not _tilemap or health <= 0:
		return
	var center := global_position
	var half := Vector2(80, 80)
	if ram:
		center = global_position + _sting_dir * 120.0
		half = Vector2(150, 150)
	elif absf(velocity.x) > 20.0:
		center = global_position + Vector2(signf(velocity.x) * 80.0, 0.0)
	var tl := _tilemap.local_to_map(_tilemap.to_local(center - half))
	var br := _tilemap.local_to_map(_tilemap.to_local(center + half))
	for y in range(tl.y, br.y + 1):
		for x in range(tl.x, br.x + 1):
			var tp := Vector2i(x, y)
			if _tilemap.get_cell_source_id(0, tp) != -1:
				_tile_break_script.break_tile(_tilemap, tp, get_parent())

func _spit() -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if not mole or not is_instance_valid(mole):
		return
	var dir: Vector2 = (mole.global_position - anim.global_position).normalized()
	var spawn_pos: Vector2 = anim.global_position + dir * 120.0
	var proj := _projectile_scene.instantiate() as Area2D
	get_parent().add_child(proj)
	proj.global_position = spawn_pos
	proj.scale = Vector2(0.25, 0.25)
	proj.rotation = dir.angle()
	proj.setup(dir * PROJECTILE_SPEED)

func _spawn_hornets() -> void:
	if not _boss_active or health <= 0:
		return
	var alive := get_tree().get_nodes_in_group("queen_hornets")
	if alive.size() >= MAX_HORNETS:
		return
	var hornet := _hornet_scene.instantiate()
	hornet.add_to_group("queen_hornets")
	hornet.global_position = anim.global_position + Vector2(randf_range(-260.0, 260.0), -240.0)
	hornet.detect_range = 1800.0
	get_parent().add_child(hornet)
	SFX.play("swing", global_position, -14.0, 0.1, 0.9)

func _on_trigger_entered(body: Node) -> void:
	if _boss_active or _cutscene_playing:
		return
	if not body.is_in_group("mole"):
		return
	_cutscene_playing = true
	_start_cutscene(body)

func _start_cutscene(mole: Node) -> void:
	_cutscene_mole = mole

	var current_cam := get_viewport().get_camera_2d() as Camera2D
	_cutscene_start_cam_pos = current_cam.global_position
	current_cam.enabled = false

	mole.process_mode = PROCESS_MODE_DISABLED
	get_tree().paused = true

	process_mode = PROCESS_MODE_ALWAYS
	trigger.process_mode = PROCESS_MODE_ALWAYS

	_cutscene_cam = Camera2D.new()
	_cutscene_cam.name = "CutsceneCam"
	_cutscene_cam.process_mode = PROCESS_MODE_ALWAYS
	_cutscene_cam.global_position = _cutscene_start_cam_pos
	_cutscene_cam.zoom = Vector2(2.0, 2.0)
	add_child(_cutscene_cam)
	_cutscene_cam.make_current()

	_cutscene_start_pos = (mole as Node2D).global_position
	_cutscene_target_pos = anim.global_position
	_cutscene_stage = 0
	_cutscene_time = 0.0

func _start_intro_dialogue() -> void:
	_dialogue_finished = false
	_dialogue_line_index = 0
	_dialogue_box = preload("res://scenes/dialogue_box.tscn").instantiate()
	_dialogue_box.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_dialogue_box)
	_dialogue_box.next_pressed.connect(_on_intro_dialogue_next)
	_show_intro_dialogue_line()

func _show_intro_dialogue_line() -> void:
	var is_last := _dialogue_line_index == INTRO_LINES.size() - 1
	_dialogue_box.show_text(INTRO_LINES[_dialogue_line_index], 0, 0, true, false)
	if is_last:
		_dialogue_box.next_button.text = "START FIGHT!"
		_style_next_button_red()

func _on_intro_dialogue_next() -> void:
	if _dialogue_line_index >= INTRO_LINES.size() - 1:
		_dialogue_box.next_pressed.disconnect(_on_intro_dialogue_next)
		var box := _dialogue_box
		_dialogue_box = null
		box.hide_box()
		get_tree().create_timer(0.35).timeout.connect(func():
			if is_instance_valid(box):
				box.queue_free()
		)
		_dialogue_finished = true
		return
	_dialogue_line_index += 1
	_show_intro_dialogue_line()

func _style_next_button_red() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.8, 0.15, 0.15, 1)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.03, 0.03, 0.03, 1)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_right = 6
	normal.corner_radius_bottom_left = 6

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.95, 0.25, 0.2, 1)
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = Color(0.03, 0.03, 0.03, 1)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_right = 6
	hover.corner_radius_bottom_left = 6

	_dialogue_box.next_button.add_theme_stylebox_override("normal", normal)
	_dialogue_box.next_button.add_theme_stylebox_override("hover", hover)
	_dialogue_box.next_button.add_theme_stylebox_override("pressed", hover)
	_dialogue_box.next_button.add_theme_stylebox_override("focus", normal)

func _end_cutscene() -> void:
	_cutscene_stage = -1
	_cutscene_cam.queue_free()
	_cutscene_cam = null

	var mole_cam := _cutscene_mole.get_node("Camera2D") as Camera2D
	mole_cam.enabled = true
	mole_cam.zoom = Vector2(0.65, 0.65)
	mole_cam.position.y = -500

	process_mode = PROCESS_MODE_INHERIT
	trigger.process_mode = PROCESS_MODE_INHERIT

	_boss_active = true
	_cutscene_playing = false
	_sting_cooldown = 1.5
	_hornet_timer = 4.0
	anim.play("fly")

	if _ancestor_wall:
		var shape := _ancestor_wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape:
			shape.set_deferred("disabled", false)

	_cutscene_mole.process_mode = PROCESS_MODE_INHERIT
	get_tree().paused = false

	_cutscene_mole = null

	_create_health_bar()
	_create_offscreen_indicator()

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("mole") and not _mole_in_contact:
		_mole_in_contact = true
		body.take_damage(1, global_position, true)

func _on_hitbox_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_in_contact = false

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not _boss_active:
		return
	var parent = area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		take_damage(parent.get_damage())

func take_damage(amount: float) -> void:
	if health <= 0:
		return
	health -= amount
	EnemyDamage.spawn_damage_number(self, amount)
	modulate = Color(2, 1.5, 1.2, 1)
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	_animate_health_bar()
	var mole := get_tree().get_first_node_in_group("mole")
	if mole and mole.has_method("screen_shake"):
		mole.screen_shake(12.0, 0.2)
	if health <= 0:
		die()

func die() -> void:
	ComboManager.increment()
	Shop.drop_coins(global_position, 40, 6)
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	_kill_all_hornets()
	_destroy_health_bar()
	_destroy_offscreen_indicator()
	_start_death_cutscene()

	modulate = Color(3.0, 2.4, 1.6, 1.0)

	var center := Vector2(100.0, 110.0)
	var half_w := 58.0
	var half_h := 68.0

	for i in 15:
		var delay: float = (i / 14.0) * 1.5 + randf_range(0.0, 0.15)
		var offset := Vector2(randf_range(-half_w, half_w), randf_range(-half_h, half_h))
		get_tree().create_timer(delay).timeout.connect(_small_explosion.bind(center + offset))

	var big_tw := create_tween()
	big_tw.tween_interval(1.5)
	big_tw.tween_callback(_big_explosion.bind(center))
	big_tw.tween_interval(0.2)
	big_tw.tween_callback(_break_apart)
	big_tw.tween_callback(_play_death_effect)

	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.5)
	tw.tween_property(self, "modulate:a", 0.0, 2.5)
	tw.tween_interval(0.4)
	tw.tween_callback(_finish_death_cutscene)

func _kill_all_hornets() -> void:
	for node in get_tree().get_nodes_in_group("queen_hornets"):
		if is_instance_valid(node):
			node.queue_free()

func _small_explosion(local_pos: Vector2) -> void:
	if not is_instance_valid(self):
		return
	_spawn_explosion(to_global(local_pos), randf_range(0.4, 0.7))
	if randf() < 0.6:
		SFX.play("explosion", to_global(local_pos), -13.0, 0.3)

func _big_explosion(local_pos: Vector2) -> void:
	_spawn_explosion(to_global(local_pos), 3.0)
	_spawn_explosion(to_global(local_pos) + Vector2(randf_range(-260, 260), randf_range(-260, 260)), 1.4)
	SFX.play("explosion", to_global(local_pos), -1.0, 0.05)
	_shake_cutscene_cam(24.0)

func _shake_cutscene_cam(strength: float) -> void:
	if not _cutscene_cam or not is_instance_valid(_cutscene_cam):
		return
	var tween := create_tween()
	for i in 8:
		tween.tween_property(_cutscene_cam, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04)
	tween.tween_property(_cutscene_cam, "offset", Vector2.ZERO, 0.06)

func _spawn_explosion(world_pos: Vector2, power: float) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = int(28 * power)
	particles.lifetime = 0.65
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 130.0 * power
	particles.initial_velocity_max = 430.0 * power
	particles.gravity = Vector2(0, 420)
	particles.scale_amount_min = 5.0 * power
	particles.scale_amount_max = 10.0 * power
	particles.color = Color(1.0, 0.75, 0.1, 1.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.92, 0.5, 1.0))
	gradient.set_color(1, Color(0.5, 0.25, 0.02, 0.0))
	particles.color_ramp = gradient
	add_child(particles)
	particles.global_position = world_pos
	get_tree().create_timer(particles.lifetime + 0.4).timeout.connect(particles.queue_free)

func _start_death_cutscene() -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	_cutscene_mole = mole

	var current_cam := get_viewport().get_camera_2d() as Camera2D
	if current_cam:
		current_cam.enabled = false

	if mole:
		mole.process_mode = PROCESS_MODE_DISABLED

	get_tree().paused = true
	process_mode = PROCESS_MODE_ALWAYS
	set_physics_process(false)

	_cutscene_cam = Camera2D.new()
	_cutscene_cam.name = "CutsceneCam"
	_cutscene_cam.process_mode = PROCESS_MODE_ALWAYS
	_cutscene_cam.zoom = Vector2(0.8, 0.8)
	add_child(_cutscene_cam)
	_cutscene_cam.global_position = anim.global_position
	_cutscene_cam.make_current()

	var zoom_tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zoom_tw.tween_property(_cutscene_cam, "zoom", Vector2(0.45, 0.45), 2.8)

func _finish_death_cutscene() -> void:
	if _cutscene_cam and is_instance_valid(_cutscene_cam):
		_cutscene_cam.queue_free()
	_cutscene_cam = null

	if _cutscene_mole and is_instance_valid(_cutscene_mole):
		var mole_cam := _cutscene_mole.get_node("Camera2D") as Camera2D
		if mole_cam:
			mole_cam.enabled = true
			mole_cam.zoom = Vector2(0.65, 0.65)
			mole_cam.position.y = -500
		_cutscene_mole.process_mode = PROCESS_MODE_INHERIT
	_cutscene_mole = null

	get_tree().paused = false
	process_mode = PROCESS_MODE_INHERIT
	_go_to_next_level()
	queue_free()

func _go_to_next_level() -> void:
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/level_09.tscn")

func _break_apart() -> void:
	anim.visible = false

	var frame_tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	var atlas := frame_tex as AtlasTexture
	var source_tex := atlas.atlas if atlas else frame_tex
	var source_region := atlas.region if atlas else Rect2(Vector2.ZERO, frame_tex.get_size())

	var w := source_region.size.x
	var h := source_region.size.y
	var ox := source_region.position.x
	var oy := source_region.position.y

	var cols := 4
	var rows := 2
	var pw := w / cols
	var ph := h / rows
	var center_offset := Vector2(w * 0.5, h * 0.5)

	for col in cols:
		for row in rows:
			var local_center := Vector2(col * pw + pw * 0.5, row * ph + ph * 0.5) - center_offset
			var sub_rect := Rect2(ox + col * pw, oy + row * ph, pw, ph)

			var piece := Sprite2D.new()
			piece.texture = source_tex
			piece.region_enabled = true
			piece.region_rect = sub_rect
			piece.scale = anim.scale * 0.5
			piece.position = anim.position + local_center
			add_child(piece)

			var angle := randf_range(0.0, TAU)
			var speed := randf_range(250.0, 500.0)
			var vel := Vector2.RIGHT.rotated(angle) * speed

			var pt := create_tween()
			pt.tween_property(piece, "position", piece.position + vel, 1.0).set_ease(Tween.EASE_OUT)
			pt.parallel().tween_property(piece, "rotation", randf_range(-4.0, 4.0), 1.0).set_ease(Tween.EASE_OUT)
			pt.parallel().tween_property(piece, "modulate", Color(1, 1, 1, 0), 0.9).set_ease(Tween.EASE_IN)
			pt.tween_callback(piece.queue_free)

func _play_death_effect() -> void:
	var sprite := anim
	var death_particles := CPUParticles2D.new()
	death_particles.emitting = true
	death_particles.one_shot = true
	death_particles.amount = 60
	death_particles.lifetime = 1.4
	death_particles.explosiveness = 1.0
	death_particles.direction = Vector2.ZERO
	death_particles.spread = 180.0
	death_particles.initial_velocity_min = 100.0
	death_particles.initial_velocity_max = 400.0
	death_particles.gravity = Vector2(0, 200)
	death_particles.scale_amount_min = 2.0
	death_particles.scale_amount_max = 5.0
	death_particles.color = Color(0.95, 0.75, 0.1, 1)
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.85, 0.3, 1))
	fade.set_color(1, Color(0.6, 0.35, 0.05, 0))
	death_particles.color_ramp = fade
	add_child(death_particles)
	death_particles.global_position = sprite.global_position
	get_tree().create_timer(2.0).timeout.connect(death_particles.queue_free)