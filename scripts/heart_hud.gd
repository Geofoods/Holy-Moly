extends Node2D

## Keeps the heart HUD anchored just to the left of the inventory hotbar.

const GAP_TO_HOTBAR := 14.0
const SHRINK := 0.75
const NUDGE := Vector2(12, -14)

var _base_scale := Vector2.ONE

func _ready() -> void:
	_base_scale = scale
	get_viewport().size_changed.connect(_reposition)
	# Position once after the inventory UI has laid itself out.
	_reposition.call_deferred()
	_follow_inventory.call_deferred()

## The tutorial can move the hotbar at runtime; follow it via signal
## instead of re-anchoring every frame.
func _follow_inventory() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var inv := scene.get_node_or_null("InventoryUI")
	if inv != null and inv.has_signal("repositioned") and not inv.repositioned.is_connected(_reposition):
		inv.repositioned.connect(_reposition)

func _reposition() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var inv := scene.get_node_or_null("InventoryUI")
	if inv == null or not inv.has_method("hotbar_left_top"):
		return
	scale = _base_scale * SHRINK
	var box := _heart_box_size()
	var left_top: Vector2 = inv.hotbar_left_top()
	position = Vector2(left_top.x - GAP_TO_HOTBAR - box.x / 2.0, left_top.y + box.y / 2.0) + NUDGE

func _heart_box_size() -> Vector2:
	var anim := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim == null or anim.sprite_frames == null:
		return Vector2(600, 600) * scale
	var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if tex == null:
		return Vector2(600, 600) * scale
	return tex.get_size() * scale