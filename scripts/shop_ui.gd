extends CanvasLayer

const ITEMS_PER_PAGE := 4

const COL_BG := Color(0.93, 0.85, 0.66, 1)
const COL_BORDER := Color(0.42, 0.28, 0.14, 1)
const COL_INNER_BG := Color(0.97, 0.91, 0.78, 1)
const COL_INNER_BORDER := Color(0.6, 0.44, 0.24, 0.6)
const COL_TEXT := Color(0.32, 0.2, 0.08, 1)
const COL_BODY := Color(0.2, 0.14, 0.06, 1)
const COL_MUTED := Color(0.5, 0.4, 0.25, 1)
const COL_ACCENT := Color(0.55, 0.35, 0.1, 1)
const COL_GOLD := Color(0.6, 0.42, 0.1, 1)
const COL_RED := Color(0.55, 0.15, 0.15, 1)
const COL_OWNED := Color(0.3, 0.55, 0.25, 1)
const COL_BTN := Color(0.8, 0.68, 0.46, 1)
const COL_BTN_HOT := Color(0.97, 0.91, 0.78, 1)
const COL_BTN_DISABLED := Color(0.72, 0.64, 0.5, 1)
const COL_DISABLED_TEXT := Color(0.55, 0.45, 0.32, 1)
const COL_CLOSE := Color(0.72, 0.1, 0.18, 1)
const COL_CLOSE_HOT := Color(0.9, 0.15, 0.25, 1)

var _font := preload("res://Baby Doll.otf")
var _rows: VBoxContainer = null
var _coin_label: Label = null
## Transient line under the coin count, used for feedback that a purchase was
## refused (a full inventory cannot be shown by the row itself).
var _status: Label = null
var _status_tween: Tween = null
var _panel: PanelContainer = null
var _dim: ColorRect = null
var _closing := false
var _page := 0
var shop_type := "weapons"
## Which page of the panel is up: "buy" (the shop's own stock) or "sell" (the
## mole's inventory, bought back at half price).
var _tab := "buy"
var _tab_buy: Button = null
var _tab_sell: Button = null
var _title: Label = null
var _hint: Label = null
var _page_label: Label = null
var _prev_btn: Button = null
var _next_btn: Button = null
var _pager: HBoxContainer = null
var _button_tweens: Dictionary = {}

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	tree_exiting.connect(_on_tree_exiting)
	_build_ui()
	_refresh()
	_play_open_anim.call_deferred()

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 20
	root.theme = theme

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.clip_contents = true
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(980, 0)
	_panel.add_theme_stylebox_override("panel", _make_style_box(COL_BG, COL_BORDER, 18, 5, true))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = _buy_title()
	title.add_theme_color_override("font_color", COL_TEXT)
	title.add_theme_font_size_override("font_size", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_title = title

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(46, 46)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_stylebox_override("normal", _make_style_box(COL_CLOSE, Color(0.03, 0.03, 0.03, 1), 8, 2))
	for state in ["hover", "pressed", "focus"]:
		close_btn.add_theme_stylebox_override(state, _make_style_box(COL_CLOSE_HOT, Color(0.03, 0.03, 0.03, 1), 8, 2))
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	_coin_label = Label.new()
	_coin_label.add_theme_color_override("font_color", COL_GOLD)
	_coin_label.add_theme_font_size_override("font_size", 22)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_coin_label)

	_status = Label.new()
	_status.add_theme_color_override("font_color", COL_RED)
	_status.add_theme_font_size_override("font_size", 20)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size.y = 26
	_status.modulate.a = 0.0
	vbox.add_child(_status)

	var tab_bar := HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", 10)
	vbox.add_child(tab_bar)
	_tab_buy = _make_plain_btn("BUY")
	_tab_buy.custom_minimum_size = Vector2(170, 44)
	_tab_buy.add_theme_font_size_override("font_size", 22)
	_tab_buy.pressed.connect(func() -> void: _set_tab("buy"))
	tab_bar.add_child(_tab_buy)
	_tab_sell = _make_plain_btn("SELL")
	_tab_sell.custom_minimum_size = Vector2(170, 44)
	_tab_sell.add_theme_font_size_override("font_size", 22)
	_tab_sell.pressed.connect(func() -> void: _set_tab("sell"))
	tab_bar.add_child(_tab_sell)

	var content := PanelContainer.new()
	content.add_theme_stylebox_override("panel", _make_style_box(COL_INNER_BG, COL_INNER_BORDER, 12, 3))
	vbox.add_child(content)

	var rows_margin := MarginContainer.new()
	rows_margin.add_theme_constant_override("margin_left", 20)
	rows_margin.add_theme_constant_override("margin_right", 20)
	rows_margin.add_theme_constant_override("margin_top", 12)
	rows_margin.add_theme_constant_override("margin_bottom", 12)
	content.add_child(rows_margin)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	rows_margin.add_child(_rows)

	_pager = HBoxContainer.new()
	_pager.alignment = BoxContainer.ALIGNMENT_CENTER
	_pager.add_theme_constant_override("separation", 16)
	_prev_btn = _make_plain_btn("< PREV")
	_prev_btn.pressed.connect(func() -> void:
		_page = maxi(_page - 1, 0)
		_refresh()
	)
	_pager.add_child(_prev_btn)
	_page_label = Label.new()
	_page_label.custom_minimum_size = Vector2(120, 0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_color_override("font_color", COL_MUTED)
	_page_label.add_theme_font_size_override("font_size", 20)
	_pager.add_child(_page_label)
	_next_btn = _make_plain_btn("NEXT >")
	_next_btn.pressed.connect(func() -> void:
		_page = mini(_page + 1, _total_pages() - 1)
		_refresh()
	)
	_pager.add_child(_next_btn)
	vbox.add_child(_pager)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	var hint := Label.new()
	hint.text = "Press E or click to equip  |  ESC to close"
	hint.add_theme_color_override("font_color", COL_MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hint)
	_hint = hint
	var close_bottom := _make_plain_btn("CLOSE")
	close_bottom.pressed.connect(_close)
	bottom.add_child(close_bottom)
	vbox.add_child(bottom)

func _make_style_box(bg: Color, border: Color, radius: int, border_width: int = 2, shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_width)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 16
	return sb

func _make_plain_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.mouse_entered.connect(_on_button_hover.bind(btn))
	btn.mouse_exited.connect(_on_button_unhover.bind(btn))
	btn.pressed.connect(_on_button_pressed.bind(btn))
	btn.custom_minimum_size = Vector2(120, 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_disabled_color", COL_DISABLED_TEXT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("normal", _make_style_box(COL_BTN, COL_BORDER, 8, 2))
	btn.add_theme_stylebox_override("hover", _make_style_box(COL_BTN_HOT, COL_BORDER, 8, 2))
	btn.add_theme_stylebox_override("pressed", _make_style_box(COL_BTN_HOT, COL_BORDER, 8, 2))
	btn.add_theme_stylebox_override("focus", _make_style_box(COL_BTN_HOT, COL_BORDER, 8, 2))
	btn.add_theme_stylebox_override("disabled", _make_style_box(COL_BTN_DISABLED, Color(0.42, 0.28, 0.14, 0.6), 8, 2))
	return btn

func _on_button_hover(button: Button) -> void:
	if button.disabled:
		return
	SFX.play_ui("ui_hover", -18.0, 1.8)
	_animate_button(button, Vector2(1.035, 1.035), 0.12, Tween.TRANS_BACK)

func _on_button_unhover(button: Button) -> void:
	_animate_button(button, Vector2.ONE, 0.1, Tween.TRANS_SINE)

func _on_button_pressed(button: Button) -> void:
	SFX.play_ui("ui_click", -10.0, 1.1)
	_animate_button(button, Vector2(0.96, 0.96), 0.06, Tween.TRANS_QUAD)

func _animate_button(button: Button, target_scale: Vector2, duration: float, transition: Tween.TransitionType) -> void:
	var button_id := button.get_instance_id()
	var old_tween: Tween = _button_tweens.get(button_id)
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	var tween := create_tween()
	_button_tweens[button_id] = tween
	tween.tween_property(button, "scale", target_scale, duration).set_trans(transition).set_ease(Tween.EASE_OUT)

func _list() -> Array:
	return Shop.get_shop_list(shop_type)

func _buy_title() -> String:
	match shop_type:
		"abilities":
			return "ABILITY SHOP"
		"items":
			return "ITEM SHOP"
		"all":
			return "GENERAL STORE"
		_:
			return "WEAPON SHOP"

func _set_tab(tab: String) -> void:
	if _tab == tab:
		return
	_tab = tab
	_page = 0
	_refresh()

## Highlights the tab that is up. Done by swapping the button's normal stylebox
## and text colour rather than disabling it, so the active tab still reads as a
## live button.
func _style_tab(button: Button, active: bool) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_style_box(COL_BTN_HOT if active else COL_BTN, COL_BORDER, 8, 2))
	button.add_theme_color_override("font_color", COL_ACCENT if active else COL_TEXT)

func _refresh() -> void:
	if _coin_label:
		_coin_label.text = "Coins: %d" % Shop.coins
	_style_tab(_tab_buy, _tab == "buy")
	_style_tab(_tab_sell, _tab == "sell")
	if not _rows:
		return
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()

	if _tab == "sell":
		if _title:
			_title.text = "SELL ITEMS"
		if _hint:
			_hint.text = "Sell loot for half price  |  ESC to close"
		if _pager:
			_pager.visible = false
		_build_sell_rows()
		return

	if _title:
		_title.text = _buy_title()
	if _hint:
		_hint.text = "Press E or click to equip  |  ESC to close"
	var list := _list()
	var pages := _page_count(list.size())
	_page = clampi(_page, 0, pages - 1)
	var start := _page * ITEMS_PER_PAGE
	var end := mini(start + ITEMS_PER_PAGE, list.size())
	for i in range(start, end):
		if list[i] is ItemData:
			_rows.add_child(_make_item_row(list[i] as ItemData))
		else:
			_rows.add_child(_make_row(list[i] as WeaponData))
	if _page_label:
		_page_label.text = "Page %d / %d" % [_page + 1, pages]
	if _prev_btn:
		_prev_btn.disabled = _page <= 0
	if _next_btn:
		_next_btn.disabled = _page >= pages - 1
	if _pager:
		_pager.visible = pages > 1

## One row per occupied inventory slot. The mole only has four slots, so this
## never needs a pager. An empty inventory gets a hint line instead of a blank
## panel, which would look like a bug.
func _build_sell_rows() -> void:
	var any := false
	for i in Inventory.MAX_SLOTS:
		var item: ItemData = Inventory.slots[i]
		if item == null:
			continue
		any = true
		_rows.add_child(_make_sell_row(i, item, int(Inventory.slot_counts[i])))
	if any:
		return
	var empty := Label.new()
	empty.text = "NOTHING TO SELL - GO FIND SOME LOOT!"
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.custom_minimum_size = Vector2(0, 56)
	empty.add_theme_color_override("font_color", COL_MUTED)
	empty.add_theme_font_size_override("font_size", 20)
	_rows.add_child(empty)

func _make_sell_row(slot: int, item: ItemData, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size.y = 56

	var name := Label.new()
	name.text = item.item_name if count <= 1 else "%s x%d" % [item.item_name, count]
	name.custom_minimum_size.x = 200
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", COL_TEXT)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)

	var desc := Label.new()
	desc.text = item.description
	desc.custom_minimum_size.x = 360
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc.add_theme_color_override("font_color", COL_BODY)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(desc)

	var price := Shop.get_sell_price(item)
	var price_label := Label.new()
	price_label.custom_minimum_size.x = 96
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 20)
	if price <= 0:
		price_label.text = "—"
		price_label.add_theme_color_override("font_color", COL_MUTED)
	else:
		price_label.text = "$%d" % price
		price_label.add_theme_color_override("font_color", COL_GOLD)
	row.add_child(price_label)

	var btn := _make_plain_btn("SELL")
	btn.custom_minimum_size = Vector2(140, 40)
	btn.disabled = price <= 0
	btn.pressed.connect(func() -> void:
		if Shop.sell_inventory_slot(slot):
			_refresh()
	)
	row.add_child(btn)
	return row

func _page_count(size: int) -> int:
	return maxi(ceili(float(size) / float(ITEMS_PER_PAGE)), 1)

func _total_pages() -> int:
	return _page_count(_list().size())

func _make_row(w: WeaponData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size.y = 56

	var name := Label.new()
	name.text = w.display_name
	name.custom_minimum_size.x = 180
	name.add_theme_font_size_override("font_size", 24)
	name.add_theme_color_override("font_color", COL_TEXT)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)

	var desc := Label.new()
	desc.text = w.description
	desc.custom_minimum_size.x = 380
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc.add_theme_color_override("font_color", COL_BODY)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(desc)

	var price := Label.new()
	price.custom_minimum_size.x = 96
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 20)
	if Shop.owns(w.id):
		price.text = "OWNED"
		price.add_theme_color_override("font_color", COL_OWNED)
	else:
		price.text = "$%d" % w.price
		price.add_theme_color_override("font_color", COL_GOLD if Shop.coins >= w.price else COL_RED)
	row.add_child(price)

	var btn := _make_plain_btn("BUY")
	btn.custom_minimum_size = Vector2(140, 40)
	if Shop.owns(w.id):
		var equipped: bool = (w.id == Shop.equipped_melee_id) or (w.id == Shop.equipped_ranged_id)
		if w.weapon_type == WeaponData.Type.ABILITY:
			btn.text = "OWNED"
			btn.disabled = true
		elif equipped:
			btn.text = "EQUIPPED"
			btn.disabled = true
		else:
			btn.text = "EQUIP"
			btn.pressed.connect(func() -> void:
				Shop.equip(w.id)
				_refresh()
			)
	else:
		btn.text = "BUY"
		btn.disabled = Shop.coins < w.price
		btn.pressed.connect(func() -> void:
			if Shop.buy(w):
				_refresh()
		)
	row.add_child(btn)
	return row

func _make_item_row(item: ItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size.y = 56

	var name := Label.new()
	name.text = item.item_name
	name.custom_minimum_size.x = 200
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", COL_TEXT)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)

	var desc := Label.new()
	desc.text = item.description
	desc.custom_minimum_size.x = 360
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc.add_theme_color_override("font_color", COL_BODY)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(desc)

	var price: int = int(Shop.item_prices.get(item.item_name, 0))
	var price_label := Label.new()
	price_label.custom_minimum_size.x = 96
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 20)
	price_label.text = "$%d" % price
	price_label.add_theme_color_override("font_color", COL_GOLD if Shop.coins >= price else COL_RED)
	row.add_child(price_label)

	var btn := _make_plain_btn("BUY")
	btn.custom_minimum_size = Vector2(140, 40)
	btn.disabled = Shop.coins < price
	btn.pressed.connect(func() -> void:
		if Shop.buy_item(item):
			_refresh()
		elif not _can_carry():
			_set_status("INVENTORY IS FULL - USE SOMETHING FIRST", COL_RED)
		else:
			_set_status("NOT ENOUGH COINS", COL_RED)
	)
	row.add_child(btn)
	return row

## Mirrors Inventory.add_item's slot rules so a refused purchase can say why.
## The BUY button is only disabled on coins, so a full inventory is otherwise a
## dead click - and buy_item deliberately charges nothing when it refuses.
func _can_carry() -> bool:
	return Inventory.has_empty_slot()

func _set_status(text: String, color: Color) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", color)
	_status.modulate.a = 1.0
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(1.4)
	_status_tween.tween_property(_status, "modulate:a", 0.0, 0.4)

func _play_open_anim() -> void:
	_panel.pivot_offset = _panel.size / 2.0
	_panel.resized.connect(func() -> void:
		_panel.pivot_offset = _panel.size / 2.0
	)
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()

func _on_tree_exiting() -> void:
	get_tree().paused = false

func _close() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 0.0, 0.15)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.15)
	tween.tween_callback(queue_free)
