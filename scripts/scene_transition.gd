extends CanvasLayer

## Circle wipe between scenes, with a loading screen held in reserve.
##
## The tree keeps running for the whole wipe, so the level being left ticks
## behind the closing circle and the level being entered ticks behind the
## opening one. PROCESS_MODE_ALWAYS still matters: a wipe can start from an
## already-paused tree (level_results auto-advances that way, and so does the
## boss finale), and the circle has to keep drawing while everything else stays
## frozen by whoever handed off to us.
##
## Nothing being frozen is also why Inventory.transition_invulnerable is raised
## for the length of the wipe - see change_to(). It covers the mole on both
## sides of the swap, so neither can be hurt by a level it can no longer see.
##
## The next scene starts loading on a background thread the moment the wipe
## begins, so it is normally ready before the circle has closed. The loading
## screen only fades in when it isn't - when the load is still running once the
## screen is fully covered - so a quick transition never shows one.

## One wipe at a time. The pause that used to accompany a wipe kept every
## caller frozen for its length; with the tree live, a level exit or a door can
## be re-triggered while this one is still running, and a second circle would
## race this one through the scene swap.
static var _active := false

@onready var rect: ColorRect = $ColorRect

const WIPE_TIME := 0.8
const LOADING_FADE_TIME := 0.25
## Once the loading screen has appeared it stays up at least this long, so a
## load that finishes just after the circle closes doesn't flash it on screen.
const LOADING_MIN_SHOW := 0.5
const LOADING_TEXTS := ["Digging.", "Digging..", "Digging..."]
const LOADING_FONT := preload("res://Baby Doll.otf")
## The mole digging in his hole: moledig.png is his 6-frame dig strip (the
## same one mole.tscn animates), moleholebold.png the hole he digs out of.
const MOLE_HOLE_TEX := preload("res://sprites/moleholebold.png")
const MOLE_DIG_TEX := preload("res://sprites/moledig.png")
const MOLE_FRAME_SIZE := 600.0
const MOLE_FRAME_COUNT := 6
const DIG_FPS := 12.0

var _shader_material: ShaderMaterial

var _target_path := ""
var _threaded_load := false

var _loading_root: Control
var _loading_label: Label
var _loading_fill: ColorRect
var _loading_mole: Sprite2D
var _loading_mole_base_y := 0.0
var _loading_bar_width := 0.0
var _loading_shown := false
var _loading_shown_time := 0.0
var _reported_progress := 0.0

func _ready() -> void:
	# The wipe keeps drawing even when a paused scene hands off to us.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shader := preload("res://shaders/circle_wipe.gdshader")
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("progress", 0.0)
	rect.material = _shader_material
	rect.modulate.a = 1.0
	_build_loading_screen()

func change_to(path: String) -> void:
	if path.is_empty():
		queue_free()
		return
	if _active:
		queue_free()
		return
	_active = true
	# Both levels keep ticking behind the circle, so the mole would be hit by
	# enemies, bullets and hazards it can no longer see or answer. Raising this
	# on an autoload covers the level being left and the level being entered the
	# instant it is swapped in; take_damage() reads it directly. Cleared once the
	# circle has finished opening.
	Inventory.transition_invulnerable = true
	# The level being left keeps running behind the closing circle, so the mole
	# is told to play out the movement it already had instead of reading keys
	# the player has already let go of. Front ends have no mole, hence the guard.
	var mole := get_tree().get_first_node_in_group("mole")
	if mole != null and mole.has_method("glide_into_next_scene"):
		mole.glide_into_next_scene()
	# Whatever the scene being left carried for itself is let go here rather than
	# on arrival, so a track like the village's fades out under the closing circle
	# instead of trailing into the level that comes next. Nothing here waits on
	# the scene: the fade lives on an autoload that always processes.
	#
	# Unless the level arriving wants that same track, in which case it is left
	# running and picked up again on arrival - see region_track_survives().
	if not LevelMusic.region_track_survives(path):
		LevelMusic.stop_region()
	# The load starts now, behind the closing circle. That gives it the whole
	# wipe to finish before anything would need to be shown.
	_target_path = path
	_threaded_load = ResourceLoader.load_threaded_request(path) == OK
	_shader_material.set_shader_parameter("progress", 0.0)
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, WIPE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	# The reverb rides on the master bus, so whatever a cave level set on it
	# outlives that level. Every scene change goes through here, so this is the
	# one place that has to clear it - a level that follows re-tunes it for its
	# own depth in the mole's _ready, and the menu and other front ends have no
	# mole, so they would otherwise keep echoing.
	SFX.reset_reverb()
	if path.begins_with("res://scenes/level") or path == "res://scenes/tutorial.tscn" or path == "res://scenes/map.tscn":
		Inventory.current_level_path = path
	await _swap_scene(path)
	await get_tree().process_frame
	if _loading_shown:
		# Hold the loading screen its minimum before letting it go, then fade
		# it out under the opening circle.
		while _loading_shown_time < LOADING_MIN_SHOW:
			await get_tree().process_frame
		var fade := create_tween()
		fade.tween_property(_loading_root, "modulate:a", 0.0, LOADING_FADE_TIME)
	tween = create_tween()
	tween.tween_method(_set_progress, 1.0, 0.0, WIPE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	# Always hand the tree back running. The scene just loaded manages its own
	# pause state, and a wipe can legitimately start from an already-paused
	# state - level_results auto-advances that way, and so does the boss finale.
	# Restoring whatever we found here would leave the incoming level frozen.
	get_tree().paused = false
	# The circle has opened: the new level takes damage again.
	Inventory.transition_invulnerable = false
	_active = false
	queue_free()

## Swaps in the next scene. The threaded load started when the wipe began; if
## it is already done - the usual case - the swap happens with nothing shown
## beyond the closed circle. If it is still running, the loading screen stays
## up until the loader hands the scene over.
func _swap_scene(path: String) -> void:
	if _threaded_load:
		var status := ResourceLoader.load_threaded_get_status(path)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_show_loading_screen()
			await get_tree().process_frame
			status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			if packed != null and get_tree().change_scene_to_packed(packed) == OK:
				return
	# Either the threaded request never started or it failed: fall back to the
	# plain synchronous load this used before threads were involved.
	get_tree().change_scene_to_file(path)

func _build_loading_screen() -> void:
	# Built up front but hidden, sitting above the wipe's black circle: only a
	# load that outlasts the closing wipe un-hides it.
	_loading_root = Control.new()
	_loading_root.name = "LoadingScreen"
	_loading_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_root.modulate.a = 0.0
	_loading_root.visible = false
	add_child(_loading_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.name = "Bg"
	# Pitch black, with no tint: the wipe's black circle shows through as-is.
	bg.color = Color(0, 0, 0, 1)
	_loading_root.add_child(bg)

	var vs := get_viewport().get_visible_rect().size

	# The mole digging in his hole sits at the center while the load runs -
	# the same art the mole himself digs with, so the screen reads as the game.
	var hole := Sprite2D.new()
	hole.name = "DigHole"
	hole.texture = MOLE_HOLE_TEX
	hole.scale = Vector2.ONE * 0.3
	hole.position = Vector2(vs.x * 0.5, vs.y * 0.5 - 70)
	_loading_root.add_child(hole)

	_loading_mole = Sprite2D.new()
	_loading_mole.name = "DigMole"
	var mole_tex := AtlasTexture.new()
	mole_tex.atlas = MOLE_DIG_TEX
	mole_tex.region = Rect2(0, 0, MOLE_FRAME_SIZE, MOLE_FRAME_SIZE)
	_loading_mole.texture = mole_tex
	_loading_mole.scale = Vector2.ONE * 0.3
	_loading_mole.position = hole.position + Vector2(0, -10)
	_loading_mole_base_y = _loading_mole.position.y
	_loading_root.add_child(_loading_mole)

	_loading_label = Label.new()
	_loading_label.text = LOADING_TEXTS[0]
	_loading_label.add_theme_font_override("font", LOADING_FONT)
	_loading_label.add_theme_font_size_override("font_size", 44)
	_loading_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_loading_label.add_theme_constant_override("outline_size", 8)
	_loading_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.position = Vector2(0, vs.y * 0.5 + 20)
	_loading_label.size = Vector2(vs.x, 60)
	_loading_root.add_child(_loading_label)

	_loading_bar_width = minf(420.0, vs.x * 0.5)
	var bar_pos := Vector2((vs.x - _loading_bar_width) / 2.0, vs.y * 0.5 + 94.0)

	var track := ColorRect.new()
	track.position = bar_pos
	track.size = Vector2(_loading_bar_width, 10)
	track.color = Color(0.25, 0.18, 0.11)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_root.add_child(track)

	_loading_fill = ColorRect.new()
	_loading_fill.position = bar_pos
	_loading_fill.size = Vector2(0, 10)
	_loading_fill.color = Color(0.77, 0.63, 0.42)
	_loading_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_root.add_child(_loading_fill)

func _show_loading_screen() -> void:
	if _loading_shown:
		return
	_loading_shown = true
	_loading_root.visible = true
	var fade := create_tween()
	fade.tween_property(_loading_root, "modulate:a", 1.0, LOADING_FADE_TIME)

func _process(delta: float) -> void:
	if not _loading_shown:
		return
	_loading_shown_time += delta
	# The loader only estimates progress, and the estimate can stall or jump,
	# so it is smoothed into the bar and never allowed to run backwards.
	var progress: Array = []
	ResourceLoader.load_threaded_get_status(_target_path, progress)
	if not progress.is_empty():
		_reported_progress = maxf(_reported_progress, float(progress[0]))
	_loading_fill.size.x = lerpf(_loading_fill.size.x, _loading_bar_width * _reported_progress, minf(1.0, 8.0 * delta))
	_loading_label.text = LOADING_TEXTS[int(fmod(_loading_shown_time, 1.2) / 0.4)]
	# The dig strip is a one-shot on the mole; here it ping-pongs so he keeps
	# digging for as long as the load runs.
	var cycle := int(_loading_shown_time * DIG_FPS) % (MOLE_FRAME_COUNT * 2 - 2)
	var frame := cycle if cycle < MOLE_FRAME_COUNT else MOLE_FRAME_COUNT * 2 - 2 - cycle
	(_loading_mole.texture as AtlasTexture).region = Rect2(frame * MOLE_FRAME_SIZE, 0.0, MOLE_FRAME_SIZE, MOLE_FRAME_SIZE)
	_loading_mole.position.y = _loading_mole_base_y - 4.0 * absf(sin(_loading_shown_time * 3.0))

func _set_progress(value: float) -> void:
	_shader_material.set_shader_parameter("progress", value)
