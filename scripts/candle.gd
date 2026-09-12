extends RigidBody2D

## Candles are decoration, so they stay frozen (static) until the tile under
## them is dug away. This avoids rigidbody jitter/ejection glitches entirely;
## when support disappears they fall once, settle, and freeze again.

const TILE_CHECK_INTERVAL := 0.25
const BOTTOM_LOCAL_Y := 40.0  # collision rect bottom edge in local space (25.25 + 29.5/2)
const PROBE_MARGIN := 6.0     # probe this far into the tile below the bottom edge
const MAX_FALL_SPEED := 1200.0
const MAX_SPIN := 3.0
const SETTLE_SPEED := 30.0
const REFREEZE_DELAY := 0.35

var _tilemap: TileMap = null
var _check_timer := 0.0
var _was_fast := false
var _settle_timer := 0.0

func _ready() -> void:
	freeze = true
	_tilemap = _find_tilemap()
	_exclude_mole()

func _exclude_mole() -> void:
	# The mole shares the tiles' collision layer, so explicitly ignore it.
	var mole := get_tree().get_first_node_in_group("mole")
	if mole is CollisionObject2D:
		add_collision_exception_with(mole)

func _find_tilemap() -> TileMap:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	# Prefer the level's main tilemap, then fall back to any TileMap in the scene.
	for child in root.get_children():
		if child is TileMap and child.name == "TileMap":
			return child
	return _find_any_tilemap(root) as TileMap

func _find_any_tilemap(node: Node) -> Node:
	if node is TileMap:
		return node
	for child in node.get_children():
		var found := _find_any_tilemap(child)
		if found != null:
			return found
	return null

func _physics_process(delta: float) -> void:
	if _tilemap == null or not is_instance_valid(_tilemap):
		return

	if freeze:
		_check_timer -= delta
		if _check_timer <= 0.0:
			_check_timer = TILE_CHECK_INTERVAL
			if not _has_support():
				_start_fall()
	else:
		# Falling/settling: clamp any crazy depenetration kicks.
		var speed := linear_velocity.length()
		if speed > MAX_FALL_SPEED:
			linear_velocity = linear_velocity.normalized() * MAX_FALL_SPEED
		angular_velocity = clampf(angular_velocity, -MAX_SPIN, MAX_SPIN)

		if speed > 300.0:
			_was_fast = true
		if _was_fast:
			if speed < SETTLE_SPEED:
				_settle_timer -= delta
				if _settle_timer <= 0.0:
					freeze = true
			else:
				_settle_timer = REFREEZE_DELAY

func _has_support() -> bool:
	var probe_y := (BOTTOM_LOCAL_Y + PROBE_MARGIN) * global_scale.y
	var below := _tilemap.local_to_map(_tilemap.to_local(global_position + Vector2(0, probe_y)))
	for layer in _tilemap.get_layers_count():
		if _tilemap.get_cell_source_id(layer, below) != -1:
			return true
	return false

func _start_fall() -> void:
	_exclude_mole()
	_was_fast = false
	_settle_timer = REFREEZE_DELAY
	freeze = false
	linear_velocity = Vector2(0, 60)
