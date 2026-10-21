extends Node2D

## Dotted throw-path preview shown while the mouse button is held with a
## throwable selected. The mole works out the ballistics (or the drill's straight
## line) and hands the world-space points here; this node only styles them, so
## aiming rules and drawing can change independently.
##
## Dots fade and shrink toward the end of the path, and a ring marks where the
## projectile is expected to land or where the drill runs out.

const DOT_SPACING := 26.0
const DOT_RADIUS := 4.5
const START_ALPHA := 0.95
const END_ALPHA := 0.2
const END_RING_RADIUS := 22.0

var _points := PackedVector2Array()
var _colour := Color(1.0, 0.62, 0.3, 1.0)

func show_path(world_points: PackedVector2Array, colour: Color) -> void:
	_points = PackedVector2Array()
	for point in world_points:
		_points.append(to_local(point))
	_colour = colour
	queue_redraw()

func clear_path() -> void:
	_points = PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	if _points.size() < 2:
		return
	var total := _length()
	if total <= 0.0:
		return

	var total_dots := maxi(1, ceili(total / DOT_SPACING))
	var travelled := 0.0
	var next_dot := 0.0
	var dot_index := 0
	for i in range(1, _points.size()):
		var a := _points[i - 1]
		var b := _points[i]
		var segment := a.distance_to(b)
		if segment <= 0.0:
			continue
		while next_dot <= travelled + segment:
			var t := (next_dot - travelled) / segment
			var point := a.lerp(b, t)
			var fade := clampf(float(dot_index) / float(total_dots), 0.0, 1.0)
			var alpha := lerpf(START_ALPHA, END_ALPHA, fade)
			var radius := lerpf(DOT_RADIUS, DOT_RADIUS * 0.55, fade)
			# A wide, faint dot under the core reads as a soft glow without
			# needing a second material or a screen-space effect.
			draw_circle(point, radius + 2.5, Color(_colour.r, _colour.g, _colour.b, alpha * 0.16))
			draw_circle(point, radius, Color(_colour.r, _colour.g, _colour.b, alpha))
			dot_index += 1
			next_dot += DOT_SPACING
		travelled += segment

	var end := _points[_points.size() - 1]
	var ring_colour := Color(_colour.r, _colour.g, _colour.b, 0.9)
	draw_arc(end, END_RING_RADIUS, 0.0, TAU, 32, ring_colour, 3.0, true)
	draw_circle(end, 5.0, ring_colour)

func _length() -> float:
	var total := 0.0
	for i in range(1, _points.size()):
		total += _points[i - 1].distance_to(_points[i])
	return total
