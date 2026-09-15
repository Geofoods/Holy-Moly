extends CharacterBody2D

const EnemyDamage := preload("res://scripts/enemy.gd")

const HP_MAX := 66.0
const PATROL_SPEED := 70.0
const DETECT_RANGE := 540.0
const TELEGRAPH_TIME := 0.7
const COOLDOWN := 1.7
const SHARD_SPEED := 400.0

var health := HP_MAX

var _state := "patrol"
var _dir := -1
var _state_time := 0.0
var _mole_contact := false
var _flash := 0.0
var _flash_color := Color(1, 1, 1, 1)

@onready var visual: AnimatedSprite2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	hurtbox.add_to_group("enemy_hurtbox")
	hitbox.monitorable = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.body_exited.connect(_on_hitbox_body_exited)
	_build_visual()

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0 and modulate != Color.WHITE:
			modulate = Color.WHITE
	queue_redraw()

func _physics_process(delta: float) -> void:
	match _state:
		"patrol":
			_patrol(delta)
		"telegraph":
			_state_time -= delta
			visual.modulate = Color(1, 0.5, 0.5) if int(_state_time * 10.0) % 2 == 0 else Color.WHITE
			velocity.x = 0.0
			if _state_time <= 0.0:
				_fire_shards()
				_state = "cooldown"
				_state_time = COOLDOWN
				visual.modulate = Color.WHITE
		"cooldown":
			_state_time -= delta
			velocity.x = 0.0
			if _state_time <= 0.0:
				_state = "patrol"

func _patrol(_delta: float) -> void:
	visual.modulate = Color.WHITE
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole != null and is_instance_valid(mole) and global_position.distance_to(mole.global_position) < DETECT_RANGE:
		_state = "telegraph"
		_state_time = TELEGRAPH_TIME
		_face(mole.global_position)
		return
	velocity.x = _dir * PATROL_SPEED
	velocity.y = 0.0
	move_and_slide()
	if is_on_wall():
		_dir *= -1
	visual.flip_h = _dir < 0

func _face(target: Vector2) -> void:
	visual.flip_h = target.x < global_position.x

func _fire_shards() -> void:
	var mole := get_tree().get_first_node_in_group("mole")
	var base := Vector2(_dir, -0.25).normalized()
	if mole != null and is_instance_valid(mole):
		base = (mole.global_position - global_position).normalized()
	for i in 3:
		var dir := base.rotated((float(i) - 1.0) * 0.42)
		var proj := preload("res://area_2d.tscn").instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position + Vector2(0, -28)
		proj.scale = Vector2(0.3, 0.3)
		proj.setup(dir * SHARD_SPEED)

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("mole") and not _mole_contact:
		_mole_contact = true
		body.take_damage(1, global_position, true)

func _on_hitbox_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_contact = false

func take_damage(amount: float) -> void:
	health -= amount
	ComboManager.increment()
	EnemyDamage.spawn_damage_number(self, amount)
	_flash = 0.12
	modulate = Color(2.0, 0.9, 1.2)
	if health <= 0.0:
		die()
	else:
		ScoreManager.add_kill(6, global_position)

func die() -> void:
	ScoreManager.add_kill(80, global_position)
	Shop.drop_coins(global_position, 4, 1)
	Shop.drop_coins(global_position, 1, 3)
	set_physics_process(false)
	set_process(false)
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	visual.modulate = Color(2.0, 1.2, 2.0, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _draw() -> void:
	if health >= HP_MAX:
		return
	var w := 54.0
	var frac := clampf(health / HP_MAX, 0.0, 1.0)
	var p := Vector2(-w / 2.0, -92)
	draw_rect(Rect2(p.x - 1, p.y - 1, w + 2, 9), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(p.x, p.y, w * frac, 7), Color(0.55, 0.9, 0.35))

func _build_visual() -> void:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 128:
		for x in 128:
			var dx := float(x) - 64.0
			var dy := float(y) - 62.0
			var d := sqrt(dx * dx + dy * dy)
			if d > 30.0:
				continue
			var t := (dy + 30.0) / 60.0
			var color := Color(0.2, 0.3, 0.52).lerp(Color(0.45, 0.56, 0.82), t)
			if d > 25.0:
				color = color.darkened(0.55)
			var cd := sqrt(dx * dx + (dy - 6.0) * (dy - 6.0))
			if cd < 15.0:
				color = color.lerp(Color(0.62, 1.0, 1.0), 1.0 - cd / 15.0)
			var f := fmod(dx - dy, 12.0)
			if f < 0.0:
				f += 12.0
			if absf(f) < 1.0 or absf(f - 12.0) < 1.0:
				color = color.darkened(0.2)
			img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_loop("default", true)
	frames.add_frame("default", tex)
	if visual:
		visual.sprite_frames = frames
		visual.play("default")