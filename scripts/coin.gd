extends RigidBody2D

var value := 1

const COIN_RADIUS := 22.0

const MAGNET_RANGE := 260.0
const MAGNET_SPEED := 1500.0
const MAGNET_DELAY := 0.5
const COLLECT_DISTANCE := 46.0

var _time := 0.0
var _mole: Node2D = null
var _sprite: Sprite2D = null

func _ready() -> void:
	_setup_sprite()
	add_to_group("coin")
	contact_monitor = true
	max_contacts_reported = 8
	linear_velocity = Vector2(randf_range(-180.0, 180.0), randf_range(-460.0, -320.0))
	angular_velocity = randf_range(-8.0, 8.0)
	body_entered.connect(_on_body_entered)
	_mole = get_tree().get_first_node_in_group("mole")

## Use the coin artwork when it is present, otherwise fall back to _draw().
func _setup_sprite() -> void:
	var tex := CoinArt.texture()
	if tex == null:
		return
	var region := CoinArt.region()
	var longest := maxf(region.size.x, region.size.y)
	if longest <= 0.0:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = region
	_sprite.scale = Vector2.ONE * (COIN_RADIUS * 2.0 / longest)
	add_child(_sprite)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_time += delta
	if _time < MAGNET_DELAY:
		return
	var mole := _mole
	if mole == null or not is_instance_valid(mole):
		mole = get_tree().get_first_node_in_group("mole")
		_mole = mole
	if not mole:
		return
	var to_mole: Vector2 = (mole as Node2D).global_position - global_position
	var dist_sq := to_mole.length_squared()
	if dist_sq > MAGNET_RANGE * MAGNET_RANGE:
		return
	sleeping = false
	linear_velocity = linear_velocity.lerp(to_mole.normalized() * MAGNET_SPEED, minf(delta * 8.0, 1.0))
	if dist_sq < COLLECT_DISTANCE * COLLECT_DISTANCE:
		_collect()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_collect()

func _collect() -> void:
	var gained := value * roundi(ComboManager.get_coin_multiplier())
	Shop.add_coins(gained)
	SFX.play("coin", global_position, -8.0, 0.15)
	_spawn_collect_burst()
	var scene := get_tree().current_scene
	if scene:
		var pop := Label.new()
		pop.text = "+%d" % gained
		pop.add_theme_font_size_override("font_size", 20)
		pop.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		pop.modulate.a = 0.0
		scene.add_child(pop)
		pop.global_position = global_position + Vector2(-12, -30)
		var tw := pop.create_tween()
		tw.set_parallel(true)
		tw.tween_property(pop, "position:y", pop.position.y - 30.0, 0.5)
		tw.tween_property(pop, "modulate:a", 1.0, 0.08)
		tw.chain().tween_property(pop, "modulate:a", 0.0, 0.3)
	queue_free()

func _spawn_collect_burst() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 10
	burst.lifetime = 0.35
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 500)
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 190.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.82, 0.25, 1.0))
	grad.set_color(1, Color(0.8, 0.55, 0.1, 0.0))
	burst.color_ramp = grad
	burst.z_index = 5
	scene.add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)

func _draw() -> void:
	if _sprite != null:
		return
	var gold := Color(1.0, 0.82, 0.25)
	var dark := Color(0.8, 0.55, 0.1)
	for i in 3:
		var inset := i * 1.5
		var r := 10.0 - inset
		draw_circle(Vector2.ZERO, r, dark if i == 0 else gold)
	draw_circle(Vector2.ZERO, 4.0, dark)
