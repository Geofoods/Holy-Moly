extends Control

@export var icon_color: Color = Color(1, 1, 1, 1)
@export var icon_radius: float = 14.0
@export var stroke_width: float = 3.5

func _draw() -> void:
	var center := size / 2.0
	var start_angle := deg_to_rad(-30.0)
	var end_angle := deg_to_rad(250.0)
	draw_arc(center, icon_radius, start_angle, end_angle, 28, icon_color, stroke_width, true)

	# Arrowhead at the arc's start point. It points along the curve's tangent so it
	# reads as the ring bending into an arrowhead (a curved refresh arrow).
	var tip_angle := start_angle
	var anchor := center + Vector2(cos(tip_angle), sin(tip_angle)) * icon_radius
	# Tangent = direction the arrow flies (curling back toward the gap).
	var tangent := Vector2(sin(tip_angle), -cos(tip_angle))
	# Radial = across the stroke, used to spread the arrowhead's barbs.
	var radial := Vector2(cos(tip_angle), sin(tip_angle))

	var arrow_len := stroke_width * 2.8
	var arrow_half := stroke_width * 2.2

	var tip := anchor + tangent * arrow_len
	var barb_outer := anchor + radial * arrow_half
	var barb_inner := anchor - radial * arrow_half

	draw_colored_polygon(PackedVector2Array([tip, barb_outer, barb_inner]), icon_color)
