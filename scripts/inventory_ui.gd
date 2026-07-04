extends CanvasLayer

const SLOT_COUNT := 3
const SLOT_SIZE := Vector2(84, 84)
const SLOT_GAP := 14
const HOTBAR_FONT := preload("res://Baby Doll.otf")
var _font: Font = HOTBAR_FONT

var slot_panels: Array = []
var slot_icons: Array = []
var slot_textures: Array = []
var slot_labels: Array = []
var _placeholder_textures: Dictionary = {}
var container: Node2D = null

func _make_colored_texture(color: Color) -> Texture2D:
	var key := str(color)
	if key in _placeholder_textures:
		return _placeholder_textures[key]
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_textures[key] = tex
	return tex

func _ready() -> void:
	_build_ui()
	Inventory.slots_changed.connect(_on_slots_changed)
	Inventory.selected_slot_changed.connect(_on_selected_slot_changed)
	_update_all_slots()

func _build_ui() -> void:
	container = Node2D.new()
	add_child(container)
	var total_width := SLOT_COUNT * SLOT_SIZE.x + (SLOT_COUNT - 1) * SLOT_GAP
	var start_x := -total_width / 2.0 + SLOT_SIZE.x / 2.0
	for i in SLOT_COUNT:
		var panel := Panel.new()
		panel.size = SLOT_SIZE
		panel.position = Vector2(start_x + i * (SLOT_SIZE.x + SLOT_GAP), 8)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("595959")
		style.border_color = Color("f266b3")
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", style)

		var icon_rect := ColorRect.new()
		icon_rect.name = "Icon"
		icon_rect.size = Vector2(64, 64)
		icon_rect.position = Vector2((SLOT_SIZE.x - 64) / 2, 4)
		icon_rect.color = Color(0, 0, 0, 0)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(icon_rect)

		var tex := TextureRect.new()
		tex.name = "IconTexture"
		tex.size = Vector2(60, 60)
		tex.position = Vector2((SLOT_SIZE.x - 60) / 2, 6)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.expand = true
		tex.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(tex)

		var icon_label := Label.new()
		icon_label.name = "IconLabel"
		icon_label.size = Vector2(60, 60)
		icon_label.position = Vector2((SLOT_SIZE.x - 60) / 2, 6)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 24)
		icon_label.add_theme_font_override("font", HOTBAR_FONT)
		icon_label.text = ""
		icon_label.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(icon_label)

		var num_label := Label.new()
		num_label.name = "NumLabel"
		num_label.size = Vector2(SLOT_SIZE.x, 18)
		num_label.position = Vector2(0, SLOT_SIZE.y - 18)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.add_theme_font_size_override("font_size", 14)
		num_label.add_theme_font_override("font", HOTBAR_FONT)
		num_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		num_label.text = str(i + 1)
		num_label.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(num_label)

		container.add_child(panel)
		slot_panels.append(panel)
		slot_textures.append(tex)
		slot_labels.append(lbl)
	var s = get_viewport().get_visible_rect().size
	container.position = Vector2(s.x/2,s.y-SLOT_SIZE.y-16)

func reposition(p): if container: container.position=p
func _on_slots_changed(a): for i in a: _update_slot(i)
func _on_selected_slot_changed(_s): _update_all_slots()
func _update_all_slots(): for i in SLOT_COUNT: _update_slot(i)

func _update_slot(idx):
	var item = Inventory.slots[idx] if idx < Inventory.slots.size() else null
	var panel = slot_panels[idx]
	var tex = slot_textures[idx]
	var lbl = slot_labels[idx]
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left=6
	style.corner_radius_top_right=6
	style.corner_radius_bottom_left=6
	style.corner_radius_bottom_right=6
	if Inventory.selected_slot==idx:
		style.bg_color=Color("707070")
		style.border_color=Color("ff8fcb")
		style.border_width_left=3
		style.border_width_top=3
		style.border_width_right=3
		style.border_width_bottom=3
	else:
		style.bg_color=Color("595959")
		style.border_color=Color("f266b3")
		style.border_width_left=2
		style.border_width_top=2
		style.border_width_right=2
		style.border_width_bottom=2
	if item:
		tex.texture = item.icon_texture if item.icon_texture else _make_colored_texture(item.icon_color)
		tex.show()
		var c = Inventory.slot_counts[idx] if idx<Inventory.slot_counts.size() else 0
		lbl.text = str(c) if c>1 else ""
	else:
		tex.texture=null
		tex.hide()
		lbl.text=""
	panel.add_theme_stylebox_override("panel",style)
