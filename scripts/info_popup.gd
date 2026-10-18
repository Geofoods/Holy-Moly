extends CanvasLayer

const DANGER_LABELS := ["", "LOW", "MILD", "MODERATE", "HIGH", "EXTREME", "MERCILESS"]
const DANGER_COLORS := [
	Color.WHITE,
	Color(0.25, 0.65, 0.3, 1),
	Color(0.55, 0.65, 0.15, 1),
	Color(0.85, 0.55, 0.1, 1),
	Color(0.8, 0.25, 0.15, 1),
	Color(0.55, 0.1, 0.1, 1),
	Color(0.9, 0.3, 0.8, 1),
]

## The coin the reward burst is built from, and how many of them fly. Reusing the
## HUD icon's script keeps the flying coins identical to the counter they land on,
## including the fall-back drawing when the artwork is missing.
const REWARD_COIN_SCRIPT := preload("res://scripts/coin_hud_icon.gd")
const REWARD_COIN_COUNT := 14
const REWARD_COIN_SIZE := 44.0

@onready var dim_background: ColorRect = $DimBackground
@onready var panel: Control = $CenterContainer/Panel
@onready var bestiary_tab: Button = $CenterContainer/Panel/Margin/VBox/TabRow/BestiaryTab
@onready var controls_tab: Button = $CenterContainer/Panel/Margin/VBox/TabRow/ControlsTab
@onready var quests_tab: Button = $CenterContainer/Panel/Margin/VBox/TabRow/QuestsTab
@onready var bestiary_view: HBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/BestiaryView
@onready var controls_view: ScrollContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/ControlsView
@onready var quests_view: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/QuestsView
@onready var list_vbox: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/BestiaryView/ListScroll/ListVBox
@onready var detail_vbox: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/BestiaryView/DetailMargin/DetailScroll/DetailVBox
@onready var controls_vbox: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/ControlsView/ControlsMargin/ControlsVBox
@onready var quests_vbox: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/QuestsView/QuestScroll/QuestsMargin/QuestsVBox
@onready var quest_scroll: ScrollContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/QuestsView/QuestScroll
@onready var quest_incomplete_filter: CheckBox = $CenterContainer/Panel/Margin/VBox/ContentPanel/QuestsView/QuestFilterRow/IncompleteFilter
@onready var quest_complete_filter: CheckBox = $CenterContainer/Panel/Margin/VBox/ContentPanel/QuestsView/QuestFilterRow/CompleteFilter

var _font := preload("res://Baby Doll.otf")
var _browse_music_stream := preload("res://easy-breeze-ra-main-version-33378-02-16.mp3")
var _browse_music: AudioStreamPlayer = null
var is_open := false
var _was_paused_before := false
var _selected_id := ""
var _list_buttons: Dictionary = {}
## Which quests the log lists. Two independent checkboxes rather than one
## exclusive tab: checking neither hides every quest, checking both shows all.
var _show_incomplete := true
var _show_complete := true
## Quest id -> its card in the log, rebuilt every populate so the guide can jump
## straight to a quest the player just unlocked or finished.
var _quest_entries: Dictionary = {}
## Full-screen control the collect-reward coins and "+N" text fly across. Built
## lazily on the first claim and reused, so it always sits above the panel.
var _burst_layer: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dim_background.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.call_deferred("set", "pivot_offset", panel.size / 2.0)
	_populate_bestiary_list()
	_populate_controls()
	_populate_quests()
	if Bestiary.get_entries().size() > 0:
		_select_entry(Bestiary.get_entries()[0]["id"])

func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and (event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_P):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	if is_open:
		return
	is_open = true
	_was_paused_before = get_tree().paused
	get_tree().paused = true
	visible = true
	dim_background.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim_background, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	LevelMusic.pause()
	_pause_scene_music()
	_start_browse_music()
	# Quest state moves while the guide is closed, so the tab is rebuilt on open
	# rather than trusting whatever was last drawn.
	_populate_quests()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_stop_browse_music()
	LevelMusic.resume()
	_resume_scene_music()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim_background, "modulate:a", 0.0, 0.15)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(panel, "scale", Vector2(0.92, 0.92), 0.15)
	await tween.finished
	visible = false
	get_tree().paused = _was_paused_before

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

## Opens the guide straight to the quest log with `quest_id` scrolled into view
## and flashed, so tapping a quest banner lands the player on that quest.
func open_quest(quest_id: String) -> void:
	open()
	_ensure_quest_visible(quest_id)
	_show_tab("quests")
	_focus_quest(quest_id)

## A quest can be hidden by the two filter checkboxes; tick whichever one would
## hide the quest we are about to jump to.
func _ensure_quest_visible(quest_id: String) -> void:
	if Quests.is_complete(quest_id):
		if not _show_complete:
			_show_complete = true
			quest_complete_filter.button_pressed = true
	elif not _show_incomplete:
		_show_incomplete = true
		quest_incomplete_filter.button_pressed = true

func _focus_quest(quest_id: String) -> void:
	var entry: Control = _quest_entries.get(quest_id)
	if entry == null:
		return
	_scroll_to(entry)
	_flash_entry(entry)

## The scroll only knows its real extent after the frame that lays the freshly
## built cards out, so wait a frame before asking it to reveal the card.
func _scroll_to(entry: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(entry):
		quest_scroll.ensure_control_visible(entry)

func _flash_entry(entry: Control) -> void:
	if not is_instance_valid(entry):
		return
	var tween := create_tween()
	tween.tween_property(entry, "modulate", Color(1.3, 1.18, 0.6, 1), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(entry, "modulate", Color(1, 1, 1, 1), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_bestiary_tab_toggled(pressed: bool) -> void:
	if not pressed:
		return
	_show_tab("bestiary")

func _on_controls_tab_toggled(pressed: bool) -> void:
	if not pressed:
		return
	_show_tab("controls")

func _on_quests_tab_toggled(pressed: bool) -> void:
	if not pressed:
		return
	_show_tab("quests")

func _on_quest_incomplete_filter_toggled(pressed: bool) -> void:
	_show_incomplete = pressed
	_populate_quests()

func _on_quest_complete_filter_toggled(pressed: bool) -> void:
	_show_complete = pressed
	_populate_quests()

## Switches which content view is showing and which tab reads as selected. The
## three tabs are plain toggles wired to their own callbacks; this is the one
## place that keeps them mutually exclusive. Setting a toggle to the value it
## already holds does not re-emit toggled, so there is no loop back through the
## per-tab handlers.
func _show_tab(tab: String) -> void:
	bestiary_tab.button_pressed = tab == "bestiary"
	controls_tab.button_pressed = tab == "controls"
	quests_tab.button_pressed = tab == "quests"
	bestiary_view.visible = tab == "bestiary"
	controls_view.visible = tab == "controls"
	quests_view.visible = tab == "quests"
	if tab == "quests":
		_populate_quests()

func _make_heading(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _populate_bestiary_list() -> void:
	for child in list_vbox.get_children():
		child.queue_free()
	_list_buttons.clear()

	for entry in Bestiary.get_entries():
		var btn := Button.new()
		btn.text = "  %s" % entry["name"]
		btn.custom_minimum_size = Vector2(0, 52)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.32, 0.2, 0.08, 1))
		btn.flat = true
		btn.pressed.connect(_select_entry.bind(entry["id"]))
		list_vbox.add_child(btn)
		_list_buttons[entry["id"]] = btn

func _select_entry(id: String) -> void:
	_selected_id = id
	for entry_id in _list_buttons:
		var btn: Button = _list_buttons[entry_id]
		btn.modulate = Color(1.0, 0.92, 0.7, 1.0) if entry_id == id else Color.WHITE

	var entry := Bestiary.get_entry(id)
	if entry.is_empty():
		return

	for child in detail_vbox.get_children():
		child.queue_free()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	detail_vbox.add_child(header)

	var icon_path: String = entry.get("icon", "")
	if icon_path != "":
		var tex := load(icon_path)
		if tex:
			var region: Rect2 = entry.get("icon_region", Rect2())
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(96, 96)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if region.size != Vector2.ZERO:
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = region
				icon_rect.texture = atlas
			else:
				icon_rect.texture = tex
			header.add_child(icon_rect)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)
	title_col.add_child(_make_heading(entry["name"], 32, Color(0.32, 0.2, 0.08, 1)))

	var danger: int = entry.get("danger_level", 1)
	var danger_row := HBoxContainer.new()
	title_col.add_child(danger_row)
	var cat_label := _make_heading(String(entry.get("category", "")).to_upper(), 14, Color(0.5, 0.4, 0.25, 1))
	cat_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	danger_row.add_child(cat_label)
	var sep := Label.new()
	sep.text = "   •   DANGER: "
	sep.add_theme_font_override("font", _font)
	sep.add_theme_font_size_override("font_size", 14)
	sep.add_theme_color_override("font_color", Color(0.5, 0.4, 0.25, 1))
	danger_row.add_child(sep)
	var danger_label := _make_heading(DANGER_LABELS[clampi(danger, 1, 6)], 14, DANGER_COLORS[clampi(danger, 1, 6)])
	danger_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	danger_row.add_child(danger_label)

	detail_vbox.add_child(HSeparator.new())

	_add_detail_section("WHAT IS IT", entry.get("description", ""))
	_add_detail_section("BEHAVIOR", entry.get("behavior", ""))
	_add_detail_section("ATTACK PATTERN", entry.get("attack_pattern", ""))
	_add_detail_section("BEST STRATEGY", entry.get("strategy", ""))

func _add_detail_section(title: String, body: String) -> void:
	if body == "":
		return
	detail_vbox.add_child(_make_heading(title, 16, Color(0.55, 0.35, 0.1, 1)))
	var body_label := _make_heading(body, 18, Color(0.2, 0.14, 0.06, 1))
	body_label.custom_minimum_size = Vector2(560, 0)
	detail_vbox.add_child(body_label)

func _populate_controls() -> void:
	for child in controls_vbox.get_children():
		child.queue_free()

	for group in Bestiary.get_controls():
		controls_vbox.add_child(_make_heading(String(group["category"]).to_upper(), 22, Color(0.42, 0.28, 0.1, 1)))
		for row in group["rows"]:
			var row_box := HBoxContainer.new()
			row_box.add_theme_constant_override("separation", 12)
			controls_vbox.add_child(row_box)

			var key_label := _make_heading(row["label"], 17, Color(0.55, 0.15, 0.15, 1))
			key_label.custom_minimum_size = Vector2(210, 0)
			row_box.add_child(key_label)

			var detail_label := _make_heading(row["detail"], 17, Color(0.2, 0.14, 0.06, 1))
			detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_box.add_child(detail_label)
		controls_vbox.add_child(HSeparator.new())

## Builds the quest log tab: a header, then one card per quest that passes the
## current filter. Quest state lives in Progress and the reward rule in Quests;
## this only draws them.
func _populate_quests() -> void:
	for child in quests_vbox.get_children():
		child.queue_free()
	_quest_entries.clear()

	quests_vbox.add_child(_make_heading(
		"QUESTS   %d / %d COMPLETE" % [Quests.completed_count(), Quests.total_count()],
		22, Color(0.42, 0.28, 0.1, 1)))
	quests_vbox.add_child(HSeparator.new())

	var shown := _filtered_quests()
	if shown.is_empty():
		quests_vbox.add_child(_make_heading(_empty_filter_text(), 18, Color(0.45, 0.35, 0.22, 1)))
		return
	for quest in shown:
		var entry := _make_quest_entry(quest)
		quests_vbox.add_child(entry)
		_quest_entries[str(quest["id"])] = entry

## The quests the current checkboxes let through, in log order. Every quest is
## listed, even ones not discovered yet: an undiscovered quest shows as "???" so
## the player can see how much is still out there. A locked quest counts as not
## complete, so it rides the incomplete filter.
func _filtered_quests() -> Array:
	var result: Array = []
	for quest in Quests.get_quests():
		var complete := Quests.is_complete(str(quest["id"]))
		if complete and not _show_complete:
			continue
		if not complete and not _show_incomplete:
			continue
		result.append(quest)
	return result

func _empty_filter_text() -> String:
	if not _show_incomplete and not _show_complete:
		return "No filters checked. Tick a box to see your quests."
	if _show_complete and not _show_incomplete:
		return "No quests finished yet. Get out there!"
	if _show_incomplete and not _show_complete:
		return "Every quest is done. Nicely played!"
	return "No quests to show."

func _make_quest_entry(quest: Dictionary) -> Control:
	var quest_id := str(quest["id"])
	var locked := not Quests.is_unlocked(quest_id)
	var complete := Quests.is_complete(quest_id)
	var rewarded := Quests.is_rewarded(quest_id)
	var claimable := Quests.can_claim(quest_id)

	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	entry.add_child(row)

	row.add_child(_make_quest_icon(quest, locked))

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	row.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	box.add_child(title_row)

	var title := _make_heading(
		"???" if locked else str(quest["title"]), 24,
		Color(0.5, 0.45, 0.35, 1) if locked else Color(0.32, 0.2, 0.08, 1))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var status := _make_heading(_quest_status_text(locked, complete, rewarded), 15, _quest_status_color(locked, complete, rewarded))
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(status)

	var desc := _make_heading(
		"???" if locked else str(quest["description"]), 17,
		Color(0.55, 0.5, 0.4, 1) if locked else Color(0.2, 0.14, 0.06, 1))
	desc.custom_minimum_size = Vector2(500, 0)
	box.add_child(desc)

	var reward := _make_heading(
		"REWARD: ???" if locked else "REWARD: %d COINS" % int(quest.get("reward_coins", 0)), 17,
		Color(0.6, 0.55, 0.45, 1) if locked else Color(0.55, 0.35, 0.1, 1))
	reward.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(reward)

	if claimable:
		var btn := Button.new()
		btn.text = "COLLECT REWARD"
		btn.custom_minimum_size = Vector2(240, 46)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.06, 0.1, 0.06, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn.add_theme_stylebox_override("normal", _make_claim_style(Color(0.45, 0.7, 0.35)))
		btn.add_theme_stylebox_override("hover", _make_claim_style(Color(0.55, 0.82, 0.45)))
		btn.add_theme_stylebox_override("pressed", _make_claim_style(Color(0.35, 0.6, 0.3)))
		btn.add_theme_stylebox_override("focus", _make_claim_style(Color(0.55, 0.82, 0.45)))
		btn.pressed.connect(_on_quest_claim_pressed.bind(quest_id, btn))
		box.add_child(btn)

	entry.add_child(HSeparator.new())
	return entry

## The quest's artwork for the log. Locked quests show a dim "?" instead of the
## real icon so an undiscovered quest gives nothing away.
func _make_quest_icon(quest: Dictionary, locked: bool) -> Control:
	var slot := Vector2(76, 76)
	if locked:
		var mark := _make_heading("?", 46, Color(0.55, 0.5, 0.42, 1))
		mark.custom_minimum_size = slot
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return mark

	var quest_id := str(quest["id"])
	var icon := TextureRect.new()
	icon.custom_minimum_size = slot
	icon.texture = Quests.get_quest_icon(quest_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Quests.get_quest_icon_tint(quest_id)
	return icon

func _quest_status_text(locked: bool, complete: bool, rewarded: bool) -> String:
	if locked:
		return "???"
	if rewarded:
		return "REWARDED"
	if complete:
		return "COMPLETE!"
	return "IN PROGRESS"

func _quest_status_color(locked: bool, complete: bool, rewarded: bool) -> Color:
	if locked:
		return Color(0.5, 0.48, 0.42, 1)
	if rewarded:
		return Color(0.35, 0.5, 0.3, 1)
	if complete:
		return Color(0.2, 0.55, 0.22, 1)
	return Color(0.55, 0.45, 0.3, 1)

func _make_claim_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.25, 0.4, 0.15, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb

func _on_quest_claim_pressed(quest_id: String, button: Button = null) -> void:
	# Read the reward and the button's screen spot before claiming: claiming
	# rebuilds the log, which queues the button for deletion.
	var reward := int(Quests.get_quest(quest_id).get("reward_coins", 0))
	var origin := Vector2.ZERO
	if button != null and is_instance_valid(button):
		origin = button.get_global_rect().get_center()
	if not Quests.claim(quest_id):
		return
	SFX.play_ui("item_pickup", -4.0, 1.1)
	_populate_quests()
	if reward > 0:
		_play_reward_burst(origin, reward)

## The collect-reward flourish: a fistful of coins bursts out of the button and
## swoops to the coin counter, with a "+N" that floats up and fades. It runs on
## the guide's own always-processing node so the tweens keep going while the menu
## holds the tree paused.
func _play_reward_burst(origin: Vector2, amount: int) -> void:
	var layer := _burst_layer_node()
	var target := Shop.reveal_coin_hud()
	if target == Vector2.ZERO:
		# No counter to land on (a HUD-less scene): drift toward the top-left
		# corner where it normally lives so the coin still reads as collected.
		target = Vector2(96.0, 40.0)
	if origin == Vector2.ZERO:
		origin = target
	SFX.play_ui("coin", -6.0, 1.15)
	for i in REWARD_COIN_COUNT:
		_spawn_reward_coin(layer, origin, target, i)
	_spawn_reward_text(layer, origin, amount)

## The shared layer the burst draws in, created on first use. A plain full-rect
## Control ignores the mouse, so it never swallows a click on the panel beneath.
func _burst_layer_node() -> Control:
	if _burst_layer != null and is_instance_valid(_burst_layer):
		return _burst_layer
	_burst_layer = Control.new()
	_burst_layer.name = "RewardBurst"
	_burst_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_burst_layer)
	_burst_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	return _burst_layer

## One coin: it pops out on its own random spoke, pauses a beat, then curves in
## toward the counter. `index` staggers the swoop so the coins arrive as a stream
## rather than a single clump.
func _spawn_reward_coin(layer: Control, origin: Vector2, target: Vector2, index: int) -> void:
	var coin := Control.new()
	coin.set_script(REWARD_COIN_SCRIPT)
	coin.custom_minimum_size = Vector2(REWARD_COIN_SIZE, REWARD_COIN_SIZE)
	coin.size = Vector2(REWARD_COIN_SIZE, REWARD_COIN_SIZE)
	coin.pivot_offset = coin.size * 0.5
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.modulate.a = 0.0
	coin.scale = Vector2(0.2, 0.2)
	layer.add_child(coin)
	coin.global_position = origin - coin.size * 0.5

	var half := coin.size * 0.5
	var burst := origin + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(80.0, 160.0)
	var mid := (burst + target) * 0.5 + Vector2(randf_range(-50.0, 50.0), randf_range(-70.0, -10.0))

	var tw := create_tween()
	# Explode outward and pop into view.
	tw.tween_property(coin, "global_position", burst - half, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(coin, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(coin, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Hang for a beat, staggered per coin, then swoop to the counter.
	tw.tween_interval(0.22 + index * 0.03)
	tw.tween_property(coin, "global_position", mid - half, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(coin, "global_position", target - half, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Shrink and fade out as it lands, so it reads as pouring into the counter.
	tw.parallel().tween_property(coin, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(coin, "scale", Vector2(0.35, 0.35), 0.3)
	tw.tween_callback(coin.queue_free)

## The "+N" that rises off the button and fades, naming the payout the coins are
## carrying.
func _spawn_reward_text(layer: Control, origin: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	label.global_position = origin - label.size * 0.5

	var tw := create_tween()
	tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "global_position:y", label.global_position.y - 72.0, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(label.queue_free)

func _pause_scene_music() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var music = scene.get_node_or_null("MenuMusic")
	if music and music is AudioStreamPlayer:
		music.stream_paused = true

func _resume_scene_music() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var music = scene.get_node_or_null("MenuMusic")
	if music and music is AudioStreamPlayer:
		music.stream_paused = false

func _start_browse_music() -> void:
	if _browse_music and is_instance_valid(_browse_music):
		return
	_browse_music = AudioStreamPlayer.new()
	_browse_music.stream = _browse_music_stream
	_browse_music.volume_db = -12.0
	_browse_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_browse_music.bus = &"Music"
	add_child(_browse_music)
	_browse_music.finished.connect(_browse_music.play)
	_browse_music.play()

func _stop_browse_music() -> void:
	if not _browse_music or not is_instance_valid(_browse_music):
		return
	var tween := create_tween()
	tween.tween_property(_browse_music, "volume_db", -40.0, 0.5)
	tween.tween_callback(_browse_music.queue_free)
	_browse_music = null
