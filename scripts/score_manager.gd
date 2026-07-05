extends CanvasLayer

## Global scoring system.
##
## Points are awarded on enemy kills, multiplied by the current combo (see
## ComboManager). The current score is shown in a HUD during gameplay, the high
## score is persisted to disk and survives restarts.

const SAVE_PATH := "user://holy_moley_scores.cfg"
const FONT_PATH := "res://Baby Doll.otf"

var current_score := 0
var high_score := 0

var _root: Control = null
var _value_label: Label = null
var _pop_tween: Tween = null

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_high_score()
	_build_hud()

func _process(_delta: float) -> void:
	# The score HUD is only shown while actually playing a level (a mole exists
	# in the scene), so it stays hidden on menus and the end screens.
	if _root == null:
		return
	var in_game := get_tree().get_first_node_in_group("mole") != null
	if _root.visible != in_game:
		_root.visible = in_game

# --- Scoring API ---------------------------------------------------------

## Combo count doubles as the score multiplier (min 1x).
func get_multiplier() -> int:
	return maxi(1, ComboManager.combo)

## Award points for a kill worth `base`, scaled by the current combo multiplier.
## Pass the enemy's global position to spawn a floating "+points" popup.
func add_kill(base: int, world_pos = null) -> void:
	var mult := get_multiplier()
	var gained := base * mult
	current_score += gained
	_update_label()
	_pop_value_label()
	if current_score > high_score:
		high_score = current_score
		_save_high_score()
	if world_pos != null:
		_spawn_popup(gained, mult, world_pos)

## Start a fresh run (called when a new game begins from a menu/end screen).
func start_new_run() -> void:
	current_score = 0
	_update_label()

## Make sure the best score is stored (safe to call on end screens).
func finalize() -> void:
	if current_score > high_score:
		high_score = current_score
	_save_high_score()

# --- Persistence ---------------------------------------------------------

func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("score", "high_score", 0))

func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "high_score", high_score)
	cfg.save(SAVE_PATH)

# --- HUD -----------------------------------------------------------------

func _build_hud() -> void:
	var font := load(FONT_PATH) as Font

	_root = Control.new()
	_root.name = "ScoreHUD"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.position = Vector2(210, 66)
	_root.visible = false
	add_child(_root)

	var caption := Label.new()
	caption.text = "SCORE"
	caption.add_theme_font_override("font", font)
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", Color(0.95, 0.55, 0.75, 1))
	caption.add_theme_constant_override("outline_size", 4)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_root.add_child(caption)

	_value_label = Label.new()
	_value_label.position = Vector2(0, 22)
	_value_label.pivot_offset = Vector2(4, 34)
	_value_label.add_theme_font_override("font", font)
	_value_label.add_theme_font_size_override("font_size", 48)
	_value_label.add_theme_color_override("font_color", Color.WHITE)
	_value_label.add_theme_constant_override("outline_size", 6)
	_value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_root.add_child(_value_label)

	_update_label()

func _update_label() -> void:
	if _value_label:
		_value_label.text = str(current_score)

func _pop_value_label() -> void:
	if _value_label == null:
		return
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_value_label.scale = Vector2(1.25, 1.25)
	_pop_tween = create_tween()
	_pop_tween.tween_property(_value_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_popup(amount: int, mult: int, world_pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var font := load(FONT_PATH) as Font

	var lbl := Label.new()
	if mult > 1:
		lbl.text = "+%d  ×%d" % [amount, mult]
	else:
		lbl.text = "+%d" % amount
	lbl.z_index = 200
	lbl.position = world_pos + Vector2(-24, -70)
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 30 + mini(mult, 6) * 4)
	lbl.add_theme_color_override("font_color", _multiplier_color(mult))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	scene.add_child(lbl)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 80.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(lbl.queue_free)

func _multiplier_color(mult: int) -> Color:
	if mult >= 10:
		return Color(1.0, 0.2, 0.9)
	elif mult >= 7:
		return Color(1.0, 0.25, 0.25)
	elif mult >= 5:
		return Color(1.0, 0.55, 0.1)
	elif mult >= 3:
		return Color(1.0, 0.9, 0.2)
	elif mult >= 2:
		return Color(0.5, 1.0, 0.5)
	return Color.WHITE
