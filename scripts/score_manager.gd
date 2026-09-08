extends CanvasLayer

## Global scoring system.
##
## Points are awarded on enemy kills, multiplied by the current combo (see
## ComboManager). The high score is persisted to disk and survives restarts.

const SAVE_PATH := "user://holy_moley_scores.cfg"
const FONT_PATH := "res://Baby Doll.otf"

var current_score := 0
var high_score := 0

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_high_score()

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
	if current_score > high_score:
		high_score = current_score
		_save_high_score()
	if world_pos != null:
		_spawn_popup(gained, mult, world_pos)

## Start a fresh run (called when a new game begins from a menu/end screen).
func start_new_run() -> void:
	current_score = 0

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
