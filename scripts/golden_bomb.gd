extends "res://scripts/custom_bomb.gd"

## Golden Bomb: a bigger blast with a much larger blast radius that punches three
## tiles out in every direction and hurts the mole less (nice gold plating).

func _init() -> void:
	accent = Color(1.0, 0.82, 0.25, 1.0)
	blast_radius = 300.0
	enemy_damage = 9.0
	self_damage = 3.0
	hits_mole = true
	tile_break_radius = 3

func _blast() -> void:
	_break_tiles_in_radius()
	_damage_enemies_in_radius()
	var sprite := _sprite
	if sprite:
		var glint := CPUParticles2D.new()
		glint.emitting = true
		glint.one_shot = true
		glint.amount = 30
		glint.lifetime = 0.6
		glint.explosiveness = 1.0
		glint.direction = Vector2.ZERO
		glint.spread = 180.0
		glint.initial_velocity_min = 200.0
		glint.initial_velocity_max = 500.0
		glint.scale_amount_min = 5.0
		glint.scale_amount_max = 12.0
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
		grad.set_color(1, Color(1.0, 0.6, 0.1, 0.0))
		glint.color_ramp = grad
		glint.z_index = 4
		get_parent().add_child(glint)
		glint.global_position = global_position
		get_tree().create_timer(1.0).timeout.connect(glint.queue_free)