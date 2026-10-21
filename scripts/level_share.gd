extends Node

## Talks to the community level service in server/level_server.py.
##
## The editor owns the UI; this autoload only turns publishing, browsing and
## downloading into small async calls. Every method returns a Dictionary with
## `ok` and either the requested values or a human-readable `error`, so callers
## never have to know about HTTP status codes or Godot's request result enum.
##
## The service URL comes from the Online panel and is remembered in user://.
## A build can bake a default into Project Settings under
## online/level_service_url without needing the player to configure anything.

const SETTINGS_PATH := "user://level_share.cfg"
const DEFAULT_BASE_URL := "http://127.0.0.1:8787"
const REQUEST_TIMEOUT := 15.0
const HOSTED_REQUEST_TIMEOUT := 90.0
const MAX_RESPONSE_BYTES := 2 * 1024 * 1024
const NAME_MAX := 60
const AUTHOR_MAX := 40
const DESCRIPTION_MAX := 280

var base_url := DEFAULT_BASE_URL
var author := ""
var last_error := ""


func _ready() -> void:
	base_url = _normalise_url(str(ProjectSettings.get_setting(
			"online/level_service_url", DEFAULT_BASE_URL)))
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		base_url = _normalise_url(str(config.get_value("online", "base_url", base_url)))
		author = str(config.get_value("online", "author", "")).strip_edges()


func configure(server_url: String, author_name: String) -> void:
	base_url = _normalise_url(server_url)
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


func fetch_levels(limit: int = 50, offset: int = 0) -> Dictionary:
	var path := "/api/levels?limit=%d&offset=%d" % [
		clampi(limit, 1, 100), maxi(offset, 0)]
	var result := await _request_json(path, HTTPClient.METHOD_GET)
	if not bool(result.get("ok", false)):
		return result
	var data = result.get("data", null)
	if not (data is Dictionary) or not (data.get("levels") is Array):
		return _fail("The level server returned an unexpected response.")
	return {
		"ok": true,
		"levels": data["levels"],
		"total": int(data.get("total", data["levels"].size())),
	}


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


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("online", "base_url", base_url)
	config.set_value("online", "author", author)
	config.save(SETTINGS_PATH)


func _normalise_url(value: String) -> String:
	var url := value.strip_edges()
	if url.is_empty():
		return DEFAULT_BASE_URL
	if not (url.begins_with("http://") or url.begins_with("https://")):
		url = "http://" + url
	return url.trim_suffix("/")


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
