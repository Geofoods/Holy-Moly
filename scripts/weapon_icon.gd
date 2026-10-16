extends Control

## HUD icon for the held ranged weapon, drawn procedurally because the game has
## no ranged-weapon art. It models the wizard staff - a wooden rod topped with a
## glowing crystal - and takes the weapon's icon colour for the crystal so a
## future ranged weapon can reuse it by setting icon_color.

var icon_color := Color(0.7, 0.35, 1.0)

const WOOD := Color(0.42, 0.26, 0.12)
const WOOD_DARK := Color(0.28, 0.16, 0.08)
const WOOD_LIGHT := Color(0.55, 0.36, 0.16)

func _draw() -> void:
	var cx := size.x * 0.5
	var rod_bottom := size.y * 0.95
	var rod_top := size.y * 0.34
	var rod_w := maxf(4.0, size.x * 0.11)

	draw_line(Vector2(cx, rod_bottom), Vector2(cx, rod_top), WOOD_DARK, rod_w + 2.0)
	draw_line(Vector2(cx, rod_bottom), Vector2(cx, rod_top), WOOD, rod_w)
	draw_line(
		Vector2(cx - rod_w * 0.18, rod_bottom),
		Vector2(cx - rod_w * 0.18, rod_top),
		WOOD_LIGHT, rod_w * 0.3)

	var tip := Vector2(cx, size.y * 0.26)
	var r := size.x * 0.2
	var glow := icon_color
	glow.a = 0.35
	draw_circle(tip, r * 1.3, glow)
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(0, -r),
		tip + Vector2(r, 0),
		tip + Vector2(0, r),
		tip + Vector2(-r, 0),
	]), icon_color)
	draw_circle(tip, r * 0.4, Color(1.0, 0.96, 1.0, 0.95))
