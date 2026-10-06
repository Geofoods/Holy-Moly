extends Node

## Door the mole opens by pressing E, the same way it talks to the village moles:
## a PRESS E prompt hangs over the door while the mole stands in its area, and E
## sends the mole through to target_scene.
##
## Where the mole was standing when it went through is saved on the way out (see
## level_exit.gd), so coming back drops the mole at the door it left by instead of
## on the scene's spawn point.
##
## Deliberately untyped so the script drops onto whatever shape a door is drawn
## with: the door.tscn prefab hangs it off the door's Control root, while a level
## that lays its own door out hangs it off the Area2D that is the trigger. The
## trigger is whichever of the two carries the collision shape.

const PROMPT_HALF_WIDTH := 170.0
const PROMPT_HEIGHT := 60.0

@export_file("*.tscn") var target_scene: String = "res://scenes/level1.tscn"
@export var prompt_text := "PRESS E"
@export var prompt_offset := Vector2(0, -90)

@onready var _area: Area2D = _resolve_area()

var _prompt: Label = null
var _mole: Node2D = null
var _mole_nearby := false
var _transitioning := false

## The prefab keeps its trigger in an Area2D child, but a level that lays its own
## door out hangs the shape on the door node itself. Whichever is there is the one
## to listen to.
func _resolve_area() -> Area2D:
	var child_area := get_node_or_null("Area2D") as Area2D
	if child_area:
		return child_area
	return _host() as Area2D

## The door itself may be positioned as a Control or as a Node2D depending on which
## scene drew it, and the prompt is anchored to whichever one this is.
func _door_position() -> Vector2:
	var host := _host()
	if host is Node2D:
		return (host as Node2D).global_position
	return (host as Control).global_position

## This script has to attach to a door drawn either way round, so it can't extend
## the type it expects and is stuck extending Node instead. The compiler then treats
## every mention of self as this script's own type and refuses to relate it to
## Area2D or Control, so those casts have to go through a plain Node. Widening to
## Node is a plain upcast, and Node -> Area2D is an ordinary downcast, so both go
## through - unlike self, which the analyzer has already ruled out statically.
func _host() -> Node:
	return self

## TEMPORARY DIAGNOSTIC - remove once the door is confirmed working.
const DEBUG_DOOR := true

func _dbg(msg: String) -> void:
	if DEBUG_DOOR:
		print("[door] %s (%s)" % [msg, get_path()])

func _ready() -> void:
	_dbg("_ready entered")
	if _area:
		_area.body_entered.connect(_on_area_body_entered)
		_area.body_exited.connect(_on_area_body_exited)
		_dbg("_area resolved: %s (self=%s)" % [_area.get_path(), _area == self])
	else:
		_dbg("_area DID NOT RESOLVE")
	_set_up_prompt()
	_dbg("prompt found=%s" % _prompt)
	_resolve_starting_overlap()

## body_entered only fires on the not-overlapping -> overlapping edge, so a mole that
## is already standing in the doorway when the scene opens would never be reported.
## House1 spawns the mole inside its door, and coming back from the village lands it
## there again. Worse, that first edge can land before mole.gd has reached its
## add_to_group("mole"), which sits behind an awaited process frame - miss it and the
## group check below rejects the body outright. So re-check once physics has settled
## and the group exists, the same way level_exit.gd waits before arming.
func _resolve_starting_overlap() -> void:
	if not _area:
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _transitioning:
		return
	for body in _area.get_overlapping_bodies():
		_dbg("settle check: %s in_mole_group=%s" % [body.name, body.is_in_group("mole")])
		if body.is_in_group("mole"):
			_mole_nearby = true
			_mole = body as Node2D
			_dbg("settle adopted existing overlap")
			return
	_dbg("settle found no mole; _mole_nearby=%s" % _mole_nearby)

## Built here rather than styled per scene so every door shows the same prompt the
## moles do, whichever scene dropped it in.
func _set_up_prompt() -> void:
	_prompt = get_node_or_null("Prompt") as Label
	if not _prompt:
		return
	_prompt.top_level = true
	_prompt.z_index = 200
	_prompt.z_as_relative = false
	_prompt.light_mask = 0
	_prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_prompt.offset_left = 0.0
	_prompt.offset_top = 0.0
	_prompt.offset_right = 0.0
	_prompt.offset_bottom = 0.0
	if prompt_text != "":
		_prompt.text = prompt_text
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	var variation := FontVariation.new()
	variation.base_font = load("res://Baby Doll.otf") as Font
	variation.variation_embolden = 1.0
	_prompt.add_theme_font_override("font", variation)

func _process(_delta: float) -> void:
	if not _prompt:
		return
	_prompt.visible = _mole_nearby and not _transitioning
	if _prompt.visible:
		var p := _door_position() + prompt_offset
		_prompt.offset_left = p.x - PROMPT_HALF_WIDTH
		_prompt.offset_right = p.x + PROMPT_HALF_WIDTH
		_prompt.offset_top = p.y
		_prompt.offset_bottom = p.y + PROMPT_HEIGHT

func _unhandled_input(event: InputEvent) -> void:
	if DEBUG_DOOR and event.is_action_pressed("interact"):
		_dbg("E pressed: _mole_nearby=%s _transitioning=%s" % [_mole_nearby, _transitioning])
	if not _mole_nearby or _transitioning:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_transition()

func _on_area_body_entered(body: Node) -> void:
	if DEBUG_DOOR:
		_dbg("body_entered: %s in_mole_group=%s" % [body.name, body.is_in_group("mole")])
	if body.is_in_group("mole"):
		_mole_nearby = true
		_mole = body as Node2D

func _on_area_body_exited(body: Node) -> void:
	if DEBUG_DOOR:
		_dbg("body_exited: %s" % body.name)
	if body.is_in_group("mole"):
		_mole_nearby = false
		_mole = null

func _transition() -> void:
	_dbg("_transition called, target=%s" % target_scene)
	if target_scene.is_empty():
		_dbg("target_scene EMPTY, aborting")
		return
	_save_return_position()
	_transitioning = true
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(target_scene)

## Records the mole's own spot rather than the door's, so re-entering puts it back
## in the doorway it walked out of. The door is only a marker for that, and the mole
## may well be standing off-centre in the area.
func _save_return_position() -> void:
	var cs := get_tree().current_scene
	if cs == null or _mole == null:
		return
	Inventory.set_level_return_position(cs.scene_file_path, _mole.global_position)
