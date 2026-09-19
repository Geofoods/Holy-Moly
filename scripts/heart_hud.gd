extends Node2D

## Bottom-left health HUD: the animated mole heart plus a bar showing exact HP.

const SHRINK := 0.75
const MARGIN := 24.0

const BAR_GAP := 0.0     # screen px; 0 tucks the bar into the heart art
const BAR_WIDTH := 240.0 # screen px
const BAR_HEIGHT := 34.0 # screen px
const ART_RIGHT := 185.0 # local-space anchor; tucks the bar under the heart art

const BAR_BG := Color(0.12, 0.08, 0.05, 0.85)
const BAR_BORDER := Color(0.42, 0.28, 0.14, 1.0)
const BAR_FILL := Color(0.85, 0.25, 0.25, 1.0)
const BAR_FILL_LOW := Color(0.95, 0.6, 0.15, 1.0)

var _base_scale := Vector2.ONE
var _last_ratio := -1.0

func _ready() -> void:
	_base_scale = scale
	get_viewport().size_changed.connect(_reposition)
	# Position once after the rest of the HUD has laid itself out.
	_reposition.call_deferred()
	_follow_inventory.call_deferred()

## The tutorial can move the hotbar at runtime; stay vertically in line with it.
func _follow_inventory() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var inv := scene.get_node_or_null("InventoryUI")
	if inv != null and inv.has_signal("repositioned") and not inv.repositioned.is_connected(_reposition):
		inv.repositioned.connect(_reposition)

func _process(_delta: float) -> void:
	var ratio := _health_ratio()
	if absf(ratio - _last_ratio) > 0.001:
		_last_ratio = ratio
		queue_redraw()

func _reposition() -> void:
	scale = _base_scale * SHRINK
	var box := _heart_box_size()
	var vp := get_viewport().get_visible_rect().size
	var cy := vp.y - MARGIN - box.y / 2.0
	var scene := get_tree().current_scene
	if scene != null:
		var inv := scene.get_node_or_null("InventoryUI")
		if inv != null and inv.has_method("hotbar_center_y"):
			cy = inv.hotbar_center_y()
	position = Vector2(MARGIN + box.x / 2.0, cy)
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
	draw_rect(Rect2(x, y, w, h), BAR_BG)
	draw_rect(Rect2(x + pad, y + pad, (w - pad * 2.0) * _health_ratio(), h - pad * 2.0), BAR_FILL if _health_ratio() > 0.35 else BAR_FILL_LOW)
	draw_rect(Rect2(x, y, w, h), BAR_BORDER, false, 2.0 * inv)

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
