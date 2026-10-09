extends Node2D

## Bottom-left health HUD: the animated mole heart plus a bar showing exact HP.
## When the mole dies the bar empties and cracks over.

const SHRINK := 0.75
const MARGIN := 24.0
## Gap under the coins label when the bar is tucked up under it, which is where
## it goes while the mobile controls are on (see _reposition).
const COINS_GAP := 12.0

const BAR_GAP := 0.0     # screen px; 0 tucks the bar into the heart art
const BAR_WIDTH := 240.0 # screen px
const BAR_HEIGHT := 34.0 # screen px
const ART_RIGHT := 185.0 # local-space anchor; tucks the bar under the heart art

const BAR_BG := Color(0.12, 0.08, 0.05, 0.85)
const BAR_BORDER := Color(0.42, 0.28, 0.14, 1.0)
const BAR_FILL := Color(0.85, 0.25, 0.25, 1.0)
const BAR_FILL_LOW := Color(0.95, 0.6, 0.15, 1.0)

const CRACK_COLOR := Color(0.04, 0.02, 0.01, 0.95)
const CRACK_COUNT := 4
const CRACK_REVEAL_TIME := 0.45

var _base_scale := Vector2.ONE
var _last_ratio := -1.0
var _cracked := false
var _crack_progress := 0.0

## Crack polylines in normalized bar space (0..1 on both axes, y running top to
## bottom). Built once so the pattern stays put across redraws.
var _cracks: Array[PackedVector2Array] = []

func _ready() -> void:
	_base_scale = scale
	_build_cracks()
	Inventory.player_died.connect(_on_player_died)
	get_viewport().size_changed.connect(_reposition)
	MobileControls.enabled_changed.connect(_reposition)
	# Position once after the rest of the HUD has laid itself out.
	_reposition.call_deferred()
	_follow_inventory.call_deferred()

## Read off Inventory rather than the mole, because the mole banks its health
## back to full the same instant it dies (so the retry starts healed), which
## would otherwise hide the death from the bar.
func _on_player_died() -> void:
	if _cracked:
		return
	_cracked = true
	_crack_progress = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_crack_progress, 0.0, 1.0, CRACK_REVEAL_TIME)

func _set_crack_progress(value: float) -> void:
	_crack_progress = value
	queue_redraw()

## The hub scenes hide the hotbar rather than dropping the node, and a hidden
## hotbar still reports a layout position. Treat an invisible one as absent so
## the heart falls back to its default placement, exactly as it does in the mole
## village where InventoryUI isn't in the scene at all. Typed as Node so the
## hotbar's own signal and method stay dynamically accessible.
func _hotbar() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var inv := scene.get_node_or_null("InventoryUI")
	if inv == null or not bool(inv.get("visible")):
		return null
	return inv

## The coins counter the Shop HUD keeps in the top-left corner. Located by name
## so this stays a lookup, like the hotbar above.
func _coins_rect() -> Rect2:
	var hud := Shop.get_node_or_null("CoinHud") as Control
	if hud == null:
		return Rect2()
	return hud.get_global_rect()

## The tutorial can move the hotbar at runtime; stay vertically in line with it.
func _follow_inventory() -> void:
	var inv := _hotbar()
	if inv != null and inv.has_signal("repositioned") and not inv.repositioned.is_connected(_reposition):
		inv.repositioned.connect(_reposition)

func _process(_delta: float) -> void:
	var ratio := _health_ratio()
	if absf(ratio - _last_ratio) > 0.001:
		_last_ratio = ratio
		queue_redraw()

## Takes the mobile-controls flag when called from its enabled_changed signal,
## which it ignores in favour of reading the current state itself.
func _reposition(_is_on: bool = false) -> void:
	scale = _base_scale * SHRINK
	var box := _heart_box_size()
	var vp := get_viewport().get_visible_rect().size
	var cy := vp.y - MARGIN - box.y / 2.0
	var inv := _hotbar()
	if inv != null and inv.has_method("hotbar_center_y"):
		cy = inv.hotbar_center_y()
	position = Vector2(MARGIN + box.x / 2.0, cy)
	# With the mobile controls on, the joystick owns the bottom-left corner the
	# heart normally lives in, so the whole bar moves up to sit directly below
	# the coins label instead.
	var coins := _coins_rect()
	if MobileControls.enabled and coins.size != Vector2.ZERO:
		position = Vector2(coins.position.x + box.x / 2.0, coins.end.y + COINS_GAP + box.y / 2.0)
	queue_redraw()

func _draw() -> void:
	if scale.x <= 0.0:
		return
	var inv := 1.0 / scale.x
	var pad := 3.0 * inv
	var w := BAR_WIDTH * inv
	var h := BAR_HEIGHT * inv
	var x := ART_RIGHT + BAR_GAP * inv
	var y := -h / 2.0
	# A dead mole's bar reads as empty and cracked, even though player_health has
	# already been banked back to full for the retry.
	var ratio := 0.0 if _cracked else _health_ratio()
	draw_rect(Rect2(x, y, w, h), BAR_BG)
	draw_rect(Rect2(x + pad, y + pad, (w - pad * 2.0) * ratio, h - pad * 2.0), BAR_FILL if ratio > 0.35 else BAR_FILL_LOW)
	draw_rect(Rect2(x, y, w, h), BAR_BORDER, false, 2.0 * inv)
	if _cracked:
		_draw_cracks(Rect2(x, y, w, h), inv)

func _draw_cracks(bar: Rect2, inv: float) -> void:
	for crack in _cracks:
		var revealed := _clip_crack(crack, _crack_progress)
		if revealed.size() < 2:
			continue
		var mapped := PackedVector2Array()
		for point in revealed:
			mapped.append(Vector2(bar.position.x + point.x * bar.size.x, bar.position.y + point.y * bar.size.y))
		draw_polyline(mapped, CRACK_COLOR, 2.5 * inv, true)

## Rolls a handful of jagged top-to-bottom cracks, jittering in x as they climb
## down the bar.
func _build_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE
	for _i in CRACK_COUNT:
		var points := PackedVector2Array()
		var x := rng.randf_range(0.06, 0.82)
		var y := 0.0
		points.append(Vector2(x, y))
		while y < 1.0:
			x = clampf(x + rng.randf_range(-0.14, 0.14), 0.02, 0.98)
			y = minf(1.0, y + rng.randf_range(0.16, 0.34))
			points.append(Vector2(x, y))
		_cracks.append(points)

## Trims a crack to the part revealed so far (its y is monotonic), so the pattern
## creeps down the bar instead of popping in all at once.
static func _clip_crack(points: PackedVector2Array, limit: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size():
		var point: Vector2 = points[i]
		if point.y <= limit:
			out.append(point)
			continue
		if out.size() > 0:
			var previous: Vector2 = out[out.size() - 1]
			var span := point.y - previous.y
			var t := 0.0 if is_zero_approx(span) else (limit - previous.y) / span
			out.append(previous.lerp(point, t))
		break
	return out

func _health_ratio() -> float:
	return clampf(Inventory.player_health / Inventory.MAX_HEALTH, 0.0, 1.0)

func _heart_box_size() -> Vector2:
	var anim := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim == null or anim.sprite_frames == null:
		return Vector2(600, 600) * scale
	var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if tex == null:
		return Vector2(600, 600) * scale
	return tex.get_size() * scale
