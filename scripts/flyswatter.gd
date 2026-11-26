extends Node2D

## One-shot swat dropped at the cursor. The sprite sheet's third frame is the
## slap, so the damage lands there; the rest of the animation is just the follow
## through. Bugs (ant, beetle, hornet) die outright, the snail takes a big chunk.

const HIT_FRAME := 2
const SWAT_RADIUS := 110.0
const BUG_KILL_DAMAGE := 9999.0
const SNAIL_DAMAGE := 200.0
const REGULAR_DAMAGE := 1.0
const EnemyBase := preload("res://scripts/enemy.gd")
const BUG_SCRIPTS := [
	"res://scripts/enemy.gd",
	"res://scripts/beetle_enemy.gd",
	"res://scripts/hornet_enemy.gd",
]
const SNAIL_SCRIPT := "res://scripts/snail_dialogue.gd"

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
var _hit_done := false

func _ready() -> void:
	# The sheet's swatter head sits up and to the left of the frame centre.
	_sprite.offset = Vector2(-60, 40)
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(queue_free)
	_sprite.play(&"swat")

func _on_frame_changed() -> void:
	if _hit_done or _sprite.frame < HIT_FRAME:
		return
	_hit_done = true
	_swat()

func _swat() -> void:
	var shape := CircleShape2D.new()
	shape.radius = SWAT_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit_enemies := {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var area := result["collider"] as Area2D
		if area == null or not area.is_in_group("enemy_hurtbox"):
			continue
		var enemy := area.get_parent()
		if enemy == null or not is_instance_valid(enemy) or hit_enemies.has(enemy):
			continue
		hit_enemies[enemy] = true
		var script_path: String = enemy.get_script().resource_path if enemy.get_script() else ""
		if script_path in BUG_SCRIPTS:
			enemy.take_damage(BUG_KILL_DAMAGE, Vector2.DOWN)
		elif script_path == SNAIL_SCRIPT and enemy.has_method("take_saw_damage"):
			enemy.take_saw_damage(SNAIL_DAMAGE)
		elif enemy.has_method("take_damage"):
			var away: Vector2 = (enemy.global_position - global_position).normalized()
			enemy.take_damage(REGULAR_DAMAGE, away)
			EnemyBase.apply_blast_knockback(enemy, global_position)
	SFX.play("enemy_hit", global_position, -4.0, 0.1, 1.3)
