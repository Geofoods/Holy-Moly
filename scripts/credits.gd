extends Control

## Rolling end-credits crawl. The credit list is built in code so the roll can be
## measured and timed from its own layout, then scrolled from below the screen up
## through the credits to the studio cards at the end. Each entry fades up as it
## rises into view, the crawl stops on the end cards long enough to read them, and
## the last stop is THE END: it sits in the middle of the screen for a beat, the
## whole screen fades slowly to black, and the game returns to the main menu.
## A return button is always available and the roll can be fast-forwarded with
## ESC / Enter / Space or a click, so nobody gets stuck watching the whole thing.
## Skipping is held off for the first fraction of a second so a click made while
## the scene is still fading in cannot wipe the crawl out before it has been seen.

const FONT_PATH := "res://Baby Doll.otf"
const LOGO_PATH := "res://holymolylogo.png"
const RETURN_PATH := "res://scenes/intro.tscn"
const MUSIC_PATH := "res://Spirited Away - The Name of Life (Slowed + Reverb).mp3"
## Matched to the other out-of-gameplay music (the intro and game over rolls both
## sit at -14) rather than to the quieter in-game level bed, so the credits do not
## feel like they dropped in quieter than the menu the player just came from.
const MUSIC_VOLUME_DB := -14.0

const STUDIO := "Holy Moly"
const VERSION := "v0.2beta"
const COPYRIGHT_YEAR := 2026

## Crawl speed in pixels per second, and the one timing control for the whole
## roll. Slow enough that a name is still readable as it passes. Because the roll
## is measured from its own layout, a longer credit list makes the crawl last
## longer rather than rushing past it.
const CRAWL_SPEED := 55.0
## Beat of silence once THE END has the middle of the screen, before the fade.
## The one and only pause in the roll: everything above it scrolls straight past.
const END_HOLD := 3.5
## Time for that slow fade to black before the hand-off to the main menu.
const END_FADE := 2.5
## Time for one entry to fade up once it arrives, and how high up the screen that
## happens as a fraction of the height.
const ENTRY_FADE := 0.7
const ENTRY_FADE_LINE := 0.9
## Blank space the roll waits below the screen before its first entry, and the
## space it keeps travelling after the last one so it exits cleanly.
const LEAD_IN := 40.0
const TAIL := 80.0
## Space under one credit row, and how far in from the screen edge the role and
## name columns start and end.
const ROW_GAP := 24.0
const SIDE_MARGIN := 220
## Skip input is ignored for this long after the crawl starts, so the click that
## arrives with the scene does not count as a skip.
const SKIP_GRACE := 0.8

const COL_TITLE := Color(1.0, 0.88, 0.45, 1.0)
const COL_ROLE := Color(0.74, 0.85, 0.76, 1.0)
const COL_NAME := Color(0.98, 1.0, 0.98, 1.0)
const COL_MUTED := Color(0.6, 0.7, 0.62, 1.0)

## Roles and names in roll order. `section` starts a new headed group, and every
## credit is one row with the role on the left and the name on the right, which
## is how a credit roll is read rather than as a flat wall of text.
const CREDITS: Array[Dictionary] = [
	{"section": "Lead Design"},
	{"role": "Lead Designer & Programmer", "name": "George Sun"},
	{"role": "Art Director & Designer", "name": "Bryan Tang"},

	{"section": "Engineering"},
	{"role": "Gameplay & Physics", "name": "George Sun"},
	{"role": "Level Design & Tilemaps", "name": "George Sun"},
	{"role": "Enemy Behaviour & AI", "name": "George Sun"},
	{"role": "Shaders, Particles & VFX", "name": "George Sun"},
	{"role": "Save System & Progression", "name": "George Sun"},
	{"role": "Tools & Debugging", "name": "George Sun"},

	{"section": "Art & Animation"},
	{"role": "Character Art & Animation", "name": "Bryan Tang"},
	{"role": "Tiles, Terrain & Props", "name": "Bryan Tang"},
	{"role": "Environment & Lighting", "name": "Bryan Tang"},
	{"role": "Interface Art & Icons", "name": "Bryan Tang"},

	{"section": "Audio"},
	{"role": "Music & Sound Design", "name": "Bryan Tang"},
	{"role": "Sound Implementation & Mixing", "name": "George Sun"},

	{"section": "Quality Assurance"},
	{"role": "Playtesting & Bug Reports", "name": "Bryan Tang"},
	{"role": "Compatibility & Regression", "name": "George Sun"},
]

@onready var _roll: VBoxContainer = $RollClip/Roll
@onready var _return_button: Button = $ReturnButton
@onready var _skip_hint: Label = $SkipHint

var _music: AudioStreamPlayer = null
var _tween: Tween = null
var _rolling := false
var _roll_end_y := 0.0
var _roll_stop_y := 0.0
var _roll_elapsed := 0.0
var _leaving := false
var _the_end_roll: Label = null
var _fade_rect: ColorRect = null
## Roll entries waiting to fade up as they arrive.
var _entries: Array[Control] = []

func _ready() -> void:
	# The wipe out of the win screen holds the tree paused while this scene
	# loads, so without this the crawl's tween is born paused and the roll
	# only starts moving once the opening wipe hands the tree back.
	process_mode = Node.PROCESS_MODE_ALWAYS
	LevelMusic.stop()
	_start_music()
	_add_fade_rect()
	_build_roll()
	_return_button.mouse_entered.connect(_on_return_hover)
	_return_button.mouse_exited.connect(_on_return_unhover)
	# Let the freshly built roll lay itself out before measuring and scrolling it.
	await get_tree().process_frame
	_start_roll()

func _build_roll() -> void:
	_add_logo()
	_add_spacer(60.0)
	_add_label("A " + STUDIO.to_upper() + " GAME", 26, COL_MUTED, 4)
	_add_spacer(70.0)
	for entry in CREDITS:
		var section := str(entry.get("section", ""))
		if not section.is_empty():
			_add_section(section)
		if entry.has("role") and entry.has("name"):
			_add_row(str(entry["role"]), str(entry["name"]))
			_add_spacer(ROW_GAP)
	_add_spacer(80.0)
	_add_label("THANK YOU FOR PLAYING", 52, COL_TITLE, 6)
	_add_spacer(60.0)
	_add_label("PUBLISHED BY", 22, COL_MUTED, 4)
	_add_spacer(12.0)
	_add_label(STUDIO, 40, COL_NAME, 6)
	_add_spacer(60.0)
	_add_label("© %d %s. All rights reserved." % [COPYRIGHT_YEAR, STUDIO], 20, COL_MUTED, 4)
	_add_spacer(10.0)
	_add_label("Made with Godot · " + VERSION, 20, COL_MUTED, 4)
	_add_spacer(70.0)
	_the_end_roll = _add_label("THE END", 72, COL_TITLE, 8)
	_add_spacer(TAIL)

## Black curtain the ending fades down behind. Input passes straight through it
## so the return button stays usable while it closes.
func _add_fade_rect() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

## Marks an entry for the arrival fade. Everything visible in the roll goes
## through here, so the crawl opens on an empty frame instead of a wall of text
## sitting there waiting to scroll.
func _register(node: Control) -> Control:
	node.modulate.a = 0.0
	_entries.append(node)
	return node

func _add_logo() -> TextureRect:
	var logo := TextureRect.new()
	logo.texture = load(LOGO_PATH) as Texture2D
	logo.custom_minimum_size = Vector2(720, 300)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_roll.add_child(logo)
	_register(logo)
	return logo

## One credit: the role on the left, the name on the right, both sharing the row
## so the name lines up down the whole roll regardless of role length.
func _add_row(role: String, credit_name: String) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	var row := HBoxContainer.new()
	var role_label := _make_label(role, 22, COL_ROLE, 4)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _make_label(credit_name, 30, COL_NAME, 6)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(role_label)
	row.add_child(name_label)
	margin.add_child(row)
	_roll.add_child(margin)
	_register(margin)

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
	var label := _make_label(text, font_size, color, outline)
	_roll.add_child(label)
	_register(label)
	return label

func _make_label(text: String, font_size: int, color: Color, outline: int) -> Label:
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
	return label

func _add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	_roll.add_child(spacer)

## Scrolls the roll from below the screen at a constant speed until THE END sits
## in the middle of it, holds there, then closes out. There is deliberately no
## other stop in the crawl: the credits scroll straight through and only the last
## line pauses. The stop is measured after layout, so adding entries to CREDITS
## cannot knock THE END off centre.
func _start_roll() -> void:
	var viewport_h: float = size.y
	if viewport_h <= 0.0:
		viewport_h = get_viewport_rect().size.y
	_return_button.pivot_offset = _return_button.size / 2.0

	var content_h: float = _roll.get_combined_minimum_size().y
	_roll.position = Vector2(0.0, viewport_h + LEAD_IN)
	_roll_end_y = -(content_h + TAIL)
	_roll_stop_y = maxf(viewport_h * 0.5 - (_the_end_roll.position.y + _the_end_roll.size.y * 0.5), _roll_end_y)

	_roll_elapsed = 0.0
	_rolling = true
	_tween = create_tween()
	_tween.tween_property(_roll, "position:y", _roll_stop_y, (_roll.position.y - _roll_stop_y) / CRAWL_SPEED).set_trans(Tween.TRANS_LINEAR)
	_tween.tween_interval(END_HOLD)
	_tween.tween_callback(_close_out)

## Jumps the crawl to THE END, because the player asked to skip it rather than
## because it ran out. The ending that follows is exactly the one the roll plays
## on its own.
func _finish_roll() -> void:
	if not _rolling:
		return
	_rolling = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_roll.position.y = _roll_stop_y
	var tween := create_tween()
	tween.tween_interval(END_HOLD)
	tween.tween_callback(_close_out)

## Slow fade to black, then the hand-off to the main menu. Split out so the skip
## path and the natural end of the roll close out identically.
func _close_out() -> void:
	_skip_hint.visible = false
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, END_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_go_to_menu)

func _process(delta: float) -> void:
	_fade_entries()
	if _rolling:
		_roll_elapsed += delta

## Fades up each roll entry as it rises past the line near the bottom of the
## screen, so a credit arrives instead of simply being already there.
func _fade_entries() -> void:
	var line: float = size.y * ENTRY_FADE_LINE
	for entry in _entries:
		if entry.get_meta("faded", false):
			continue
		if entry.global_position.y >= line:
			continue
		entry.set_meta("faded", true)
		var tween := create_tween()
		tween.tween_property(entry, "modulate:a", 1.0, ENTRY_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
	_music.volume_db = MUSIC_VOLUME_DB
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
