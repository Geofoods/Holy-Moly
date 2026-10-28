extends Area2D

## The way out of a level built in the Level Editor.
##
## A campaign level leaves through a bare zone -- see level_exit.gd -- which works
## because its levels were laid out around a known exit. A level still being built
## has to show its author where the exit is, so this one draws itself: a dark green
## disc inside a ring of turning dashes, with a handful of bright shards orbiting
## in the middle. Walking into it pulls the mole through and reports the finish.
##
## It never decides where to go. Stepping into it is reported, and the level
## editor -- the only thing that ever places one -- ends the playtest with it.

signal entered(portal: Area2D)

## Wide enough to walk into without pixel-hunting: a little over one tile.
const RADIUS := 40.0
## Portal green: bright enough to read as a way out against the level's browns
## and blues, while still belonging to the same world as the other props.
const RIM := Color(0.48, 1.0, 0.58)
const VOID := Color(0.02, 0.10, 0.05)
const CORE := Color(0.32, 0.95, 0.45)
const DASHES := 8
const SHARDS := 5
const TURN_SPEED := 0.8
const PULSE_SPEED := 2.2
## How long the mole takes to be pulled through the ring and vanish.
const ABSORB_TIME := 0.7

var _time := 0.0
var _armed := false
var _entered := false
## 0 while idle, 1 once the mole has been pulled all the way in. The rings, the
## core and the orbiting shards all read from this, so one tween drives the whole
## entering animation.
var _absorb := 0.0
var _absorbing := false

func _ready() -> void:
	# Portals keep turning while the Level Editor holds everything else still, so
	# the exit reads as a living thing even before a playtest starts.
	add_to_group("level_portal")
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
	entered.emit(self)

## Pulls the mole into the ring: it is drawn toward the centre, spun, shrunk and
## faded out while the portal brightens and throws a burst ring. Awaiting this is
## what gives the completion screen a proper beat before it appears.
func play_enter_animation(body: Node) -> void:
	if _absorbing:
		return
	_absorbing = true
	_entered = true

	var target := body as Node2D
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "_absorb", 1.0, ABSORB_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if is_instance_valid(target):
		# Stop the mole where it is before moving it, so gravity and input cannot
		# fight the tween on the way in.
		if target is CharacterBody2D:
			(target as CharacterBody2D).velocity = Vector2.ZERO
			target.set_physics_process(false)
		target.z_index = 20
		tween.tween_property(target, "global_position", global_position, ABSORB_TIME) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(target, "scale", target.scale * 0.05, ABSORB_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(target, "rotation", target.rotation + TAU * 1.5, ABSORB_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(target, "modulate:a", 0.0, ABSORB_TIME * 0.55) \
				.set_delay(ABSORB_TIME * 0.45)

	await tween.finished
	if is_instance_valid(target):
		target.visible = false

	# Leave the burst ring on screen for a moment before the completion screen
	# takes over, so the portal is seen to swallow the mole rather than cut away.
	await get_tree().create_timer(0.12).timeout

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

## The ring turns for as long as the portal is running. Edit mode keeps portals
## processing on purpose (see level_editor.gd::_freeze_entity), so the shards spin
## while a level is being built as well as during its playtest.
func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	var pull := _absorb
	# Glow underneath everything, so the rim and the hole sit on top of it. It
	# swells as the mole is pulled in.
	for i in 3:
		var t := float(i + 1) / 3.0
		var grow := 1.0 + 0.3 * t + 0.22 * pull
		draw_circle(Vector2.ZERO, RADIUS * grow * (1.0 + 0.04 * pulse),
				Color(RIM.r, RIM.g, RIM.b, (0.13 + 0.10 * pull) * (1.0 - t * 0.65)))
	# The hole itself: dark, so the level does not show through the middle of it.
	draw_circle(Vector2.ZERO, RADIUS * 0.92, VOID)
	# Two rings of dashes turning against each other, which is what makes the
	# middle read as somewhere to go rather than a disc painted on the level.
	var spin := 1.0 + pull * 2.5
	_swirl(RADIUS * 0.68, _time * TURN_SPEED * spin, 6.0, 0.5 + 0.3 * pulse)
	_swirl(RADIUS * 0.42, -_time * TURN_SPEED * 1.6 * spin, 5.0, 0.4 + 0.3 * pulse)
	# The objects inside: bright shards orbiting the core and turning on their own
	# axes. They shrink toward the centre as the mole is absorbed.
	_shards(pull)
	# A light at the end of it, and the rim the whole thing is read by.
	var core_radius := RADIUS * (0.15 + 0.12 * pull)
	draw_circle(Vector2.ZERO, core_radius, Color(CORE.r, CORE.g, CORE.b, 0.9))
	draw_arc(Vector2.ZERO, RADIUS * 0.95, 0.0, TAU, 64, RIM, 4.0, true)
	# A single ring thrown outward as the mole disappears through the middle.
	if pull > 0.0:
		var burst_radius := RADIUS * (0.35 + 1.35 * pull)
		var burst_alpha := 1.0 - pull
		draw_arc(Vector2.ZERO, burst_radius, 0.0, TAU, 64,
				Color(RIM.r, RIM.g, RIM.b, burst_alpha), 3.0 + 5.0 * burst_alpha, true)


## One ring of the portal's dashes: arcs evenly spread around the circle and turned
## by `phase`.
func _swirl(radius: float, phase: float, width: float, alpha: float) -> void:
	var step := TAU / float(DASHES)
	for i in DASHES:
		var from := phase + step * float(i)
		draw_arc(Vector2.ZERO, radius, from, from + step * 0.55, 10,
				Color(RIM.r, RIM.g, RIM.b, alpha), width, true)


## The objects orbiting inside the ring. Each shard is a four-point diamond that
## both orbits the centre and spins on its own axis, so the portal is visibly
## alive even when the rest of the level is held still.
func _shards(pull: float) -> void:
	var orbit := RADIUS * 0.28 * (1.0 - pull * 0.6)
	for i in SHARDS:
		var phase := _time * 1.9 + TAU * float(i) / float(SHARDS)
		var centre := Vector2(cos(phase), sin(phase)) * orbit
		var spin := _time * 2.7 + float(i) * 0.9
		var size := RADIUS * (0.10 + 0.025 * sin(_time * 3.0 + float(i)))
		var points := PackedVector2Array()
		for k in 4:
			var angle := spin + TAU * float(k) / 4.0
			points.append(centre + Vector2(cos(angle), sin(angle)) * size)
		var tint := CORE if i % 2 == 0 else RIM
		draw_colored_polygon(points, Color(tint.r, tint.g, tint.b, 0.95))
