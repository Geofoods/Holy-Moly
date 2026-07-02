extends Node2D

const GROUND_Y := 85.0
const PLATFORM_HEIGHT := 40.0

var colors = {
	"ground": Color(0.45, 0.26, 0.13),
	"dirt_dark": Color(0.35, 0.20, 0.10),
	"dirt_light": Color(0.55, 0.35, 0.18),
	"grass": Color(0.25, 0.50, 0.12),
	"stone": Color(0.48, 0.45, 0.42),
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

	var x := -1600.0
	var end_x := 5500.0
	var ground_y := 85.0
	var steps_since_drop := 0

	while x < end_x:
		var w = 0.0
		var gap = 0.0
		var elevated := false
		var elev_y := 0.0
		var color: Color = colors["ground"]

		if x < -100:
			w = rng.randf_range(500.0, 900.0)
			gap = 0.0
		elif x < 500:
			w = rng.randf_range(300.0, 600.0)
			gap = rng.randf_range(0.0, 80.0) if x > 250 else 0.0
		else:
			var roll := rng.randf()
			if roll < 0.50:
				w = rng.randf_range(200.0, 900.0)
				gap = rng.randf_range(0.0, 180.0)
				color = colors["ground"] if rng.randf() < 0.6 else colors["dirt_dark"]
			elif roll < 0.75:
				w = rng.randf_range(120.0, 350.0)
				gap = rng.randf_range(60.0, 200.0)
				elev_y = rng.randf_range(80.0, 230.0)
				elevated = true
				color = colors["stone"]
			else:
				x += rng.randf_range(100.0, 250.0)
				continue

		if w > 0.0 and not elevated:
			steps_since_drop += 1
			var drop_chance := 0.15 + steps_since_drop * 0.02
			drop_chance = min(drop_chance, 0.5)
			if rng.randf() < drop_chance:
				ground_y += rng.randf_range(30.0, 60.0)
				steps_since_drop = 0

			var sy := ground_y
			if w > 500 and x > 1000 and rng.randf() < 0.3:
				create_cave(terrain_root, x + w / 2, sy, w, rng)
			else:
				create_platform(terrain_root, x + w / 2, sy, w, PLATFORM_HEIGHT, color)
				if w > 120.0:
					create_grass_strip(terrain_root, x + w / 2, sy, w)
		elif w > 0.0 and elevated:
			create_platform(terrain_root, x + w / 2, ground_y - elev_y, w, PLATFORM_HEIGHT, color)
			if w > 100.0:
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


func create_cave(parent: Node, cx: float, floor_y: float, w: float, rng: RandomNumberGenerator) -> void:
	var cave_height := rng.randf_range(160.0, 250.0)
	var opening := rng.randf_range(80.0, 140.0)
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
	grass.offset_bottom = 6
	grass.color = colors["grass"]

	var grass_holder := Node2D.new()
	grass_holder.position = Vector2(cx, surface_y)
	grass_holder.add_child(grass)
	parent.add_child(grass_holder)
