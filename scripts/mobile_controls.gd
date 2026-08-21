extends CanvasLayer

const MENU_SCENES := [
	"res://scenes/intro.tscn",
	"res://scenes/game_over.tscn",
	"res://scenes/win_screen.tscn",
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var in_menu: bool = MENU_SCENES.has(scene.scene_file_path)
	visible = not get_tree().paused and not in_menu
