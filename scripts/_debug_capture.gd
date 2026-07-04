extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	await get_tree().create_timer(0.3).timeout
	var root = get_parent()
	var info_button = root.get_node("CanvasLayer/InfoButton")
	var info_popup = root.get_node("InfoPopup")
	print("DEBUG: emitting InfoButton pressed")
	info_button.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	print("DEBUG: is_open = ", info_popup.is_open, " tree paused = ", get_tree().paused)
	info_popup.close()
	await get_tree().create_timer(0.3).timeout
	print("DEBUG: is_open = ", info_popup.is_open, " tree paused = ", get_tree().paused)
	print("DEBUG: TEST COMPLETE")
