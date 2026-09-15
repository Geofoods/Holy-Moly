extends "res://scripts/custom_bomb.gd"

## Mine: thrown, then after ARM_TIME it arms and stays put. It only detonates
## when an enemy steps into TRIGGER_RANGE. Hurts the mole's own mine? No--the
## player sheds the "nails" so their own mines are safe.

const ARM_TIME := 1.0
const TRIGGER_RANGE := 70.0

var _arming := false
var _armed := false

func _init() -> void:
	accent = Color(0.55, 0.55, 0.6, 1.0)
	blast_radius = 210.0
	enemy_damage = 8.0
	self_damage = 1.0
	hits_mole = false
	breaks_tiles = true
	tile_break_radius = 2

func _ready() -> void:
	super._ready()
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.4
	physics_material_override = pm

func arm() -> void:
	_arming = true
	get_tree().create_timer(ARM_TIME).timeout.connect(func():
		if is_instance_valid(self):
			_armed = true
			SFX.play("bomb_tick", global_position, -10.0, 0.1)
	)

func _process(delta: float) -> void:
	linear_velocity = linear_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	if not _armed:
		if _arming and _sprite:
			var blink := 0.4 + sin(Time.get_ticks_msec() * 0.02) * 0.2
			_sprite.modulate = Color(accent.r * blink, accent.g * blink, accent.b * blink, 1.0)
		return
	if _sprite:
		_sprite.modulate = Color(accent.r * 1.8, accent.g * 1.8, accent.b * 1.8, 1.0)
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= TRIGGER_RANGE:
			_explode()
			return

func _blast() -> void:
	_break_tiles_in_radius()
	_damage_enemies_in_radius()
	var debris := CPUParticles2D.new()
	debris.emitting = true
	debris.one_shot = true
	debris.amount = 22
	debris.lifetime = 0.5
	debris.explosiveness = 1.0
	debris.direction = Vector2.ZERO
	debris.spread = 180.0
	debris.initial_velocity_min = 160.0
	debris.initial_velocity_max = 420.0
	debris.gravity = Vector2(0, 500)
	debris.scale_amount_min = 4.0
	debris.scale_amount_max = 9.0
	debris.color = Color(0.5, 0.5, 0.55, 1.0)
	debris.z_index = 4
	get_parent().add_child(debris)
	debris.global_position = global_position
	get_tree().create_timer(1.0).timeout.connect(debris.queue_free)