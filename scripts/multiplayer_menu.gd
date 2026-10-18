extends Control
## Lobby for the online PvP mode: host a room or join one by address, see who is
## in it, then start the match.
##
## The UI is built in code and the scene is only the Control root. This screen
## has one job - getting a session up - and keeping it in one file means its
## states (idle / connecting / in a room) can be derived in one place instead of
## being spread across a node tree and a handful of signal connections.
##
## The palette is the one settings_menu.tscn uses for its overlay - a cream
## panel with brown trim and dark ink on top - rather than the dark aesthetic the
## in-game HUDs use. backgrnd.png is a dark image on its own, so text laid
## straight onto it reads as a near-black screen.

const FONT_PATH := "res://Baby Doll.otf"
const BACKDROP_PATH := "res://backgrnd.png"

## The overlay-panel look, lifted from settings_menu.tscn so this screen belongs
## to the same set as PAUSE and SETTINGS.
const PANEL_COLOR := Color(0.93, 0.85, 0.66)
const BORDER_COLOR := Color(0.42, 0.28, 0.14)
const INK := Color(0.32, 0.2, 0.08)
const INK_SOFT := Color(0.46, 0.34, 0.2)
const WARN_INK := Color(0.6, 0.09, 0.12)
const FIELD_COLOR := Color(0.97, 0.93, 0.84)
const FIELD_FOCUS_COLOR := Color(1, 0.98, 0.92)
const BUTTON_COLOR := Color(0.8, 0.68, 0.46)
const BUTTON_HOVER_COLOR := Color(0.97, 0.91, 0.78)
const BUTTON_DISABLED_COLOR := Color(0.74, 0.66, 0.52)
const DANGER_COLOR := Color(0.72, 0.1, 0.18)
const DANGER_HOVER_COLOR := Color(0.9, 0.15, 0.25)
const DANGER_TEXT := Color(1, 0.88, 0.88)
const GO_COLOR := Color(0.13, 0.85, 0.35)
const GO_HOVER_COLOR := Color(0.2, 1, 0.45)
const GO_TEXT := Color(0.04, 0.14, 0.06)

const PANEL_WIDTH := 760.0
const FIELD_WIDTH := 300.0
const ROW_HEIGHT := 46.0
const SWATCH_SIZE := 20.0

var _name_edit: LineEdit = null
var _address_edit: LineEdit = null
var _port_edit: LineEdit = null
var _host_button: Button = null
var _join_button: Button = null
var _start_button: Button = null
var _status: Label = null
var _player_list: VBoxContainer = null
var _roster_title: Label = null


func _ready() -> void:
	_build()
	Net.roster_changed.connect(_refresh_roster)
	Net.session_ended.connect(_on_session_ended)
	_refresh_roster()
	_set_status("HOST A ROOM, OR JOIN ONE BY ADDRESS.", INK_SOFT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Net.quit_to_title()


func _build() -> void:
	var font := load(FONT_PATH) as Font

	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = load(BACKDROP_PATH)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# The same dim the settings screen uses. It only needs to settle the art
	# back; the panel is what the content actually sits on.
	var dim := ColorRect.new()
	dim.name = "DimBackground"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var centre := CenterContainer.new()
	centre.name = "CenterContainer"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	centre.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(_make_label("MULTIPLAYER", 50, INK, font))
	box.add_child(_make_label("FREE FOR ALL - FIRST TO %d" % Net.kills_to_win, 20, INK_SOFT, font))

	_name_edit = _make_field(font, Net.local_name, "your name")
	box.add_child(_labelled_row("NAME", _name_edit, font))

	_address_edit = _make_field(font, "127.0.0.1", "host address")
	box.add_child(_labelled_row("HOST IP", _address_edit, font))

	_port_edit = _make_field(font, str(Net.DEFAULT_PORT), "port")
	_port_edit.max_length = 5
	box.add_child(_labelled_row("PORT", _port_edit, font))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	box.add_child(actions)

	# The key controls are named so the tree reads plainly here and in the
	# remote inspector; the rest are anonymous because nothing refers to them.
	_host_button = _make_button("HOST", font, BUTTON_COLOR, BUTTON_HOVER_COLOR, INK)
	_host_button.name = "HostButton"
	_host_button.pressed.connect(_on_host_pressed)
	actions.add_child(_host_button)

	_join_button = _make_button("JOIN", font, BUTTON_COLOR, BUTTON_HOVER_COLOR, INK)
	_join_button.name = "JoinButton"
	_join_button.pressed.connect(_on_join_pressed)
	actions.add_child(_join_button)

	var back_button := _make_button("BACK", font, DANGER_COLOR, DANGER_HOVER_COLOR, DANGER_TEXT)
	back_button.name = "BackButton"
	back_button.pressed.connect(Net.quit_to_title)
	actions.add_child(back_button)

	_status = _make_label("", 19, INK_SOFT, font)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	_roster_title = _make_label("IN THE ROOM", 22, INK, font)
	_roster_title.visible = false
	box.add_child(_roster_title)

	_player_list = VBoxContainer.new()
	_player_list.name = "Players"
	_player_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_list.add_theme_constant_override("separation", 6)
	box.add_child(_player_list)

	_start_button = _make_button("START MATCH", font, GO_COLOR, GO_HOVER_COLOR, GO_TEXT)
	_start_button.name = "StartButton"
	_start_button.visible = false
	_start_button.pressed.connect(_on_start_pressed)
	box.add_child(_start_button)

	box.add_child(_make_label("WASD MOVE    SPACE JUMP    LEFT CLICK SWING    ESC LEAVE", 16, INK_SOFT, font))


## --- Styleboxes -----------------------------------------------------------

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _field_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


## --- Widgets --------------------------------------------------------------

func _make_label(text: String, size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Text sits on the cream panel throughout, so no outline is needed; the colour
## alone carries it.
func _make_button(text: String, font: Font, background: Color, hover: Color, ink: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180.0, 58.0)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 24)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.47, 0.34))
	button.add_theme_stylebox_override("normal", _button_style(background, BORDER_COLOR))
	button.add_theme_stylebox_override("hover", _button_style(hover, BORDER_COLOR))
	button.add_theme_stylebox_override("pressed", _button_style(hover, BORDER_COLOR))
	button.add_theme_stylebox_override("focus", _button_style(hover, BORDER_COLOR))
	button.add_theme_stylebox_override("disabled", _button_style(BUTTON_DISABLED_COLOR, Color(0.5, 0.42, 0.3)))
	return button


func _make_field(font: Font, value: String, placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(FIELD_WIDTH, ROW_HEIGHT)
	field.max_length = 32
	field.add_theme_font_override("font", font)
	field.add_theme_font_size_override("font_size", 22)
	field.add_theme_color_override("font_color", INK)
	field.add_theme_color_override("font_placeholder_color", Color(0.6, 0.52, 0.4))
	field.add_theme_color_override("caret_color", INK)
	field.add_theme_color_override("selection_color", Color(0.42, 0.28, 0.14, 0.3))
	field.add_theme_stylebox_override("normal", _field_style(FIELD_COLOR))
	field.add_theme_stylebox_override("focus", _field_style(FIELD_FOCUS_COLOR))
	return field


func _labelled_row(caption: String, field: LineEdit, font: Font) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var label := _make_label(caption, 22, INK_SOFT, font)
	label.custom_minimum_size = Vector2(120.0, ROW_HEIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)
	row.add_child(field)
	return row


## One player in the lobby: a colour chip with a dark edge, then the name in ink.
## The tint alone cannot carry the row - slot 1's colour is white, and the tinted
## text this used to be was the same problem in reverse on a dark background.
func _make_player_row(id: int, font: Font) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Net.player_color_of(id)
	chip_style.border_color = BORDER_COLOR
	chip_style.set_border_width_all(2)
	chip_style.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", chip_style)
	row.add_child(chip)

	var suffix := "  (YOU)" if id == Net.local_id() else ""
	row.add_child(_make_label("%s%s" % [Net.player_name_of(id), suffix], 24, INK, font))
	return row


## --- State ----------------------------------------------------------------

func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


## The single source of truth for what the form allows. Everything is re-derived
## from the live session, so no control can be left stuck by a handshake that
## failed halfway.
func _refresh_roster() -> void:
	if _player_list == null:
		return
	for child in _player_list.get_children():
		child.queue_free()

	var ids := Net.peer_ids()
	var online := Net.is_online()
	var busy := _is_connecting()

	_host_button.disabled = busy or online
	_join_button.disabled = busy or online
	for field in [_name_edit, _address_edit, _port_edit]:
		field.editable = not busy and not online

	_roster_title.visible = online
	_start_button.visible = online and Net.is_host()
	_start_button.disabled = busy or ids.size() < 2

	if not online:
		return
	if busy:
		_set_status("CONNECTING...", INK_SOFT)
		return

	var font := load(FONT_PATH) as Font
	for id: int in ids:
		_player_list.add_child(_make_player_row(id, font))
	if Net.is_host() and ids.size() < 2:
		_set_status("WAITING FOR ANOTHER PLAYER...", INK_SOFT)
	elif not Net.is_host():
		_set_status("WAITING FOR THE HOST TO START...", INK_SOFT)


func _is_connecting() -> bool:
	var peer := multiplayer.multiplayer_peer
	if not (peer is ENetMultiplayerPeer):
		return false
	return (peer as ENetMultiplayerPeer).get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING


func _on_host_pressed() -> void:
	Net.set_local_name(_name_edit.text)
	var port := _read_port()
	var err := Net.host_game(port)
	if err != OK:
		_set_status(Net.last_error, WARN_INK)
		return
	# The port is echoed back so the host can read it out to whoever is joining;
	# the lobby status set by the roster refresh is replaced deliberately.
	_set_status("ROOM OPEN ON PORT %d - OTHERS JOIN AT YOUR IP." % port, INK_SOFT)


func _on_join_pressed() -> void:
	Net.set_local_name(_name_edit.text)
	var address := _address_edit.text.strip_edges()
	if address.is_empty():
		_set_status("ENTER THE HOST'S ADDRESS FIRST.", WARN_INK)
		return
	var port := _read_port()
	var err := Net.join_game(address, port)
	if err != OK:
		_set_status(Net.last_error, WARN_INK)


func _read_port() -> int:
	var port := _port_edit.text.to_int()
	if port <= 0 or port > 65535:
		port = Net.DEFAULT_PORT
		_port_edit.text = str(port)
	return port


func _on_start_pressed() -> void:
	if Net.start_match():
		return
	_set_status(Net.last_error, WARN_INK)


## The host hung up, or the handshake never completed. The form goes back to
## idle with the reason on screen.
func _on_session_ended(reason: String) -> void:
	_refresh_roster()
	_set_status(reason, WARN_INK)
