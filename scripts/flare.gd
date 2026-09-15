extends "res://scripts/custom_bomb.gd"

## Flare: explodes into a pool of warm light for LIGHT_DURATION seconds,
## brightening up the caves. Tiny bit of damage to enemies; never harms the mole.

const LIGHT_DURATION := 12.0

func _init() -> void:
	accent = Color(1.0, 0.55, 0.2, 1.0)
	blast_radius = 140.0
	enemy_damage = 3.0
	self_damage = 0.0
	hits_mole = false
	breaks_tiles = false

func _process(delta: float) -> void:
	if not fuse_active or is_flashing:
		return
	fuse_elapsed += delta
	var progress := clampf(fuse_elapsed / (FUSE_TIME - FLASH_TIME), 0.0, 1.0)
	tick_cooldown -= delta
	if tick_cooldown <= 0.0:
		SFX.play("bomb_tick", global_position, -6.0, 0.08)
		tick_cooldown = lerpf(0.5, 0.1, progress)
	var pulse := 0.5 + sin(fuse_elapsed * lerpf(8.0, 25.0, progress)) * 0.5
	var intensity := lerpf(0.4, 1.4, progress) + pulse * 0.3
	if _sprite:
		_sprite.modulate = Color(accent.r * intensity, accent.g * intensity, accent.b * intensity, 1.0)
	if fuse_elapsed >= FUSE_TIME - FLASH_TIME:
		_start_flash()

func _blast() -> void:
	_damage_enemies_in_radius()
	_spawn_light()
	_spawn_sparks()

func _spawn_light() -> void:
	var lamp := Node2D.new()
	lamp.name = "FlareLight"
	lamp.z_index = 0
	get_parent().add_child(lamp)
	lamp.global_position = global_position

	var light := PointLight2D.new()
	light.name = "PointLight2D"
	light.energy = 1.4
	light.texture_scale = 3.0
	light.color = Color(1.0, 0.75, 0.4, 1.0)
	light.texture = _radial_texture()
	lamp.add_child(light)

	var glow := CPUParticles2D.new()
	glow.emitting = true
	glow.one_shot = false
	glow.amount = 12
	glow.lifetime = 1.0
	glow.explosiveness = 0.2
	glow.direction = Vector2.UP
	glow.spread = 40.0
	glow.initial_velocity_min = 20.0
	glow.initial_velocity_max = 60.0
	glow.gravity = Vector2(0, -20)
	glow.scale_amount_min = 8.0
	glow.scale_amount_max = 14.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.7, 0.35, 0.9))
	grad.set_color(1, Color(0.9, 0.5, 0.2, 0.0))
	glow.color_ramp = grad
	get_parent().add_child(glow)
	glow.global_position = global_position
	get_tree().create_timer(LIGHT_DURATION).timeout.connect(glow.queue_free)

	var tween := lamp.create_tween()
	tween.tween_interval(LIGHT_DURATION)
	tween.tween_property(light, "energy", 0.0, 0.8)
	tween.parallel().tween_property(lamp, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lamp.queue_free)

func _spawn_sparks() -> void:
	var sparks := CPUParticles2D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = 20
	sparks.lifetime = 0.8
	sparks.explosiveness = 0.9
	sparks.direction = Vector2.ZERO
	sparks.spread = 180.0
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 320.0
	sparks.gravity = Vector2(0, 260)
	sparks.scale_amount_min = 4.0
	sparks.scale_amount_max = 8.0
	sparks.color = Color(1.0, 0.7, 0.3, 1.0)
	sparks.z_index = 4
	get_parent().add_child(sparks)
	sparks.global_position = global_position

func _radial_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size:
		for x in size:
			var dx := float(x - size / 2) / (size / 2)
			var dy := float(y - size / 2) / (size / 2)
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)