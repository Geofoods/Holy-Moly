extends Control

## The community level browser reachable straight from the title screen.
##
## It is deliberately separate from Level Forge: players can see what the
## community has published, like a level, then choose whether to open it for
## editing or play it as a normal game level. Both actions save the downloaded
## JSON under user://levels; EDIT hands it to Level Forge's one-shot launch
## request, while PLAY goes to the dedicated gameplay scene. The author's own
## editor autosave is never touched either way.

const UI_FONT := preload("res://Baby Doll.otf")
const SCENE_TRANSITION := preload("res://scenes/scene_transition.tscn")
const TITLE_SCENE := "res://scenes/intro.tscn"
const EDITOR_SCENE := "res://scenes/level_editor.tscn"
const DOWNLOAD_DIR := "user://levels"

const PANEL_BG := Color(0.10, 0.075, 0.07, 0.96)
const PANEL_BORDER := Color(0.62, 0.44, 0.28, 1.0)
const ROW_BG := Color(0.16, 0.12, 0.10, 0.96)
const ROW_BORDER := Color(0.35, 0.26, 0.19, 1.0)
const BUTTON_BG := Color(0.22, 0.16, 0.12, 0.98)
const BUTTON_HOVER := Color(0.33, 0.23, 0.16, 1.0)
const BUTTON_PRESSED := Color(0.46, 0.32, 0.18, 1.0)
const BUTTON_DISABLED := Color(0.16, 0.13, 0.12, 0.9)
const TEXT_COLOR := Color(0.98, 0.9, 0.78, 1.0)
const MUTED := Color(0.74, 0.67, 0.58, 1.0)
const ACCENT := Color(1.0, 0.84, 0.45, 1.0)
const LIKE_ACTIVE := Color(1.0, 0.52, 0.42, 1.0)
const SEARCH_DEBOUNCE := 0.35
## Sorting happens on the community server before paging, so these order the
## whole catalogue rather than just the fifty rows shown.
const SORT_OPTIONS := [
	{"id": "newest", "label": "NEWEST"},
	{"id": "downloads", "label": "MOST DOWNLOADED"},
	{"id": "likes", "label": "MOST LIKED"},
]
## Rolling windows keep the ranges independent of the player's timezone. The
## server gets the same absolute cutoff so sorting and paging still cover the
## whole matching catalogue.
const TIME_OPTIONS := [
	{"id": "all", "label": "ALL TIME", "seconds": 0, "status": "all time"},
	{"id": "day", "label": "24 HOURS", "seconds": 86400, "status": "the last 24 hours"},
	{"id": "week", "label": "7 DAYS", "seconds": 604800, "status": "the last 7 days"},
	{"id": "month", "label": "30 DAYS", "seconds": 2592000, "status": "the last 30 days"},
]

var _status: Label = null
var _refresh_button: Button = null
var _search_edit: LineEdit = null
var _search_timer: Timer = null
var _sort := "newest"
var _sort_buttons: Dictionary = {}
var _time_filter := "all"
var _time_buttons: Dictionary = {}
var _list: VBoxContainer = null
var _rows: Dictionary = {}
var _request_serial := 0
var _busy := false


func _ready() -> void:
	# Reaching the browser means any previous community run is over; its
	# checkpoint must not leak into the next level the player picks.
	LevelShare.clear_community_play()
	_build_ui()
	_refresh_levels()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL_BG, PANEL_BORDER, 10))
	margin.add_child(panel)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 22)
	padding.add_theme_constant_override("margin_top", 16)
	padding.add_theme_constant_override("margin_right", 22)
	padding.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(padding)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	padding.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = "LEVEL BROWSER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ACCENT)
	header.add_child(title)
	var back_button := _make_button("BACK", Vector2(130.0, 42.0))
	back_button.pressed.connect(_go_back)
	header.add_child(back_button)
	column.add_child(header)

	var subtitle := Label.new()
	subtitle.text = "Community levels built in Level Forge. Like the ones you enjoy, then jump straight in."
	subtitle.add_theme_font_override("font", UI_FONT)
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", MUTED)
	column.add_child(subtitle)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 10)
	var search_label := Label.new()
	search_label.text = "SEARCH"
	search_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search_label.add_theme_font_override("font", UI_FONT)
	search_label.add_theme_font_size_override("font_size", 18)
	search_label.add_theme_color_override("font_color", MUTED)
	search_row.add_child(search_label)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search level names, authors, descriptions, or IDs"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.custom_minimum_size = Vector2(0.0, 38.0)
	_search_edit.max_length = 80
	_search_edit.clear_button_enabled = true
	_search_edit.add_theme_font_override("font", UI_FONT)
	_search_edit.add_theme_font_size_override("font_size", 18)
	_search_edit.add_theme_color_override("font_color", TEXT_COLOR)
	_search_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.56, 0.5))
	_search_edit.add_theme_color_override("caret_color", ACCENT)
	_search_edit.add_theme_color_override("selection_color", Color(ACCENT, 0.3))
	_search_edit.add_theme_stylebox_override("normal", _style(BUTTON_BG, PANEL_BORDER))
	_search_edit.add_theme_stylebox_override("focus", _style(BUTTON_BG, ACCENT))
	_search_edit.add_theme_stylebox_override("read_only", _style(BUTTON_DISABLED, PANEL_BORDER))
	_search_edit.text_changed.connect(_on_search_changed)
	_search_edit.text_submitted.connect(_on_search_submitted)
	search_row.add_child(_search_edit)
	column.add_child(search_row)

	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = SEARCH_DEBOUNCE
	_search_timer.timeout.connect(_refresh_levels)
	add_child(_search_timer)

	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 10)
	var sort_label := Label.new()
	sort_label.text = "SORT"
	sort_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort_label.add_theme_font_override("font", UI_FONT)
	sort_label.add_theme_font_size_override("font_size", 18)
	sort_label.add_theme_color_override("font_color", MUTED)
	sort_row.add_child(sort_label)
	for option in SORT_OPTIONS:
		var sort_id := str(option["id"])
		var sort_button := _make_button(str(option["label"]), Vector2(0.0, 34.0))
		sort_button.add_theme_font_size_override("font_size", 17)
		sort_button.pressed.connect(_on_sort_pressed.bind(sort_id))
		sort_row.add_child(sort_button)
		_sort_buttons[sort_id] = sort_button
	column.add_child(sort_row)
	_update_sort_buttons()

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 10)
	var time_label := Label.new()
	time_label.text = "TIME"
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_label.add_theme_font_override("font", UI_FONT)
	time_label.add_theme_font_size_override("font_size", 18)
	time_label.add_theme_color_override("font_color", MUTED)
	time_row.add_child(time_label)
	for option in TIME_OPTIONS:
		var time_id := str(option["id"])
		var time_button := _make_button(str(option["label"]), Vector2(0.0, 34.0))
		time_button.add_theme_font_size_override("font_size", 17)
		time_button.pressed.connect(_on_time_pressed.bind(time_id))
		time_row.add_child(time_button)
		_time_buttons[time_id] = time_button
	column.add_child(time_row)
	_update_time_buttons()

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	_refresh_button = _make_button("REFRESH", Vector2(150.0, 38.0))
	_refresh_button.pressed.connect(_refresh_levels)
	toolbar.add_child(_refresh_button)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_override("font", UI_FONT)
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", MUTED)
	toolbar.add_child(_status)
	column.add_child(toolbar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list_margin := MarginContainer.new()
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_theme_constant_override("margin_right", 8)
	scroll.add_child(list_margin)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	list_margin.add_child(_list)
	column.add_child(scroll)

	var footer := Label.new()
	footer.text = "EDIT opens the level in Level Forge. PLAY launches it as a normal game level. Downloads are counted by the community server."
	footer.add_theme_font_override("font", UI_FONT)
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color(0.66, 0.58, 0.5))
	column.add_child(footer)


func _refresh_levels() -> void:
	if _busy:
		return
	if _search_timer != null:
		_search_timer.stop()
	var query := _search_edit.text.strip_edges() if _search_edit != null else ""
	var since := _time_since()
	_request_serial += 1
	var serial := _request_serial
	_refresh_button.disabled = true
	_status.text = "Contacting the community server... (free servers may take ~1 min to wake)"
	_clear_list()
	var result: Dictionary = await LevelShare.fetch_levels(50, 0, _sort, query, since)
	if serial != _request_serial or not is_inside_tree():
		return
	_refresh_button.disabled = false
	if not bool(result.get("ok", false)):
		_status.text = "Could not reach the community server: " + str(result.get("error", "Unknown error"))
		return
	var raw_levels = result.get("levels", [])
	if not (raw_levels is Array):
		_status.text = "The community server returned an unexpected response."
		return
	var levels := _filter_time_range(_filter_levels(raw_levels, query), since)
	if levels.is_empty():
		if query.is_empty() and since <= 0:
			_status.text = "No levels published yet. Build one in Level Forge and be the first!"
		elif query.is_empty():
			_status.text = "No levels published in %s." % _time_status()
		elif since <= 0:
			_status.text = "No levels match \"%s\"." % query
		else:
			_status.text = "No levels match \"%s\" in %s." % [query, _time_status()]
		return
	if query.is_empty() and since <= 0:
		var total := int(result.get("total", levels.size()))
		_status.text = "Showing %d of %d level%s." % [
			levels.size(), total, "" if total == 1 else "s"]
	elif query.is_empty():
		_status.text = "Showing %d level%s from %s." % [
			levels.size(), "" if levels.size() == 1 else "s", _time_status()]
	else:
		_status.text = "Showing %d matching level%s." % [
			levels.size(), "" if levels.size() == 1 else "s"]
	for raw_entry in levels:
		if raw_entry is Dictionary:
			_add_level_row(raw_entry)


## The server filters the whole catalogue when it supports `q` and `since`. Older
## deployments ignore those parameters, so repeat both checks locally for the
## page they returned.
func _filter_levels(levels: Array, query: String) -> Array:
	var terms := query.to_lower().split(" ", false)
	if terms.is_empty():
		return levels
	var matches: Array = []
	for raw_entry in levels:
		if raw_entry is Dictionary and _entry_matches(raw_entry, terms):
			matches.append(raw_entry)
	return matches


func _filter_time_range(levels: Array, since: int) -> Array:
	if since <= 0:
		return levels
	var matches: Array = []
	for raw_entry in levels:
		if raw_entry is Dictionary and _entry_created_unix(raw_entry) >= since:
			matches.append(raw_entry)
	return matches


func _entry_created_unix(entry: Dictionary) -> int:
	var parsed := Time.get_unix_time_from_datetime_string(str(entry.get("created_at", "")))
	return parsed if parsed >= 0 else 0


func _entry_matches(entry: Dictionary, terms: PackedStringArray) -> bool:
	var haystack := "%s %s %s %s" % [
		str(entry.get("id", "")),
		str(entry.get("name", "")),
		str(entry.get("author", "")),
		str(entry.get("description", "")),
	]
	haystack = haystack.to_lower()
	for term in terms:
		if not haystack.contains(term):
			return false
	return true


func _on_search_changed(_text: String) -> void:
	if _busy or _search_timer == null:
		return
	_search_timer.start()


func _on_search_submitted(_text: String) -> void:
	if _search_timer != null:
		_search_timer.stop()
	_refresh_levels()


func _on_sort_pressed(sort_id: String) -> void:
	if sort_id == _sort:
		return
	SFX.play_ui("ui_click", -6.0, 1.2)
	_sort = sort_id
	_update_sort_buttons()
	_refresh_levels()


## Highlights the active order so the buttons read as one choice, not three
## actions.
func _update_sort_buttons() -> void:
	for sort_id in _sort_buttons:
		var button: Button = _sort_buttons[sort_id]
		var active: bool = sort_id == _sort
		button.add_theme_color_override("font_color", ACCENT if active else TEXT_COLOR)
		button.add_theme_stylebox_override("normal",
				_style(BUTTON_BG, ACCENT if active else PANEL_BORDER))


func _on_time_pressed(time_id: String) -> void:
	if time_id == _time_filter:
		return
	SFX.play_ui("ui_click", -6.0, 1.2)
	_time_filter = time_id
	_update_time_buttons()
	_refresh_levels()


func _update_time_buttons() -> void:
	for time_id in _time_buttons:
		var button: Button = _time_buttons[time_id]
		var active: bool = time_id == _time_filter
		button.add_theme_color_override("font_color", ACCENT if active else TEXT_COLOR)
		button.add_theme_stylebox_override("normal",
				_style(BUTTON_BG, ACCENT if active else PANEL_BORDER))


func _time_option() -> Dictionary:
	for option in TIME_OPTIONS:
		if str(option["id"]) == _time_filter:
			return option
	return TIME_OPTIONS[0]


func _time_since() -> int:
	var seconds := int(_time_option().get("seconds", 0))
	if seconds <= 0:
		return 0
	return int(Time.get_unix_time_from_system()) - seconds


func _time_status() -> String:
	return str(_time_option().get("status", "all time"))


func _clear_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()


func _add_level_row(entry: Dictionary) -> void:
	var level_id := str(entry.get("id", ""))
	if level_id.is_empty():
		return
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(ROW_BG, ROW_BORDER, 8))
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 14)
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_right", 14)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(card_margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card_margin.add_child(row)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)

	var title := Label.new()
	title.text = str(entry.get("name", "Untitled Level"))
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", ACCENT)
	text_column.add_child(title)

	var byline := Label.new()
	var author := str(entry.get("author", "Anonymous"))
	var created := str(entry.get("created_at", "")).left(10)
	byline.text = "by %s | %s" % [author, created]
	byline.add_theme_font_override("font", UI_FONT)
	byline.add_theme_font_size_override("font_size", 15)
	byline.add_theme_color_override("font_color", MUTED)
	text_column.add_child(byline)

	var description := Label.new()
	var text := str(entry.get("description", "")).strip_edges()
	description.text = text if not text.is_empty() else "No description."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font", UI_FONT)
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color(0.9, 0.84, 0.75))
	text_column.add_child(description)

	var stats := Label.new()
	stats.text = _entry_stats(entry)
	stats.add_theme_font_override("font", UI_FONT)
	stats.add_theme_font_size_override("font_size", 15)
	stats.add_theme_color_override("font_color", Color(0.84, 0.72, 0.55))
	text_column.add_child(stats)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)

	var like_button := _make_button(_like_label(entry), Vector2(132.0, 38.0))
	like_button.pressed.connect(_on_like_pressed.bind(level_id))
	actions.add_child(like_button)
	_update_like_button(like_button, entry)

	var edit_button := _make_button("EDIT", Vector2(132.0, 44.0))
	edit_button.pressed.connect(_on_edit_pressed.bind(level_id, edit_button))
	actions.add_child(edit_button)

	var play_button := _make_button("PLAY", Vector2(132.0, 44.0))
	play_button.pressed.connect(_on_play_pressed.bind(level_id, play_button))
	actions.add_child(play_button)

	_list.add_child(card)
	_rows[level_id] = {
		"entry": entry,
		"stats": stats,
		"like": like_button,
		"edit": edit_button,
		"play": play_button,
	}


func _entry_stats(entry: Dictionary) -> String:
	var likes := int(entry.get("likes", 0))
	var downloads := int(entry.get("downloads", 0))
	var blocks := int(entry.get("blocks", 0))
	var enemies := int(entry.get("enemies", 0))
	return "%d like%s | %d download%s | %d block%s | %d enem%s" % [
		likes, "" if likes == 1 else "s",
		downloads, "" if downloads == 1 else "s",
		blocks, "" if blocks == 1 else "s",
		enemies, "y" if enemies == 1 else "ies"]


func _like_label(entry: Dictionary) -> String:
	var level_id := str(entry.get("id", ""))
	var likes := int(entry.get("likes", 0))
	return "%s (%d)" % ["LIKED" if LevelShare.is_level_liked(level_id) else "LIKE", likes]


func _update_like_button(button: Button, entry: Dictionary) -> void:
	var level_id := str(entry.get("id", ""))
	var likes := int(entry.get("likes", 0))
	var liked := LevelShare.is_level_liked(level_id)
	button.text = "%s (%d)" % ["LIKED" if liked else "LIKE", likes]
	button.add_theme_color_override("font_color", LIKE_ACTIVE if liked else TEXT_COLOR)
	button.add_theme_stylebox_override("normal",
			_style(ROW_BG if liked else BUTTON_BG, LIKE_ACTIVE if liked else PANEL_BORDER, 6))


func _on_like_pressed(level_id: String) -> void:
	var row: Dictionary = _rows.get(level_id, {})
	var button: Button = row.get("like")
	if button == null or button.disabled:
		return
	SFX.play_ui("ui_click", -6.0, 1.2)
	button.disabled = true
	var wanted := not LevelShare.is_level_liked(level_id)
	var result: Dictionary = await LevelShare.set_level_liked(level_id, wanted)
	if not is_instance_valid(button):
		return
	button.disabled = false
	if not bool(result.get("ok", false)):
		_status.text = "Could not update that like: " + str(result.get("error", "Unknown error"))
		return
	var updated = result.get("level", {})
	if not (updated is Dictionary):
		return
	var entry: Dictionary = row["entry"]
	entry["likes"] = int(updated.get("likes", entry.get("likes", 0)))
	row["stats"].text = _entry_stats(entry)
	_update_like_button(button, entry)
	if wanted:
		_status.text = "Liked \"%s\"." % str(entry.get("name", "level"))
	else:
		_status.text = "Removed your like from \"%s\"." % str(entry.get("name", "level"))


func _on_edit_pressed(level_id: String, button: Button) -> void:
	_open_level(level_id, button, false)


func _on_play_pressed(level_id: String, button: Button) -> void:
	_open_level(level_id, button, true)


## Both row actions share the download and save step. EDIT hands the file to the
## editor without starting a playtest; PLAY hands it to the normal gameplay scene
## and leaves the editor entirely out of the run.
func _open_level(level_id: String, button: Button, start_playing: bool) -> void:
	if _busy:
		return
	_busy = true
	if _search_timer != null:
		_search_timer.stop()
	if _search_edit != null:
		_search_edit.editable = false
	SFX.play_ui("ui_click", -6.0, 1.2)
	_set_row_actions_disabled(level_id, true)
	button.disabled = true
	_refresh_button.disabled = true
	_status.text = "Downloading level..."
	var result: Dictionary = await LevelShare.download_level(level_id)
	if not is_inside_tree():
		return
	_set_row_actions_disabled(level_id, false)
	_refresh_button.disabled = false
	if _search_edit != null:
		_search_edit.editable = true
	_busy = false
	if not bool(result.get("ok", false)):
		_status.text = "Could not download that level: " + str(result.get("error", "Unknown error"))
		return
	var data = result.get("data", null)
	if not (data is Dictionary):
		_status.text = "That level did not contain readable level data."
		return
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_DIR)
	var path := "%s/community_%s.json" % [DOWNLOAD_DIR, level_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status.text = "Could not save the downloaded level."
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_busy = true
	if start_playing:
		LevelShare.begin_community_play(path)
		_go_to_scene(LevelShare.COMMUNITY_PLAY_SCENE)
	else:
		LevelShare.request_editor_level(path, false)
		_go_to_scene(EDITOR_SCENE)


func _set_row_actions_disabled(level_id: String, disabled: bool) -> void:
	var row: Dictionary = _rows.get(level_id, {})
	for key in ["edit", "play"]:
		var button = row.get(key)
		if is_instance_valid(button):
			button.disabled = disabled


func _go_back() -> void:
	if _busy:
		return
	_busy = true
	SFX.play_ui("ui_click", -6.0, 1.2)
	_go_to_scene(TITLE_SCENE)


func _go_to_scene(path: String) -> void:
	var transition := SCENE_TRANSITION.instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(path)


func _make_button(label: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = min_size
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.82))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.5))
	button.add_theme_color_override("font_focus_color", TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _style(BUTTON_BG, PANEL_BORDER))
	button.add_theme_stylebox_override("hover", _style(BUTTON_HOVER, ACCENT))
	button.add_theme_stylebox_override("pressed", _style(BUTTON_PRESSED, ACCENT))
	button.add_theme_stylebox_override("focus", _style(BUTTON_HOVER, ACCENT))
	button.add_theme_stylebox_override("disabled", _style(BUTTON_DISABLED, Color(0.3, 0.24, 0.2)))
	return button


func _style(bg: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style
