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
const COL_SPEECH_BG := Color(0.99, 0.96, 0.88, 1)
const COL_SPEECH_BORDER := Color(0.5, 0.34, 0.16, 1)

## Fallback lines for the merchant's speech bubble when a shopkeeper does not
## supply its own (see Shop.merchant_greeting / merchant_thanks).
const DEFAULT_MERCHANT_GREETING := "Have a browse, digger!"
const DEFAULT_MERCHANT_THANKS := "Pleasure doing business, digger!"
## Fallback lines for the sell tab: the pitch spoken when it is opened, and the
## thanks spoken each time the merchant buys a piece of loot back. Mirrors
## Shop.merchant_sell_pitch / merchant_sell.
const DEFAULT_MERCHANT_SELL_PITCH := "Loot to unload? I pay half of what it's worth, digger."
const DEFAULT_MERCHANT_SELL := "Sold! Always glad to take that off your hands."
## Flavour the merchant speaks for a specific trade, keyed by the item or weapon
## name. Buying and selling have their own tables so the same thing can get a
## different line depending on which way the coins are going. Anything not listed
## falls back to the merchant's one-line thanks (see Shop.merchant_thanks /
## merchant_sell), so a stall never falls quiet over an item nobody wrote for.
const BUY_LINES := {
	"Drill": "A good drill, that. Bites through stone like it owes me money.",
	"Bomb": "Mind the fuse, digger. Blow a hole in anything that annoys you.",
	"Ice Bomb": "Frozen solid in a jar. Chills a room right through, and the mood with it.",
	"Holy Water": "Blessed this batch myself. Heals what ails you, and a few things that don't.",
	"Pickaxe": "Heavy as sin and twice as mean. Swing it and the whole wall gives up.",
	"Wizard Staff": "Zaps from a distance. No idea how it works, I just sell the things.",
}
const SELL_LINES := {
	"Miner's Rations": "Rations, eh? Half-chewed, but I know a mole who'll take 'em.",
	"Potted Honeycomb": "Ooh, honeycomb. Sticky stuff, but there's a market for sweet.",
	"Drill": "A drill, lightly used. I'll polish it up and put a price on it.",
	"Bomb": "A live bomb! Careful with that on my counter, digger.",
	"Ice Bomb": "An ice bomb. I'll keep it somewhere cold. Obviously.",
	"Golden Bomb": "Golden?! Now that's a find. Coins for it, gladly.",
	"Holy Water": "You're selling holy water back to me? Fine, but don't tell the snail.",
	"Mine": "A mine, still ticking? Delightful. I'll store it very carefully.",
	"Stink Bomb": "A stink bomb. Wrap it twice before it goes under my counter.",
	"Spark Bomb": "Sparkly little thing. Somebody'll pay plenty for that bang.",
	"Flare": "A flare. Useful, cheerful, and worth a few coins to me.",
	"Coal Lump": "A lump of coal. Not glamorous, but it burns.",
	"Vacuum Jelly": "Wobbles about, this one. Odd stuff, but I'll take it off your hands.",
	"Bounce Mushroom": "A bouncy one! The kids round here love these. I'll price it high.",
	"Shiny Lure": "Shiny enough to fool a fish. I'll find it a good home.",
	"Compass Charm": "A compass charm? I'll point it at my coin purse and sell it on.",
	"Shop Token": "A shop token, back to me! Coin it in, digger.",
	"Grub Stick": "Grub stick. Chewy. Somebody out there wants it, I promise.",
	"Tunnel Gloves": "Tunnel gloves, barely scuffed. A tidy little trade.",
	"Shelled Backpack": "A shelled pack. Rugged. I'll get a good price for that.",
	"Climbing Talons": "Talons! Those I can sell to anyone with a wall to climb.",
	"Lantern Charm": "A lantern charm - handy when the dark gets thick. I'll take it.",
	"Rebound Hook": "A rebound hook. Returns to you - now it returns to my shelf.",
	"Wax Cache": "Wax cache. Sealed tight? Good. I'll shift it by nightfall.",
	"Earthquake Boots": "Earthquake boots! Mind the tremors on my floorboards.",
	"Mol-dozer Ram": "A ram for headbutting rock. Sold before I even price it.",
}
## Seconds per character the merchant's bubble takes to type a line, matching
## dialogue_box.gd so his talk reads the same here as it does in a conversation.
const TYPE_SPEED := 0.018

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
var _hint: Label = null
var _page_label: Label = null
var _prev_btn: Button = null
var _next_btn: Button = null
var _pager: HBoxContainer = null
var _button_tweens: Dictionary = {}
## Merchant portrait and speech bubble in the panel's top-left corner. The bubble
## line types itself out, then flips to a thank-you each time the player buys or
## sells with the pictured person.
var _speech: Label = null
## The whole line being typed; _speech holds only the part shown so far.
var _speech_full := ""
var _speech_type_tween: Tween = null
var _speech_flash_tween: Tween = null

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

	# Top row: the merchant pictured on the left when a stallkeeper opened the
	# panel, the coin purse beside him, and the close button pinned to the right.
	# There is no shop title - the shopkeeper standing there is the storefront.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	vbox.add_child(top_row)

	_build_merchant_block(top_row)

	# The coin purse sits to the right of the shopkeeper: a coin drawing plus the
	# running total, so the player can price a purchase up at a glance.
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 6)
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(purse)

	var coin_icon := Control.new()
	coin_icon.custom_minimum_size = Vector2(28, 28)
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_icon.set_script(preload("res://scripts/coin_hud_icon.gd"))
	purse.add_child(coin_icon)

	_coin_label = Label.new()
	_coin_label.add_theme_color_override("font_color", COL_GOLD)
	_coin_label.add_theme_font_size_override("font_size", 26)
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	purse.add_child(_coin_label)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(46, 46)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_stylebox_override("normal", _make_style_box(COL_CLOSE, Color(0.03, 0.03, 0.03, 1), 8, 2))
	for state in ["hover", "pressed", "focus"]:
		close_btn.add_theme_stylebox_override(state, _make_style_box(COL_CLOSE_HOT, Color(0.03, 0.03, 0.03, 1), 8, 2))
	# Sits at the very top-right, beside the shopkeeper rather than centred
	# against the speech bubble.
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_btn.pressed.connect(_close)
	top_row.add_child(close_btn)

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

## Adds the shopkeeper (portrait plus speech bubble) to the panel's top row when a
## merchant NPC opened the panel. A portable Shop Token panel has no face behind
## it, so the row is left with just the spacer and close button.
func _build_merchant_block(row: HBoxContainer) -> void:
	if Shop.merchant_name.is_empty() and Shop.merchant_portrait == null:
		return

	if Shop.merchant_portrait != null:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", _make_style_box(COL_INNER_BG, COL_BORDER, 10, 3))
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(frame)
		var portrait := TextureRect.new()
		portrait.texture = Shop.merchant_portrait
		portrait.custom_minimum_size = Vector2(170, 80)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(portrait)

	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _make_style_box(COL_SPEECH_BG, COL_SPEECH_BORDER, 12, 3, true))
	bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bubble)

	var bubble_margin := MarginContainer.new()
	bubble_margin.add_theme_constant_override("margin_left", 16)
	bubble_margin.add_theme_constant_override("margin_right", 16)
	bubble_margin.add_theme_constant_override("margin_top", 10)
	bubble_margin.add_theme_constant_override("margin_bottom", 10)
	bubble.add_child(bubble_margin)

	var bubble_box := VBoxContainer.new()
	bubble_box.add_theme_constant_override("separation", 2)
	bubble_margin.add_child(bubble_box)

	if not Shop.merchant_name.is_empty():
		var speaker := Label.new()
		speaker.text = Shop.merchant_name
		speaker.add_theme_color_override("font_color", COL_ACCENT)
		speaker.add_theme_font_size_override("font_size", 22)
		bubble_box.add_child(speaker)

	_speech = Label.new()
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size = Vector2(380, 0)
	_speech.add_theme_color_override("font_color", COL_BODY)
	_speech.add_theme_font_size_override("font_size", 20)
	bubble_box.add_child(_speech)
	_merchant_says(Shop.merchant_greeting if not Shop.merchant_greeting.is_empty() else DEFAULT_MERCHANT_GREETING)

## Types a fresh line into the merchant's speech bubble, letter by letter, at the
## same cadence dialogue_box.gd uses for a conversation. Any line already typing
## is replaced, so a quick string of buys or sells never overlaps itself.
func _merchant_says(text: String) -> void:
	if _speech == null:
		return
	_speech_full = text
	if _speech_type_tween != null and _speech_type_tween.is_valid():
		_speech_type_tween.kill()
	_speech.text = ""
	var count := _speech_full.length()
	if count <= 0:
		return
	_speech_type_tween = create_tween()
	_speech_type_tween.tween_method(_set_speech_typed_length, 0, count, count * TYPE_SPEED)

func _set_speech_typed_length(length: int) -> void:
	_speech.text = _speech_full.substr(0, length)

## Speaks for a purchase of `item_key` (an item or weapon name), picking his
## per-item line where there is one, with a quick flash so the change reads.
func _merchant_bought(item_key: String) -> void:
	_flash_speech()
	var fallback := Shop.merchant_thanks if not Shop.merchant_thanks.is_empty() else DEFAULT_MERCHANT_THANKS
	_merchant_says(_line_for(BUY_LINES, item_key, fallback))

## Gilbert's pitch for the buy-back service, played when the sell tab is opened.
func _merchant_sell_pitch() -> void:
	_flash_speech()
	_merchant_says(Shop.merchant_sell_pitch if not Shop.merchant_sell_pitch.is_empty() else DEFAULT_MERCHANT_SELL_PITCH)

## Gilbert's shop greeting, replayed whenever the buy tab comes back up so
## flipping over to sell and back welcomes the player again.
func _merchant_greeting() -> void:
	_flash_speech()
	_merchant_says(Shop.merchant_greeting if not Shop.merchant_greeting.is_empty() else DEFAULT_MERCHANT_GREETING)

## Speaks as he buys a piece of loot back, picking his per-item line where there
## is one for `item_key`.
func _merchant_sold(item_key: String) -> void:
	_flash_speech()
	var fallback := Shop.merchant_sell if not Shop.merchant_sell.is_empty() else DEFAULT_MERCHANT_SELL
	_merchant_says(_line_for(SELL_LINES, item_key, fallback))

## The line for `key` from one of the tables above, or `fallback` when the table
## has nothing written for it.
func _line_for(lines: Dictionary, key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var line := str(lines.get(key, ""))
	return line if not line.is_empty() else fallback

## Brightens the bubble for a beat so the swapped line stands out from the old one.
func _flash_speech() -> void:
	if _speech == null:
		return
	if _speech_flash_tween != null and _speech_flash_tween.is_valid():
		_speech_flash_tween.kill()
	_speech.modulate = Color(1.35, 1.35, 0.85, 1.0)
	_speech_flash_tween = create_tween()
	_speech_flash_tween.tween_property(_speech, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)

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

func _set_tab(tab: String) -> void:
	if _tab == tab:
		return
	_tab = tab
	_page = 0
	# Speak in the merchant's own voice as the tabs change: his buy-back pitch on
	# the sell tab, his shop greeting back on the buy tab.
	if tab == "sell":
		_merchant_sell_pitch()
	else:
		_merchant_greeting()
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
		_coin_label.text = str(Shop.coins)
	_style_tab(_tab_buy, _tab == "buy")
	_style_tab(_tab_sell, _tab == "sell")
	if not _rows:
		return
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()

	if _tab == "sell":
		if _hint:
			_hint.text = "Sell loot for half price  |  ESC to close"
		if _pager:
			_pager.visible = false
		_build_sell_rows()
		return

	if _hint:
		_hint.text = "Press E or click to equip  |  ESC to close"
	var pages := _pages()
	var total := maxi(pages.size(), 1)
	_page = clampi(_page, 0, total - 1)
	var page_items: Array = pages[_page] if _page < pages.size() else []
	for entry in page_items:
		if entry is ItemData:
			_rows.add_child(_make_item_row(entry as ItemData))
		else:
			_rows.add_child(_make_row(entry as WeaponData))
	if _page_label:
		_page_label.text = "Page %d / %d" % [_page + 1, total]
	if _prev_btn:
		_prev_btn.disabled = _page <= 0
	if _next_btn:
		_next_btn.disabled = _page >= total - 1
	if _pager:
		_pager.visible = total > 1

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
			_merchant_sold(item.item_name)
			_refresh()
	)
	row.add_child(btn)
	return row

## The stock split into the pages the pager actually shows. The shop's weapons
## fill the first page(s) and everything else follows on later pages, so the
## three tools stay together instead of ITEMS_PER_PAGE folding the shelf's first
## item onto their page.
func _pages() -> Array:
	var pages: Array = []
	var weapons: Array = []
	var rest: Array = []
	for entry in _list():
		if entry is WeaponData and (entry as WeaponData).weapon_type != WeaponData.Type.ABILITY:
			weapons.append(entry)
		else:
			rest.append(entry)
	_chunk_into(pages, weapons)
	_chunk_into(pages, rest)
	return pages

## Appends `entries` to `pages` in ITEMS_PER_PAGE-sized chunks.
func _chunk_into(pages: Array, entries: Array) -> void:
	var i := 0
	while i < entries.size():
		pages.append(entries.slice(i, i + ITEMS_PER_PAGE))
		i += ITEMS_PER_PAGE

func _total_pages() -> int:
	return maxi(_pages().size(), 1)

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
				_merchant_bought(w.display_name)
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
			_merchant_bought(item.item_name)
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
