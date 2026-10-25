extends RefCounted

## Click/tap-to-interact support, shared by everything that can be pressed on
## (chests, NPC moles, the shopkeeper, the snail) and by everything that must
## keep such a press out of its own click handling (the mole's held item, the
## weapons, the on-screen controls' world tap).
##
## A press is a left mouse button press - which is also what a finger tap
## arrives as, since touches are emulated as mouse clicks. The hit target is
## the interactable's own sprite: its current frame drawn in the sprite's local
## space, so the click area is what the player actually sees rather than the
## much larger proximity area that drives the "PRESS E" prompt.
##
## Interactables register their sprite in TAP_GROUP (see register). Everything
## else either asks is_press_on() about one particular sprite or
## is_press_on_any()/target_at() about all of them. A press that lands on an
## interactable is swallowed with consume() by the interactable that acts on
## it: the viewport is told the event is handled (so the weapons'
## _unhandled_input never swings at an NPC) and the "dig_slash" action state is
## dropped (so the polled dig_slash sites - the grapple start and the dash
## cancel - don't fire off a press that was meant for conversation).
##
## Only the interactable calls consume(). Everything else merely declines the
## press (returns early): marking the event handled in _input - which runs
## ahead of _unhandled_input - would keep the interactables from ever seeing
## it.

const TAP_GROUP := &"tap_interactable"

## Extra click forgiveness around the sprite, in the sprite's own local units.
const TAP_MARGIN := 12.0

## Puts an interactable's sprite in TAP_GROUP so the hit tests can find it.
static func register(sprite: Node2D) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.add_to_group(TAP_GROUP)

## Stops a sprite being treated as an interactable. Opened chests use this so a
## press lands on the shovel instead of being swallowed by the empty chest.
static func unregister(sprite: Node2D) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.remove_from_group(TAP_GROUP)

## True for a left mouse button press (finger taps are emulated mouse clicks).
static func is_press(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT

## True when the press landed on this one sprite.
static func is_press_on(event: InputEvent, sprite: Node2D) -> bool:
	if not is_press(event) or sprite == null or not is_instance_valid(sprite):
		return false
	return tap_rect(sprite).has_point(_to_local(sprite, event.position))

## True when the press landed on any registered interactable.
static func is_press_on_any(event: InputEvent) -> bool:
	if not is_press(event):
		return false
	return target_at(event.position) != null

## The registered sprite under the given viewport position, or null.
static func target_at(viewport_pos: Vector2) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for sprite in tree.get_nodes_in_group(TAP_GROUP):
		if not sprite is Node2D or not (sprite as Node2D).is_inside_tree():
			continue
		var node := sprite as Node2D
		if tap_rect(node).has_point(_to_local(node, viewport_pos)):
			return node
	return null

## Marks a press as taken by an interactable: no weapon swing, no item use, no
## dig_slash for it. Called only by the interactable that acts on the press (or
## swallows it as out of reach) - never by the guards that merely decline it.
## The node is only asked for its viewport (the one the event is travelling
## through). Safe to call more than once per event.
static func consume(event: InputEvent, node: Node) -> void:
	if node != null and is_instance_valid(node) and node.get_viewport() != null:
		node.get_viewport().set_input_as_handled()
	if InputMap.has_action(&"dig_slash"):
		Input.action_release(&"dig_slash")

## The sprite's current frame in its own local space (the node's own transform
## carries the scale, and it is inverted before this rect is used). Centered
## sprites draw the frame at -size/2 plus the offset, and flipping mirrors it
## inside that same box.
static func tap_rect(sprite: Node2D) -> Rect2:
	var size := Vector2.ZERO
	var offset := Vector2.ZERO
	if sprite is AnimatedSprite2D:
		var anim := sprite as AnimatedSprite2D
		offset = anim.offset
		var frames := anim.sprite_frames
		if frames != null and anim.animation != StringName() and frames.has_animation(anim.animation):
			var tex := frames.get_frame_texture(anim.animation, anim.frame)
			if tex != null:
				size = tex.get_size()
	elif sprite is Sprite2D:
		var spr := sprite as Sprite2D
		offset = spr.offset
		if spr.texture != null:
			size = spr.texture.get_size()
	if size == Vector2.ZERO:
		return Rect2()
	return Rect2(-size * 0.5 + offset, size).grow(TAP_MARGIN)

## Maps a viewport-space position (mouse/touch event positions) into the
## sprite's local space, the same way physics picking does.
static func _to_local(sprite: Node2D, viewport_pos: Vector2) -> Vector2:
	return sprite.get_global_transform_with_canvas().affine_inverse() * viewport_pos
