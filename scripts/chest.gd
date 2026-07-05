extends Area2D

signal opened

var is_open := false
var player_nearby := false
@export var item: ItemData = null

func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	if not player_nearby or is_open:
		return
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		_open_chest()

func _process(_delta: float) -> void:
	if is_open:
		var prompt = $PromptLabel
		if prompt:
			prompt.visible = false
		return
	var bodies := get_overlapping_bodies()
	player_nearby = false
	for b in bodies:
		if b.is_in_group("mole"):
			player_nearby = true
			break
	var prompt = $PromptLabel
	if prompt:
		prompt.visible = player_nearby

func _open_chest() -> void:
	is_open = true
	SFX.play("chest_open", global_position)
	var spr = get_node_or_null("../AnimatedSprite2D")
	if spr is AnimatedSprite2D:
		spr.stop()
		spr.frame = 1
	_play_open_animation()
	var mole := get_tree().get_first_node_in_group("mole")
	if mole and mole.has_method("screen_shake"):
		mole.screen_shake(6.0, 0.15)
	opened.emit()
	_grant_item()

func _get_loot_item() -> ItemData:
	if item != null:
		return item
	var bomb := preload("res://resources/bomb.tres")
	var drill := preload("res://resources/drill.tres")
	var holy_water := preload("res://resources/holy_water.tres")
	var roll := randf()
	return bomb if roll < 0.4 else drill if roll < 0.8 else holy_water

func _grant_item() -> void:
	var loot := _get_loot_item()
	Inventory.add_item(loot)
	_show_item_rise(loot)

func _show_item_rise(loot: ItemData) -> void:
	if not loot.icon_texture:
		return
	var sprite := Sprite2D.new()
	sprite.texture = loot.icon_texture
	sprite.global_position = global_position + Vector2(0, -40)
	sprite.z_index = 20
	add_child(sprite)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "global_position:y", sprite.global_position.y - 80.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tween.tween_callback(sprite.queue_free)

func _play_open_animation() -> void:
	var lid = $Lid
	var glow = $Glow

	if lid:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(lid, "rotation_degrees", -110.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(lid, "position:y", lid.position.y - 6.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if glow:
		glow.show()
		glow.modulate.a = 0.0
		glow.scale = Vector2(0.4, 0.4)
		var glow_tween := create_tween()
		glow_tween.set_parallel(true)
		glow_tween.tween_property(glow, "modulate:a", 0.9, 0.15)
		glow_tween.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		glow_tween.chain().tween_property(glow, "modulate:a", 0.0, 0.4)

	# ADD: particle burst
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 16
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2(0, 400)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(1.0, 0.85, 0.3, 1.0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	fade.set_color(1, Color(1.0, 0.7, 0.1, 0.0))
	particles.color_ramp = fade
	particles.z_index = 10
	add_child(particles)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
