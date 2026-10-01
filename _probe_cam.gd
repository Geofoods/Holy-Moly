extends Node2D

func _ready() -> void:
	var level := (load("res://scenes/level_10.tscn") as PackedScene).instantiate()
	add_child(level)
	for i in 20:
		await get_tree().process_frame
		await get_tree().physics_frame
	var snail := level.get_node_or_null("Snail") as Node2D
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	snail.call("_begin_boss_fight")
	for i in 200:
		await get_tree().process_frame
		await get_tree().physics_frame

	var s_min := 9.0
	var s_max := -9.0
	var p_min := 9.0
	var p_max := -9.0
	var sample := 0
	var xf := get_viewport().get_canvas_transform()
	var vs := get_viewport().get_visible_rect().size
	for i in 700:
		await get_tree().process_frame
		await get_tree().physics_frame
		if not is_instance_valid(snail) or not is_instance_valid(mole):
			break
		# Ground truth: canvas transform maps world -> screen, and it already
		# accounts for zoom, offset and limits.
		xf = get_viewport().get_canvas_transform()
		var sp := xf * snail.global_position
		var mp := xf * mole.global_position
		var sfrac := sp.x / vs.x
		var pfrac := mp.x / vs.x
		s_min = minf(s_min, sfrac)
		s_max = maxf(s_max, sfrac)
		p_min = minf(p_min, pfrac)
		p_max = maxf(p_max, pfrac)
		if i % 250 == 0:
			var cam := get_viewport().get_camera_2d() as Camera2D
			var gap := (snail.global_position.x - cam.global_position.x) / w
			print("### f=%d snail=%.3f player=%.3f off_x=%.1f zoom=%.3f snail_cam_gap=%.3f camx=%.1f" % [
				i, sfrac, pfrac, cam.offset.x, absf(cam.zoom.x), gap, cam.global_position.x])
		sample += 1
	# Real visual footprint of the shell sprite on screen, via its global rect.
	var left_most := 9.0
	var right_most := -9.0
	for child in snail.get_children():
		var spr := child as AnimatedSprite2D
		if spr == null or spr.sprite_frames == null:
			continue
		var tex := spr.sprite_frames.get_frame_texture(spr.animation, 0) as Texture2D
		if tex == null:
			continue
		var rect := spr.get_global_transform() * Rect2(Vector2.ZERO, tex.get_size())
		var sx := xf * Vector2(rect.position.x, 0)
		var ex := xf * Vector2(rect.end.x, 0)
		left_most = minf(left_most, minf(sx.x, ex.x) / vs.x)
		right_most = maxf(right_most, maxf(sx.x, ex.x) / vs.x)
	print("### shell_sprite_screen [%.3f, %.3f] width=%.3f" % [left_most, right_most, right_most - left_most])
	print("### samples=%d viewport=%s" % [sample, get_viewport().get_visible_rect().size])
	print("### snail_screen  [%.3f, %.3f]" % [s_min, s_max])
	print("### player_screen [%.3f, %.3f]" % [p_min, p_max])
	get_tree().quit()