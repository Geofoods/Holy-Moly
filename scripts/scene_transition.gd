extends CanvasLayer

@onready var rect: ColorRect = $ColorRect

func change_to(path: String) -> void:
	rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	queue_free()
