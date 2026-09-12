extends Control

func _draw() -> void:
	var center := size * 0.5
	var gold := Color(1.0, 0.85, 0.35)
	var dark := Color(0.8, 0.55, 0.1)
	for i in 3:
		var inset := i * 1.5
		var r := 10.5 - inset
		draw_circle(center, r, dark if i == 0 else gold)
	draw_circle(center, 4.0, dark)