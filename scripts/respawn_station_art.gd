extends Node2D

## Artwork for the respawn station, drawn procedurally like shop_stall.gd so the
## checkpoint needs no new sprite sheet. All state (is this pad the banked one,
## where is it in its breath cycle) comes from the station node above, so the
## glow on the art and the light in the world stay in step.

## Drawn in the station's local space at 1:1 - the station is placed at the same
## scale as the level, so these are their on-screen sizes.
const BASE_HALF := 170.0
const BASE_TOP := -80.0
const BASE_BOTTOM := 10.0
const PAD_RX := 122.0
const PAD_RY := 36.0
const POST_X := 160.0
const POST_HALF := 28.0
const POST_TOP := -340.0
const BAR_TOP := -392.0
const BAR_HALF_HEIGHT := 30.0
const ORB_Y := -262.0
const ORB_RADIUS := 44.0

const OUTLINE := 8.0
const COL_OUTLINE := Color(0.09, 0.07, 0.05, 1.0)
const COL_STONE := Color(0.44, 0.40, 0.37, 1.0)
const COL_STONE_LIGHT := Color(0.64, 0.59, 0.54, 1.0)
const COL_STONE_DARK := Color(0.25, 0.22, 0.20, 1.0)
const COL_BRASS := Color(0.74, 0.56, 0.26, 1.0)
const COL_IDLE := Color(0.44, 0.47, 0.52, 1.0)
const COL_ACTIVE := Color(0.40, 0.92, 1.0, 1.0)

## The pad's rolling ring spends the first stretch of each breath travelling
## outward, then nothing until the next one.
const RING_SHARE := 0.45
const ELLIPSE_SEGMENTS := 28
const HALO_LAYERS := 4

var _station: Node = null

func _ready() -> void:
	light_mask = 2
	_station = get_parent()
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _is_lit() -> bool:
	return _station != null and _station.is_checkpoint_active()

func _pulse() -> float:
	return _station.pulse() if _station != null else 0.0

func _cycle() -> float:
	return _station.cycle() if _station != null else 0.0

func _draw() -> void:
	var lit := _is_lit()
	var pulse := _pulse()
	_draw_halo(lit, pulse)
	_draw_base()
	_draw_pad(lit, pulse)
	_draw_frame()
	_draw_orb(lit, pulse)

func _draw_halo(lit: bool, pulse: float) -> void:
	# Soft glow around the orb, built from stacked translucent discs. Off-state
	# keeps a faint smudge so an unbanked station still reads as a device.
	var strength := (0.34 + 0.22 * pulse) if lit else 0.07
	for i in HALO_LAYERS:
		var t := float(i) / float(HALO_LAYERS - 1)
		var radius := ORB_RADIUS * (1.5 + t * 2.6)
		var color := COL_ACTIVE if lit else Color(0.70, 0.74, 0.80, 1.0)
		draw_circle(Vector2(0.0, ORB_Y), radius, Color(color.r, color.g, color.b, strength * (1.0 - t)))

func _draw_base() -> void:
	# Plinth the pad sits on, tapering slightly so it doesn't read as a box.
	var body := PackedVector2Array([
		Vector2(-BASE_HALF, BASE_BOTTOM),
		Vector2(-BASE_HALF + 26.0, BASE_TOP),
		Vector2(BASE_HALF - 26.0, BASE_TOP),
		Vector2(BASE_HALF, BASE_BOTTOM),
	])
	draw_colored_polygon(body, COL_STONE)
	draw_polyline(_closed(body), COL_OUTLINE, OUTLINE, true)

	# Course lines, so the stone has some scale to it.
	for i in 2:
		var y := lerpf(BASE_TOP, BASE_BOTTOM, 0.36 + 0.28 * float(i))
		var inset := 14.0
		draw_line(Vector2(-BASE_HALF + inset, y), Vector2(BASE_HALF - inset, y), COL_STONE_DARK, 5.0)

	# Lit lip around the pad.
	var lip := PackedVector2Array([
		Vector2(-BASE_HALF + 20.0, BASE_TOP - 14.0),
		Vector2(BASE_HALF - 20.0, BASE_TOP - 14.0),
		Vector2(BASE_HALF - 26.0, BASE_TOP + 6.0),
		Vector2(-BASE_HALF + 26.0, BASE_TOP + 6.0),
	])
	draw_colored_polygon(lip, COL_STONE_LIGHT)
	draw_polyline(_closed(lip), COL_OUTLINE, OUTLINE, true)

func _draw_pad(lit: bool, pulse: float) -> void:
	var center := Vector2(0.0, BASE_TOP - 4.0)
	var color := COL_ACTIVE if lit else COL_IDLE

	draw_colored_polygon(_ellipse(center, PAD_RX, PAD_RY), color)
	draw_polyline(_ellipse_line(center, PAD_RX, PAD_RY), COL_OUTLINE, OUTLINE, true)

	var inner := PAD_RX * 0.55
	draw_colored_polygon(
		_ellipse(center, inner, PAD_RY * 0.55),
		Color(color.r, color.g, color.b, 0.45 + 0.45 * pulse)
	)
	draw_polyline(_ellipse_line(center, inner, PAD_RY * 0.55), COL_OUTLINE, 4.0, true)

	if not lit:
		return
	# A ring rolls off the pad once per breath to show the station is live.
	var cycle := _cycle()
	if cycle >= RING_SHARE:
		return
	var t := cycle / RING_SHARE
	var ring := _ellipse_line(center, PAD_RX * (0.5 + t * 1.4), PAD_RY * (0.5 + t * 1.4))
	draw_polyline(ring, Color(COL_ACTIVE.r, COL_ACTIVE.g, COL_ACTIVE.b, (1.0 - t) * 0.9), 6.0, true)

func _draw_frame() -> void:
	# Two posts and a crossbar, so the orb has something to hang from.
	for side in [-1.0, 1.0]:
		var cx: float = side * POST_X
		var post := Rect2(cx - POST_HALF, POST_TOP, POST_HALF * 2.0, BASE_TOP - POST_TOP + 12.0)
		draw_rect(post, COL_STONE)
		draw_rect(post, COL_OUTLINE, false, OUTLINE)

	var bar := Rect2(-POST_X - POST_HALF, BAR_TOP, (POST_X + POST_HALF) * 2.0, BAR_HALF_HEIGHT * 2.0)
	draw_rect(bar, COL_BRASS)
	draw_rect(bar, COL_OUTLINE, false, OUTLINE)

	# Chain from the crossbar down to the orb.
	draw_line(Vector2(0.0, BAR_TOP + BAR_HALF_HEIGHT * 2.0), Vector2(0.0, ORB_Y - ORB_RADIUS * 0.6), COL_BRASS, 10.0)

func _draw_orb(lit: bool, pulse: float) -> void:
	var center := Vector2(0.0, ORB_Y)
	var radius := ORB_RADIUS * (1.0 + (0.06 * pulse if lit else 0.0))
	draw_circle(center, radius, COL_ACTIVE if lit else COL_IDLE)
	draw_arc(center, radius, 0.0, TAU, 24, COL_OUTLINE, OUTLINE, true)
	# A brighter core, offset up-left so the orb reads as a solid, lit sphere.
	draw_circle(center - Vector2(radius * 0.22, radius * 0.26), radius * 0.36, Color(1.0, 1.0, 1.0, 0.35 if lit else 0.15))

func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS:
		var angle := TAU * float(i) / float(ELLIPSE_SEGMENTS)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _ellipse_line(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := _ellipse(center, rx, ry)
	points.append(points[0])
	return points

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
