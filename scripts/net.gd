extends Node
## Session manager for the online PvP mode.
##
## Holy Moley is a single-player campaign, so this mode is deliberately
## self-contained: nothing here touches Inventory, Progress, Shop, Quests or
## LevelData, and the arena can be entered without a run in progress.
##
## Transport is Godot's built-in ENetMultiplayerPeer - a host opens a server and
## everyone else joins by address. ENet needs a real UDP socket, which the HTML5
## export does not have, so the browser build hides the mode (see intro.gd).
##
## Authority model, which pvp_arena.gd and pvp_player.gd both lean on:
##   - the server (peer 1) owns the roster, the scores and the start/rematch
##     hand-off. Clients never write to `players` themselves.
##   - every peer instantiates one node per roster entry, but each node is
##     authoritative on its own peer only, so per-frame movement never crosses
##     the network. See pvp_player.gd.
##   - a swing is scored exactly once: the attacker's client detects the hit and
##     reports it to the victim's client, which applies it to itself.

## Well clear of the game's own ports and of common service defaults.
const DEFAULT_PORT := 27015
const MAX_PLAYERS := 4
const DEFAULT_KILLS_TO_WIN := 5
const ARENA_SCENE := "res://scenes/pvp_arena.tscn"
const MENU_SCENE := "res://scenes/multiplayer_menu.tscn"
const TITLE_SCENE := "res://scenes/intro.tscn"
const TRANSITION_SCENE := "res://scenes/scene_transition.tscn"
const DEFAULT_NAME := "MOLE"

## Distinct tints so the moles in one arena stay tellable apart. Each joiner
## takes the lowest free slot, so a colour is only reused once someone leaves.
const PLAYER_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.5, 0.5),
	Color(0.55, 0.8, 1.0),
	Color(0.7, 1.0, 0.55),
	Color(1.0, 0.85, 0.45),
]

signal roster_changed
signal match_started
## Fired on every peer once the whole roster's arenas exist, so the fighters can
## be placed at the same moment everywhere.
signal players_spawned
signal match_over(winner_id: int)
signal session_ended(reason: String)

## peer id -> {"name": String, "color_idx": int, "score": int, "spawn": int}
## Server-authoritative. Clients only ever replace this wholesale from a roster
## broadcast, so there is no field to drift out of sync.
var players: Dictionary = {}
var local_name := DEFAULT_NAME
var kills_to_win := DEFAULT_KILLS_TO_WIN
var in_match := false
var last_error := ""

## The multiplayer signals live on the SceneTree's MultiplayerAPI, which outlives
## every scene, so they must only be connected once for the whole session.
var _bound := false
## Set while this peer is the one tearing the session down, so its own hang-up
## does not come back as a "the host left" error screen.
var _leaving := false
## Peers whose arena scene is in their tree for the current match, and whether the
## release is still pending. See notify_arena_ready().
var _arena_ready: Dictionary = {}
var _awaiting_spawn := false
## The scene being moved to, and whether a move is already being driven. See
## change_scene().
var _scene_target := ""
var _scene_changing := false


func is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func local_id() -> int:
	return multiplayer.get_unique_id()


func local_slot() -> int:
	return int(players.get(local_id(), {}).get("spawn", 0))


func player_name_of(id: int) -> String:
	return str(players.get(id, {}).get("name", "PLAYER %d" % id))


func player_color_of(id: int) -> Color:
	var index := int(players.get(id, {}).get("color_idx", 0))
	return PLAYER_COLORS[index % PLAYER_COLORS.size()]


func score_of(id: int) -> int:
	return int(players.get(id, {}).get("score", 0))


## Peer ids in a stable order. Every peer builds the same arena from its own
## copy of the roster, so the node layout matches without anything extra going
## over the wire.
func peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for id in players:
		ids.append(int(id))
	ids.sort()
	return ids


func host_game(port: int) -> Error:
	close_session()
	players.clear()
	in_match = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		last_error = "Could not open port %d (%s)." % [port, error_string(err)]
		return err
	multiplayer.multiplayer_peer = peer
	_bind_signals()
	_leaving = false
	# The server is a player too, but ENet never fires peer_connected for
	# itself, so the host is the only entry seeded by hand.
	_add_player(1, _clean_name(local_name))
	_broadcast_roster()
	return OK


func join_game(address: String, port: int) -> Error:
	close_session()
	players.clear()
	in_match = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		last_error = "Could not reach %s:%d (%s)." % [address, port, error_string(err)]
		return err
	multiplayer.multiplayer_peer = peer
	_bind_signals()
	_leaving = false
	# Shown until the server's roster arrives, so the joiner can see itself in
	# the lobby while the handshake is still going.
	_add_player(local_id(), _clean_name(local_name))
	roster_changed.emit()
	return OK


func set_local_name(player_name: String) -> void:
	local_name = _clean_name(player_name)


## Tears the peer down but keeps the roster, so a "quit to menu" can still show
## who was in the match on the way out.
func close_session() -> void:
	_leaving = true
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		(peer as ENetMultiplayerPeer).close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## Every peer's exit path: drop the connection and head back to the lobby.
func quit_to_menu() -> void:
	close_session()
	players.clear()
	in_match = false
	change_scene(MENU_SCENE)


## Same, but all the way out to the title screen.
func quit_to_title() -> void:
	close_session()
	players.clear()
	in_match = false
	change_scene(TITLE_SCENE)


## Returns false with `last_error` set when the match cannot start, so the caller
## can put the reason on screen instead of silently doing nothing.
func start_match() -> bool:
	if not is_host():
		last_error = "Only the host can start the match."
		return false
	if players.size() < 2:
		last_error = "Need at least two players."
		return false
	# A rematch is the same match: the board is wiped here so both the arena that
	# is about to load and the score display start from zero.
	for id in players:
		players[id]["score"] = 0
	_broadcast_roster()
	_begin_match.rpc()
	_begin_match()
	return true


## Called by a freshly loaded arena on every peer. The players are only placed
## once every peer in the roster has one: a MultiplayerSynchronizer packet that
## arrives before the node it addresses exists logs "node not found" and is
## dropped, and that very packet carries the spawn position. Waiting makes the
## room open at the same moment everywhere and keeps the logs clean.
func notify_arena_ready() -> void:
	if not is_online():
		players_spawned.emit()
		return
	if is_host():
		_register_arena_ready(1)
	else:
		_arena_ready_report.rpc_id(1)


## Called by a player whose health just ran out. Routed to the server, which is
## the only peer allowed to touch the scores.
func report_kill(victim_id: int, killer_id: int) -> void:
	if is_host():
		_apply_kill(victim_id, killer_id)
	else:
		_submit_kill.rpc_id(1, victim_id, killer_id)


## Swaps scenes behind the game's own circle wipe, so the PvP mode is entered and
## left the way every level is.
##
## Requests are serialised and the latest one wins. scene_transition.gd runs one
## wipe at a time and drops a second request outright, and a dropped quit is not
## a cosmetic problem here: the arena latches its exit as soon as it asks to
## leave, so a swallowed request would strand the player on a dead screen.
func change_scene(path: String) -> void:
	_scene_target = path
	if _scene_changing:
		return
	_scene_changing = true
	while not _scene_target.is_empty():
		var target := _scene_target
		_scene_target = ""
		await _perform_scene_change(target)
	_scene_changing = false


func _perform_scene_change(path: String) -> void:
	# Wait out any wipe already on screen before asking for another one, rather
	# than racing it and being dropped.
	while _transition_in_flight():
		await get_tree().process_frame
	var transition = load(TRANSITION_SCENE).instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(path)


## True while a circle wipe is still on screen. That node frees itself once the
## incoming scene has settled, so its presence is the signal.
func _transition_in_flight() -> bool:
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.has_method("change_to"):
			return true
	return false


func _bind_signals() -> void:
	if _bound:
		return
	_bound = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_connected_to_server() -> void:
	# The handshake is done, so the name can be handed to the server that will
	# be the only peer deciding colours, spawn slots and scores.
	_announce_name.rpc_id(1, local_name)


func _on_connection_failed() -> void:
	if _leaving:
		return
	close_session()
	players.clear()
	session_ended.emit("COULD NOT REACH THE HOST")


func _on_server_disconnected() -> void:
	if _leaving:
		return
	close_session()
	players.clear()
	in_match = false
	session_ended.emit("THE HOST LEFT")


func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	# A placeholder entry, replaced as soon as the joiner announces itself. Doing
	# it here rather than on _announce_name keeps a silent peer visible instead of
	# letting it linger as an invisible teammate.
	_add_player(id, "PLAYER %d" % id)
	_broadcast_roster()


func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
	if is_host():
		_broadcast_roster()
	else:
		# Clients receive this for the peers that leave, so their arena can drop
		# the matching node. The server's roster broadcast follows and is the
		# authority either way.
		roster_changed.emit()


func _add_player(id: int, player_name: String) -> void:
	if players.has(id):
		players[id]["name"] = player_name
		return
	players[id] = {
		"name": player_name,
		"color_idx": _free_index("color_idx", PLAYER_COLORS.size()),
		"score": 0,
		"spawn": _free_index("spawn", 0),
	}


## Lowest slot not already taken, so colours and spawn points stay distinct while
## a match is running rather than being handed out by raw join order.
func _free_index(key: String, limit: int) -> int:
	var used := {}
	for id in players:
		used[int(players[id].get(key, 0))] = true
	var index := 0
	while used.has(index) and (limit <= 0 or index < limit):
		index += 1
	return index


func _clean_name(raw: String) -> String:
	var trimmed := raw.strip_edges()
	if trimmed.is_empty():
		return DEFAULT_NAME
	return trimmed.left(16)


func _broadcast_roster() -> void:
	var payload := {}
	for id in players:
		payload[id] = (players[id] as Dictionary).duplicate()
	_apply_roster.rpc(payload)
	_apply_roster(payload)


@rpc("authority", "call_remote", "reliable")
func _apply_roster(payload: Dictionary) -> void:
	var ids := payload.keys()
	ids.sort()
	var next := {}
	for id in ids:
		next[int(id)] = payload[id]
	players = next
	roster_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _announce_name(player_name: String) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_add_player(sender, _clean_name(player_name))
	_broadcast_roster()


@rpc("any_peer", "call_remote", "reliable")
func _submit_kill(victim_id: int, killer_id: int) -> void:
	if not is_host():
		return
	# Only the peer that died may report its own death. Without this check any
	# client could award itself points by inventing kills for the others.
	if multiplayer.get_remote_sender_id() != victim_id:
		return
	_apply_kill(victim_id, killer_id)


func _apply_kill(victim_id: int, killer_id: int) -> void:
	if not in_match:
		return
	# A death with nobody to credit (falling out of the room) still costs the
	# victim their life, it just does not score for anyone.
	if players.has(killer_id) and killer_id != victim_id:
		players[killer_id]["score"] = int(players[killer_id]["score"]) + 1
	_broadcast_roster()
	if players.has(killer_id) and score_of(killer_id) >= kills_to_win:
		_finish_match(killer_id)


func _finish_match(winner_id: int) -> void:
	if not in_match:
		return
	in_match = false
	_apply_match_over.rpc(winner_id)
	_apply_match_over(winner_id)


@rpc("authority", "call_remote", "reliable")
func _apply_match_over(winner_id: int) -> void:
	in_match = false
	match_over.emit(winner_id)


@rpc("authority", "call_remote", "reliable")
func _begin_match() -> void:
	in_match = true
	_arena_ready.clear()
	_awaiting_spawn = true
	match_started.emit()
	change_scene(ARENA_SCENE)


@rpc("any_peer", "call_remote", "reliable")
func _arena_ready_report() -> void:
	if not is_host():
		return
	_register_arena_ready(multiplayer.get_remote_sender_id())


func _register_arena_ready(id: int) -> void:
	if not _awaiting_spawn or id <= 0:
		return
	_arena_ready[id] = true
	for peer in players:
		if not _arena_ready.has(peer):
			return
	_awaiting_spawn = false
	_spawn_players.rpc()
	_spawn_players()


@rpc("authority", "call_remote", "reliable")
func _spawn_players() -> void:
	players_spawned.emit()
