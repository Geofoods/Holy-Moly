extends Control

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var tex := CoinArt.texture()
	if tex != null:
		# Fit the opaque part of the artwork into the control, centred.
		var region := CoinArt.region()
		var factor := minf(size.x / region.size.x, size.y / region.size.y)
		var draw_size := region.size * factor
		draw_texture_rect_region(tex, Rect2((size - draw_size) * 0.5, draw_size), region)
		return
	var center := size * 0.5
	var gold := Color(1.0, 0.85, 0.35)
	var dark := Color(0.8, 0.55, 0.1)
	for i in 3:
		var inset := i * 1.5
		var r := 10.5 - inset
		draw_circle(center, r, dark if i == 0 else gold)
	draw_circle(center, 4.0, dark)
