extends Area2D

signal opened

var is_open := false
@export var item: ItemData = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if is_open or not body.is_in_group("mole"):
		return
	is_open = true
	_play_open_animation()
	opened.emit()
	_grant_item()

func _grant_item() -> void:
	if item == null:
		return
	Inventory.add_item(item)

func _play_open_animation() -> void:
	var lid = $Lid
	var glow = $Glow

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lid, "rotation_degrees", -110.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lid, "position:y", lid.position.y - 6.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	glow.show()
	glow.modulate.a = 0.0
	glow.scale = Vector2(0.4, 0.4)
	var glow_tween := create_tween()
	glow_tween.set_parallel(true)
	glow_tween.tween_property(glow, "modulate:a", 0.9, 0.15)
	glow_tween.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	glow_tween.chain().tween_property(glow, "modulate:a", 0.0, 0.4)
