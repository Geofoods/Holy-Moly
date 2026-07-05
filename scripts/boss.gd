extends CharacterBody2D

const MAX_HEALTH := 20.0
const PAN_DURATION := 1.5
const HOLD_DURATION := 1.5

var health := MAX_HEALTH
var _boss_active := false
var _cutscene_playing := false

var _cutscene_mole: Node = null
var _cutscene_cam: Camera2D = null
var _cutscene_stage := -1
var _cutscene_time := 0.0
var _cutscene_start_pos := Vector2.ZERO
var _cutscene_target_pos := Vector2.ZERO
var _cutscene_start_cam_pos := Vector2.ZERO

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var trigger: Area2D = $CutsceneTrigger
@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	anim.stop()
	anim.frame = 0
	trigger.body_entered.connect(_on_trigger_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.add_to_group("enemy_hurtbox")

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

	_boss_active = true
	_cutscene_playing = false
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
