extends CharacterBody2D

const MAX_HEALTH := 1250.0
const BOSS_HEALTH_BAR_WIDTH := 592.0
const BOSS_HEALTH_BAR_HEIGHT := 48.0
const BOSS_HEALTH_BAR_INSET := 14.0
const BOSS_HEALTH_FILL_INSET := 3.0
const BOSS_HEALTH_BAR_INNER := BOSS_HEALTH_BAR_WIDTH - BOSS_HEALTH_FILL_INSET * 2.0
const BOSS_HEALTH_PANEL_WIDTH := BOSS_HEALTH_BAR_WIDTH + BOSS_HEALTH_BAR_INSET * 2.0
const BOSS_HEALTH_PANEL_HEIGHT := BOSS_HEALTH_BAR_HEIGHT + BOSS_HEALTH_BAR_INSET * 2.0
const BOSS_HEALTH_NAME_HEIGHT := 46.0
const BOSS_HEALTH_NAME_GAP := 12.0
const BOSS_HEALTH_ROOT_WIDTH := BOSS_HEALTH_PANEL_WIDTH
const BOSS_HEALTH_ROOT_HEIGHT := BOSS_HEALTH_NAME_HEIGHT + BOSS_HEALTH_NAME_GAP + BOSS_HEALTH_PANEL_HEIGHT
const BOSS_HEALTH_FONT := preload("res://Baby Doll.otf")
const BOSS_HEALTH_FILL_TWEEN_TIME := 0.12
const BOSS_HEALTH_TRAIL_DELAY := 0.35
const BOSS_HEALTH_TRAIL_TWEEN_TIME := 0.45
const BOSS_HEALTH_TRAIL_COLOR := Color(0.96, 0.82, 0.42, 0.9)
const PAN_DURATION := 0.75
const DESCENT_SPEED := 20.0
const SPIT_INTERVAL := 3.0
const PROJECTILE_SPEED := 800.0
## Beam period is this cooldown plus LASER_CHARGE_TIME + LASER_STRIKE_DURATION,
## so 5.5-8.5s here means a beam roughly every 8.5-11.5s of fighting.
const LASER_COOLDOWN_MIN := 5.5
const LASER_COOLDOWN_MAX := 8.5
const LASER_CHARGE_TIME := 1.6
const LASER_STRIKE_DURATION := 1.25
const LASER_FADE_TIME := 0.55
const LASER_LENGTH := 3000.0
const LASER_GROUND_TRACE_STEP := 16.0
const LASER_WIDTH := 156.0
const LASER_COLLISION_MARGIN := 28.0
const LASER_DAMAGE := 2.0
const LASER_TILE_SAMPLE_SPACING := 38.0
const LASER_TILE_HALF_WIDTH := LASER_WIDTH * 0.5
const LASER_IMPACT_OVERSHOOT := 24.0
## The heart keeps the arena stocked: a loose Drill or Holy Water drops in above
## the mole. It used to rain chests down instead, which asked the player to stop
## and open one in the middle of a dodge.
const LOOT_SPAWN_INTERVAL := 10.0
const LOOT_DROP_OFFSET := Vector2(0, -500)
const LootDrop := preload("res://scripts/loot_drop.gd")
const BOUNCE_FORCE := 700.0

## Boss death finale: the floor gives way under the mole and the destruction
## keeps pace with it on the way down to the bottom of the level.
const COLLAPSE_STEP_TIME := 0.06
const COLLAPSE_HALF_WIDTH_TILES := 3
const COLLAPSE_RIDE_OFFSET := 40.0
const COLLAPSE_CAM_OFFSET := -60.0
const COLLAPSE_LAND_DELAY := 0.8
const COLLAPSE_MOVE_SPEED := 320.0
const COLLAPSE_TELEPORT_BELOW_BOSS := 500.0
const HEART_FIREWORK_HOLD := 2.3

## The heart's debris outlives a normal enemy's gibs by a long way, so the
## shelter it broke into stays on screen for the whole ride down the shaft.
const DEATH_FRAGMENT_LIFE := 10.0

const EnemyDamage := preload("res://scripts/enemy.gd")

const INTRO_LINES := [
	"hello there little mole,",
	"it seems like you've wandered your way into the darkest depths..",
	"this is as far as you get.",
]

var health := MAX_HEALTH
var _boss_active := false
var _cutscene_playing := false
var _spit_cooldown := 0.0
var _laser_cooldown := 0.0
var _laser_attack_active := false
var _laser_hit_tile := Vector2i(-1, -1)

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

var _mole_in_bounce_zone := false

var _collapse_started := false
var _death_finished := false
var _cutscene_shake_tween: Tween = null

var _collapse_player_control := false
var _ride_mole: Node2D = null
var _ride_mole_layer := 0
var _ride_min_x := 0.0
var _ride_max_x := 0.0

var _tilemap: TileMap = null
var _arena_map: TileMap = null
var _tile_break_script: GDScript = null
var _last_break_tile_y := -999999

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var trigger: Area2D = $CutsceneTrigger
@onready var hurtbox: Area2D = $Hurtbox
@onready var bounce_zone: Area2D = $BounceZone

var _projectile_scene: PackedScene = null
var _loot_spawn_timer: float = LOOT_SPAWN_INTERVAL

var _health_bar_layer: CanvasLayer = null
var _health_bar_root: Control = null
var _health_bar_bg: ColorRect = null
var _health_bar_trail: ColorRect = null
var _health_bar_fill: ColorRect = null
var _health_bar_name: Label = null
var _health_bar_tween: Tween = null
var _health_bar_trail_tween: Tween = null

const INDICATOR_SCREEN_MARGIN := 70.0
var _indicator_layer: CanvasLayer = null
var _indicator_arrow: Polygon2D = null

func _ready() -> void:
	anim.stop()
	anim.frame = 0
	trigger.body_entered.connect(_on_trigger_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.add_to_group("enemy_hurtbox")
	bounce_zone.body_entered.connect(_on_bounce_zone_body_entered)
	bounce_zone.body_exited.connect(_on_bounce_zone_body_exited)
	_tilemap = get_parent().get_node_or_null("TileMap") as TileMap
	_arena_map = get_parent().get_node_or_null("TileMap2") as TileMap
	_tile_break_script = load("res://scripts/tile_break_sfx.gd")
	_projectile_scene = preload("res://area_2d.tscn")

func _create_health_bar() -> void:
	_health_bar_layer = CanvasLayer.new()
	_health_bar_layer.name = "BossHealthBar"
	_health_bar_layer.layer = 100
	get_parent().add_child(_health_bar_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -BOSS_HEALTH_ROOT_WIDTH * 0.5
	root.offset_top = -100.0
	root.offset_right = BOSS_HEALTH_ROOT_WIDTH * 0.5
	root.offset_bottom = -100.0 + BOSS_HEALTH_ROOT_HEIGHT
	root.custom_minimum_size = Vector2(BOSS_HEALTH_ROOT_WIDTH, BOSS_HEALTH_ROOT_HEIGHT)
	root.z_index = 100
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar_layer.add_child(root)
	_health_bar_root = root

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.05, 0.9)
	panel_style.border_color = Color(0.42, 0.28, 0.14, 1.0)
	panel_style.set_border_width_all(2)

	var name_panel := Panel.new()
	name_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_panel.offset_left = 0.0
	name_panel.offset_top = 0.0
	name_panel.offset_right = 0.0
	name_panel.offset_bottom = BOSS_HEALTH_NAME_HEIGHT
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(name_panel)

	_health_bar_name = Label.new()
	_health_bar_name.text = "Corrupted Heart"
	_health_bar_name.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_bar_name.offset_left = 0.0
	_health_bar_name.offset_top = 0.0
	_health_bar_name.offset_right = 0.0
	_health_bar_name.offset_bottom = 0.0
	_health_bar_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_bar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_bar_name.clip_text = false
	_health_bar_name.add_theme_font_override("font", BOSS_HEALTH_FONT)
	_health_bar_name.add_theme_font_size_override("font_size", 36)
	_health_bar_name.add_theme_color_override("font_color", Color(0.92, 0.72, 1.0))
	_health_bar_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_child(_health_bar_name)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0.0
	panel.offset_top = BOSS_HEALTH_NAME_HEIGHT + BOSS_HEALTH_NAME_GAP
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.custom_minimum_size = Vector2(BOSS_HEALTH_PANEL_WIDTH, BOSS_HEALTH_PANEL_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	_health_bar_bg = ColorRect.new()
	_health_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_bar_bg.offset_left = BOSS_HEALTH_BAR_INSET
	_health_bar_bg.offset_top = BOSS_HEALTH_BAR_INSET
	_health_bar_bg.offset_right = -BOSS_HEALTH_BAR_INSET
	_health_bar_bg.offset_bottom = -BOSS_HEALTH_BAR_INSET
	_health_bar_bg.color = EnemyDamage.health_bar_background_color()
	_health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_health_bar_bg)

	_health_bar_trail = ColorRect.new()
	_health_bar_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_bar_trail.offset_left = BOSS_HEALTH_FILL_INSET
	_health_bar_trail.offset_top = BOSS_HEALTH_FILL_INSET
	_health_bar_trail.offset_right = -BOSS_HEALTH_FILL_INSET
	_health_bar_trail.offset_bottom = -BOSS_HEALTH_FILL_INSET
	_health_bar_trail.color = BOSS_HEALTH_TRAIL_COLOR
	_health_bar_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar_bg.add_child(_health_bar_trail)

	_health_bar_fill = ColorRect.new()
	_health_bar_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_bar_fill.offset_left = BOSS_HEALTH_FILL_INSET
	_health_bar_fill.offset_top = BOSS_HEALTH_FILL_INSET
	_health_bar_fill.offset_right = -BOSS_HEALTH_FILL_INSET
	_health_bar_fill.offset_bottom = -BOSS_HEALTH_FILL_INSET
	_health_bar_fill.color = EnemyDamage.health_bar_color(1.0)
	_health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar_bg.add_child(_health_bar_fill)

	_update_health_bar_instant()

	var slide_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	slide_tween.tween_property(root, "position:y", 18.0, 0.5)

func _health_bar_right(ratio: float) -> float:
	return -(BOSS_HEALTH_FILL_INSET + BOSS_HEALTH_BAR_INNER * (1.0 - clampf(ratio, 0.0, 1.0)))

func _set_health_bar_ratio(ratio: float) -> void:
	if _health_bar_fill == null:
		return
	var clamped := clampf(ratio, 0.0, 1.0)
	_health_bar_fill.offset_right = _health_bar_right(clamped)
	_health_bar_fill.color = _health_color(clamped)

func _set_health_bar_fill_right(offset: float) -> void:
	if _health_bar_fill != null and is_instance_valid(_health_bar_fill):
		_health_bar_fill.offset_right = offset

func _set_health_bar_trail_right(offset: float) -> void:
	if _health_bar_trail != null and is_instance_valid(_health_bar_trail):
		_health_bar_trail.offset_right = offset

func _update_health_bar_instant() -> void:
	var ratio := health / MAX_HEALTH
	_set_health_bar_ratio(ratio)
	if _health_bar_trail != null:
		_health_bar_trail.offset_right = _health_bar_right(ratio)

func _health_color(ratio: float) -> Color:
	return EnemyDamage.health_bar_color(ratio)

func _animate_health_bar() -> void:
	if _health_bar_fill == null:
		return
	if _health_bar_tween != null and _health_bar_tween.is_valid():
		_health_bar_tween.kill()
	var target := _health_bar_right(health / MAX_HEALTH)
	_health_bar_fill.color = _health_color(health / MAX_HEALTH)
	_health_bar_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_health_bar_tween.tween_method(
		_set_health_bar_fill_right, _health_bar_fill.offset_right, target,
		BOSS_HEALTH_FILL_TWEEN_TIME)

	if _health_bar_trail != null:
		if _health_bar_trail_tween != null and _health_bar_trail_tween.is_valid():
			_health_bar_trail_tween.kill()
		_health_bar_trail_tween = create_tween()
		_health_bar_trail_tween.tween_interval(BOSS_HEALTH_TRAIL_DELAY)
		_health_bar_trail_tween.tween_method(
			_set_health_bar_trail_right, _health_bar_trail.offset_right, target,
			BOSS_HEALTH_TRAIL_TWEEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _destroy_health_bar() -> void:
	if _health_bar_tween != null and _health_bar_tween.is_valid():
		_health_bar_tween.kill()
	if _health_bar_trail_tween != null and _health_bar_trail_tween.is_valid():
		_health_bar_trail_tween.kill()
	if not _health_bar_layer:
		return
	var panel := _health_bar_root
	if panel == null:
		panel = _health_bar_layer.get_child(0) as Control
	var death_tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	var start_ratio := 0.0
	if _health_bar_fill != null:
		start_ratio = 1.0 - (-_health_bar_fill.offset_right - BOSS_HEALTH_FILL_INSET) / BOSS_HEALTH_BAR_INNER
	death_tween.tween_method(_set_health_bar_ratio, start_ratio, 0.0, 0.8)
	death_tween.parallel().tween_method(
		func(a: float): panel.modulate.a = a,
		1.0, 0.0, 0.8
	)
	death_tween.tween_callback(func(): 
		_health_bar_layer.queue_free()
		_health_bar_layer = null
		_health_bar_root = null
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
	_indicator_arrow.color = Color(0.9, 0.1, 0.1, 0.95)
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
	if _collapse_player_control:
		_update_ride_mole(delta)
		return
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

	if not _laser_attack_active:
		_laser_cooldown -= delta
		if _laser_cooldown <= 0.0:
			_laser_attack_active = true
			_fire_laser_attack()

	_loot_spawn_timer -= delta
	if _loot_spawn_timer <= 0.0:
		_spawn_loot_drop()
		_loot_spawn_timer = LOOT_SPAWN_INTERVAL

	_break_tiles_in_path()
	global_position.y += DESCENT_SPEED * delta
	_update_offscreen_indicator()

func _fire_laser_attack() -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if not is_instance_valid(mole):
		_laser_attack_active = false
		return

	# Lock aim at the start of the warning so the player can dodge the beam.
	var laser_start := anim.global_position
	var laser_direction := (mole.global_position - laser_start).normalized()
	if laser_direction == Vector2.ZERO:
		laser_direction = Vector2.DOWN
	_laser_hit_tile = Vector2i(-1, -1)
	# The beam stops on bedrock, and that stopping point is what the ground
	# firework below marks. Tracing here (instead of letting the beam run its full
	# length) is what puts the impact somewhere the player can actually see.
	var laser_end := _trace_laser_to_bedrock(laser_start, laser_direction, _laser_endpoint(laser_start, laser_direction))
	var telegraph_lines := _create_laser_glow(laser_start, laser_end, true)
	for line in telegraph_lines:
		if not is_instance_valid(line):
			continue
		var pulse := line.create_tween().set_loops(8)
		pulse.tween_property(line, "modulate:a", 0.2, 0.1)
		pulse.tween_property(line, "modulate:a", 1.0, 0.1)
		var base_width := line.width
		var width_pulse := line.create_tween().set_loops(8)
		width_pulse.tween_property(line, "width", base_width * 0.78, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		width_pulse.tween_property(line, "width", base_width * 1.3, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	SFX.play("enemy_fire", laser_start, -2.0, 0.2)
	if mole.has_method("screen_shake"):
		mole.screen_shake(6.0, 0.18)
	await get_tree().create_timer(LASER_CHARGE_TIME).timeout
	if not is_inside_tree() or not _boss_active or health <= 0.0:
		_clear_laser_lines(telegraph_lines)
		_laser_attack_active = false
		return

	_clear_laser_lines(telegraph_lines)
	var beam_lines := _create_laser_glow(laser_start, laser_end, false)
	_animate_laser_beam(beam_lines)
	SFX.play("explosion", laser_start, -2.0, 0.12)
	if is_instance_valid(mole) and mole.has_method("screen_shake"):
		mole.screen_shake(24.0, LASER_STRIKE_DURATION)
	_damage_mole_in_laser(mole, laser_start, laser_end)
	_break_tiles_along_laser(laser_start, laser_end)
	# Unconditional: this used to be gated on the beam finding bedrock, so whether
	# the blast showed up at all came down to the level geometry.
	_spawn_laser_ground_firework(laser_end)
	var laser_time_left := LASER_STRIKE_DURATION
	while laser_time_left > 0.0:
		var damage_interval := minf(0.1, laser_time_left)
		await get_tree().create_timer(damage_interval).timeout
		laser_time_left -= damage_interval
		_damage_mole_in_laser(mole, laser_start, laser_end)
	for line in beam_lines:
		if is_instance_valid(line):
			var fade := line.create_tween()
			fade.tween_property(line, "modulate:a", 0.0, LASER_FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(LASER_FADE_TIME).timeout
	_clear_laser_lines(beam_lines)
	_laser_attack_active = false
	_laser_cooldown = randf_range(LASER_COOLDOWN_MIN, LASER_COOLDOWN_MAX)

func _laser_endpoint(start: Vector2, direction: Vector2) -> Vector2:
	# How far the beam would run if nothing stopped it. It burns through dirt and
	# other collision objects rather than stopping at the first obstruction; only
	# bedrock ends the trip (see _trace_laser_to_bedrock).
	return start + direction * LASER_LENGTH

func _trace_laser_to_bedrock(start: Vector2, direction: Vector2, finish: Vector2) -> Vector2:
	if _tilemap == null:
		return finish
	var distance := start.distance_to(finish)
	var sample_count := maxi(1, int(ceil(distance / LASER_GROUND_TRACE_STEP)))
	for i in range(1, sample_count + 1):
		var progress := minf(float(i) * LASER_GROUND_TRACE_STEP, distance)
		var sample := start + direction * progress
		var cell := _tilemap.local_to_map(_tilemap.to_local(sample))
		if _is_bedrock(cell):
			_laser_hit_tile = cell
			return sample
	return finish

func _create_laser_glow(start: Vector2, finish: Vector2, is_preview: bool) -> Array[Line2D]:
	var lines: Array[Line2D] = []
	if is_preview:
		lines.append(_create_laser_line(start, finish, Color(0.34, 0.02, 0.72, 0.38), 90.0))
		lines.append(_create_laser_line(start, finish, Color(0.72, 0.18, 1.0, 0.75), 42.0))
	else:
		lines.append(_create_laser_line(start, finish, Color(0.28, 0.01, 0.58, 0.32), LASER_WIDTH + 72.0))
		lines.append(_create_laser_line(start, finish, Color(0.62, 0.06, 1.0, 0.62), LASER_WIDTH + 28.0))
		lines.append(_create_laser_line(start, finish, Color(0.88, 0.42, 1.0, 0.95), LASER_WIDTH))
		lines.append(_create_laser_line(start, finish, Color(0.98, 0.82, 1.0, 1.0), 30.0))
	return lines

func _animate_laser_beam(lines: Array[Line2D]) -> void:
	for line in lines:
		if not is_instance_valid(line):
			continue
		var base_width := line.width
		var pulse := line.create_tween().set_loops()
		pulse.tween_property(line, "width", base_width * 1.2, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(line, "width", base_width * 0.88, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(line, "width", base_width, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _create_laser_line(start: Vector2, finish: Vector2, color: Color, width: float) -> Line2D:
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return null
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.z_index = 20
	line.z_as_relative = false
	line.add_point(scene_root.to_local(start))
	line.add_point(scene_root.to_local(finish))
	scene_root.add_child(line)
	return line

func _clear_laser_lines(lines: Array[Line2D]) -> void:
	for line in lines:
		if is_instance_valid(line):
			line.queue_free()

func _damage_mole_in_laser(mole: Node2D, start: Vector2, finish: Vector2) -> void:
	if not is_instance_valid(mole) or not mole.has_method("take_damage"):
		return
	var segment := finish - start
	if segment.length_squared() <= 0.0:
		return
	var t := clampf((mole.global_position - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	var closest := start + segment * t
	if mole.global_position.distance_to(closest) <= LASER_WIDTH * 0.5 + LASER_COLLISION_MARGIN:
		mole.take_damage(LASER_DAMAGE, start, true, true)

func _break_tiles_along_laser(start: Vector2, finish: Vector2) -> void:
	if _tilemap == null or _tile_break_script == null:
		return
	if _laser_hit_tile != Vector2i(-1, -1) and not _is_bedrock(_laser_hit_tile):
		_tile_break_script.break_tile(_tilemap, _laser_hit_tile, get_parent(), false, _tile_break_script.DEBRIS_Z_OVER_BEAM)
	var direction := (finish - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var sample_count := maxi(1, int(ceil(start.distance_to(finish) / LASER_TILE_SAMPLE_SPACING)))
	for i in range(sample_count + 1):
		var center := start.lerp(finish, float(i) / float(sample_count))
		for offset in [-LASER_TILE_HALF_WIDTH, -LASER_TILE_HALF_WIDTH * 0.5, 0.0, LASER_TILE_HALF_WIDTH * 0.5, LASER_TILE_HALF_WIDTH]:
			var sample: Vector2 = center + perpendicular * offset
			var cell := _tilemap.local_to_map(_tilemap.to_local(sample))
			if _tilemap.get_cell_source_id(0, cell) == -1 or _is_bedrock(cell):
				continue
			_tile_break_script.break_tile(_tilemap, cell, get_parent(), false, _tile_break_script.DEBRIS_Z_OVER_BEAM)

func _spawn_laser_ground_firework(world_pos: Vector2) -> void:
	_spawn_firework_burst(world_pos, 180, Color(0.72, 0.12, 1.0, 1.0), 1100.0, 1.8)
	_spawn_firework_burst(world_pos, 96, Color(0.96, 0.72, 1.0, 1.0), 760.0, 1.45)
	_spawn_firework_burst(world_pos + Vector2(-38.0, -24.0), 56, Color(0.45, 0.18, 1.0, 1.0), 620.0, 1.25)
	SFX.play("explosion", world_pos, -1.0, 0.08)
	var mole := get_tree().get_first_node_in_group("mole")
	if is_instance_valid(mole) and mole.has_method("screen_shake"):
		mole.screen_shake(38.0, 0.65)

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
		get_parent().call_deferred("add_child", proj)
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
			if _is_bedrock(tp):
				continue
			_tile_break_script.break_tile(_tilemap, tp, get_parent(), true)

func _enable_arena_map() -> void:
	if _arena_map == null:
		return
	_arena_map.visible = true
	for layer in range(_arena_map.get_layers_count()):
		_arena_map.set_layer_enabled(layer, true)

func _break_arena_blocks() -> void:
	if _arena_map == null:
		return
	for cell in _arena_map.get_used_cells(0):
		# force = true ignores the bedrock tag, so every arena block is torn
		# away and the erase removes its collision with it.
		_tile_break_script.break_tile(_arena_map, cell, get_parent(), true)

func _on_trigger_entered(body: Node) -> void:
	if _boss_active or _cutscene_playing:
		return
	if not body.is_in_group("mole"):
		return
	_enable_arena_map()
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
	_cutscene_target_pos = $AnimatedSprite2D.global_position
	_cutscene_stage = 0
	_cutscene_time = 0.0

func _start_intro_dialogue() -> void:
	_dialogue_finished = false
	_dialogue_line_index = 0
	_dialogue_box = preload("res://scenes/dialogue_box.tscn").instantiate()
	_dialogue_box.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_dialogue_box)
	_dialogue_box.set_npc_name("Corrupted Heart")
	_dialogue_box.set_portrait(anim.sprite_frames.get_frame_texture("default", 0), Color.WHITE)
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

func _on_bounce_zone_body_entered(body: Node) -> void:
	if not _boss_active or not body.is_in_group("mole") or _mole_in_bounce_zone:
		return
	_mole_in_bounce_zone = true
	var dir: Vector2 = body.global_position - bounce_zone.global_position
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	dir = dir.normalized()
	body.velocity = dir * BOUNCE_FORCE + Vector2(0, -200)
	if body.has_method("screen_shake"):
		body.screen_shake(10.0, 0.2)

func _on_bounce_zone_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_in_bounce_zone = false

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

	_last_break_tile_y = -999999
	_boss_active = true
	_cutscene_playing = false
	_spit_cooldown = 1.0
	_laser_cooldown = randf_range(LASER_COOLDOWN_MIN, LASER_COOLDOWN_MAX)
	_laser_attack_active = false
	_loot_spawn_timer = LOOT_SPAWN_INTERVAL
	anim.play("default")

	var wall := get_parent().get_node_or_null("StaticBody2D") as StaticBody2D
	if wall:
		var shape := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape:
			shape.set_deferred("disabled", false)

	_cutscene_mole.process_mode = PROCESS_MODE_INHERIT
	get_tree().paused = false

	_cutscene_mole = null

	_create_health_bar()
	_create_offscreen_indicator()

## Drops a Drill or Holy Water into the arena. It lands above the mole, who has
## to move out and collect it rather than stop and open a chest.
func _spawn_loot_drop() -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return
	var drop_at: Vector2 = mole.global_position + LOOT_DROP_OFFSET
	LootDrop.spawn_random(get_parent(), drop_at)
	SFX.play("coin", drop_at, -12.0, 0.12, 0.9)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not _boss_active:
		return
	var parent = area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		take_damage(parent.get_damage())

func _sprite_center() -> Vector2:
	var frame_tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	var frame_size := frame_tex.get_size()
	return to_global(anim.position + anim.scale * frame_size * 0.5)

## Direction the last hit pushed the boss, so its death fragments are blown the
## same way (see spawn_death_fragments in enemy.gd).
var hit_direction := Vector2.ZERO

func take_damage(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	if not _boss_active:
		return
	if health <= 0:
		return
	health -= amount
	if direction != Vector2.ZERO:
		hit_direction = direction.normalized()
	EnemyDamage.spawn_damage_number(self, amount, get_global_mouse_position(), true)
	if health > 0.0:
		_hit_feedback()
	modulate = Color(2, 1.5, 1.5, 1)
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	_animate_health_bar()
	var mole := get_tree().get_first_node_in_group("mole")
	if mole and mole.has_method("screen_shake"):
		mole.screen_shake(14.0, 0.25)
	if health <= 0:
		die()

## Asked by the ice bomb before it freezes anything: the heart can be iced while
## it is fighting, but not once the death finale has taken over.
func can_be_frozen() -> bool:
	return _boss_active and health > 0.0

func _hit_feedback() -> void:
	var base_scale: Vector2 = anim.get_meta("hit_feedback_base_scale", anim.scale)
	anim.set_meta("hit_feedback_base_scale", base_scale)
	var old_tween: Tween = null
	if anim.has_meta("hit_feedback_tween"):
		old_tween = anim.get_meta("hit_feedback_tween") as Tween
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	var tween := anim.create_tween()
	anim.set_meta("hit_feedback_tween", tween)
	tween.tween_property(anim, "scale", base_scale * Vector2(1.06, 0.94), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(anim, "scale", base_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func die() -> void:
	ComboManager.increment()
	Shop.drop_coins(global_position, 30, 5)
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)
	_destroy_health_bar()
	_destroy_offscreen_indicator()
	_start_death_cutscene()

	modulate = Color(3.0, 2.4, 2.4, 1.0)

	var center := Vector2(581.0, 129.0)
	var half_w := 310.0 * 4.2258 * 0.5 * 0.8
	var half_h := 310.0 * 3.4451 * 0.5 * 0.8

	for i in 15:
		var delay: float = (i / 14.0) * 1.5 + randf_range(0.0, 0.15)
		var offset := Vector2(randf_range(-half_w, half_w), randf_range(-half_h, half_h))
		get_tree().create_timer(delay).timeout.connect(_small_explosion.bind(center + offset))

	var big_tw := create_tween()
	big_tw.tween_interval(1.15)
	big_tw.tween_callback(_pre_big_explosion.bind(center, half_w, half_h))
	big_tw.tween_interval(0.35)
	big_tw.tween_callback(_big_explosion.bind(center))
	# Let the giant firework finish before the mole starts the collapse ride.
	big_tw.tween_interval(HEART_FIREWORK_HOLD)
	big_tw.tween_callback(_break_apart)
	big_tw.tween_callback(_play_death_effect)
	big_tw.tween_interval(0.25)
	big_tw.tween_callback(_start_collapse)

	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(1.5 + HEART_FIREWORK_HOLD)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)

func _small_explosion(local_pos: Vector2) -> void:
	if not is_instance_valid(self):
		return
	_spawn_explosion(to_global(local_pos), randf_range(0.4, 0.7))
	if randf() < 0.6:
		SFX.play("explosion", to_global(local_pos), -13.0, 0.3)

func _pre_big_explosion(local_pos: Vector2, half_w: float, half_h: float) -> void:
	# Crackling purple bursts race across the heart before the final blast.
	for i in 7:
		var offset := Vector2(randf_range(-half_w, half_w), randf_range(-half_h, half_h))
		var particles := CPUParticles2D.new()
		particles.one_shot = true
		particles.emitting = true
		particles.explosiveness = 1.0
		particles.amount = 24
		particles.lifetime = 0.5
		particles.direction = Vector2.ZERO
		particles.spread = 180.0
		particles.initial_velocity_min = 240.0
		particles.initial_velocity_max = 620.0
		particles.gravity = Vector2.ZERO
		particles.scale_amount_min = 5.0
		particles.scale_amount_max = 12.0
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 0.9, 1.0, 1.0))
		gradient.set_color(0.45, Color(0.8, 0.25, 1.0, 1.0))
		gradient.set_color(1, Color(0.3, 0.05, 0.55, 0.0))
		particles.color_ramp = gradient
		particles.z_index = 10
		add_child(particles)
		particles.global_position = to_global(local_pos + offset)
		get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)

func _big_explosion(local_pos: Vector2) -> void:
	var world_pos := to_global(local_pos)
	# A bright core and overlapping colored shells make the heart burst like a
	# huge firework instead of a single short-lived puff.
	_spawn_firework_burst(world_pos, 180, Color(0.82, 0.25, 1.0, 1.0), 980.0, 1.8)
	_spawn_firework_burst(world_pos, 120, Color(1.0, 0.78, 0.26, 1.0), 760.0, 1.6)
	_spawn_firework_burst(world_pos + Vector2(-160, -80), 72, Color(0.35, 0.85, 1.0, 1.0), 620.0, 1.5)
	_spawn_firework_burst(world_pos + Vector2(170, 65), 72, Color(1.0, 0.32, 0.48, 1.0), 620.0, 1.5)
	for i in 4:
		var offset := Vector2(randf_range(-300.0, 300.0), randf_range(-220.0, 220.0))
		var color: Color = [Color(0.9, 0.35, 1.0), Color(1.0, 0.75, 0.25), Color(0.3, 0.8, 1.0), Color(1.0, 0.35, 0.5)][i]
		get_tree().create_timer(0.18 * (i + 1)).timeout.connect(
			_spawn_firework_burst.bind(world_pos + offset, 56, color, 560.0, 1.4))
	SFX.play("explosion", world_pos, -1.0, 0.05)
	_shake_cutscene_cam(68.0, 0.9)

func _spawn_firework_burst(world_pos: Vector2, amount: int, color: Color, speed: float, lifetime: float) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.45
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0.0, 120.0)
	particles.damping_min = 18.0
	particles.damping_max = 55.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 13.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	gradient.set_color(0.16, color)
	gradient.set_color(1, Color(color.r * 0.35, color.g * 0.3, color.b * 0.45, 0.0))
	particles.color_ramp = gradient
	particles.z_index = 15
	add_child(particles)
	particles.global_position = world_pos
	get_tree().create_timer(lifetime + 0.25).timeout.connect(particles.queue_free)

func _shake_cutscene_cam(strength: float, duration: float = 0.45) -> void:
	if not _cutscene_cam or not is_instance_valid(_cutscene_cam):
		return
	if _cutscene_shake_tween and _cutscene_shake_tween.is_valid():
		_cutscene_shake_tween.kill()
	var tween := _cutscene_cam.create_tween()
	_cutscene_shake_tween = tween
	var steps := 18
	var step_time := duration / steps
	for i in steps:
		var falloff := 1.0 - float(i) / float(steps)
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) * falloff
		tween.tween_property(_cutscene_cam, "offset", offset, step_time).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_cutscene_cam, "offset", Vector2.ZERO, 0.1).set_trans(Tween.TRANS_SINE)

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
	particles.color = Color(1.0, 0.55, 0.15, 1.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	gradient.set_color(1, Color(0.45, 0.12, 0.04, 0.0))
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
	_cutscene_cam.zoom = Vector2(0.75, 0.75)
	add_child(_cutscene_cam)
	_cutscene_cam.global_position = anim.global_position + Vector2(0, -40)
	_cutscene_cam.make_current()

	var zoom_tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zoom_tw.tween_property(_cutscene_cam, "zoom", Vector2(0.4, 0.4), 2.8)

func _finish_death_cutscene() -> void:
	# The collapse ends the cutscene once the mole lands; stay one-shot in case
	# the death sequence and the collapse ever both try to finish it.
	if _death_finished:
		return
	_death_finished = true
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
		var mole_body := _cutscene_mole as CollisionObject2D
		if mole_body and _ride_mole_layer != 0:
			mole_body.collision_layer = _ride_mole_layer
	_cutscene_mole = null

	get_tree().paused = false
	process_mode = PROCESS_MODE_INHERIT
	queue_free()

## The boss's death takes the floor with it: the tiles beneath the mole break
## away row by row, the mole rides the collapse down, and everything caught in
## the shaft is killed on the way. It ends at the bottom of the level.
func _start_collapse() -> void:
	if _collapse_started:
		return
	_collapse_started = true

	var mole := _cutscene_mole as Node2D
	if _tilemap == null or mole == null or not is_instance_valid(mole):
		_finish_death_cutscene()
		return
	_run_collapse(mole)

func _run_collapse(mole: Node2D) -> void:
	if _tilemap == null or not is_instance_valid(mole):
		_finish_death_cutscene()
		return

	# Drop the mole below the heart, then begin the existing block-breaking ride.
	mole.global_position = global_position + Vector2(0.0, COLLAPSE_TELEPORT_BELOW_BOSS)
	if _cutscene_cam and is_instance_valid(_cutscene_cam):
		_cutscene_cam.global_position = mole.global_position + Vector2(0.0, COLLAPSE_CAM_OFFSET)

	# Keep the descent playable: the tree stays unpaused so break particles and
	# sounds run, and the mole keeps sideways control while the floor falls away.
	var body := mole as CollisionObject2D
	if body:
		_ride_mole_layer = body.collision_layer
		body.collision_layer = 0
	_play_mole_fall_anim(mole)
	get_tree().paused = false
	_collapse_player_control = true
	_ride_mole = mole

	var center_tile := _tilemap.local_to_map(_tilemap.to_local(mole.global_position))
	_ride_min_x = _tilemap.to_global(_tilemap.map_to_local(Vector2i(center_tile.x - COLLAPSE_HALF_WIDTH_TILES, 0))).x
	_ride_max_x = _tilemap.to_global(_tilemap.map_to_local(Vector2i(center_tile.x + COLLAPSE_HALF_WIDTH_TILES, 0))).x
	var first_row := center_tile.y + 1
	# Captured up front: the used rect shrinks as the shaft is carved out.
	var bottom_row := _tilemap.get_used_rect().end.y - 1

	for row in range(first_row, bottom_row + 1):
		var row_center_x := _tilemap.local_to_map(_tilemap.to_local(mole.global_position)).x
		var bedrock_x := _find_bedrock_x(row, row_center_x)
		_break_collapse_row(row, row_center_x)
		_break_chests_in_row(row, row_center_x)
		_kill_enemies_in_row(row, row_center_x)

		# Break the loose blocks beside the landing point, then settle on top of
		# the nearest intact bedrock instead of continuing through it.
		if bedrock_x >= 0:
			var landing_x := _tilemap.to_global(_tilemap.map_to_local(Vector2i(bedrock_x, row))).x
			await _ride_mole_to_row(mole, row, landing_x)
			break

		await _ride_mole_to_row(mole, row, mole.global_position.x)

	_collapse_player_control = false
	_ride_mole = null
	_kill_all_remaining_enemies()
	# The arena's second tilemap is the final impact platform: break it only
	# after the mole has reached the bedrock at the bottom of the shaft.
	_shake_cutscene_cam(72.0, 0.9)
	_break_arena_blocks()
	await get_tree().create_timer(COLLAPSE_LAND_DELAY).timeout
	_finish_death_cutscene()

func _ride_mole_to_row(mole: Node2D, row: int, target_x: float) -> void:
	var target := Vector2(target_x, _row_world_y(row) - COLLAPSE_RIDE_OFFSET)
	var ride := create_tween()
	ride.set_parallel(true)
	ride.tween_property(mole, "global_position", target, COLLAPSE_STEP_TIME)
	if _cutscene_cam and is_instance_valid(_cutscene_cam):
		ride.tween_property(_cutscene_cam, "global_position", target + Vector2(0, COLLAPSE_CAM_OFFSET), COLLAPSE_STEP_TIME)
	await ride.finished

func _play_mole_fall_anim(mole: Node2D) -> void:
	# The mole's own animation state machine is paused for the cutscene, so show
	# its airborne pose while it rides the collapse.
	var sprite := mole.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation("jumpbold"):
		sprite.play("jumpbold")

## Breaks one row of the shaft. Returns (broken, solid): how many tiles gave
## way, and how many were found in the band at all.
func _break_collapse_row(row: int, center_x: int) -> Vector2i:
	var broken := 0
	var solid := 0
	var min_x := center_x - COLLAPSE_HALF_WIDTH_TILES
	var max_x := center_x + COLLAPSE_HALF_WIDTH_TILES
	for x in range(min_x, max_x + 1):
		var tp := Vector2i(x, row)
		if _tilemap.get_cell_source_id(0, tp) == -1:
			continue
		solid += 1
		if _is_bedrock(tp):
			continue
		# force = false, so the collapse still respects unbreakable tiles.
		_tile_break_script.break_tile(_tilemap, tp, get_parent())
		broken += 1
	return Vector2i(broken, solid)

func _is_bedrock(tile_pos: Vector2i) -> bool:
	var tile_data := _tilemap.get_cell_tile_data(0, tile_pos)
	return tile_data != null and (tile_data.get_custom_data("bedrock") as bool)

func _find_bedrock_x(row: int, center_x: int) -> int:
	var nearest_x := -1
	var nearest_distance := COLLAPSE_HALF_WIDTH_TILES + 1
	for x in range(center_x - COLLAPSE_HALF_WIDTH_TILES, center_x + COLLAPSE_HALF_WIDTH_TILES + 1):
		if not _is_bedrock(Vector2i(x, row)):
			continue
		var distance := absi(x - center_x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_x = x
	return nearest_x

func _row_world_y(row: int) -> float:
	return _tilemap.to_global(_tilemap.map_to_local(Vector2i(0, row))).y

func _kill_enemies_in_row(row: int, _center_x: int) -> void:
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy == null or enemy == self or not (enemy is Node2D) or not enemy.has_method("die"):
			continue
		var cell := _tilemap.local_to_map(_tilemap.to_local((enemy as Node2D).global_position))
		if cell.y != row:
			continue
		# This is a level-wide collapse: every enemy is caught when the falling
		# mole reaches its depth, even if it is outside the narrow break shaft.
		hurtbox.remove_from_group("enemy_hurtbox")
		enemy.process_mode = Node.PROCESS_MODE_ALWAYS
		enemy.call("die")

func _kill_all_remaining_enemies() -> void:
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy == null or enemy == self or not enemy.has_method("die"):
			continue
		hurtbox.remove_from_group("enemy_hurtbox")
		enemy.process_mode = Node.PROCESS_MODE_ALWAYS
		enemy.call("die")

func _update_ride_mole(delta: float) -> void:
	if _ride_mole == null or not is_instance_valid(_ride_mole):
		return
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		var new_x := clampf(_ride_mole.global_position.x + dir * COLLAPSE_MOVE_SPEED * delta, _ride_min_x, _ride_max_x)
		_ride_mole.global_position.x = new_x
		var sprite := _ride_mole.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			sprite.flip_h = dir < 0.0

## Smashes every chest the mole plows through in this row of the shaft, opening
## unopened ones first so they still drop their loot.
func _break_chests_in_row(row: int, _center_x: int) -> void:
	for child in get_parent().get_children():
		if not (child is Node2D):
			continue
		var chest_area: Area2D = null
		for c in child.get_children():
			if c is Area2D and c.has_method("_open_chest"):
				chest_area = c as Area2D
				break
		if chest_area == null:
			continue
		var cell := _tilemap.local_to_map(_tilemap.to_local((child as Node2D).global_position))
		if cell.y != row:
			continue
		if chest_area.get("is_open") == false:
			chest_area.call("_open_chest")
		chest_area.call("break_as_block")

func _break_apart() -> void:
	EnemyDamage.spawn_death_fragments(self, anim, Vector2.ZERO, scale.x, DEATH_FRAGMENT_LIFE, true)

func _play_death_effect() -> void:
	var sprite := $AnimatedSprite2D
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
	death_particles.color = Color(0.6, 0.2, 0.9, 1)
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.3, 1.0, 1))
	fade.set_color(1, Color(0.4, 0.1, 0.6, 0))
	death_particles.color_ramp = fade
	add_child(death_particles)
	death_particles.global_position = sprite.global_position
	get_tree().create_timer(2.0).timeout.connect(death_particles.queue_free)
