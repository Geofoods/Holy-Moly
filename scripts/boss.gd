extends CharacterBody2D

const MAX_HEALTH := 40.0
const PAN_DURATION := 0.75
const HOLD_DURATION := 0.75
const DESCENT_SPEED := 20.0
const SPIT_INTERVAL := 3.0
const PROJECTILE_SPEED := 800.0
const CHEST_SPAWN_INTERVAL := 10.0

var health := MAX_HEALTH
var _boss_active := false
var _cutscene_playing := false
var _spit_cooldown := 0.0

var _cutscene_mole: Node = null
var _cutscene_cam: Camera2D = null
var _cutscene_stage := -1
var _cutscene_time := 0.0
var _cutscene_start_pos := Vector2.ZERO
var _cutscene_target_pos := Vector2.ZERO
var _cutscene_start_cam_pos := Vector2.ZERO

var _tilemap: TileMap = null
var _tile_break_script: GDScript = null
var _last_break_tile_y := -999999

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var trigger: Area2D = $CutsceneTrigger
@onready var hurtbox: Area2D = $Hurtbox

var _projectile_scene: PackedScene = null
var _chest_scene: PackedScene = null
var _chest_spawn_timer: float = 10.0

var _health_bar_layer: CanvasLayer = null
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null
var _health_bar_label: Label = null
var _health_bar_name: Label = null
var _health_bar_tween: Tween = null
var _displayed_health: float = 0.0

func _ready() -> void:
	anim.stop()
	anim.frame = 0
	trigger.body_entered.connect(_on_trigger_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.add_to_group("enemy_hurtbox")
	_tilemap = get_parent().get_node_or_null("TileMap") as TileMap
	_tile_break_script = load("res://scripts/tile_break_sfx.gd")
	_projectile_scene = preload("res://area_2d.tscn")
	_chest_scene = preload("res://chest.tscn")

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
	panel_style.border_color = Color(0.6, 0.3, 0.8, 1)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	_health_bar_layer.add_child(panel)

	_health_bar_name = Label.new()
	_health_bar_name.text = "THE CORRUPTED ONE"
	_health_bar_name.size = Vector2(420, 20)
	_health_bar_name.position = Vector2(screen.x / 2.0 - 210, -72)
	_health_bar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_bar_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_bar_name.add_theme_font_override("font", font)
	_health_bar_name.add_theme_font_size_override("font_size", 14)
	_health_bar_name.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0, 1))
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
	_health_bar_fill.color = Color(0.2, 0.8, 0.3, 1)
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
	_health_bar_label.text = "%d / %d" % [int(_displayed_health), MAX_HEALTH]

func _health_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.2, 0.8, 0.3, 1).lerp(Color(0.9, 0.8, 0.2, 1), (1.0 - ratio) * 2.0)
	elif ratio > 0.25:
		return Color(0.9, 0.8, 0.2, 1).lerp(Color(0.9, 0.3, 0.2, 1), (0.5 - ratio) * 4.0)
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
			_health_bar_label.text = "%d / %d" % [int(r * MAX_HEALTH), MAX_HEALTH],
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
		1:
			if _cutscene_time >= HOLD_DURATION:
				_cutscene_stage = 2
				_cutscene_time = 0.0
				_cutscene_start_pos = _cutscene_cam.global_position
				_cutscene_target_pos = _cutscene_start_cam_pos
		2:
			var t := minf(_cutscene_time / PAN_DURATION, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			_cutscene_cam.global_position = _cutscene_start_pos.lerp(_cutscene_target_pos, t)
			if t >= 1.0:
				_end_cutscene()

func _physics_process(delta: float) -> void:
	if not _boss_active:
		return

	_spit_cooldown -= delta
	if _spit_cooldown <= 0.0:
		_spit()
		_spit_cooldown = SPIT_INTERVAL

	_chest_spawn_timer -= delta
	if _chest_spawn_timer <= 0.0:
		_spawn_chest()
		_chest_spawn_timer = CHEST_SPAWN_INTERVAL

	_break_tiles_in_path()
	global_position.y += DESCENT_SPEED * delta

func _spit() -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if not mole or not is_instance_valid(mole):
		return

	var dir: Vector2 = (mole.global_position - anim.global_position).normalized()
	var spawn_pos: Vector2 = anim.global_position + dir * 200.0

	var count := 1 if randf() < 0.5 else 3
	var spread := deg_to_rad(45.0)
	var offsets: Array[float] = []
	if count == 1:
		offsets = [0.0]
	else:
		offsets = [-spread, 0.0, spread]

	for offset in offsets:
		var rot := atan2(dir.y, dir.x) + offset
		var spread_dir := Vector2(cos(rot), sin(rot))
		var proj := _projectile_scene.instantiate() as Area2D
		get_parent().add_child(proj)
		proj.global_position = spawn_pos
		proj.scale = Vector2(0.3, 0.3)
		proj.rotation = rot
		proj.setup(spread_dir * PROJECTILE_SPEED)

func _break_tiles_in_path() -> void:
	if not _tilemap:
		return

	var shape_node := $CollisionShape2D as CollisionShape2D
	var center := shape_node.global_position
	var tile_center := _tilemap.local_to_map(_tilemap.to_local(center))
	if tile_center.y <= _last_break_tile_y:
		return
	_last_break_tile_y = tile_center.y

	var shape := shape_node.shape as RectangleShape2D
	var half := shape.size / 2.0

	var top_left := _tilemap.local_to_map(_tilemap.to_local(Vector2(center.x - half.x, center.y - half.y)))
	var bottom_right := _tilemap.local_to_map(_tilemap.to_local(Vector2(center.x + half.x, center.y + half.y)))

	for x in range(top_left.x, bottom_right.x + 1):
		for y in range(top_left.y, bottom_right.y + 1):
			var tp := Vector2i(x, y)
			_tile_break_script.break_tile(_tilemap, tp, get_parent(), true)

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

	_cutscene_start_pos = _cutscene_cam.global_position
	_cutscene_target_pos = $AnimatedSprite2D.global_position
	_cutscene_stage = 0
	_cutscene_time = 0.0

func _end_cutscene() -> void:
	_cutscene_stage = -1
	_cutscene_cam.queue_free()
	_cutscene_cam = null

	var mole_cam := _cutscene_mole.get_node("Camera2D") as Camera2D
	mole_cam.enabled = true
	mole_cam.zoom = Vector2(0.5, 0.5)
	mole_cam.position.y = -500

	process_mode = PROCESS_MODE_INHERIT
	trigger.process_mode = PROCESS_MODE_INHERIT

	_last_break_tile_y = -999999
	_boss_active = true
	_cutscene_playing = false
	_spit_cooldown = 1.0
	_chest_spawn_timer = CHEST_SPAWN_INTERVAL
	anim.play("default")

	_cutscene_mole.process_mode = PROCESS_MODE_INHERIT
	get_tree().paused = false

	_cutscene_mole = null

	_create_health_bar()

func _spawn_chest() -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if not mole or not is_instance_valid(mole):
		return
	var chest := _chest_scene.instantiate()
	chest.global_position = mole.global_position + Vector2(0, -500)
	get_parent().add_child(chest)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not _boss_active:
		return
	var parent := area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		take_damage(1)

func take_damage(amount: float) -> void:
	health -= amount
	modulate = Color(2, 1.5, 1.5, 1)
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	_animate_health_bar()
	var mole := get_tree().get_first_node_in_group("mole")
	if mole and mole.has_method("screen_shake"):
		mole.screen_shake(14.0, 0.25)
	if health <= 0:
		die()

func die() -> void:
	ComboManager.increment()
	ScoreManager.add_kill(20, global_position)
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
	_destroy_health_bar()
	_play_death_effect()
	get_tree().create_timer(1.0).timeout.connect(_go_to_win_screen)

func _go_to_win_screen() -> void:
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/win_screen.tscn")

func _play_death_effect() -> void:
	var sprite := $AnimatedSprite2D
	var death_particles := CPUParticles2D.new()
	death_particles.emitting = true
	death_particles.one_shot = true
	death_particles.amount = 60
	death_particles.lifetime = 1.0
	death_particles.explosiveness = 1.0
	death_particles.direction = Vector2.ZERO
	death_particles.spread = 180.0
	death_particles.initial_velocity_min = 100.0
	death_particles.initial_velocity_max = 400.0
	death_particles.gravity = Vector2(0, 200)
	death_particles.scale_amount_min = 2.0
	death_particles.scale_amount_max = 5.0
	death_particles.color = Color(0.6, 0.2, 0.9, 1)
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.3, 1.0, 1))
	fade.set_color(1, Color(0.4, 0.1, 0.6, 0))
	death_particles.color_ramp = fade
	add_child(death_particles)
	death_particles.global_position = sprite.global_position
	get_tree().create_timer(1.5).timeout.connect(death_particles.queue_free)
