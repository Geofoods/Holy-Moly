extends Control

## Whack-a-mole, reversed: you are the mole. Dodge the shovel on a 4x2 hole
## grid with the arrow keys, surviving the timer to win coins.

const COLS := 4
const ROWS := 2
const DURATION := 30.0
const MAX_LIVES := 3
const TELEGRAPH_TIME := 0.5
const STRIKE_DURATION := 0.16
const START_DELAY := 1.0
const MAX_SHOVELS := 3

const HOLE_SCALE := 0.25
const MOLE_SCALE := 0.25
const SHOVEL_SCALE := 0.38
const HEART_SCALE := 0.18
const COL_SPACING := 240.0
const ROW_SPACING := 240.0
const MOVE_STEP := 0.032

const FONT_PATH := "res://Baby Doll.otf"
const MOLE_HOLE_TEX := preload("res://sprites/moleholebold.png")
const MOLE_DIG_TEX := preload("res://sprites/moledig.png")
const MOLE_HP_TEX := preload("res://sprites/molehp.png")
const SHOVEL_TEX := preload("res://sprites/shovel.png")

var _hole_positions: Array[Vector2] = []
var _index := 0
var _time_left := DURATION
var _lives := MAX_LIVES
var _over := false
var _whackers: Array[Dictionary] = []

var _fx: Node2D
var _mole: Sprite2D
var _shovels: Array[Sprite2D] = []
var _markers: Array[Label] = []
var _timer_label: Label
var _hearts: Array[Sprite2D] = []
var _overlay: Control = null


func _ready() -> void:
	LevelMusic.stop()
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(_layout)
	_build_static_ui()
	_layout()
	_init_fx()
	_place_mole()
	_spawn_whacker(START_DELAY)
	_hint()

func _layout() -> void:
	size = get_viewport_rect().size
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.position = Vector2.ZERO
		bg.size = size
	var board_w := (COLS - 1) * COL_SPACING
	var board_h := (ROWS - 1) * ROW_SPACING
	var ox := size.x / 2.0 - board_w / 2.0
	var oy := size.y * 0.60 - board_h / 2.0
	_hole_positions.clear()
	for r in ROWS:
		for c in COLS:
			_hole_positions.append(Vector2(ox + c * COL_SPACING, oy + r * ROW_SPACING))

	var board := get_node_or_null("Holes") as Node2D
	if board:
		for i in _hole_positions.size():
			var hole := board.get_child(i) as Sprite2D
			if hole:
				hole.position = _hole_positions[i]

	var hud := get_node_or_null("Hud") as Node2D
	if hud:
		hud.position = Vector2(size.x / 2.0 - 220, 110)

	var heart_step := 600.0 * HEART_SCALE - 26.0
	for i in _hearts.size():
		_hearts[i].position = Vector2(size.x / 2.0 + 40.0 + i * heart_step, 126.0)

	_place_mole()

func _build_static_ui() -> void:
	var font := load(FONT_PATH) as Font

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.45, 0.31, 0.19)
	add_child(background)

	var holes := Node2D.new()
	holes.name = "Holes"
	add_child(holes)
	for i in COLS * ROWS:
		var hole := Sprite2D.new()
		hole.texture = MOLE_HOLE_TEX
		hole.scale = Vector2.ONE * HOLE_SCALE
		hole.z_index = 1
		holes.add_child(hole)

	var title := Label.new()
	title.text = "WHACK-A-MOLE"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 12)
	title.size = Vector2(size.x, 60)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "You are the mole! Arrow keys to dodge the shovel."
	subtitle.add_theme_font_override("font", font)
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	subtitle.add_theme_constant_override("outline_size", 4)
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 62)
	subtitle.size = Vector2(size.x, 30)
	add_child(subtitle)

	var hud := Node2D.new()
	hud.name = "Hud"
	add_child(hud)

	_timer_label = Label.new()
	_timer_label.add_theme_font_override("font", font)
	_timer_label.add_theme_font_size_override("font_size", 30)
	_timer_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
	_timer_label.add_theme_constant_override("outline_size", 5)
	_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.size = Vector2(160, 44)
	hud.add_child(_timer_label)
	_update_timer_label()

	var heart_w := 600.0 * HEART_SCALE
	var heart_step := heart_w - 26.0
	for i in MAX_LIVES:
		var heart := Sprite2D.new()
		var tex := AtlasTexture.new()
		tex.atlas = MOLE_HP_TEX
		tex.region = Rect2(0, 0, 600, 600)
		heart.texture = tex
		heart.scale = Vector2.ONE * HEART_SCALE
		add_child(heart)
		_hearts.append(heart)

	var hint := Label.new()
	hint.text = "←  → switch holes"
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 0.9))
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.position.y = size.y - 40
	hint.size.x = size.x
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _init_fx() -> void:
	_fx = Node2D.new()
	_fx.name = "Fx"
	add_child(_fx)

	var mole_tex := AtlasTexture.new()
	mole_tex.atlas = MOLE_DIG_TEX
	mole_tex.region = Rect2(0, 0, 600, 600)
	_mole = Sprite2D.new()
	_mole.texture = mole_tex
	_mole.scale = Vector2.ONE * MOLE_SCALE
	_mole.z_index = 2
	_fx.add_child(_mole)

	for i in MAX_SHOVELS:
		var shovel := Sprite2D.new()
		shovel.texture = SHOVEL_TEX
		shovel.scale = Vector2.ONE * SHOVEL_SCALE
		shovel.z_index = 4
		shovel.visible = false
		_fx.add_child(shovel)
		_shovels.append(shovel)

		var marker := Label.new()
		marker.text = "!"
		marker.add_theme_font_override("font", load(FONT_PATH) as Font)
		marker.add_theme_font_size_override("font_size", 72)
		marker.add_theme_color_override("font_color", Color(1.0, 0.2, 0.15))
		marker.add_theme_constant_override("outline_size", 10)
		marker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.size = Vector2(90, 90)
		marker.visible = false
		marker.z_index = 3
		_fx.add_child(marker)
		_markers.append(marker)

func _hint() -> void:
	var label := Label.new()
	label.text = "SURVIVE!"
	label.add_theme_font_override("font", load(FONT_PATH) as Font)
	label.add_theme_font_size_override("font_size", 60)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, size.y * 0.36)
	label.size = Vector2(size.x, 80)
	add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _process(delta: float) -> void:
	if _over:
		return
	_time_left -= delta
	_update_timer_label()
	if _time_left <= 0.0:
		_win()
		return
	var target_count := _active_shovel_count()
	while _whackers.size() < target_count:
		_spawn_whacker()
	for i in _whackers.size():
		_update_whacker(_whackers[i], i, delta)

func _input(event: InputEvent) -> void:
	if _over or not (event is InputEventKey):
		return
	if event.is_echo() or not event.pressed:
		return
	if event.is_action("ui_left"):
		_try_move(-1, 0)
	elif event.is_action("ui_right"):
		_try_move(1, 0)
	elif event.is_action("ui_up"):
		_try_move(0, -1)
	elif event.is_action("ui_down"):
		_try_move(0, 1)

func _col() -> int:
	return _index % COLS

func _row() -> int:
	return _index / COLS

func _try_move(dx: int, dy: int) -> void:
	var c := _col() + dx
	var r := _row() + dy
	if c < 0 or c >= COLS or r < 0 or r >= ROWS:
		return
	_index = r * COLS + c
	_animate_mole_move()

func _place_mole() -> void:
	if _mole == null:
		return
	_mole.position = _hole_positions[_index] + Vector2(0, -10.0)
	_set_mole_frame(0)

func _set_mole_frame(f: int) -> void:
	(_mole.texture as AtlasTexture).region = Rect2(f * 600.0, 0.0, 600.0, 600.0)

func _animate_mole_move() -> void:
	SFX.play_ui("jump", -8.0, 1.7)
	var tween := create_tween()
	for f in range(1, 6):
		tween.tween_callback(_set_mole_frame.bind(f))
		tween.tween_interval(MOVE_STEP)
	tween.tween_interval(0.04)
	tween.tween_callback(func() -> void:
		_mole.position = _hole_positions[_index] + Vector2(0, -10.0)
	)
	for f in [4, 3, 2, 1, 0]:
		tween.tween_callback(_set_mole_frame.bind(f))
		tween.tween_interval(MOVE_STEP)

func _active_shovel_count() -> int:
	var t := 1.0 - _time_left / DURATION
	if t >= 2.0 / 3.0:
		return MAX_SHOVELS
	if t >= 1.0 / 3.0:
		return 2
	return 1

func _spawn_whacker(wait_time: float = -1.0) -> void:
	_whackers.append({
		"t": -1,
		"p": "wait",
		"tm": START_DELAY if wait_time < 0.0 else wait_time,
	})

func _update_whacker(w: Dictionary, i: int, delta: float) -> void:
	match w.p:
		"wait":
			w.tm -= delta
			if w.tm <= 0.0:
				_begin_whack(w, i)
		"telegraph":
			w.tm -= delta
			if w.tm <= 0.0:
				_do_whack(w, i)

func _whack_interval() -> float:
	var t := 1.0 - _time_left / DURATION
	return lerpf(1.15, 0.55, t)

func _pick_target(forbidden: Array[int]) -> int:
	var candidates: Array[int] = []
	for i in COLS * ROWS:
		if i not in forbidden:
			candidates.append(i)
	return candidates[randi() % candidates.size()]

func _begin_whack(w: Dictionary, i: int) -> void:
	var forbidden: Array[int] = []
	if w.t >= 0:
		forbidden.append(w.t)
	for j in _whackers.size():
		if j != i and _whackers[j].p == "telegraph":
			forbidden.append(_whackers[j].t)
	w.t = _pick_target(forbidden)

	var target_pos := _hole_positions[w.t]
	var marker := _markers[i]
	marker.position = target_pos + Vector2(-45, -150)
	marker.visible = true
	marker.scale = Vector2(1.3, 1.3)
	var pop := create_tween()
	pop.tween_property(marker, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var shovel := _shovels[i]
	shovel.scale = Vector2.ONE * SHOVEL_SCALE
	shovel.position = target_pos + Vector2(0, -168)
	shovel.rotation = -0.7
	shovel.visible = true
	var raise := create_tween()
	raise.tween_interval(0.06)
	raise.tween_property(shovel, "position", target_pos + Vector2(0, -188), 0.14).set_ease(Tween.EASE_OUT)

	SFX.play_ui("ui_click", -12.0, 1.35)
	w.p = "telegraph"
	w.tm = TELEGRAPH_TIME

func _do_whack(w: Dictionary, i: int) -> void:
	_markers[i].visible = false
	var target_pos := _hole_positions[w.t]
	SFX.play("swing", target_pos, -4.0, 0.15)
	var hit: bool = _index == w.t

	var shovel := _shovels[i]
	var tween := create_tween()
	tween.tween_property(shovel, "position", target_pos + Vector2(0, -26), STRIKE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shovel, "rotation", -0.1, STRIKE_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_property(shovel, "position", target_pos + Vector2(0, -200), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: shovel.visible = false)

	if hit:
		_take_damage()
	w.p = "wait"
	w.tm = _whack_interval() * randf_range(0.85, 1.15)

func _hide_all_whackers() -> void:
	for shovel in _shovels:
		shovel.visible = false
	for marker in _markers:
		marker.visible = false

func _take_damage() -> void:
	_lives -= 1
	_hearts[_lives].visible = false
	SFX.play_ui("hurt", -4.0, 0.85)
	SFX.play("enemy_hit", _mole.position, -2.0, 0.3)
	_shake(10.0, 0.25)
	var tween := create_tween()
	tween.tween_property(_mole, "modulate", Color(2, 0.4, 0.3, 1), 0.06)
	tween.tween_property(_mole, "modulate", Color.WHITE, 0.18)
	if _lives <= 0:
		_lose()

func _shake(amount: float, duration: float) -> void:
	var tween := create_tween()
	for i in 6:
		tween.tween_property(_fx, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), duration / 12.0)
	tween.tween_property(_fx, "position", Vector2.ZERO, 0.05)

func _update_timer_label() -> void:
	if _timer_label:
		_timer_label.text = "TIME  %02d" % ceili(maxf(_time_left, 0.0))

func _win() -> void:
	_over = true
	_hide_all_whackers()
	var reward_coins := 50 + 15 * _lives
	var reward_score := 150 * _lives
	Shop.add_coins(reward_coins)
	ScoreManager.current_score += reward_score
	ScoreManager.finalize()
	SFX.play_ui("chest_open", -6.0, 1.0)
	SFX.play_ui("coin", -4.0, 1.2)
	_show_overlay(true, "SURVIVED!", "+%d coins   •   +%d score" % [reward_coins, reward_score])

func _lose() -> void:
	_over = true
	_hide_all_whackers()
	SFX.play("death", _mole.position, -6.0, 1.0)
	_show_overlay(false, "WHACKED!", "You got shoveled. Try again!")

func _show_overlay(win: bool, head: String, body: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = get_viewport_rect().size
	layer.add_child(dim)

	_overlay = Panel.new()
	_overlay.name = "ResultPanel"
	_overlay.position = Vector2(size.x / 2.0 - 260, size.y / 2.0 - 160)
	_overlay.size = Vector2(520, 300)
	layer.add_child(_overlay)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.09, 0.97)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 14
	_overlay.add_theme_stylebox_override("panel", style)

	var font := load(FONT_PATH) as Font
	var title := Label.new()
	title.text = head
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4) if win else Color(1.0, 0.4, 0.35))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 34)
	title.size = Vector2(520, 70)
	_overlay.add_child(title)

	var body_label := Label.new()
	body_label.text = body
	body_label.add_theme_font_override("font", font)
	body_label.add_theme_font_size_override("font_size", 26)
	body_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	body_label.add_theme_constant_override("outline_size", 4)
	body_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.position = Vector2(0, 100)
	body_label.size = Vector2(520, 50)
	_overlay.add_child(body_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	buttons.position = Vector2(80, 170)
	buttons.size = Vector2(360, 76)
	_overlay.add_child(buttons)

	var retry := _make_button("PLAY AGAIN", Color(0.85, 0.55, 0.2))
	retry.pressed.connect(func() -> void: _change_scene(scene_file_path))
	buttons.add_child(retry)

	var menu := _make_button("MAIN MENU", Color(0.15, 0.55, 0.9))
	menu.pressed.connect(func() -> void: _change_scene("res://scenes/intro.tscn"))
	buttons.add_child(menu)

func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 72)
	btn.add_theme_font_override("font", load(FONT_PATH) as Font)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.03, 0.03, 0.03, 1))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.border_color = color.lightened(0.25)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.18)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)
	return btn

func _change_scene(path: String) -> void:
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(path)
