extends Node2D
## The online PvP arena: one self-contained room, a local camera for each
## player's own viewport, and a first-to-five free-for-all.
##
## The layout is built here in code rather than in the scene. It is a data table
## (PLATFORMS, SPAWN_POINTS), so the room is retuned by editing numbers, and
## every peer builds an identical room from the same table instead of from a file
## that would have to stay in step.
##
## This scene is also what the mode's tests drive, and it can be opened on its
## own (F6) to walk the room: with no session it drops in a single local player
## and nothing is replicated.

const PLAYER_SCENE := preload("res://scenes/pvp_player.tscn")
const PvpPlayer := preload("res://scripts/pvp_player.gd")
const FONT_PATH := "res://Baby Doll.otf"

## The room's playable interior. Everything outside it is the backdrop.
const ARENA := Rect2(0.0, -220.0, 1400.0, 1000.0)
## Painted well past the room so the viewport never shows the default clear
## colour at its edges.
const BACKDROP := Rect2(-900.0, -1100.0, 3400.0, 2800.0)
const BACKDROP_COLOR := Color(0.05, 0.04, 0.05)
const ROOM_COLOR := Color(0.13, 0.09, 0.10)
const BLOCK_COLOR := Color(0.33, 0.22, 0.18)
const BLOCK_EDGE_COLOR := Color(0.5, 0.34, 0.26)
const EDGE_HEIGHT := 6.0

const BANNER_TIME := 1.4
const END_BANNER_TIME := 1.6
## How long to wait for the other peers' rooms before opening without them.
const SPAWN_TIMEOUT := 4.0

## Static geometry in world coordinates. The four outer walls sit outside ARENA
## so their visible inner face lands exactly on the room's edge.
const PLATFORMS: Array[Rect2] = [
	Rect2(-60.0, 780.0, 1520.0, 60.0),
	Rect2(-60.0, -280.0, 1520.0, 60.0),
	Rect2(-60.0, -220.0, 60.0, 1000.0),
	Rect2(1400.0, -220.0, 60.0, 1000.0),
	Rect2(160.0, 560.0, 260.0, 24.0),
	Rect2(980.0, 560.0, 260.0, 24.0),
	Rect2(560.0, 420.0, 280.0, 24.0),
	Rect2(120.0, 300.0, 220.0, 24.0),
	Rect2(1060.0, 300.0, 220.0, 24.0),
	Rect2(590.0, 160.0, 220.0, 24.0),
]

## One per player slot, used for the initial placement. A respawn goes through
## spawn_point_for() instead, which picks by who is still standing.
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(150.0, 685.0),
	Vector2(1250.0, 685.0),
	Vector2(700.0, 325.0),
	Vector2(700.0, 65.0),
]

var _players: Dictionary = {}
var _hud: CanvasLayer = null
var _score_list: VBoxContainer = null
var _banner: Label = null
var _overlay: Control = null
var _winner_label: Label = null
var _rematch_button: Button = null
var _banner_tween: Tween = null
var _leaving := false
## Fighters stay out of the room until every peer's copy of it exists - see
## _open_room().
var _open := false

@onready var _players_root: Node2D = $Players


func _ready() -> void:
	PvpPlayer.ensure_input_actions()
	_build_scenery()
	_build_hud()
	Net.roster_changed.connect(_sync_roster)
	Net.players_spawned.connect(_open_room)
	Net.match_started.connect(_silence_replication)
	Net.match_over.connect(_on_match_over)
	Net.session_ended.connect(_on_session_ended)
	if Net.is_online():
		Net.notify_arena_ready()
		# Safety net: if a peer never reports in - still loading, or gone - the
		# room opens anyway rather than leaving everyone in an empty arena.
		get_tree().create_timer(SPAWN_TIMEOUT).timeout.connect(_open_room)
	else:
		# No session at all: the room is being walked on its own.
		_open_room()


## Fighters are only placed once every peer has this room in its tree. A
## synchronizer packet that arrives before the node it addresses logs "node not
## found" and is dropped, and that first packet is the spawn position.
func _open_room() -> void:
	if _open:
		return
	_open = true
	_sync_roster()
	_show_banner("FIGHT!", BANNER_TIME)


## A rematch replaces this room with a fresh one, and the two peers do not tear
## their copies down at the same instant. Without this, the synchronizers of the
## match being left keep sending in that gap, and the peer that is already gone
## logs a "node not found" for every packet. match_started arrives on every peer
## before the swap, so silencing here closes the gap rather than racing it.
func _silence_replication() -> void:
	for id in _players:
		var node = _players[id]
		if node != null and is_instance_valid(node) and node.has_method("set_replication_visible"):
			node.set_replication_visible(false)


## Leaves the match. Every exit goes back to the lobby, so a player never lands
## in a room with nobody in it.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Net.quit_to_menu()


## Peer ids to have nodes for. Without a session the room is being walked on its
## own, so it gets a single local player and nothing to replicate to.
func _roster_ids() -> Array:
	var ids := Net.peer_ids()
	if ids.is_empty():
		ids = [1]
	return ids


## Brings the node set in line with the roster: one player per entry, nobody
## left over. Every peer runs this off the same replicated roster, so the node
## names - and therefore the paths the RPCs and the synchronizer use - match on
## every peer.
func _sync_roster() -> void:
	if not _open:
		return
	var ids := _roster_ids()
	for id: int in ids:
		var existing = _players.get(id)
		if existing == null or not is_instance_valid(existing):
			_spawn_player(id)
	for id: int in _players.keys():
		if not ids.has(id):
			_drop_player(id)
	_refresh_scores()


func _spawn_player(id: int) -> void:
	# Untyped on purpose: the player script is reached through its scene, and
	# naming it here would be a second preload of the same script for no gain.
	# The player scene inherits scenes/mole.tscn and overrides the root script
	# with pvp_player.gd, so the campaign mole's body, sprite frames and light
	# come along unchanged.
	var node = PLAYER_SCENE.instantiate()
	node.name = str(id)
	_players_root.add_child(node)
	_players[id] = node
	# configure() sets the authority before the next multiplayer poll, so the
	# synchronizer never gets a chance to run with the default one.
	node.configure(id, self, _slot_spawn_point(_slot_of(id)))


func _slot_of(id: int) -> int:
	return int(Net.players.get(id, {}).get("spawn", 0))


func _drop_player(id: int) -> void:
	var node = _players.get(id)
	_players.erase(id)
	if node != null and is_instance_valid(node):
		node.queue_free()


func _slot_spawn_point(slot: int) -> Vector2:
	return SPAWN_POINTS[slot % SPAWN_POINTS.size()]


## Where a respawning player should reappear: the free point furthest from
## whoever is still standing, so nobody walks straight back into the exchange
## they just lost.
func spawn_point_for(peer_id: int) -> Vector2:
	var threats: Array[Vector2] = []
	for id in _players:
		if int(id) == peer_id:
			continue
		var node = _players[id]
		if node != null and is_instance_valid(node) and node.alive:
			threats.append(node.global_position)
	var best := _slot_spawn_point(_slot_of(peer_id))
	var best_gap := -1.0
	for point in SPAWN_POINTS:
		var nearest := INF
		for threat in threats:
			nearest = minf(nearest, point.distance_squared_to(threat))
		if nearest > best_gap:
			best_gap = nearest
			best = point
	return best


func _build_scenery() -> void:
	_add_polygon(_rect_points(BACKDROP), BACKDROP_COLOR, -100)
	_add_polygon(_rect_points(ARENA), ROOM_COLOR, -90)
	for rect in PLATFORMS:
		_add_block(rect)
		# A lighter strip along the top face, so the surfaces that can actually
		# be stood on read at a glance.
		_add_polygon(_rect_points(Rect2(rect.position, Vector2(rect.size.x, EDGE_HEIGHT))), BLOCK_EDGE_COLOR, -49)


## One solid piece of the room: the static body the players stand on, and the
## plain rectangle drawn for it. Built together so the two cannot drift apart.
func _add_block(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	# The body sits at the rectangle's centre, so its shape can be centred on it
	# and the collider lands exactly on the drawn rectangle.
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	_add_polygon(_rect_points(rect), BLOCK_COLOR, -50)


func _add_polygon(points: PackedVector2Array, color: Color, z: int) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.z_index = z
	add_child(poly)


func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Hud"
	_hud.layer = 20
	add_child(_hud)

	_score_list = VBoxContainer.new()
	_score_list.name = "Scores"
	_score_list.position = Vector2(30.0, 24.0)
	_score_list.add_theme_constant_override("separation", 6)
	_hud.add_child(_score_list)

	_banner = _make_label(46, Color(1.0, 0.88, 0.45))
	_banner.name = "Banner"
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -520.0
	_banner.offset_right = 520.0
	_banner.offset_top = 96.0
	_banner.offset_bottom = 168.0
	_banner.modulate.a = 0.0
	_hud.add_child(_banner)

	_overlay = Control.new()
	_overlay.name = "MatchOver"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_hud.add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -300.0
	box.offset_right = 300.0
	box.offset_top = -140.0
	box.offset_bottom = 140.0
	box.add_theme_constant_override("separation", 28)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay.add_child(box)

	_winner_label = _make_label(54, Color(1.0, 0.88, 0.45))
	_winner_label.text = "MATCH OVER"
	box.add_child(_winner_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)

	_rematch_button = _make_button("REMATCH")
	_rematch_button.pressed.connect(_on_rematch_pressed)
	row.add_child(_rematch_button)

	var quit_button := _make_button("LEAVE")
	quit_button.pressed.connect(_leave)
	row.add_child(quit_button)


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load(FONT_PATH) as Font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200.0, 60.0)
	button.add_theme_font_override("font", load(FONT_PATH) as Font)
	button.add_theme_font_size_override("font_size", 24)
	# Jump is ui_accept, which is also "activate the focused control": without
	# this, pressing jump would fire whichever button happens to hold focus.
	button.focus_mode = Control.FOCUS_NONE
	return button


func _refresh_scores() -> void:
	for child in _score_list.get_children():
		child.queue_free()
	var header := _make_label(20, Color(0.75, 0.68, 0.6))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.text = "FIRST TO %d" % Net.kills_to_win
	_score_list.add_child(header)
	for id: int in _roster_ids():
		var row := _make_label(26, Net.player_color_of(id))
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var suffix := "  (YOU)" if id == Net.local_id() else ""
		row.text = "%s  %d%s" % [Net.player_name_of(id), Net.score_of(id), suffix]
		_score_list.add_child(row)


func _show_banner(text: String, hold: float) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.modulate.a = 1.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _on_match_over(winner_id: int) -> void:
	if _winner_label == null:
		return
	_winner_label.text = "%s WINS!" % Net.player_name_of(winner_id)
	_winner_label.add_theme_color_override("font_color", Net.player_color_of(winner_id))
	# Only the host can start one, so a client gets the screen without a button
	# that would refuse to work.
	_rematch_button.visible = Net.is_host()
	_overlay.visible = true


func _on_rematch_pressed() -> void:
	if Net.start_match():
		return
	_show_banner(Net.last_error, END_BANNER_TIME)


func _on_session_ended(reason: String) -> void:
	if _leaving:
		return
	_leaving = true
	_show_banner(reason, END_BANNER_TIME)
	await get_tree().create_timer(END_BANNER_TIME + 0.3).timeout
	Net.quit_to_menu()
