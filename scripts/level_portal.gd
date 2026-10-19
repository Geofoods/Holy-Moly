extends Area2D

## The way out of a level built in Level Forge.
##
## A campaign level leaves through a bare zone -- see level_exit.gd -- which works
## because its levels were laid out around a known exit. A level still being built
## has to show its author where the exit is, so this one draws itself: a dark disc
## inside a ring of turning dashes, breathing a little behind a soft glow.
##
## It never decides where to go. Stepping into it is reported, and the level
## editor -- the only thing that ever places one -- ends the playtest with it.

signal entered

## Wide enough to walk into without pixel-hunting: a little over one tile.
const RADIUS := 40.0
## The blue of the campaign's own respawn station, so the way out reads as part of
## the same world rather than as an editor gizmo.
const RIM := Color(0.45, 0.95, 1.0)
const VOID := Color(0.04, 0.09, 0.20)
const CORE := Color(0.42, 0.72, 1.0)
const DASHES := 8
const TURN_SPEED := 0.8
const PULSE_SPEED := 2.2

var _time := 0.0
var _armed := false
var _entered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_arm_after_settle()

## Ignore the mole if the playtest starts with it already standing in the portal,
## which happens when the spawn marker is moved onto one. As with a campaign exit,
## the portal only opens for a mole that leaves and deliberately walks back in.
func _arm_after_settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_armed = not _mole_overlapping()

func _mole_overlapping() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("mole"):
			return true
	return false

## Walking out of a portal that was shut for the mole re-opens it, so moving the
## spawn marker onto one costs the author a step out and back rather than the exit.
func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_armed = true

func _on_body_entered(body: Node) -> void:
	if _entered or not _armed or not body.is_in_group("mole"):
		return
	_entered = true
	entered.emit()

## The ring turns for as long as the portal is running. Edit mode freezes
## everything placed in a level, so while a level is being built this is a still
## picture; the playtest is what brings it to life.
func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

## A still of the portal, for the editor's palette. The button that places a portal
## wears the same ring the portal draws in the world, so the two are unmistakably
## the same thing -- and generating it from the same constants keeps the colours in
## one place.
static func icon(size: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var centre := Vector2(size, size) * 0.5
	var core := float(size) * 0.24
	var hole := float(size) * 0.40
	var rim := float(size) * 0.48
	for y in size:
		for x in size:
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(centre)
			if distance <= core:
				image.set_pixel(x, y, CORE)
			elif distance <= hole:
				image.set_pixel(x, y, VOID)
			elif distance <= rim:
				image.set_pixel(x, y, RIM)
	return ImageTexture.create_from_image(image)

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	# Glow underneath everything, so the rim and the hole sit on top of it.
	for i in 3:
		var t := float(i + 1) / 3.0
		draw_circle(Vector2.ZERO, RADIUS * (1.0 + 0.3 * t) * (1.0 + 0.04 * pulse),
				Color(RIM.r, RIM.g, RIM.b, 0.13 * (1.0 - t * 0.65)))
	# The hole itself: dark, so the level does not show through the middle of it.
	draw_circle(Vector2.ZERO, RADIUS * 0.92, VOID)
	# Two rings of dashes turning against each other, which is what makes the
	# middle read as somewhere to go rather than a disc painted on the level.
	_swirl(RADIUS * 0.68, _time * TURN_SPEED, 6.0, 0.5 + 0.3 * pulse)
	_swirl(RADIUS * 0.42, -_time * TURN_SPEED * 1.6, 5.0, 0.4 + 0.3 * pulse)
	# A light at the end of it, and the rim the whole thing is read by.
	draw_circle(Vector2.ZERO, RADIUS * 0.15, Color(CORE.r, CORE.g, CORE.b, 0.9))
	draw_arc(Vector2.ZERO, RADIUS * 0.95, 0.0, TAU, 64, RIM, 4.0, true)


## One ring of the portal's dashes: arcs evenly spread around the circle and turned
## by `phase`.
func _swirl(radius: float, phase: float, width: float, alpha: float) -> void:
	var step := TAU / float(DASHES)
	for i in DASHES:
		var from := phase + step * float(i)
		draw_arc(Vector2.ZERO, radius, from, from + step * 0.55, 10,
				Color(RIM.r, RIM.g, RIM.b, alpha), width, true)
