extends CanvasLayer

const SLOT_COUNT := 4
const SLOT_SIZE := Vector2(84, 84)
const SLOT_GAP := 14
const HOTBAR_FONT := preload("res://Baby Doll.otf")
var _font: Font = HOTBAR_FONT

const PARCHMENT_BG := Color(0.8, 0.68, 0.46)
const PARCHMENT_BG_ACTIVE := Color(0.97, 0.91, 0.78)
const PARCHMENT_BORDER := Color(0.42, 0.28, 0.14)
const PARCHMENT_TEXT := Color(0.32, 0.2, 0.08)

var slot_panels: Array = []
var slot_icons: Array = []
var slot_textures: Array = []
var slot_labels: Array = []
var _placeholder_textures: Dictionary = {}
var _art_bounds_cache: Dictionary = {}
var container: Node2D = null
## Built once and reused, matching the shine the held Golden Shovel carries in
## the world (see sword.gd) so the hotbar reads the same way.
var _polish_material: ShaderMaterial = null
## The pop-up weapon list, shown when the melee slot is clicked. Null while the
## list is closed. It carries a full-screen catcher so a click anywhere else
## dismisses the list rather than swinging the shovel.
var _weapon_picker: Control = null
## The drawn ranged-weapon icon that replaces the melee sprite in slot 0 while
## the staff is held (Q swaps). Null until the hotbar is built.
var _ranged_icon: Control = null

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
				_on_slot_pressed(slot_idx)
		)
		var style := StyleBoxFlat.new()
		style.bg_color = PARCHMENT_BG
		style.border_color = PARCHMENT_BORDER
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
		icon_label.add_theme_color_override("font_color", PARCHMENT_TEXT)
		icon_label.text = ""
		icon_label.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(icon_label)

		# Slot 0 is the weapon slot: while the ranged weapon is held this drawn
		# icon takes the place of the melee sprite (see _update_slot).
		if i == 0:
			var ranged_icon := Control.new()
			ranged_icon.name = "RangedIcon"
			ranged_icon.size = Vector2(64, 64)
			ranged_icon.position = Vector2((SLOT_SIZE.x - 64) / 2, (SLOT_SIZE.y - 64) / 2)
			ranged_icon.mouse_filter = Control.MOUSE_FILTER_PASS
			ranged_icon.set_script(preload("res://scripts/weapon_icon.gd"))
			ranged_icon.hide()
			panel.add_child(ranged_icon)
			_ranged_icon = ranged_icon

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
func hotbar_center_y() -> float:
	if container == null:
		return get_viewport().get_visible_rect().size.y - SLOT_SIZE.y / 2.0 - 16.0 + 8.0
	return container.position.y + 8.0 + SLOT_SIZE.y / 2.0
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
		style.bg_color=PARCHMENT_BG_ACTIVE
		style.border_color=PARCHMENT_BORDER
		style.border_width_left=3
		style.border_width_top=3
		style.border_width_right=3
		style.border_width_bottom=3
	else:
		style.bg_color=PARCHMENT_BG
		style.border_color=PARCHMENT_BORDER
		style.border_width_left=2
		style.border_width_top=2
		style.border_width_right=2
		style.border_width_bottom=2
	# The weapon slot (slot 0) shows whichever weapon is active: the melee sprite
	# while the tool is in hand, the drawn ranged icon while the staff is out.
	if _ranged_icon and idx == 0:
		_ranged_icon.hide()
	if idx == 0 and _ranged_icon and Shop != null and Shop.ranged_active and Shop.has_ranged_weapon():
		var rw: WeaponData = Shop.get_ranged()
		_ranged_icon.icon_color = rw.icon_color if rw else Color(0.7, 0.35, 1.0)
		_ranged_icon.queue_redraw()
		_ranged_icon.show()
		tex.texture = null
		tex.material = null
		tex.hide()
		lbl.text = ""
		panel.add_theme_stylebox_override("panel",style)
		return
	if item:
		tex.texture = _cropped_texture(item.icon_texture) if item.icon_texture else _make_colored_texture(item.icon_color)
		tex.self_modulate = item.icon_color if item.icon_texture and item.item_name == "Shovel" else Color.WHITE
		tex.pivot_offset = tex.size / 2.0
		tex.rotation_degrees = 45.0 if item.item_name == "Shovel" else 0.0
		tex.scale = Vector2.ONE if item.item_name == "Shovel" else Vector2.ONE * 0.62
		if item.item_name == "Shovel" and Shop:
			var w := Shop.get_melee()
			if w != null and w.polished:
				if _polish_material == null:
					_polish_material = ShaderMaterial.new()
					_polish_material.shader = preload("res://shaders/gold_shine.gdshader")
				tex.material = _polish_material
			else:
				tex.material = null
		else:
			tex.material = null
		tex.show()
		var c = Inventory.slot_counts[idx] if idx < Inventory.slot_counts.size() else 0
		lbl.text = str(c) if c > 1 else (item.icon_text if item.icon_texture == null and item.icon_text != "" else "")
	else:
		tex.texture = null
		tex.self_modulate = Color.WHITE
		tex.rotation_degrees = 0.0
		tex.scale = Vector2.ONE
		tex.material = null
		tex.hide()
		lbl.text = ""
	panel.add_theme_stylebox_override("panel",style)

## Slot 0 is the shared weapon slot for every held weapon, melee and ranged
## alike. Once more than one is owned, clicking it opens the picker instead of
## just toggling selection; every other slot keeps the plain select/deselect
## behaviour.
func _on_slot_pressed(slot_idx: int) -> void:
	if slot_idx == 0 and _owned_weapons().size() > 1:
		_open_weapon_picker()
		return
	if Inventory.selected_slot == slot_idx:
		Inventory.selected_slot = -1
	else:
		Inventory.selected_slot = slot_idx

## Every held weapon the mole owns, melee and ranged alike, in catalog order -
## the order the picker lists them. The staff sits in the same list as the
## shovel and the pickaxe because they all share slot 0.
func _owned_weapons() -> Array:
	var list: Array = []
	if Shop == null:
		return list
	for w in Shop.weapon_catalog:
		if Shop.owns(w.id):
			list.append(w)
	return list

func _open_weapon_picker() -> void:
	if Shop == null or _weapon_picker != null:
		return
	var weapons := _owned_weapons()
	if weapons.is_empty():
		return
	# Choosing a weapon makes it the held weapon, so make slot 0 the active slot.
	Inventory.selected_slot = 0

	var view := get_viewport().get_visible_rect().size
	var width := 236.0
	var row_h := 48.0
	var title_h := 36.0
	var pad := 12.0
	var height := title_h + weapons.size() * row_h + pad

	_weapon_picker = Control.new()
	_weapon_picker.name = "WeaponPicker"
	_weapon_picker.size = view
	_weapon_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_weapon_picker.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_weapon_picker()
	)
	add_child(_weapon_picker)

	var panel := Panel.new()
	panel.size = Vector2(width, height)
	panel.position = _picker_panel_position(width, height)
	panel.add_theme_stylebox_override("panel", _picker_panel_style())
	_weapon_picker.add_child(panel)

	var title := Label.new()
	title.text = "WEAPONS"
	title.size = Vector2(width, title_h)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", HOTBAR_FONT)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", PARCHMENT_TEXT)
	panel.add_child(title)

	for i in weapons.size():
		panel.add_child(_make_weapon_row(weapons[i], Vector2(pad, title_h + i * row_h), width - pad * 2.0, row_h - 8.0))

func _make_weapon_row(w: WeaponData, pos: Vector2, row_width: float, row_h: float) -> Button:
	var equipped := Shop.is_active_weapon(w.id)
	var btn := Button.new()
	btn.position = pos
	btn.size = Vector2(row_width, row_h)
	btn.text = w.display_name + ("  -  equipped" if equipped else "")
	btn.tooltip_text = w.description
	btn.add_theme_font_override("font", HOTBAR_FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", PARCHMENT_TEXT)
	btn.add_theme_color_override("font_hover_color", PARCHMENT_TEXT)
	btn.add_theme_color_override("font_pressed_color", PARCHMENT_TEXT)
	var bg := Color(0.86, 0.95, 0.82) if equipped else PARCHMENT_BG
	btn.add_theme_stylebox_override("normal", _picker_row_style(bg))
	btn.add_theme_stylebox_override("hover", _picker_row_style(bg.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", _picker_row_style(bg.darkened(0.08)))
	btn.add_theme_stylebox_override("focus", _picker_row_style(Color(0, 0, 0, 0)))
	btn.pressed.connect(func() -> void:
		Shop.equip(w.id)
		_close_weapon_picker()
	)
	return btn

## Sits the list just above the melee slot, kept on screen when the hotbar is
## near an edge.
func _picker_panel_position(width: float, height: float) -> Vector2:
	var slot0: Control = slot_panels[0]
	var center_x := container.position.x + slot0.position.x + slot0.size.x / 2.0
	var view := get_viewport().get_visible_rect().size
	var pos := Vector2(
		center_x - width / 2.0,
		container.position.y + slot0.position.y - height - 10.0)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - width - 8.0))
	pos.y = maxf(8.0, pos.y)
	return pos

func _close_weapon_picker() -> void:
	if _weapon_picker == null:
		return
	_weapon_picker.queue_free()
	_weapon_picker = null

func _picker_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PARCHMENT_BG_ACTIVE
	s.border_color = PARCHMENT_BORDER
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	return s

func _picker_row_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = PARCHMENT_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s
