extends CanvasLayer

const HOLD_DURATION := 3.0
const SLIDE_IN_TIME := 0.4
const SLIDE_OUT_TIME := 0.3

@onready var panel: Control = $Panel
@onready var level_num_label: Label = $Panel/Margin/VBox/LevelNumLabel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var divider: ColorRect = $Panel/Margin/VBox/Divider
@onready var tip_label: Label = $Panel/Margin/VBox/TipLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(820.0, vp_size.x - 60.0), 190.0)
	panel.position = Vector2((vp_size.x - panel.size.x) / 2.0, -panel.size.y - 20.0)
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(panel.size.x / 2.0, 0.0)
	panel.scale = Vector2(0.94, 0.94)

	var scene_path := get_tree().current_scene.scene_file_path
	var info: Dictionary = LevelData.get_info(scene_path)
	if info.is_empty():
		queue_free()
		return

	level_num_label.text = "LEVEL %d" % info["number"]
	title_label.text = info["name"]
	tip_label.text = "TIP  •  " + info["tip"]

	_play()

func _play() -> void:
	var shown_y := 40.0
	var hidden_y := panel.position.y

	var tween := create_tween()
	tween.tween_property(panel, "position:y", shown_y, SLIDE_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, SLIDE_IN_TIME * 0.7)
	tween.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), SLIDE_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_DURATION - SLIDE_IN_TIME - SLIDE_OUT_TIME)
	tween.tween_property(panel, "position:y", hidden_y, SLIDE_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, SLIDE_OUT_TIME)
	tween.tween_callback(queue_free)
