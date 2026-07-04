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
	var spr = get_node_or_null("../AnimatedSprite2D")
	if spr is AnimatedSprite2D:
		spr.stop()
		spr.frame = 1
	_play_open_animation()
	opened.emit()
	_grant_item()

func _grant_item() -> void:
	if item != null:
		Inventory.add_item(item)
		return

	var bomb := preload("res://resources/bomb.tres")
	var drill := preload("res://resources/drill.tres")
	var loot := bomb if randf() < 0.5 else drill
	Inventory.add_item(loot)

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
