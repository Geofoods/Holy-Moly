extends Node2D

const MAX_FIREFLIES := 64
const SPAWN_RADIUS := 1800.0
const DESPAWN_DIST := 2200.0
const SPAWNS_PER_FRAME := 5
## How often (in seconds) to rescan children for despawns / refresh the count.
## Spawning still happens every frame up to the cached count.
const SCAN_INTERVAL := 0.25

var firefly_scene := preload("res://scenes/firefly.tscn")
var _pool: Array[Node2D] = []

@export var firefly_color := Color(1, 0.9, 0.4, 0.9)

## The level editor points this at its camera while editing and at the preview
## mole during a playtest. Campaign scenes leave it null and follow the mole.
var focus_override: Node2D = null

var _focus: Node2D = null
var _focus_refresh_timer := 0.0
var _scan_timer := 0.0
var _live_count := 0

func _ready() -> void:
	child_entered_tree.connect(func(_n: Node): _live_count += 1)
	child_exiting_tree.connect(func(_n: Node): _live_count -= 1)

func _process(delta: float) -> void:
	_focus_refresh_timer -= delta
	if _focus_refresh_timer <= 0.0:
		_focus_refresh_timer = 0.5
		_focus = _resolve_focus()
	if _focus == null or not is_instance_valid(_focus):
		return

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_INTERVAL
		_recycle_far_children()

	var spawned := 0
	while _live_count < MAX_FIREFLIES and spawned < SPAWNS_PER_FRAME:
		var f := _take_firefly()
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(50.0, SPAWN_RADIUS)
		f.global_position = _focus.global_position + Vector2(cos(angle), sin(angle)) * dist
		add_child(f)
		spawned += 1


func _resolve_focus() -> Node2D:
	if focus_override != null and is_instance_valid(focus_override):
		return focus_override
	return get_tree().get_first_node_in_group("mole") as Node2D


## Lets the editor switch between its camera and the preview mole without
## waiting for the next half-second focus refresh.
func set_focus_override(node: Node2D) -> void:
	focus_override = node
	_focus = null
	_focus_refresh_timer = 0.0


func _take_firefly() -> Node2D:
	var f: Node2D
	if not _pool.is_empty():
		f = _pool.pop_back()
	else:
		f = firefly_scene.instantiate()
	f.set("color", firefly_color)
	return f

func _recycle_far_children() -> void:
	var focus_pos: Vector2 = _focus.global_position
	var max_dist_sq := DESPAWN_DIST * DESPAWN_DIST
	for child in get_children():
		var node2d := child as Node2D
		if node2d == null:
			continue
		if node2d.global_position.distance_squared_to(focus_pos) > max_dist_sq:
			remove_child(node2d)
			_pool.append(node2d)
