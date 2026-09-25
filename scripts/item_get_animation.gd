extends CanvasLayer

## The "get" fanfare: shown when a story NPC hands the mole a new tool. The item
## pops in over a burst of light, a ring of sparkles flies off it, the reward
## line rises into place underneath, and then the whole thing fades away and
## frees itself.
##
## Built in code (like [shop_ui]) so any scene can spawn it without a .tscn.
## Call [method configure] before adding it to the tree.

const LAYER := 95
const FONT_PATH := "res://Baby Doll.otf"

const ICON_SIZE := 190.0
## The icon rests above the screen centre, leaving room for the text below it.
const ICON_REST_OFFSET_Y := -70.0
## How far above that spot the icon starts, so it drops into place.
const ICON_DROP := 110.0
const GLOW_SIZE := ICON_SIZE * 3.6
const GLOW_ALPHA := 0.7

const TEXT_OFFSET_Y := 150.0
const TEXT_RISE := 26.0
const TEXT_HEIGHT := 76.0
const TEXT_FONT_SIZE := 44

const FADE_IN_TIME := 0.18
const POP_TIME := 0.45
const HOLD_TIME := 1.6
const FADE_OUT_TIME := 0.5

var _message := ""
var _icon: Texture2D = null
var _tint := Color.WHITE

var _root: Control = null
var _glow: TextureRect = null
var _icon_rect: TextureRect = null
var _text_label: Label = null
var _sparkles: CPUParticles2D = null

func configure(message: String, icon: Texture2D, tint: Color) -> void:
	_message = message
	_icon = icon
	_tint = tint

func _ready() -> void:
	layer = LAYER
	# The reward can land while the game is paused: the arena pans its camera
	# back to the fight the moment the snail's dialogue closes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_play()

func _build() -> void:
	var view := get_viewport().get_visible_rect().size
	var icon_center := view * 0.5 + Vector2(0.0, ICON_REST_OFFSET_Y)

	_root = Control.new()
	_root.name = "ItemGetRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)

	_glow = TextureRect.new()
	_glow.name = "Glow"
	_glow.texture = _glow_texture()
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.size = Vector2(GLOW_SIZE, GLOW_SIZE)
	_glow.position = icon_center - _glow.size * 0.5
	_glow.pivot_offset = _glow.size * 0.5
	_glow.modulate = Color(_tint.r, _tint.g, _tint.b, GLOW_ALPHA)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_glow)

	if _icon != null:
		_icon_rect = TextureRect.new()
		_icon_rect.name = "ItemIcon"
		_icon_rect.texture = _icon
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.size = Vector2(ICON_SIZE, ICON_SIZE)
		_icon_rect.position = icon_center - _icon_rect.size * 0.5
		_icon_rect.pivot_offset = _icon_rect.size * 0.5
		_icon_rect.modulate = _tint
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_icon_rect)

	_text_label = Label.new()
	_text_label.name = "Message"
	_text_label.text = _message
	_text_label.size = Vector2(view.x, TEXT_HEIGHT)
	_text_label.position = Vector2(0.0, icon_center.y + TEXT_OFFSET_Y - TEXT_HEIGHT * 0.5)
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	_text_label.add_theme_color_override("font_color", _tint.lightened(0.3))
	_text_label.add_theme_constant_override("outline_size", 7)
	_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var font := load(FONT_PATH) as Font
	if font != null:
		_text_label.add_theme_font_override("font", font)
	_root.add_child(_text_label)

	# A CanvasLayer is not affected by the camera, so a Node2D child draws in
	# screen space and can sit exactly on the icon.
	_sparkles = CPUParticles2D.new()
	_sparkles.name = "Sparkles"
	_sparkles.position = icon_center
	_sparkles.emitting = false
	_sparkles.one_shot = true
	_sparkles.amount = 28
	_sparkles.lifetime = 0.75
	_sparkles.explosiveness = 1.0
	_sparkles.direction = Vector2.ZERO
	_sparkles.spread = 180.0
	_sparkles.initial_velocity_min = 180.0
	_sparkles.initial_velocity_max = 430.0
	_sparkles.gravity = Vector2(0.0, 320.0)
	_sparkles.scale_amount_min = 3.0
	_sparkles.scale_amount_max = 8.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(_tint.r, _tint.g, _tint.b, 1.0))
	ramp.set_color(1, Color(_tint.r, _tint.g, _tint.b, 0.0))
	_sparkles.color_ramp = ramp
	add_child(_sparkles)

func _play() -> void:
	var icon_center := get_viewport().get_visible_rect().size * 0.5 + Vector2(0.0, ICON_REST_OFFSET_Y)
	var text_rest_y := icon_center.y + TEXT_OFFSET_Y - TEXT_HEIGHT * 0.5

	if _icon_rect != null:
		_icon_rect.scale = Vector2(0.3, 0.3)
		_icon_rect.position = Vector2(icon_center.x - ICON_SIZE * 0.5, icon_center.y - ICON_SIZE * 0.5 - ICON_DROP)
	_glow.scale = Vector2(0.4, 0.4)
	_glow.modulate.a = 0.0
	_text_label.position.y = text_rest_y + TEXT_RISE

	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(_root, "modulate:a", 1.0, FADE_IN_TIME)
	intro.tween_property(_glow, "scale", Vector2.ONE, POP_TIME * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(_glow, "modulate:a", GLOW_ALPHA, POP_TIME * 0.5)
	if _icon_rect != null:
		intro.tween_property(_icon_rect, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		intro.tween_property(_icon_rect, "position:y", icon_center.y - ICON_SIZE * 0.5, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_text_label, "position:y", text_rest_y, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.finished.connect(_on_intro_finished)

func _on_intro_finished() -> void:
	_sparkles.emitting = true
	SFX.play_ui("item_pickup", -3.0, 1.6)
	var outro := create_tween()
	outro.tween_interval(HOLD_TIME)
	outro.tween_property(_root, "modulate:a", 0.0, FADE_OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_callback(queue_free)

static var _cached_glow: ImageTexture = null

## Soft radial glow, generated once and shared by every fanfare.
static func _glow_texture() -> Texture2D:
	if _cached_glow != null:
		return _cached_glow
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := (size - 1) * 0.5
	for y in size:
		for x in size:
			var dist := Vector2(x - centre, y - centre).length() / centre
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))
	_cached_glow = ImageTexture.create_from_image(image)
	return _cached_glow
