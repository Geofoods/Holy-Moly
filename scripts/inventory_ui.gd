extends CanvasLayer

const SLOT_COUNT := 3
const SLOT_SIZE := Vector2(84, 84)
const SLOT_GAP := 14

var slot_panels: Array = []
var slot_icons: Array = []
var slot_textures: Array = []
var slot_labels: Array = []
var _placeholder_textures: Dictionary = {}

func _make_colored_texture(color: Color) -> Texture2D:
	var key := str(color)
	if key in _placeholder_textures:
		return _placeholder_textures[key]
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
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
	var container := Node2D.new()
	container.name = "InventoryContainer"
	add_child(container)

	var total_width := SLOT_COUNT * SLOT_SIZE.x + (SLOT_COUNT - 1) * SLOT_GAP
	var start_x := -total_width / 2.0 + SLOT_SIZE.x / 2.0

	for i in SLOT_COUNT:
		var panel := Panel.new()
		panel.name = "Slot%d" % (i + 1)
		panel.size = SLOT_SIZE
		panel.position = Vector2(start_x + i * (SLOT_SIZE.x + SLOT_GAP), 8)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.3, 0.35, 1)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		panel.add_theme_stylebox_override("panel", style)

		var icon_rect := ColorRect.new()
		icon_rect.name = "Icon"
		icon_rect.size = Vector2(36, 36)
		icon_rect.position = Vector2((SLOT_SIZE.x - 36) / 2, 4)
		icon_rect.color = Color(0, 0, 0, 0)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(icon_rect)

		var tex_rect := TextureRect.new()
		tex_rect.name = "IconTexture"
		tex_rect.size = Vector2(28, 28)
		tex_rect.position = Vector2((SLOT_SIZE.x - 28) / 2, 6)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand = true
		tex_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(tex_rect)

		var icon_label := Label.new()
		icon_label.name = "IconLabel"
		icon_label.size = Vector2(28, 28)
		icon_label.position = Vector2((SLOT_SIZE.x - 28) / 2, 6)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 14)
		icon_label.text = ""
		icon_label.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(icon_label)

		var num_label := Label.new()
		num_label.name = "NumLabel"
		num_label.size = Vector2(SLOT_SIZE.x, 16)
		num_label.position = Vector2(0, SLOT_SIZE.y - 14)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.add_theme_font_size_override("font_size", 11)
		num_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		num_label.text = str(i + 1)
		num_label.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(num_label)

		container.add_child(panel)
		slot_panels.append(panel)
		slot_icons.append(icon_rect)
		slot_textures.append(tex_rect)
		slot_labels.append(icon_label)

	var screen_size := get_viewport().get_visible_rect().size
	container.position = Vector2(screen_size.x / 2, screen_size.y - SLOT_SIZE.y - 16)

func _on_slots_changed(slot_indices: Array) -> void:
	for idx in slot_indices:
		_update_slot(idx)

func _on_selected_slot_changed(slot: int) -> void:
	for i in SLOT_COUNT:
		_update_slot(i)

func _update_all_slots() -> void:
	for i in SLOT_COUNT:
		_update_slot(i)

func _update_slot(idx: int) -> void:
	var item: ItemData = Inventory.slots[idx] if idx < Inventory.slots.size() else null
	var panel := slot_panels[idx] as Panel
	var icon_rect := slot_icons[idx] as ColorRect
	var tex_rect := slot_textures[idx] as TextureRect
	var icon_label := slot_labels[idx] as Label

	var style := StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6

	var is_selected := Inventory.selected_slot == idx

	if item:
		if is_selected:
			style.bg_color = Color(0.25, 0.25, 0.35, 0.95)
			style.border_color = Color(0.8, 0.8, 1.0, 1)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
		else:
			style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
			style.border_color = Color(0.5, 0.5, 0.6, 1)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2

		if item.icon_texture:
			tex_rect.texture = item.icon_texture
			tex_rect.show()
			icon_rect.color = Color(0, 0, 0, 0)
		else:
			tex_rect.texture = _make_colored_texture(item.icon_color)
			tex_rect.show()
			icon_rect.color = Color(0, 0, 0, 0)

		var count: int = Inventory.slot_counts[idx] if idx < Inventory.slot_counts.size() else 0
		icon_label.text = str(count) if count > 1 else ""
	else:
		if is_selected:
			style.bg_color = Color(0.2, 0.2, 0.25, 0.7)
			style.border_color = Color(0.8, 0.8, 1.0, 0.5)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
		else:
			style.bg_color = Color(0.1, 0.1, 0.12, 0.6)
			style.border_color = Color(0.2, 0.2, 0.25, 1)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
		tex_rect.texture = null
		tex_rect.hide()
		icon_rect.color = Color(0, 0, 0, 0)
		icon_label.text = ""

	panel.add_theme_stylebox_override("panel", style)
