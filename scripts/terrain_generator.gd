extends Node2D

const PLATFORM_HEIGHT := 400.0

var colors = {
	"ground": Color(0.45, 0.26, 0.13),
	"dirt_dark": Color(0.35, 0.20, 0.10),
	"dirt_light": Color(0.55, 0.35, 0.18),
	"grass": Color(0.25, 0.50, 0.12),
	"stone": Color(0.48, 0.45, 0.42),
	"stone_dark": Color(0.35, 0.33, 0.30),
}

func _ready() -> void:
	generate_terrain()

func generate_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var terrain_root := Node2D.new()
	terrain_root.name = "TerrainRoot"
	add_child(terrain_root)
	move_child(terrain_root, 0)

	var x := -16000.0
	var end_x := 55000.0
	var ground_y := 850.0
	var steps_since_drop := 0
	var entered_cave := false

	while x < end_x:
		var w = 0.0
		var gap = 0.0
		var elevated := false
		var elev_y := 0.0
		var color: Color = colors["ground"]

		if x < -1000:
			w = rng.randf_range(5000.0, 9000.0)
			gap = 0.0
		elif x < 5000:
			w = rng.randf_range(3000.0, 6000.0)
			gap = rng.randf_range(0.0, 800.0) if x > 2500 else 0.0
		elif x > 16000 and not entered_cave:
			entered_cave = true
			var drop_dist := rng.randf_range(800.0, 1500.0)
			ground_y += drop_dist
			generate_cave_entrance(terrain_root, x + 2000, ground_y, rng)
			generate_cave_shaft(terrain_root, x + 2000, ground_y, rng)
			break
		else:
			var roll := rng.randf()
			if roll < 0.50:
				w = rng.randf_range(2000.0, 9000.0)
				gap = rng.randf_range(0.0, 1800.0)
				color = colors["ground"] if rng.randf() < 0.6 else colors["dirt_dark"]
			elif roll < 0.75:
				w = rng.randf_range(1200.0, 3500.0)
				gap = rng.randf_range(600.0, 2000.0)
				elev_y = rng.randf_range(800.0, 2300.0)
				elevated = true
				color = colors["stone"]
			else:
				x += rng.randf_range(1000.0, 2500.0)
				continue

		if w > 0.0 and not elevated:
			steps_since_drop += 1
			var drop_chance := 0.15 + steps_since_drop * 0.02
			drop_chance = min(drop_chance, 0.5)
			if rng.randf() < drop_chance:
				ground_y += rng.randf_range(300.0, 600.0)
				steps_since_drop = 0

			var sy := ground_y
			if w > 5000 and x > 10000 and rng.randf() < 0.3:
				create_cave(terrain_root, x + w / 2, sy, w, rng)
			else:
				create_platform(terrain_root, x + w / 2, sy, w, PLATFORM_HEIGHT, color)
				if w > 1200.0:
					create_grass_strip(terrain_root, x + w / 2, sy, w)
		elif w > 0.0 and elevated:
			create_platform(terrain_root, x + w / 2, ground_y - elev_y, w, PLATFORM_HEIGHT, color)
			if w > 1000.0:
				create_grass_strip(terrain_root, x + w / 2, ground_y - elev_y, w)

		x += w + gap


func create_platform(parent: Node, cx: float, surface_y: float, w: float, h: float, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(cx, surface_y)

	var rect := ColorRect.new()
	rect.offset_left = -w / 2
	rect.offset_top = 0
	rect.offset_right = w / 2
	rect.offset_bottom = h
	rect.color = color

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(w, h)
	shape.shape = rect_shape
	shape.position = Vector2(0, h / 2)

	body.add_child(rect)
	body.add_child(shape)
	parent.add_child(body)


func create_decoration(parent: Node, cx: float, top: float, w: float, h: float, color: Color) -> void:
	var rect := ColorRect.new()
	rect.offset_left = -w / 2
	rect.offset_top = 0
	rect.offset_right = w / 2
	rect.offset_bottom = h
	rect.color = color

	var holder := Node2D.new()
	holder.position = Vector2(cx, top)
	holder.add_child(rect)
	parent.add_child(holder)


func create_cave(parent: Node, cx: float, floor_y: float, w: float, rng: RandomNumberGenerator) -> void:
	var cave_height := rng.randf_range(1600.0, 2500.0)
	var opening := rng.randf_range(800.0, 1400.0)
	var ceil_w := w - 2.0 * opening
	var ceil_y := floor_y - cave_height

	create_platform(parent, cx, floor_y, w, PLATFORM_HEIGHT, colors["dirt_dark"])

	var ceil_color: Color = colors["stone"] if rng.randf() < 0.5 else colors["dirt_dark"]
	create_platform(parent, cx, ceil_y, ceil_w, PLATFORM_HEIGHT, ceil_color)


func create_grass_strip(parent: Node, cx: float, surface_y: float, w: float) -> void:
	var grass := ColorRect.new()
	grass.offset_left = -w / 2
	grass.offset_top = 0
	grass.offset_right = w / 2
	grass.offset_bottom = 60
	grass.color = colors["grass"]

	var grass_holder := Node2D.new()
	grass_holder.position = Vector2(cx, surface_y)
	grass_holder.add_child(grass)
	parent.add_child(grass_holder)


func generate_cave_entrance(parent: Node, entrance_x: float, surface_y: float, rng: RandomNumberGenerator) -> void:
	var entrance_w := rng.randf_range(1800.0, 2600.0)
	var entrance_h := rng.randf_range(2000.0, 3000.0)

	var left_wall_x := entrance_x - entrance_w / 2 - rng.randf_range(400.0, 800.0)
	var right_wall_x := entrance_x + entrance_w / 2 + rng.randf_range(400.0, 800.0)
	var wall_top_y := surface_y - entrance_h - 200.0
	var wall_h := entrance_h + 400.0

	create_platform(parent, left_wall_x, wall_top_y, rng.randf_range(600.0, 1000.0), wall_h, colors["stone"])
	create_platform(parent, right_wall_x, wall_top_y, rng.randf_range(600.0, 1000.0), wall_h, colors["stone"])

	create_platform(parent, entrance_x, surface_y, entrance_w + rng.randf_range(800.0, 1400.0), PLATFORM_HEIGHT, colors["dirt_dark"])

	var arch_y := surface_y - entrance_h
	var arch_w := entrance_w + rng.randf_range(400.0, 800.0)
	create_platform(parent, entrance_x, arch_y, arch_w, PLATFORM_HEIGHT, colors["stone"])


func generate_cave_shaft(parent: Node, start_x: float, start_y: float, rng: RandomNumberGenerator) -> void:
	var shaft_x := start_x
	var current_y := start_y + 400.0
	var shaft_bottom := start_y + rng.randf_range(20000.0, 30000.0)
	var shaft_width := rng.randf_range(2500.0, 4000.0)

	var left_wall_x := shaft_x - shaft_width / 2
	var right_wall_x := shaft_x + shaft_width / 2

	var segment_index := 0
	var prev_left := left_wall_x
	var prev_right := right_wall_x

	var bg := ColorRect.new()
	bg.offset_left = left_wall_x - 2000.0
	bg.offset_top = current_y
	bg.offset_right = right_wall_x + 2000.0
	bg.offset_bottom = shaft_bottom + 5000.0
	bg.color = colors["dirt_dark"]
	parent.add_child(bg)

	while current_y < shaft_bottom:
		segment_index += 1
		var seg_descent := rng.randf_range(1200.0, 2500.0)
		var seg_bottom := current_y + seg_descent

		var lw := prev_left + rng.randf_range(-150.0, 150.0)
		var rw := prev_right + rng.randf_range(-150.0, 150.0)
		var actual_width := rw - lw
		if actual_width < 1800.0:
			var center := (lw + rw) / 2.0
			lw = center - 1000.0
			rw = center + 1000.0
			actual_width = 2000.0

		prev_left = lw
		prev_right = rw

		var wall_color: Color = colors["stone"] if rng.randf() < 0.5 else colors["dirt_dark"]
		create_platform(parent, lw, current_y, rng.randf_range(600.0, 1000.0), seg_descent + 400.0, wall_color)
		create_platform(parent, rw, current_y, rng.randf_range(600.0, 1000.0), seg_descent + 400.0, wall_color)

		var plat_count := rng.randi_range(1, 2)
		var used_y_pos := []

		for p in range(plat_count):
			var plat_y := current_y + rng.randf_range(300.0, seg_descent - 500.0)
			var too_close := false
			for u in used_y_pos:
				if abs(plat_y - u) < 700.0:
					too_close = true
					break
			if too_close:
				continue
			used_y_pos.append(plat_y)

			var plat_w := rng.randf_range(800.0, 1400.0)
			var plat_x := lw + rng.randf_range(400.0, actual_width - plat_w - 400.0)
			plat_x += plat_w / 2

			var plat_color: Color = colors["stone_dark"] if rng.randf() < 0.4 else colors["dirt_dark"]
			create_platform(parent, plat_x, plat_y, plat_w, PLATFORM_HEIGHT, plat_color)

			if rng.randf() < 0.35:
				var spike_w := rng.randf_range(80.0, 180.0)
				var spike_h := rng.randf_range(120.0, 300.0)
				create_decoration(parent, plat_x + rng.randf_range(-plat_w / 3, plat_w / 3), plat_y - spike_h, spike_w, spike_h, colors["stone"])

		if segment_index % 2 == 0 and rng.randf() < 0.25:
			shaft_width += rng.randf_range(-300.0, 300.0)
			shaft_width = clamp(shaft_width, 2000.0, 4500.0)
			left_wall_x = shaft_x - shaft_width / 2
			right_wall_x = shaft_x + shaft_width / 2
			prev_left = left_wall_x
			prev_right = right_wall_x

		if rng.randf() < 0.2:
			shaft_x += rng.randf_range(-300.0, 300.0)

		current_y = seg_bottom

	var depth_bottom := current_y + rng.randf_range(3000.0, 5000.0)
	var lw_end := prev_left + rng.randf_range(-200.0, 100.0)
	var rw_end := prev_right + rng.randf_range(-100.0, 200.0)

	var wall_depth_colors := [colors["dirt_dark"], colors["stone_dark"], Color(0.20, 0.18, 0.16), Color(0.10, 0.09, 0.08), Color(0.05, 0.04, 0.04)]
	var depth_steps := 5
	var step_h := (depth_bottom - current_y) / depth_steps

	for i in range(depth_steps):
		var step_top := current_y + i * step_h
		var t: float = float(i) / depth_steps
		var lw_i: float = lerp(lw_end, lw_end - 300.0 * t, t)
		var rw_i: float = lerp(rw_end, rw_end + 300.0 * t, t)

		var rect := ColorRect.new()
		rect.offset_left = lw_i
		rect.offset_top = step_top
		rect.offset_right = rw_i
		rect.offset_bottom = step_top + step_h
		rect.color = wall_depth_colors[i]
		parent.add_child(rect)

		if rng.randf() < 0.25:
			var spike_w := rng.randf_range(60.0, 140.0)
			var spike_h := rng.randf_range(100.0, 200.0)
			var spike_color: Color = wall_depth_colors[min(i + 1, depth_steps - 1)]
			create_decoration(parent, lw_i + 100.0, step_top, spike_w, spike_h, spike_color)
		if rng.randf() < 0.25:
			var spike_w := rng.randf_range(60.0, 140.0)
			var spike_h := rng.randf_range(100.0, 200.0)
			var spike_color: Color = wall_depth_colors[min(i + 1, depth_steps - 1)]
			create_decoration(parent, rw_i - 100.0, step_top, spike_w, spike_h, spike_color)

	var abyss_rect := ColorRect.new()
	abyss_rect.offset_left = shaft_x - 6000.0
	abyss_rect.offset_top = depth_bottom
	abyss_rect.offset_right = shaft_x + 6000.0
	abyss_rect.offset_bottom = depth_bottom + 6000.0
	abyss_rect.color = Color(0.02, 0.01, 0.02)
	parent.add_child(abyss_rect)
