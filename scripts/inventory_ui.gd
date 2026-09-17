extends CanvasLayer

const SLOT_COUNT := 4
const SLOT_SIZE := Vector2(84, 84)
const SLOT_GAP := 14
const HOTBAR_FONT := preload("res://Baby Doll.otf")
var _font: Font = HOTBAR_FONT

var slot_panels: Array = []
var slot_icons: Array = []
var slot_textures: Array = []
var slot_labels: Array = []
var _placeholder_textures: Dictionary = {}
var _art_bounds_cache: Dictionary = {}
var container: Node2D = null

func _cropped_texture(tex: Texture2D) -> Texture2D:
	var key := tex.resource_path
	if key != "" and key in _art_bounds_cache:
		var cached = _art_bounds_cache[key]
		if cached is Texture2D:
			return cached
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = _art_bounds(tex)
	if key != "":
		_art_bounds_cache[key] = at
	return at

func _art_bounds(tex: Texture2D) -> Rect2:
	if tex.get_width() <= 0 or tex.get_height() <= 0:
		return Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img == null or img.get_width() <= 0:
		return Rect2(Vector2.ZERO, tex.get_size())
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.03:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2(Vector2.ZERO, tex.get_size())
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))

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
	if Shop:
		Shop.loadout_changed.connect(_sync_shovel_color)
	_sync_shovel_color()
	_update_all_slots()

func _sync_shovel_color() -> void:
	if Shop == null:
		return
	var w := Shop.get_melee()
	if w == null:
		return
	for i in Inventory.slots.size():
		var item = Inventory.slots[i]
		if item != null and item.item_name == "Shovel":
			item.icon_color = w.icon_color
			_update_slot(i)

func _build_ui() -> void:
	container = Node2D.new()
	add_child(container)
	var total_width := SLOT_COUNT * SLOT_SIZE.x + (SLOT_COUNT - 1) * SLOT_GAP
	var start_x := -total_width / 2.0 + SLOT_SIZE.x / 2.0
	for i in SLOT_COUNT:
		var panel := Panel.new()
		panel.size = SLOT_SIZE
		panel.position = Vector2(start_x + i * (SLOT_SIZE.x + SLOT_GAP), 8)
		var slot_idx := i
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if Inventory.selected_slot == slot_idx:
					Inventory.selected_slot = -1
				else:
					Inventory.selected_slot = slot_idx
		)
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
		tex.size = Vector2(96, 96)
		tex.position = Vector2((SLOT_SIZE.x - 96) / 2, (SLOT_SIZE.y - 96) / 2)
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



		container.add_child(panel)
		slot_panels.append(panel)
		slot_textures.append(tex)
		slot_labels.append(icon_label)
	var s = get_viewport().get_visible_rect().size
	container.position = Vector2(s.x/2,s.y-SLOT_SIZE.y-16)

signal repositioned
func reposition(p):
	if container:
		container.position = p
		repositioned.emit()
func hotbar_left_top() -> Vector2:
	if container == null:
		return Vector2.ZERO
	var total_width := SLOT_COUNT * SLOT_SIZE.x + (SLOT_COUNT - 1) * SLOT_GAP
	return container.position + Vector2(-total_width / 2.0, 8.0)
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
		tex.texture = _cropped_texture(item.icon_texture) if item.icon_texture else _make_colored_texture(item.icon_color)
		tex.self_modulate = item.icon_color if item.icon_texture and item.item_name == "Shovel" else Color.WHITE
		tex.pivot_offset = tex.size / 2.0
		tex.rotation_degrees = 45.0 if item.item_name == "Shovel" else 0.0
		tex.scale = Vector2.ONE if item.item_name == "Shovel" else Vector2.ONE * 0.62
		tex.show()
		var c = Inventory.slot_counts[idx] if idx < Inventory.slot_counts.size() else 0
		lbl.text = str(c) if c > 1 else (item.icon_text if item.icon_texture == null and item.icon_text != "" else "")
	else:
		tex.texture = null
		tex.self_modulate = Color.WHITE
		tex.rotation_degrees = 0.0
		tex.scale = Vector2.ONE
		tex.hide()
		lbl.text = ""
	panel.add_theme_stylebox_override("panel",style)
