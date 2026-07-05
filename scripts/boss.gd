extends CharacterBody2D

const MAX_HEALTH := 20.0
const PAN_DURATION := 1.5
const HOLD_DURATION := 1.5
const DESCENT_SPEED := 50.0
const SPIT_INTERVAL := 3.0
const PROJECTILE_SPEED := 400.0

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

func _ready() -> void:
	anim.stop()
	anim.frame = 0
	trigger.body_entered.connect(_on_trigger_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.add_to_group("enemy_hurtbox")
	_tilemap = get_parent().get_node_or_null("TileMap") as TileMap
	_tile_break_script = load("res://scripts/tile_break_sfx.gd")
	_projectile_scene = preload("res://area_2d.tscn")

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

	_break_tiles_in_path()
	velocity.y = DESCENT_SPEED
	move_and_slide()

func _spit() -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if not mole or not is_instance_valid(mole):
		return

	var dir: Vector2 = (mole.global_position - anim.global_position).normalized()
	var spawn_pos: Vector2 = anim.global_position + dir * 200.0

	var proj := _projectile_scene.instantiate() as Area2D
	get_parent().add_child(proj)
	proj.global_position = spawn_pos
	proj.setup(dir * PROJECTILE_SPEED)

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

	mole.process_mode = PROCESS_MODE_DISABLED
	get_tree().paused = true

	process_mode = PROCESS_MODE_ALWAYS
	trigger.process_mode = PROCESS_MODE_ALWAYS

	var mole_cam := mole.get_node("Camera2D") as Camera2D
	_cutscene_start_cam_pos = mole_cam.global_position
	mole_cam.enabled = false

	_cutscene_cam = Camera2D.new()
	_cutscene_cam.name = "CutsceneCam"
	_cutscene_cam.process_mode = PROCESS_MODE_ALWAYS
	_cutscene_cam.global_position = _cutscene_start_cam_pos
	_cutscene_cam.zoom = mole_cam.zoom
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

	process_mode = PROCESS_MODE_INHERIT
	trigger.process_mode = PROCESS_MODE_INHERIT

	_last_break_tile_y = -999999
	_boss_active = true
	_cutscene_playing = false
	_spit_cooldown = 1.0
	anim.play("default")

	_cutscene_mole.process_mode = PROCESS_MODE_INHERIT
	get_tree().paused = false

	_cutscene_mole = null

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not _boss_active:
		return
	var parent := area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		take_damage(1)

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
