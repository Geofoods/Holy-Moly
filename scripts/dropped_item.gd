extends CharacterBody2D

const GRAVITY := 900.0
const BOUNCE := 0.4
const MIN_BOUNCE_VELOCITY := 30.0

@export var item_data: ItemData

var _velocity := Vector2.ZERO
var _is_floating := false
var _float_time := 0.0
var _can_pickup := false
var _y_start_float := 0.0
var _notification_cooldown := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D

const PLACEHOLDER_SIZE := 48

func _ready() -> void:
	if item_data:
		if item_data.icon_texture:
			sprite.texture = item_data.icon_texture
		else:
			_make_placeholder()

	# Avoid physics collisions with the player
	var player = get_tree().get_first_node_in_group("mole")
	if player:
		add_collision_exception_with(player)

	# Spawn with some random velocity popped out of the chest
	# e.g., upwards and slightly left/right
	_velocity = Vector2(randf_range(-150.0, 150.0), randf_range(-400.0, -250.0))

	# Delay pickup slightly so player doesn't immediately consume it
	get_tree().create_timer(0.4).timeout.connect(func():
		_can_pickup = true
	)

func _make_placeholder() -> void:
	var img := Image.create(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(item_data.icon_color)
	for i in PLACEHOLDER_SIZE:
		for j in 3:
			img.set_pixel(i, j, Color(1, 1, 1, 0.35))
			img.set_pixel(i, PLACEHOLDER_SIZE - 1 - j, Color(0, 0, 0, 0.35))
			img.set_pixel(j, i, Color(1, 1, 1, 0.35))
			img.set_pixel(PLACEHOLDER_SIZE - 1 - j, i, Color(0, 0, 0, 0.35))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.scale = Vector2.ONE
	sprite.self_modulate = Color.WHITE
	if item_data.icon_text != "":
		var lbl := Label.new()
		lbl.text = item_data.icon_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-PLACEHOLDER_SIZE, -PLACEHOLDER_SIZE) * 0.5
		lbl.size = Vector2(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE)
		lbl.z_index = 3
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("shadow_offset_x", 2)
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		add_child(lbl)

func _physics_process(delta: float) -> void:
	if _notification_cooldown > 0.0:
		_notification_cooldown -= delta

	if not _is_floating:
		_velocity.y += GRAVITY * delta
		var collision = move_and_collide(_velocity * delta)
		if collision:
			var normal = collision.get_normal()
			_velocity = _velocity.bounce(normal) * BOUNCE
			# If we land on a floor or velocity becomes very small, start floating
			if normal.y < -0.7 or _velocity.length() < MIN_BOUNCE_VELOCITY:
				_is_floating = true
				_y_start_float = global_position.y
				_velocity = Vector2.ZERO
	else:
		# Floating bobbing animation
		_float_time += delta
		global_position.y = _y_start_float + sin(_float_time * 4.0) * 6.0

	if _can_pickup:
		for body in area.get_overlapping_bodies():
			if body.is_in_group("mole"):
				_try_pickup(body)
				break

var _is_picked_up := false

func _try_pickup(body: Node2D) -> void:
	if _is_picked_up:
		return
	var success = Inventory.add_item(item_data)
	if success:
		_is_picked_up = true
		# Play pickup sound
		SFX.play("item_pickup", global_position, -4.0, 0.1)
		queue_free()
	else:
		if _notification_cooldown <= 0.0:
			_notification_cooldown = 1.5
			if body.has_method("show_inventory_full_message"):
				body.show_inventory_full_message()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not _can_pickup:
		return
	if body.is_in_group("mole"):
		_try_pickup(body)
