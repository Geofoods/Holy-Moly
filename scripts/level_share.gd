extends Node

## Talks to the community level service in server/level_server.py.
##
## The editor owns the UI; this autoload only turns publishing, browsing and
## downloading into small async calls. Every method returns a Dictionary with
## `ok` and either the requested values or a human-readable `error`, so callers
## never have to know about HTTP status codes or Godot's request result enum.
##
## All publishing, browsing, downloading and liking goes to the hosted community
## service. Only the preferred author name, a random voter id and the levels this
## installation has liked are remembered in user://.

const SETTINGS_PATH := "user://level_share.cfg"
const SERVICE_URL := "https://holy-moley-levels.onrender.com"
const REQUEST_TIMEOUT := 15.0
const HOSTED_REQUEST_TIMEOUT := 90.0
const MAX_RESPONSE_BYTES := 2 * 1024 * 1024
const NAME_MAX := 60
const AUTHOR_MAX := 40
const DESCRIPTION_MAX := 280
## The browser's editing session gets its own working file so opening a
## community level can never overwrite the author's own editor autosave.
const BROWSER_AUTOSAVE_PATH := "user://levels/_browser_autosave.json"
## The normal-gameplay host for a community level. Kept here as well as in the
## browser so game over can tell a community run from a campaign level.
const COMMUNITY_PLAY_SCENE := "res://scenes/community_play.tscn"
## A free Render web service sleeps after fifteen minutes without traffic.
## While the game is open, a silent health ping every ten minutes keeps the
## hosted service warm for the Level Browser. The ping is deliberately not a
## user-facing request: failures are ignored and the browser still has its
## normal loading/retry path.
const WARMUP_INTERVAL := 600.0
const WARMUP_BODY_LIMIT := 4096
## Two throwaway levels were published to the live service while the community
## board was being wired up. The service has no delete route, so every list this
## client fetches skips them by id. Hidden by id rather than name, so renaming
## one cannot bring it back.
const HIDDEN_LEVEL_IDS := ["d16bbafa2582", "c99cc740cf96"]

var base_url := SERVICE_URL
var author := ""
var last_error := ""
## A random installation id is enough to make a like unique without accounts.
## It lives in the same small config as the preferred author name.
var voter_id := ""
var liked_levels: Array[String] = []

var _pending_editor_level := ""
var _pending_editor_playtest := false
var _pending_editor_autosave := ""
## The last community level the browser launched. Unlike the editor request,
## this is not consumed on arrival: game over sends the player back to the same
## scene, and that reload needs to know which JSON to build again. A new PLAY
## from the browser replaces it; returning to the browser clears it.
var _community_level_path := ""
## Checkpoint banked in the current community run. Kept out of Progress so a
## custom level can never overwrite the player's campaign checkpoint.
var _community_checkpoint: Dictionary = {}
var _warmup_in_flight := false
var _warmup_timer: Timer = null


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		author = str(config.get_value("online", "author", "")).strip_edges()
		voter_id = str(config.get_value("online", "voter_id", "")).strip_edges()
		var raw_liked = config.get_value("online", "liked_levels", [])
		if raw_liked is Array or raw_liked is PackedStringArray:
			for raw_id in raw_liked:
				var level_id := str(raw_id)
				if _valid_id(level_id) and level_id not in liked_levels:
					liked_levels.append(level_id)
	if voter_id.is_empty():
		voter_id = _new_voter_id()
		_save_settings()


## Starts the session-long keep-warm timer. Called by the title screen so normal
## gameplay and the editor do not need to know about the community service.
## Headless runs are skipped: they should not make live network requests just
## because a scene was loaded for testing.
func start_service_keepalive() -> void:
	if DisplayServer.get_name() == "headless" or _warmup_timer != null:
		return
	_warmup_timer = Timer.new()
	_warmup_timer.name = "LevelServiceWarmup"
	_warmup_timer.wait_time = WARMUP_INTERVAL
	_warmup_timer.one_shot = false
	# Keep warming even if the player leaves the game paused for a while. The
	# timer lives on this autoload, so it survives scene changes until the game
	# exits.
	_warmup_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_warmup_timer.timeout.connect(warm_up_service)
	add_child(_warmup_timer)
	_warmup_timer.start()
	warm_up_service()


## One silent GET /health. The response is intentionally ignored; this only
## exists to stop a sleeping free Render instance from making the next browser
## request wait through a cold start.
func warm_up_service() -> void:
	if _warmup_in_flight:
		return
	_warmup_in_flight = true
	var http := HTTPRequest.new()
	http.name = "LevelServiceWarmupRequest"
	http.timeout = _request_timeout()
	http.body_size_limit = WARMUP_BODY_LIMIT
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	var error := http.request(
			_url("/health"),
			PackedStringArray(["Accept: application/json"]),
			HTTPClient.METHOD_GET)
	if error != OK:
		_warmup_in_flight = false
		http.queue_free()
		return
	await http.request_completed
	_warmup_in_flight = false
	http.queue_free()


func configure(author_name: String) -> void:
	author = author_name.strip_edges().left(AUTHOR_MAX)
	_save_settings()


func get_share_url(level_id: String) -> String:
	if not _valid_id(level_id):
		return ""
	return "%s/api/levels/%s" % [base_url, level_id]


func publish(level_data: Dictionary, level_name: String, author_name: String,
		description: String) -> Dictionary:
	if not (level_data.get("blocks") is Array and level_data.get("enemies") is Array):
		return _fail("That level is not in a publishable state.")
	var clean_author := author_name.strip_edges().left(AUTHOR_MAX)
	if clean_author.is_empty():
		clean_author = "Anonymous"
	var payload := {
		"name": level_name.strip_edges().left(NAME_MAX),
		"author": clean_author,
		"description": description.strip_edges().left(DESCRIPTION_MAX),
		"level": level_data,
	}
	var result := await _request_json("/api/levels", HTTPClient.METHOD_POST, payload)
	if not bool(result.get("ok", false)):
		return result
	var data = result.get("data", null)
	if not (data is Dictionary) or not (data.get("level") is Dictionary):
		return _fail("The level server did not return the published level.")
	return {"ok": true, "level": data["level"]}


## `sort` is one of "newest", "downloads" or "likes"; the server orders the
## whole catalogue before paging, so a sorted page is not just the newest page
## reordered. `search` narrows the catalogue by name, author, description or id;
## `since` is a Unix timestamp cutoff, where 0 means all time. Older server builds
## ignore those filters, and the browser repeats them locally so they still work
## while a deployment catches up.
func fetch_levels(limit: int = 50, offset: int = 0, sort: String = "newest",
		search: String = "", since: int = 0) -> Dictionary:
	var order := sort if sort in ["newest", "downloads", "likes"] else "newest"
	var path := "/api/levels?limit=%d&offset=%d&sort=%s" % [
		clampi(limit, 1, 100), maxi(offset, 0), order]
	var needle := search.strip_edges().left(80)
	if not needle.is_empty():
		path += "&q=" + needle.uri_encode()
	if since > 0:
		path += "&since=%d" % since
	var result := await _request_json(path, HTTPClient.METHOD_GET)
	if not bool(result.get("ok", false)):
		return result
	var data = result.get("data", null)
	if not (data is Dictionary) or not (data.get("levels") is Array):
		return _fail("The level server returned an unexpected response.")
	var fetched: Array = data["levels"]
	var levels := _without_hidden_levels(fetched)
	# The server's total still counts anything filtered out above, so take back
	# however many of them came back in this page.
	var total := int(data.get("total", fetched.size())) - (fetched.size() - levels.size())
	return {
		"ok": true,
		"levels": levels,
		"total": maxi(total, levels.size()),
	}


## See HIDDEN_LEVEL_IDS. A new array is built so the downloaded payload the
## caller passed in is left untouched.
func _without_hidden_levels(levels: Array) -> Array:
	var visible: Array = []
	for raw_entry in levels:
		if raw_entry is Dictionary and str(raw_entry.get("id", "")) in HIDDEN_LEVEL_IDS:
			continue
		visible.append(raw_entry)
	return visible


func download_level(level_id: String) -> Dictionary:
	if not _valid_id(level_id):
		return _fail("Invalid level id.")
	var result := await _request_json("/api/levels/" + level_id, HTTPClient.METHOD_GET)
	if not bool(result.get("ok", false)):
		return result
	var data = result.get("data", null)
	if not (data is Dictionary) or not (data.get("data") is Dictionary) \
			or not (data.get("level") is Dictionary):
		return _fail("The level server returned an empty level.")
	return {
		"ok": true,
		"level": data["level"],
		"data": data["data"],
	}


func is_level_liked(level_id: String) -> bool:
	return level_id in liked_levels


## Likes and unlikes one level. The voter id keeps one installation from
## counting twice; the server returns the updated summary so both the dedicated
## browser and the editor's BROWSE list can show the same count immediately.
func set_level_liked(level_id: String, liked: bool) -> Dictionary:
	if not _valid_id(level_id):
		return _fail("Invalid level id.")
	var result := await _request_json(
			"/api/levels/%s/like" % level_id,
			HTTPClient.METHOD_POST,
			{"liked": liked, "voter": voter_id})
	if not bool(result.get("ok", false)):
		return result
	var data = result.get("data", null)
	if not (data is Dictionary) or not (data.get("level") is Dictionary):
		return _fail("The level server did not return the updated level.")
	if liked:
		if level_id not in liked_levels:
			liked_levels.append(level_id)
	else:
		liked_levels.erase(level_id)
	_save_settings()
	return {"ok": true, "level": data["level"], "liked": liked}


## Starts a fresh normal-gameplay run of a downloaded community level. The
## checkpoint is deliberately dropped here: pressing PLAY is a new run, while a
## retry after death comes back through community_play_level() below and keeps
## the checkpoint banked during that run.
func begin_community_play(path: String) -> void:
	_community_level_path = path
	_community_checkpoint = {}


func community_play_level() -> String:
	return _community_level_path


func set_community_checkpoint(level_path: String, spawn_point: Vector2,
		station_position: Vector2) -> void:
	if level_path != _community_level_path:
		return
	_community_checkpoint = {
		"position": spawn_point,
		"station": station_position,
	}


func community_checkpoint(level_path: String) -> Dictionary:
	if level_path != _community_level_path:
		return {}
	return _community_checkpoint.duplicate()


func clear_community_play() -> void:
	_community_level_path = ""
	_community_checkpoint = {}


## Hands the editor a downloaded community level to open on the next scene load.
## The separate autosave path is what keeps the player's own Level Editor work
## out of the way.
func request_editor_level(path: String, start_playing: bool = true) -> void:
	_pending_editor_level = path
	_pending_editor_playtest = start_playing
	_pending_editor_autosave = BROWSER_AUTOSAVE_PATH


func take_editor_request() -> Dictionary:
	if _pending_editor_level.is_empty():
		return {}
	var request := {
		"level_path": _pending_editor_level,
		"playtest": _pending_editor_playtest,
		"autosave_path": _pending_editor_autosave,
	}
	_pending_editor_level = ""
	_pending_editor_playtest = false
	_pending_editor_autosave = ""
	return request


func _request_json(path: String, method: int, payload = null) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = _request_timeout()
	http.body_size_limit = MAX_RESPONSE_BYTES
	add_child(http)

	var headers := PackedStringArray(["Accept: application/json"])
	var body := ""
	if payload != null:
		headers.append("Content-Type: application/json")
		body = JSON.stringify(payload)
	var error := http.request(_url(path), headers, method, body)
	if error != OK:
		http.queue_free()
		return _fail("Could not reach %s (error %d)." % [base_url, error])

	var response: Array = await http.request_completed
	http.queue_free()
	if response.size() < 4:
		return _fail("The level server closed the request unexpectedly.")

	var result_code := int(response[0])
	var status_code := int(response[1])
	var body_bytes: PackedByteArray = response[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return _fail(_request_result_message(result_code))
	if status_code < 200 or status_code >= 300:
		var message := "The level server returned HTTP %d." % status_code
		var error_body = JSON.parse_string(body_bytes.get_string_from_utf8())
		if error_body is Dictionary and error_body.has("error"):
			message = str(error_body["error"])
		elif status_code in [502, 503, 504]:
			message = "The community server is waking up. Wait a few seconds and try again."
		return _fail(message)

	var text := body_bytes.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return _fail("The level server returned an unreadable response.")
	return {"ok": true, "status": status_code, "data": parsed}


func _request_timeout() -> float:
	# A free Render service can take about a minute to wake after spinning down.
	# Keep local/LAN failures quick, but give public servers time to cold-start.
	var url := base_url.to_lower()
	var is_local := (
			url.begins_with("http://127.")
			or url.begins_with("http://localhost")
			or url.begins_with("http://10.")
			or url.begins_with("http://192.168.")
			or url.begins_with("http://172."))
	return REQUEST_TIMEOUT if is_local else HOSTED_REQUEST_TIMEOUT


func _request_result_message(result_code: int) -> String:
	match result_code:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Could not connect to %s. Is the community server running?" % base_url
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Could not find the community server at %s." % base_url
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "The connection to the community server was interrupted."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "The community server's HTTPS certificate could not be verified."
		HTTPRequest.RESULT_NO_RESPONSE:
			return "The community server did not respond in time. A free server may need another try after waking."
		HTTPRequest.RESULT_TIMEOUT:
			return "The community server took too long to respond. A free server can take about a minute to wake; try again."
		_:
			return "The community request failed (code %d)." % result_code


func _fail(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}


func _new_voter_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("online", "author", author)
	config.set_value("online", "voter_id", voter_id)
	config.set_value("online", "liked_levels", PackedStringArray(liked_levels))
	config.save(SETTINGS_PATH)


func _url(path: String) -> String:
	return base_url + path


func _valid_id(level_id: String) -> bool:
	if level_id.is_empty() or level_id.length() > 64:
		return false
	for i in level_id.length():
		var ch := level_id.substr(i, 1)
		var allowed := (ch >= "a" and ch <= "z") \
				or (ch >= "A" and ch <= "Z") \
				or (ch >= "0" and ch <= "9") \
				or ch == "_" or ch == "-"
		if not allowed:
			return false
	return true
