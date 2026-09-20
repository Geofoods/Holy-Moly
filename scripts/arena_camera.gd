extends Camera2D
## Drives the arena camera sequence in "The Arena". When the mole enters the
## `arenastart` zone the game pauses while the view pans from the player camera
## to the "breaking camera" where the snail begs for help, shows its dialogue,
## then pans back to this arena overview camera and unpauses for the fight. Once
## the wave manager reports the enemies cleared, the view pans over to the
## "breaking camera" to watch the wall shatter, then pans back to the player
## camera.

const PAN_DURATION := 1.0
const BREAK_HOLD := 2.5

enum State { IDLE, PANNING_TO_SNAIL, DIALOG, PANNING_BACK, FIGHTING, PANNING_TO_BREAK, BREAKING, PANNING_OUT }

var _state := State.IDLE
var _done := false
var _mole: Node2D = null
var _mole_cam: Camera2D = null
var _arena_pos := Vector2.ZERO
var _arena_zoom := Vector2(0.5, 0.5)
var _break_pos := Vector2.ZERO
var _break_zoom := Vector2(0.5, 0.5)
var _from_pos := Vector2.ZERO
var _from_zoom := Vector2.ONE
var _to_pos := Vector2.ZERO
var _to_zoom := Vector2.ONE
var _t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena_pos = global_position
	_arena_zoom = zoom
	enabled = false
	var break_cam := get_parent().get_node_or_null("breaking camera") as Camera2D
	if break_cam:
		_break_pos = break_cam.global_position
		_break_zoom = break_cam.zoom
	var arena_map := get_parent().get_node_or_null("TileMap2") as TileMap
	if arena_map:
		for layer in range(arena_map.get_layers_count()):
			arena_map.set_layer_enabled(layer, false)
	var start := get_parent().get_node_or_null("arenastart") as Area2D
	if start:
		start.body_entered.connect(_on_arena_start_entered)
	var waves := get_parent().get_node_or_null("WaveManager")
	if waves and waves.has_signal("cleared"):
		waves.cleared.connect(_on_waves_cleared)

func _process(delta: float) -> void:
	if _state == State.PANNING_TO_SNAIL or _state == State.PANNING_TO_BREAK or _state == State.PANNING_BACK or _state == State.PANNING_OUT:
		_t += delta / PAN_DURATION
		var s := _smoothstep(minf(_t, 1.0))
		global_position = _from_pos.lerp(_to_pos, s)
		zoom = _from_zoom.lerp(_to_zoom, s)
		if _t >= 1.0:
			match _state:
				State.PANNING_TO_SNAIL:
					_finish_pan_to_snail()
				State.PANNING_TO_BREAK:
					_finish_pan_to_break()
				State.PANNING_BACK:
					_finish_pan_back()
				State.PANNING_OUT:
					_finish_pan_out()

func _on_arena_start_entered(body: Node) -> void:
	if _done or _state != State.IDLE:
		return
	if not body.is_in_group("mole"):
		return
	_mole = body as Node2D
	_mole_cam = _mole.get_node_or_null("Camera2D") as Camera2D
	if _mole_cam == null:
		return
	_begin_sequence()

func _begin_sequence() -> void:
	_state = State.PANNING_TO_SNAIL
	_t = 0.0
	_from_pos = _mole_cam.global_position
	_from_zoom = _mole_cam.zoom
	_to_pos = _break_pos
	_to_zoom = _break_zoom

	var arena_map := get_parent().get_node_or_null("TileMap2") as TileMap
	if arena_map:
		arena_map.visible = true
		for layer in range(arena_map.get_layers_count()):
			arena_map.set_layer_enabled(layer, true)

	_mole.process_mode = Node.PROCESS_MODE_DISABLED
	global_position = _from_pos
	zoom = _from_zoom
	enabled = true
	make_current()
	get_tree().paused = true

func _finish_pan_to_snail() -> void:
	_state = State.DIALOG
	var snail := get_parent().get_node_or_null("Snail")
	if snail and snail.has_signal("dialogue_closed") and snail.has_method("show_dialogue"):
		if not snail.dialogue_closed.is_connected(_on_snail_dialogue_closed):
			snail.dialogue_closed.connect(_on_snail_dialogue_closed)
		snail.show_dialogue()
	else:
		call_deferred("_begin_pan_back")

func _on_snail_dialogue_closed() -> void:
	if _state != State.DIALOG:
		return
	_begin_pan_back()

func _begin_pan_back() -> void:
	_state = State.PANNING_BACK
	_t = 0.0
	_from_pos = global_position
	_from_zoom = zoom
	_to_pos = _arena_pos
	_to_zoom = _arena_zoom
	if is_instance_valid(_mole):
		_mole.process_mode = Node.PROCESS_MODE_DISABLED

func _finish_pan_back() -> void:
	_state = State.FIGHTING
	if is_instance_valid(_mole):
		_mole.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false

func _on_waves_cleared() -> void:
	if _state != State.FIGHTING:
		return
	_done = true
	_state = State.PANNING_TO_BREAK
	_t = 0.0
	_from_pos = global_position
	_from_zoom = zoom
	_to_pos = _break_pos
	_to_zoom = _break_zoom
	global_position = _from_pos
	zoom = _from_zoom
	enabled = true
	make_current()
	if is_instance_valid(_mole):
		_mole.process_mode = Node.PROCESS_MODE_DISABLED

func _finish_pan_to_break() -> void:
	_state = State.BREAKING
	await get_tree().create_timer(BREAK_HOLD).timeout
	if is_inside_tree() and _state == State.BREAKING:
		_begin_pan_out()

func _begin_pan_out() -> void:
	_state = State.PANNING_OUT
	_t = 0.0
	_from_pos = global_position
	_from_zoom = zoom
	if is_instance_valid(_mole_cam):
		_to_pos = _mole_cam.global_position
		_to_zoom = _mole_cam.zoom
		_mole_cam.reset_smoothing()
	elif is_instance_valid(_mole):
		_to_pos = _mole.global_position
		_to_zoom = _mole_cam.zoom if _mole_cam else Vector2(0.65, 0.65)
	else:
		_state = State.IDLE
		return
	if is_instance_valid(_mole):
		_mole.process_mode = Node.PROCESS_MODE_DISABLED

func _finish_pan_out() -> void:
	if is_instance_valid(_mole_cam):
		_mole_cam.reset_smoothing()
	enabled = false
	if is_instance_valid(_mole):
		_mole.process_mode = Node.PROCESS_MODE_INHERIT
	_state = State.IDLE

func _smoothstep(t: float) -> float:
	var s := t * t * (3.0 - 2.0 * t)
	return s * s * (3.0 - 2.0 * s)