extends CanvasLayer

const SHOW_DURATION := 3.0
const FADE_IN_TIME := 0.35
const FADE_OUT_TIME := 0.4

@onready var vbox: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $VBoxContainer/TitleLabel

var _tween: Tween = null
var _dismissing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.modulate.a = 0.0

	var scene_path := get_tree().current_scene.scene_file_path
	var title := LevelData.get_banner_title(scene_path)
	if title.is_empty():
		queue_free()
		return

	title_label.text = title

	# Some scenes (level_02, map) carry this node with visible = false, so the
	# layer has to switch itself on or the banner never appears.
	visible = true
	_play()

func _play() -> void:
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(vbox, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_interval(SHOW_DURATION)
	_tween.tween_callback(_fade_out)

func _fade_out() -> void:
	if _dismissing:
		return
	_dismissing = true
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(vbox, "modulate:a", 0.0, FADE_OUT_TIME)
	tw.tween_callback(queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _tween and _tween.is_valid():
			_tween.kill()
		_fade_out()
