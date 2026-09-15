extends "res://scripts/custom_bomb.gd"

## Stink Bomb: detonates a lingering stink cloud that slows enemies caught
## inside it. Doesn't break anything or hurt anyone.

const CLOUD_DURATION := 6.0

func _init() -> void:
	accent = Color(0.45, 0.85, 0.35, 1.0)
	blast_radius = 170.0
	enemy_damage = 0.0
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
	var cloud_script := preload("res://scripts/stink_cloud.gd")
	var cloud := cloud_script.new()
	get_parent().add_child(cloud)
	cloud.global_position = global_position
	var puff := CPUParticles2D.new()
	puff.emitting = true
	puff.one_shot = true
	puff.amount = 26
	puff.lifetime = 0.7
	puff.explosiveness = 0.9
	puff.direction = Vector2.ZERO
	puff.spread = 180.0
	puff.initial_velocity_min = 100.0
	puff.initial_velocity_max = 260.0
	puff.scale_amount_min = 10.0
	puff.scale_amount_max = 22.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.9, 0.4, 0.9))
	grad.set_color(1, Color(0.3, 0.6, 0.25, 0.0))
	puff.color_ramp = grad
	puff.z_index = -1
	get_parent().add_child(puff)
	puff.global_position = global_position
	get_tree().create_timer(1.2).timeout.connect(puff.queue_free)

func _blast_particles() -> void:
	pass