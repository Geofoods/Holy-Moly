extends CanvasLayer

const SHOW_DURATION := 4.5
const POP_IN_TIME := 0.35
const FADE_OUT_TIME := 0.4

@onready var panel: PanelContainer = $Panel
@onready var level_num_label: Label = $Panel/MarginContainer/VBoxContainer/LevelNumLabel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var tip_label: Label = $Panel/MarginContainer/VBoxContainer/TipLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	
	# Center the panel
	panel.size = Vector2(600.0, 220.0)
	panel.position = (vp_size - panel.size) / 2.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.7, 0.7)
	panel.pivot_offset = panel.size / 2.0

	var scene_path := get_tree().current_scene.scene_file_path
	var info: Dictionary = LevelData.get_info(scene_path)
	if info.is_empty():
		queue_free()
		return

	level_num_label.text = "LEVEL %d" % info["number"]
	title_label.text = info["name"]
	tip_label.text = "💡 " + info["tip"]

	_play()

func _play() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), POP_IN_TIME)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, POP_IN_TIME * 0.8)
	tween.tween_interval(SHOW_DURATION - POP_IN_TIME - FADE_OUT_TIME)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_callback(queue_free)
