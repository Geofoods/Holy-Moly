extends Area2D

signal opened

var is_open := false
var is_breaking := false
var player_nearby := false
@export var item: ItemData = null

@onready var chest_base: Control = _first(["Interaction/Base", "Base"]) as Control
@onready var chest_band: Control = _first(["Interaction/Band", "Band"]) as Control
@onready var chest_lock: Control = _first(["Interaction/Lock", "Lock"]) as Control
@onready var chest_lid: Node2D = _first(["Interaction/Lid", "Lid"]) as Node2D
@onready var chest_prompt: Label = $PromptLabel

func _first(candidates: Array[String]) -> Node:
	for path in candidates:
		var node := get_node_or_null(path)
		if node:
			return node
	return null

func _input(event: InputEvent) -> void:
	if not player_nearby or is_open:
		return
	if event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo:
		_open_chest()

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if not player_nearby or is_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_open_chest()

const QUERY_INTERVAL := 0.1
var _query_timer := 0.0

func _process(delta: float) -> void:
	if is_open:
		if chest_prompt:
			chest_prompt.visible = false
		return
	_query_timer -= delta
	if _query_timer > 0.0:
		return
	_query_timer = QUERY_INTERVAL
	var bodies := get_overlapping_bodies()
	player_nearby = false
	for b in bodies:
		if b.is_in_group("mole"):
			if _has_line_of_sight(b):
				player_nearby = true
			break
	if chest_prompt:
		chest_prompt.visible = player_nearby

func _has_line_of_sight(target: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.collider == target

func _open_chest() -> void:
	is_open = true
	add_to_group("opened_chest")
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

func break_as_block() -> void:
	if not is_open or is_breaking:
		return
	is_breaking = true
	remove_from_group("opened_chest")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var chest_body := get_parent()
	if chest_body is CollisionObject2D:
		chest_body.set_deferred("collision_layer", 0)
		chest_body.set_deferred("collision_mask", 0)
	if chest_prompt:
		chest_prompt.visible = false
	SFX.play("break_wood", global_position, -4.0, 0.08)

	_play_break_shatter()

func _get_loot_item() -> ItemData:
	if item != null:
		return item
	var drill := preload("res://resources/drill.tres")
	var holy_water := preload("res://resources/holy_water.tres")
	if _is_final_stage():
		return drill if randf() < 0.7 else holy_water
	var bomb := preload("res://resources/bomb.tres")
	var ice_bomb := preload("res://resources/ice_bomb.tres")
	var golden_bomb := preload("res://resources/golden_bomb.tres")
	var rations := preload("res://resources/miners_rations.tres")
	var honeycomb := preload("res://resources/potted_honeycomb.tres")
	var roll := randf()
	if roll < 0.25:
		return ice_bomb
	if roll < 0.4:
		return bomb
	if roll < 0.55:
		return golden_bomb
	if roll < 0.7:
		return drill
	if roll < 0.8:
		return rations
	if roll < 0.92:
		return honeycomb
	return holy_water

func _is_final_stage() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path.ends_with("level_09.tscn")

func _grant_item() -> void:
	var loot := _get_loot_item()
	var dropped_item_scene := preload("res://scenes/dropped_item.tscn")
	var dropped_item = dropped_item_scene.instantiate()
	dropped_item.item_data = loot
	var chest_body := get_parent()
	var chest_scene_parent := chest_body.get_parent() if chest_body else null
	if chest_scene_parent == null:
		chest_scene_parent = get_tree().current_scene
	chest_scene_parent.add_child(dropped_item)
	dropped_item.global_position = global_position + Vector2(0, -20)

	SFX.play("coin", global_position, -6.0, 0.1)

func _play_break_shatter() -> void:
	if chest_lid:
		chest_lid.visible = false
	if chest_base:
		chest_base.visible = false
	if chest_band:
		chest_band.visible = false
	if chest_lock:
		chest_lock.visible = false

	var chest_body := get_parent()
	var pieces: Array[Control] = []
	var piece_defs := [
		{"color": Color(0.4, 0.25, 0.12, 1.0), "rect": Rect2(-45, -50, 90, 60), "offset": Vector2(-12, -8)},
		{"color": Color(0.4, 0.25, 0.12, 1.0), "rect": Rect2(-45, 10, 90, 14), "offset": Vector2(10, 14)},
		{"color": Color(0.18, 0.11, 0.05, 1.0), "rect": Rect2(-45, -22, 90, 12), "offset": Vector2(-14, 4)},
		{"color": Color(0.85, 0.7, 0.2, 1.0), "rect": Rect2(-8, -24, 16, 16), "offset": Vector2(18, -6)},
		{"color": Color(0.55, 0.38, 0.16, 1.0), "rect": Rect2(-45, -14, 90, 14), "offset": Vector2(-22, -18)},
		{"color": Color(0.55, 0.38, 0.16, 1.0), "rect": Rect2(-45, -50, 90, 14), "offset": Vector2(20, -20)},
		{"color": Color(0.4, 0.25, 0.12, 1.0), "rect": Rect2(-45, -8, 90, 18), "offset": Vector2(-20, 10)},
		{"color": Color(0.18, 0.11, 0.05, 1.0), "rect": Rect2(-45, -30, 90, 10), "offset": Vector2(16, 8)},
	]

	for entry in piece_defs:
		var piece := ColorRect.new()
		piece.color = entry["color"]
		piece.position = entry["rect"].position
		piece.size = entry["rect"].size
		piece.z_index = 15
		piece.modulate.a = 1.0
		chest_body.add_child(piece)
		pieces.append(piece)
		piece.position += entry["offset"]

	var tween := create_tween()
	tween.set_parallel(true)
	for piece in pieces:
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.6, -0.2)).normalized()
		var target := piece.position + dir * randf_range(45.0, 120.0)
		tween.tween_property(piece, "position", target, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(piece, "rotation_degrees", randf_range(-160.0, 160.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(piece, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(Callable(chest_body, "queue_free"))


func _play_open_animation() -> void:
	var lid := chest_lid
	var glow := _first(["Interaction/Glow", "Glow"])

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
