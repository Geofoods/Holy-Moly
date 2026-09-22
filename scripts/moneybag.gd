extends RigidBody2D

## A moneybag formed from several coins that grouped together. Worth the sum of
## the merged coins (a bag of four 1-value coins is worth 4). Rendered at twice
## the visual size of a normal coin.

var value := 0

const BAG_RADIUS := 44.0

const MAGNET_RANGE := 280.0
const MAGNET_SPEED := 1500.0
const MAGNET_DELAY := 0.4
const COLLECT_DISTANCE := 56.0

var _time := 0.0
var _mole: Node2D = null
var _sprite: Sprite2D = null
var _collected := false

func _ready() -> void:
	_setup_sprite()
	add_to_group("moneybag")
	contact_monitor = true
	max_contacts_reported = 8
	linear_velocity = Vector2(0.0, randf_range(-120.0, -60.0))
	angular_velocity = randf_range(-2.0, 2.0)
	body_entered.connect(_on_body_entered)
	_mole = get_tree().get_first_node_in_group("mole")

## Use the moneybag artwork when it is present, otherwise fall back to _draw().
func _setup_sprite() -> void:
	var tex := MoneyBagArt.texture()
	if tex == null:
		return
	var region := MoneyBagArt.region()
	var longest := maxf(region.size.x, region.size.y)
	if longest <= 0.0:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = region
	_sprite.scale = Vector2.ONE * (BAG_RADIUS * 2.0 / longest)
	add_child(_sprite)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _collected:
		return
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
	if not _collected and body.is_in_group("mole"):
		_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	if value < 1:
		value = 1
	var gained := value * roundi(ComboManager.get_coin_multiplier())
	Shop.add_coins(gained)
	SFX.play("coin", global_position, -2.0, 0.15, 0.65)
	_spawn_collect_burst()
	var scene := get_tree().current_scene
	if scene:
		var pop := Label.new()
		pop.text = "+%d" % gained
		pop.add_theme_font_size_override("font_size", 26)
		pop.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		pop.modulate.a = 0.0
		scene.add_child(pop)
		pop.global_position = global_position + Vector2(-18, -40)
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
	burst.amount = 16
	burst.lifetime = 0.4
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 500)
	burst.initial_velocity_min = 110.0
	burst.initial_velocity_max = 240.0
	burst.scale_amount_min = 2.5
	burst.scale_amount_max = 5.0
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
	var dark := Color(0.72, 0.5, 0.12)
	draw_circle(Vector2.ZERO, BAG_RADIUS - 4.0, dark)
	draw_circle(Vector2.ZERO, BAG_RADIUS - 9.0, gold)
	draw_rect(Rect2(-BAG_RADIUS * 0.35, -BAG_RADIUS - 4.0, BAG_RADIUS * 0.7, 12.0), dark)