extends Node2D

var is_swinging := false
const SWING_ARC := 2.4
const SWING_DURATION := 0.2
var hit_enemies := []

@onready var hitbox: Area2D = $Hitbox
@onready var sprite: Sprite2D = $Sprite2D

func _process(_delta: float) -> void:
	if is_swinging:
		return
	var dir := (get_global_mouse_position() - global_position).normalized()
	rotation = atan2(dir.y, dir.x)
	
	if dir.x < 0:
		sprite.flip_v = true
		sprite.rotation_degrees = -45.0
		hitbox.rotation_degrees = -45.0
	else:
		sprite.flip_v = false
		sprite.rotation_degrees = 45.0
		hitbox.rotation_degrees = 45.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not is_swinging:
		swing()

func swing() -> void:
	is_swinging = true
	hitbox.monitoring = true
	hit_enemies = []
	
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	var aim := rotation
	
	var start_angle := aim - SWING_ARC / 2.0
	var end_angle := aim + SWING_ARC / 2.0
	
	if cos(aim) < 0:
		start_angle = aim + SWING_ARC / 2.0
		end_angle = aim - SWING_ARC / 2.0
		
	rotation = start_angle
	var tween := create_tween()
	tween.tween_property(self, "rotation", end_angle, SWING_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_end_swing)

func _end_swing() -> void:
	is_swinging = false
	hitbox.monitoring = false
	hitbox.area_entered.disconnect(_on_hitbox_area_entered)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy not in hit_enemies:
			hit_enemies.append(enemy)
			if enemy.has_method("die"):
				enemy.die()
