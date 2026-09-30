extends Control

## Rolling end-credits crawl. The credit list is built in code so the roll can be
## measured and timed from its own layout, then scrolled from below the screen to
## above it. A return button is always available and the roll can be
## fast-forwarded with ESC / Enter / Space or a click, so nobody gets stuck
## watching the whole thing. Skipping is held off for the first fraction of a
## second so a click made while the scene is still fading in cannot wipe the
## crawl out before it has been seen.

const FONT_PATH := "res://Baby Doll.otf"
const LOGO_PATH := "res://holymolylogo.png"
const RETURN_PATH := "res://scenes/intro.tscn"
const MUSIC_PATH := "res://soundreality-crystal-cave-136472.mp3"

## The ending is timed to a fixed eighty seconds rather than derived from the
## layout, so the run time is identical on every screen size and the credit
## list below can be as long as it likes without changing it. Kept short enough
## that the crawl is unambiguously moving - the list works out to roughly nine
## thousand pixels, so this is about a hundred pixels a second, which is fast
## enough to read as scrolling and slow enough to follow a name.
const ROLL_TIME := 80.0
## Crawl speed the roll works out to, pixels per second. Kept only as a sanity
## band: however big the window or the credit list gets, the crawl never moves
## faster than this, so a long list stretches the roll instead of blurring past.
const MAX_SCROLL_SPEED := 160.0
## Blank space the roll waits below the screen before its first entry, and the
## space it keeps travelling after the last one so it exits cleanly. Kept short
## relative to an eighty second roll so there is no dead air at either end.
const LEAD_IN := 60.0
const TAIL := 120.0
## Space between one credit and the next. Generous, because at the crawl speed
## above a hundred pixels is a readable pause between names.
const CREDIT_GAP := 110.0
## Skip input is ignored for this long after the crawl starts, so the click that
## arrives with the scene does not count as a skip.
const SKIP_GRACE := 0.8
## Beat of silence between the crawl carrying its own THE END off the top of the
## screen and the centred hold card fading in.
const END_CARD_DELAY := 0.9
## How long the centred THE END sticks before it fades back out.
const END_CARD_HOLD := 3.0
## Fade time for the hold card, both in and out.
const END_CARD_FADE := 0.8

const COL_TITLE := Color(1.0, 0.88, 0.45, 1.0)
const COL_ROLE := Color(0.74, 0.85, 0.76, 1.0)
const COL_NAME := Color(0.98, 1.0, 0.98, 1.0)
const COL_TAG := Color(1.0, 0.82, 0.3, 1.0)
const COL_MUTED := Color(0.6, 0.7, 0.62, 1.0)

## Roles and names in roll order. `tag` is an optional extra line under a name,
## and `section` starts a new headed group, so the list stays readable over four
## and a half minutes instead of reading as one flat wall of text.
const CREDITS: Array[Dictionary] = [
	{"section": "Lead Design"},
	{"role": "Programming · Level Design · VFX · Abilities", "name": "George Sun"},
	{"role": "Art · Programming · Game Design", "name": "Bryan Tang", "tag": "GOAT 🐐"},

	{"section": "Code & Systems"},
	{"role": "Core Loop · The Dig · The Stomp", "name": "George Sun"},
	{"role": "Tiling & Chunking · Allegedly Efficient", "name": "George Sun"},
	{"role": "Enemy Spawn Director · Ruthless", "name": "George Sun"},
	{"role": "Physics Tuning · Iteratively · Patiently", "name": "George Sun"},
	{"role": "Shaders, Particles & Premature Optimisation", "name": "George Sun"},
	{"role": "Save System · Reluctantly", "name": "George Sun"},
	{"role": "Debugging · Mostly Other People's Code", "name": "George Sun"},
	{"role": "Feel Engineering · Juice · Screen Shake", "name": "George Sun"},
	{"role": "Game Feel · How To Stop It Feeling Sludgy", "name": "Bryan Tang"},

	{"section": "Art, Pixels & Dirt"},
	{"role": "Every Pixel · Placed By Hand · At 2am", "name": "Bryan Tang"},
	{"role": "The Mole · Modelled, Cursed, Beloved", "name": "Bryan Tang"},
	{"role": "Stalactite Composition", "name": "Bryan Tang"},
	{"role": "Mushroom Taxonomy", "name": "Bryan Tang"},
	{"role": "Ore Distribution · Uneven On Purpose", "name": "Bryan Tang"},
	{"role": "Tile Smoothing Disputes · Resolved", "name": "Bryan Tang"},
	{"role": "Debris, Dust & Unnecessary Confetti", "name": "Bryan Tang"},
	{"role": "Colour Palette · Yes It Is Blue", "name": "Bryan Tang"},
	{"role": "Grave, Potion & Gem Placement", "name": "Bryan Tang"},

	{"section": "Audio & Chaos"},
	{"role": "SFX Placement · Centimetre Accurate", "name": "Bryan Tang"},
	{"role": "Audio Mixing · Loud On Purpose", "name": "George Sun"},
	{"role": "Music Choice & Volume Disputes", "name": "Bryan Tang"},
	{"role": "Level Pacing · Arguing", "name": "Bryan Tang"},
	{"role": "QA · Found The Bugs · Made The Others", "name": "George Sun"},
	{"role": "Playtesting · Reluctant", "name": "Bryan Tang"},
]

@onready var _roll: VBoxContainer = $RollClip/Roll
@onready var _the_end: Label = $TheEnd
@onready var _return_button: Button = $ReturnButton
@onready var _skip_hint: Label = $SkipHint

var _music: AudioStreamPlayer = null
var _tween: Tween = null
var _rolling := false
var _roll_end_y := 0.0
var _roll_elapsed := 0.0
var _leaving := false

func _ready() -> void:
	# The wipe out of the win screen holds the tree paused while this scene
	# loads, so without this the crawl's tween is born paused and the roll
	# only starts moving once the opening wipe hands the tree back.
	process_mode = Node.PROCESS_MODE_ALWAYS
	LevelMusic.stop()
	_start_music()
	_the_end.modulate.a = 0.0
	_build_roll()
	_return_button.mouse_entered.connect(_on_return_hover)
	_return_button.mouse_exited.connect(_on_return_unhover)
	# Let the freshly built roll lay itself out before measuring and scrolling it.
	await get_tree().process_frame
	_start_roll()

func _build_roll() -> void:
	_add_logo()
	_add_spacer(90.0)
	_add_label("A GAME BY", 30, COL_MUTED, 4)
	_add_spacer(110.0)
	for entry in CREDITS:
		var section := str(entry.get("section", ""))
		if not section.is_empty():
			_add_section(section)
		if entry.has("role") and entry.has("name"):
			_add_credit(str(entry["role"]), str(entry["name"]), str(entry.get("tag", "")))
			_add_spacer(CREDIT_GAP)
	_add_label("THANK YOU FOR PLAYING", 46, COL_TITLE, 6)
	_add_spacer(100.0)
	_add_label("HOLY MOLEY  ·  v0.2beta", 24, COL_MUTED, 4)
	_add_spacer(30.0)
	_add_label("Made with Godot", 22, COL_MUTED, 4)
	_add_spacer(120.0)
	_add_label("THE END", 72, COL_TITLE, 8)
	_add_spacer(TAIL)

func _add_logo() -> void:
	var logo := TextureRect.new()
	logo.texture = load(LOGO_PATH) as Texture2D
	logo.custom_minimum_size = Vector2(720, 300)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_roll.add_child(logo)

func _add_credit(role: String, credit_name: String, tag: String) -> void:
	_add_label(role, 24, COL_ROLE, 4)
	_add_spacer(6.0)
	_add_label(credit_name, 42, COL_NAME, 6)
	if not tag.is_empty():
		_add_spacer(4.0)
		_add_label(tag, 26, COL_TAG, 5)

## Breaks a long roll into headed groups. The rule and the extra air either side
## are what make the difference between credits and a wall of text.
func _add_section(title: String) -> void:
	_add_spacer(90.0)
	_add_label("· · ·", 20, COL_MUTED, 0)
	_add_spacer(14.0)
	_add_label(title.to_upper(), 34, COL_TITLE, 6)
	_add_spacer(14.0)
	_add_label("· · ·", 20, COL_MUTED, 0)
	_add_spacer(40.0)

func _add_label(text: String, font_size: int, color: Color, outline: int = 4) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	var font := load(FONT_PATH) as Font
	if font != null:
		label.add_theme_font_override("font", font)
	_roll.add_child(label)
	return label

func _add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	_roll.add_child(spacer)

func _start_roll() -> void:
	var viewport_h: float = size.y
	if viewport_h <= 0.0:
		viewport_h = get_viewport_rect().size.y
	_return_button.pivot_offset = _return_button.size / 2.0

	var content_h: float = _roll.get_combined_minimum_size().y
	var start_y: float = viewport_h + LEAD_IN
	_roll.position = Vector2(0.0, start_y)
	_roll_end_y = -(content_h + TAIL)

	var travel: float = start_y - _roll_end_y
	var duration: float = maxf(ROLL_TIME, travel / MAX_SCROLL_SPEED)
	_roll_elapsed = 0.0
	_rolling = true
	_tween = create_tween()
	_tween.tween_property(_roll, "position:y", _roll_end_y, duration).set_trans(Tween.TRANS_LINEAR)
	_tween.finished.connect(_finish_roll)

## Jumps the crawl to its end, either because it finished on its own or because
## the player asked to skip it. Either way the ending plays out the same: the
## crawl clears, the centred THE END fades in and sticks, fades back out, and
## the game returns to the main menu on its own.
func _finish_roll() -> void:
	if not _rolling:
		return
	_rolling = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_roll.position.y = _roll_end_y
	_skip_hint.visible = false
	var tween := create_tween()
	# Let the crawl's own THE END clear the top of the screen before the centred
	# hold card fades in, so the two do not read as one flash.
	tween.tween_interval(END_CARD_DELAY)
	tween.tween_property(_the_end, "modulate:a", 1.0, END_CARD_FADE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(END_CARD_HOLD)
	tween.tween_property(_the_end, "modulate:a", 0.0, END_CARD_FADE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_go_to_menu)

func _process(delta: float) -> void:
	if _rolling:
		_roll_elapsed += delta

func _unhandled_input(event: InputEvent) -> void:
	if not _rolling or _roll_elapsed < SKIP_GRACE:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_finish_roll()
	elif event is InputEventMouseButton and event.pressed:
		_finish_roll()

func _start_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.stream = load(MUSIC_PATH) as AudioStream
	_music.volume_db = -17.0
	add_child(_music)
	_music.finished.connect(_music.play)
	_music.play()

func _fade_out_music() -> void:
	if _music == null or not is_instance_valid(_music):
		return
	var tween := create_tween()
	tween.tween_property(_music, "volume_db", -40.0, 0.8)
	tween.tween_callback(_music.queue_free)
	_music = null

func _on_return_hover() -> void:
	if _return_button.disabled:
		return
	SFX.play_ui("ui_hover", -18.0, 1.8)
	var tween := create_tween()
	tween.tween_property(_return_button, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_return_unhover() -> void:
	var tween := create_tween()
	tween.tween_property(_return_button, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_return_pressed() -> void:
	SFX.play_ui("ui_click")
	_go_to_menu()

## Tears down the credits and wipes to the main menu. Shared by the return button
## and the automatic hand-off at the end of THE END, and guarded so a click
## landing during the hand-off cannot start a second transition on top of it.
func _go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	_fade_out_music()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(RETURN_PATH)
