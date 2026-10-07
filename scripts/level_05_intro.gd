extends Node2D

const LEVEL_PATH := "res://scenes/level_05.tscn"
const PAN_DURATION := 1.4
const SNAIL_ZOOM := Vector2(0.9, 0.9)

signal _snail_dialogue_finished

func _ready() -> void:
	var snail := get_node_or_null("Snail")
	if Progress.has_visited(LEVEL_PATH):
		# The rescue only happens once. A later visit has no cutscene to send the
		# prisoner off with, so he is cleared here rather than left standing in a
		# room he has already been saved from.
		_remove_snail(snail)
		return

	var player_camera := get_node_or_null("CharacterBody2D2/Camera2D") as Camera2D
	if player_camera == null or snail == null:
		return

	Progress.mark_visited(LEVEL_PATH)
	_play_intro(player_camera, snail)

func _play_intro(player_camera: Camera2D, snail: Node) -> void:
	var was_paused := get_tree().paused
	get_tree().paused = true

	var pause_button := get_node_or_null("CanvasLayer/PauseButton") as Button
	var info_button := get_node_or_null("CanvasLayer/InfoButton") as Button
	var pause_menu := get_node_or_null("PauseMenu")
	if pause_menu != null:
		pause_menu.set_process_input(false)
	if pause_button != null:
		pause_button.disabled = true
	if info_button != null:
		info_button.disabled = true

	var camera := Camera2D.new()
	camera.name = "SnailIntroCamera"
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	camera.zoom = player_camera.zoom
	add_child(camera)
	camera.global_position = player_camera.global_position
	camera.make_current()
	player_camera.enabled = false

	var snail_sprite := snail.get_node_or_null("AnimatedSprite2D") as Node2D
	var focus_position := snail_sprite.global_position if snail_sprite != null else (snail as Node2D).global_position
	var pan_to_snail := camera.create_tween()
	pan_to_snail.set_parallel(true)
	pan_to_snail.tween_property(camera, "global_position", focus_position, PAN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	pan_to_snail.tween_property(camera, "zoom", SNAIL_ZOOM, PAN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await pan_to_snail.finished

	if is_instance_valid(snail) and snail.has_method("show_dialogue"):
		snail.connect("dialogue_closed", _on_snail_dialogue_closed, CONNECT_ONE_SHOT)
		snail.show_dialogue()
		await _snail_dialogue_finished

	var pan_back := camera.create_tween()
	pan_back.set_parallel(true)
	pan_back.tween_property(camera, "global_position", player_camera.global_position, PAN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	pan_back.tween_property(camera, "zoom", player_camera.zoom, PAN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await pan_back.finished

	# The prisoner's one line is the whole encounter. His own retire fade can be
	# held up by the cutscene's pause, so the removal is made unconditional here:
	# the snail is gone the moment control returns to the mole.
	_remove_snail(snail)

	camera.enabled = false
	camera.queue_free()
	player_camera.enabled = true
	player_camera.make_current()
	if pause_button != null:
		pause_button.disabled = false
	if info_button != null:
		info_button.disabled = false
	if pause_menu != null:
		pause_menu.set_process_input(true)
	get_tree().paused = was_paused

## Frees the prisoner if he is still in the level. His own remove_after_dialogue
## path may already have taken him, so a node that is already gone is left alone
## rather than freed a second time.
func _remove_snail(snail: Node) -> void:
	if is_instance_valid(snail):
		snail.queue_free()

func _on_snail_dialogue_closed() -> void:
	_snail_dialogue_finished.emit()
