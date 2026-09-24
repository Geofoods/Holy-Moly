extends Node

enum TileType { DIRT, STONE, CORRUPTED, CRYSTAL, MUSHROOM, WOOD }

const SOUNDS := {
	TileType.DIRT: [
		preload("res://sounds/break_dirt_1.ogg"),
		preload("res://sounds/break_dirt_2.ogg"),
		preload("res://sounds/break_dirt_3.ogg"),
	],
	TileType.STONE: [
		preload("res://sounds/break_stone_1.ogg"),
		preload("res://sounds/break_stone_2.ogg"),
		preload("res://sounds/break_stone_3.ogg"),
	],
	TileType.CORRUPTED: [
		preload("res://sounds/break_corrupted_1.ogg"),
		preload("res://sounds/break_corrupted_2.ogg"),
		preload("res://sounds/break_corrupted_3.ogg"),
	],
	TileType.CRYSTAL: [
		preload("res://sounds/break_crystal_1.ogg"),
		preload("res://sounds/break_crystal_2.ogg"),
		preload("res://sounds/break_crystal_3.ogg"),
	],
	TileType.MUSHROOM: [
		preload("res://sounds/break_mushroom_1.ogg"),
		preload("res://sounds/break_mushroom_2.ogg"),
		preload("res://sounds/break_mushroom_3.ogg"),
	],
	TileType.WOOD: [
		preload("res://sounds/break_wood_1.ogg"),
		preload("res://sounds/break_wood_2.ogg"),
		preload("res://sounds/break_wood_3.ogg"),
	],
}

const TILE_MAP := {
	Vector2i(0, 0): TileType.DIRT,       # sandy dirt with grass top
	Vector2i(1, 0): TileType.STONE,      # pink cobblestone
	Vector2i(2, 0): TileType.STONE,      # red stone bricks
	Vector2i(3, 0): TileType.STONE,      # dark red stone
	Vector2i(4, 0): TileType.STONE,      # maroon brick
	Vector2i(5, 0): TileType.CORRUPTED,  # dark brick with orange drips
	Vector2i(6, 0): TileType.CRYSTAL,    # blue/cyan ice blocks
	Vector2i(7, 0): TileType.CORRUPTED,  # purple corrupted blocks
	Vector2i(8, 0): TileType.CORRUPTED,  # dark purple corrupted
	Vector2i(9, 0): TileType.CRYSTAL,    # red chain/gem
	Vector2i(10, 0): TileType.CRYSTAL,   # red chain
	Vector2i(11, 0): TileType.CRYSTAL,   # chain piece
	Vector2i(12, 0): TileType.CRYSTAL,   # small chain end

	Vector2i(0, 1): TileType.STONE,      # red/pink stone
	Vector2i(1, 1): TileType.STONE,      # red stone
	Vector2i(2, 1): TileType.STONE,      # dark red stone
	Vector2i(3, 1): TileType.STONE,      # dark maroon
	Vector2i(4, 1): TileType.STONE,      # very dark brick
	Vector2i(5, 1): TileType.STONE,      # very dark brick
	Vector2i(6, 1): TileType.CORRUPTED,  # dark purple
	Vector2i(7, 1): TileType.CORRUPTED,  # purple with bat shapes
	Vector2i(8, 1): TileType.CORRUPTED,  # dark with glowing eyes
	Vector2i(9, 1): TileType.CORRUPTED,  # corrupted slope
	Vector2i(10, 1): TileType.CORRUPTED, # corrupted slope
	Vector2i(11, 1): TileType.CORRUPTED, # corrupted slope
	Vector2i(12, 1): TileType.CORRUPTED, # corrupted edge

	Vector2i(0, 2): TileType.DIRT,       # empty/dirt
	Vector2i(1, 2): TileType.DIRT,       # empty/dirt
	Vector2i(3, 2): TileType.WOOD,       # tan stalactite top
	Vector2i(4, 2): TileType.CRYSTAL,    # cyan/ice stalactite top
	Vector2i(5, 2): TileType.WOOD,       # orange stalactite top
	Vector2i(6, 2): TileType.CORRUPTED,  # red/corrupted stalactite top
	Vector2i(7, 2): TileType.WOOD,       # stalactite variant
	Vector2i(8, 2): TileType.WOOD,       # stalactite variant

	Vector2i(3, 3): TileType.WOOD,       # tan stalactite body
	Vector2i(4, 3): TileType.CRYSTAL,    # ice stalactite body
	Vector2i(5, 3): TileType.WOOD,       # orange stalactite body
	Vector2i(6, 3): TileType.CORRUPTED,  # corrupted stalactite body
	Vector2i(7, 3): TileType.WOOD,       # stalactite body
	Vector2i(8, 3): TileType.WOOD,       # stalactite body

	Vector2i(3, 4): TileType.WOOD,       # tan stalactite lower
	Vector2i(4, 4): TileType.CRYSTAL,    # ice stalactite lower
	Vector2i(5, 4): TileType.WOOD,       # orange stalactite lower
	Vector2i(6, 4): TileType.CORRUPTED,  # corrupted stalactite lower

	Vector2i(3, 5): TileType.MUSHROOM,   # orange mushroom
	Vector2i(4, 5): TileType.MUSHROOM,   # orange mushroom
	Vector2i(5, 5): TileType.MUSHROOM,   # dark mushroom
	Vector2i(6, 5): TileType.MUSHROOM,   # dark mushroom
	Vector2i(7, 5): TileType.MUSHROOM,   # cyan mushroom
	Vector2i(8, 5): TileType.MUSHROOM,   # cyan mushroom
	Vector2i(9, 5): TileType.MUSHROOM,   # blue mushroom
	Vector2i(10, 5): TileType.MUSHROOM,  # blue mushroom

	Vector2i(3, 6): TileType.MUSHROOM,   # cyan mushroom small
	Vector2i(4, 6): TileType.MUSHROOM,   # cyan mushroom
	Vector2i(5, 6): TileType.MUSHROOM,   # tan mushroom
	Vector2i(6, 6): TileType.MUSHROOM,   # tan mushroom
	Vector2i(7, 6): TileType.MUSHROOM,   # tan/dark mushroom
	Vector2i(8, 6): TileType.MUSHROOM,   # corrupted mushroom
	Vector2i(9, 6): TileType.MUSHROOM,   # corrupted mushroom
	Vector2i(10, 6): TileType.MUSHROOM,  # corrupted mushroom
	Vector2i(11, 6): TileType.MUSHROOM,  # corrupted mushroom
	Vector2i(12, 6): TileType.MUSHROOM,  # corrupted mushroom
	Vector2i(13, 6): TileType.MUSHROOM,  # corrupted mushroom

	Vector2i(0, 7): TileType.CRYSTAL,    # amber potion bottle (glass)
	Vector2i(1, 7): TileType.CRYSTAL,    # amber potion bottle (glass)
	Vector2i(5, 7): TileType.STONE,      # R.I.P. gravestone
	Vector2i(7, 7): TileType.WOOD,       # candle/small prop
	Vector2i(8, 7): TileType.WOOD,       # small prop
	Vector2i(9, 7): TileType.CORRUPTED,  # corrupted stalactite top
	Vector2i(10, 7): TileType.CORRUPTED, # corrupted stalactite top
	Vector2i(11, 7): TileType.CORRUPTED, # corrupted stalactite top
	Vector2i(12, 7): TileType.CORRUPTED, # corrupted stalactite top
	Vector2i(13, 7): TileType.CORRUPTED, # corrupted stalactite top

	Vector2i(0, 8): TileType.CRYSTAL,    # cyan potion (glass)
	Vector2i(1, 8): TileType.CRYSTAL,    # dark/green potion (glass)
	Vector2i(3, 8): TileType.WOOD,       # barrel
	Vector2i(4, 8): TileType.MUSHROOM,   # pumpkin (organic)
	Vector2i(5, 8): TileType.CRYSTAL,    # cyan gem
	Vector2i(6, 8): TileType.CRYSTAL,    # cyan gem
	Vector2i(7, 8): TileType.WOOD,       # prop
	Vector2i(9, 8): TileType.CORRUPTED,  # corrupted stalactite
	Vector2i(10, 8): TileType.CORRUPTED, # corrupted stalactite
	Vector2i(11, 8): TileType.CORRUPTED, # corrupted stalactite
	Vector2i(12, 8): TileType.CORRUPTED, # corrupted stalactite
	Vector2i(13, 8): TileType.CORRUPTED, # corrupted stalactite

	Vector2i(0, 9): TileType.CRYSTAL,    # potion
	Vector2i(4, 9): TileType.MUSHROOM,   # tan mushroom cap
	Vector2i(5, 9): TileType.MUSHROOM,   # tan mushroom cap
	Vector2i(6, 9): TileType.MUSHROOM,   # orange mushroom cap
	Vector2i(11, 9): TileType.CORRUPTED, # corrupted stalactite
	Vector2i(12, 9): TileType.CORRUPTED, # corrupted stalactite
	Vector2i(13, 9): TileType.CORRUPTED, # corrupted stalactite

	Vector2i(5, 10): TileType.MUSHROOM,  # orange mushroom cap
	Vector2i(6, 10): TileType.MUSHROOM,  # corrupted mushroom cap
	Vector2i(11, 10): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(12, 10): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(13, 10): TileType.CORRUPTED,# corrupted stalactite

	Vector2i(7, 11): TileType.MUSHROOM,  # blue mushroom cap
	Vector2i(8, 11): TileType.MUSHROOM,  # cyan mushroom cap
	Vector2i(9, 11): TileType.MUSHROOM,  # orange mushroom cap
	Vector2i(10, 11): TileType.MUSHROOM, # yellow mushroom cap
	Vector2i(11, 11): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(12, 11): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(13, 11): TileType.CORRUPTED,# corrupted stalactite

	Vector2i(8, 12): TileType.MUSHROOM,  # corrupted mushroom
	Vector2i(9, 12): TileType.MUSHROOM,  # corrupted mushroom
	Vector2i(10, 12): TileType.MUSHROOM, # corrupted mushroom
	Vector2i(11, 12): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(12, 12): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(13, 12): TileType.CORRUPTED,# corrupted stalactite

	Vector2i(10, 13): TileType.CORRUPTED,
	Vector2i(11, 13): TileType.CORRUPTED,
	Vector2i(12, 13): TileType.CORRUPTED,
	Vector2i(13, 13): TileType.CORRUPTED,
	Vector2i(11, 14): TileType.CORRUPTED,
	Vector2i(12, 14): TileType.CORRUPTED,
	Vector2i(13, 14): TileType.CORRUPTED,
	Vector2i(12, 15): TileType.CORRUPTED,
}

const TILE_COLORS := {
	Vector2i(0, 0): [Color(0.77, 0.63, 0.42), Color(0.65, 0.50, 0.30)],       # sandy dirt
	Vector2i(1, 0): [Color(0.77, 0.44, 0.44), Color(0.60, 0.35, 0.35)],       # pink stone
	Vector2i(2, 0): [Color(0.65, 0.30, 0.30), Color(0.50, 0.22, 0.22)],       # red stone
	Vector2i(3, 0): [Color(0.55, 0.22, 0.22), Color(0.40, 0.15, 0.15)],       # dark red
	Vector2i(4, 0): [Color(0.45, 0.18, 0.18), Color(0.35, 0.12, 0.12)],       # maroon
	Vector2i(5, 0): [Color(0.40, 0.15, 0.10), Color(0.80, 0.55, 0.15)],       # dark + orange drip
	Vector2i(6, 0): [Color(0.35, 0.75, 0.90), Color(0.50, 0.85, 0.95)],       # cyan ice
	Vector2i(7, 0): [Color(0.45, 0.20, 0.60), Color(0.55, 0.30, 0.70)],       # purple
	Vector2i(8, 0): [Color(0.30, 0.12, 0.45), Color(0.40, 0.18, 0.55)],       # dark purple
	Vector2i(9, 0): [Color(0.70, 0.30, 0.30), Color(0.55, 0.20, 0.20)],       # red gem
	Vector2i(10, 0): [Color(0.70, 0.30, 0.30), Color(0.55, 0.20, 0.20)],      # red chain
	Vector2i(11, 0): [Color(0.65, 0.28, 0.28), Color(0.50, 0.18, 0.18)],      # chain
	Vector2i(12, 0): [Color(0.60, 0.25, 0.25), Color(0.45, 0.15, 0.15)],      # chain end
	Vector2i(0, 1): [Color(0.70, 0.38, 0.38), Color(0.55, 0.28, 0.28)],       # red/pink
	Vector2i(1, 1): [Color(0.60, 0.30, 0.30), Color(0.48, 0.22, 0.22)],       # red
	Vector2i(2, 1): [Color(0.50, 0.22, 0.22), Color(0.38, 0.15, 0.15)],       # dark red
	Vector2i(3, 1): [Color(0.42, 0.18, 0.18), Color(0.32, 0.12, 0.12)],       # dark maroon
	Vector2i(4, 1): [Color(0.35, 0.14, 0.14), Color(0.25, 0.10, 0.10)],       # very dark
	Vector2i(5, 1): [Color(0.30, 0.12, 0.12), Color(0.22, 0.08, 0.08)],       # very dark
	Vector2i(6, 1): [Color(0.28, 0.12, 0.40), Color(0.35, 0.15, 0.50)],       # dark purple
	Vector2i(7, 1): [Color(0.32, 0.14, 0.45), Color(0.25, 0.10, 0.38)],       # purple bats
	Vector2i(8, 1): [Color(0.20, 0.08, 0.30), Color(0.30, 0.12, 0.40)],       # dark eyes
	Vector2i(9, 1): [Color(0.25, 0.10, 0.35), Color(0.35, 0.15, 0.48)],       # corrupted slope
	Vector2i(10, 1): [Color(0.25, 0.10, 0.35), Color(0.32, 0.14, 0.45)],
	Vector2i(11, 1): [Color(0.28, 0.12, 0.38), Color(0.35, 0.15, 0.48)],
	Vector2i(12, 1): [Color(0.25, 0.10, 0.35), Color(0.30, 0.12, 0.40)],
	Vector2i(3, 2): [Color(0.75, 0.62, 0.42), Color(0.60, 0.48, 0.30)],       # tan
	Vector2i(4, 2): [Color(0.40, 0.80, 0.88), Color(0.55, 0.88, 0.95)],       # cyan
	Vector2i(5, 2): [Color(0.85, 0.60, 0.20), Color(0.70, 0.45, 0.15)],       # orange
	Vector2i(6, 2): [Color(0.65, 0.25, 0.15), Color(0.50, 0.18, 0.10)],       # red corrupted
	Vector2i(3, 3): [Color(0.70, 0.58, 0.38), Color(0.55, 0.42, 0.25)],
	Vector2i(4, 3): [Color(0.35, 0.75, 0.85), Color(0.50, 0.85, 0.92)],
	Vector2i(5, 3): [Color(0.80, 0.55, 0.18), Color(0.65, 0.40, 0.12)],
	Vector2i(6, 3): [Color(0.60, 0.22, 0.12), Color(0.45, 0.15, 0.08)],
	Vector2i(3, 4): [Color(0.65, 0.52, 0.35), Color(0.50, 0.38, 0.22)],
	Vector2i(4, 4): [Color(0.35, 0.72, 0.82), Color(0.48, 0.82, 0.90)],
	Vector2i(5, 4): [Color(0.78, 0.52, 0.15), Color(0.62, 0.38, 0.10)],
	Vector2i(6, 4): [Color(0.55, 0.20, 0.10), Color(0.42, 0.14, 0.07)],
	Vector2i(3, 5): [Color(0.82, 0.52, 0.18), Color(0.70, 0.40, 0.12)],       # orange mush
	Vector2i(4, 5): [Color(0.80, 0.50, 0.15), Color(0.68, 0.38, 0.10)],
	Vector2i(5, 5): [Color(0.75, 0.48, 0.15), Color(0.55, 0.30, 0.10)],       # dark mush
	Vector2i(6, 5): [Color(0.70, 0.42, 0.12), Color(0.50, 0.28, 0.08)],
	Vector2i(7, 5): [Color(0.35, 0.78, 0.85), Color(0.48, 0.85, 0.92)],       # cyan mush
	Vector2i(8, 5): [Color(0.38, 0.80, 0.88), Color(0.50, 0.87, 0.93)],
	Vector2i(9, 5): [Color(0.40, 0.82, 0.90), Color(0.52, 0.88, 0.95)],
	Vector2i(10, 5): [Color(0.42, 0.83, 0.90), Color(0.55, 0.90, 0.95)],
	Vector2i(3, 6): [Color(0.38, 0.78, 0.85), Color(0.50, 0.85, 0.92)],       # cyan small
	Vector2i(4, 6): [Color(0.40, 0.80, 0.88), Color(0.52, 0.87, 0.93)],
	Vector2i(5, 6): [Color(0.75, 0.62, 0.40), Color(0.60, 0.48, 0.28)],       # tan mush
	Vector2i(6, 6): [Color(0.72, 0.60, 0.38), Color(0.58, 0.45, 0.25)],
	Vector2i(7, 6): [Color(0.68, 0.55, 0.35), Color(0.52, 0.40, 0.22)],
	Vector2i(8, 6): [Color(0.50, 0.30, 0.15), Color(0.38, 0.20, 0.10)],       # dark/corrupted
	Vector2i(9, 6): [Color(0.48, 0.28, 0.12), Color(0.35, 0.18, 0.08)],
	Vector2i(10, 6): [Color(0.45, 0.25, 0.10), Color(0.32, 0.15, 0.06)],
	Vector2i(0, 7): [Color(0.85, 0.65, 0.20), Color(0.70, 0.50, 0.15)],       # amber potion
	Vector2i(1, 7): [Color(0.82, 0.62, 0.18), Color(0.68, 0.48, 0.12)],
	Vector2i(5, 7): [Color(0.55, 0.50, 0.45), Color(0.40, 0.38, 0.35)],       # gravestone
	Vector2i(0, 8): [Color(0.30, 0.75, 0.82), Color(0.45, 0.85, 0.90)],       # cyan potion
	Vector2i(1, 8): [Color(0.18, 0.40, 0.30), Color(0.25, 0.50, 0.38)],       # green potion
	Vector2i(3, 8): [Color(0.55, 0.35, 0.18), Color(0.42, 0.25, 0.12)],       # barrel
	Vector2i(4, 8): [Color(0.85, 0.60, 0.15), Color(0.70, 0.45, 0.10)],       # pumpkin
	Vector2i(5, 8): [Color(0.35, 0.78, 0.88), Color(0.50, 0.88, 0.95)],       # cyan gem
	Vector2i(6, 8): [Color(0.38, 0.80, 0.90), Color(0.52, 0.88, 0.95)],
}

const TYPE_COLORS := {
	TileType.DIRT: [Color(0.72, 0.58, 0.38), Color(0.60, 0.45, 0.28)],
	TileType.STONE: [Color(0.55, 0.25, 0.25), Color(0.42, 0.18, 0.18)],
	TileType.CORRUPTED: [Color(0.30, 0.12, 0.42), Color(0.40, 0.18, 0.55)],
	TileType.CRYSTAL: [Color(0.40, 0.80, 0.90), Color(0.55, 0.88, 0.95)],
	TileType.MUSHROOM: [Color(0.78, 0.50, 0.18), Color(0.62, 0.38, 0.12)],
	TileType.WOOD: [Color(0.55, 0.38, 0.20), Color(0.42, 0.28, 0.14)],
}

static func get_tile_type(atlas_coords: Vector2i) -> TileType:
	if TILE_MAP.has(atlas_coords):
		return TILE_MAP[atlas_coords]
	return TileType.DIRT

static func get_tile_colors(atlas_coords: Vector2i) -> Array:
	if TILE_COLORS.has(atlas_coords):
		return TILE_COLORS[atlas_coords]
	var tile_type := get_tile_type(atlas_coords)
	return TYPE_COLORS[tile_type]

static var _atlas_image_cache := {}

static func _atlas_image(src: TileSetAtlasSource) -> Image:
	if src == null or src.texture == null:
		return null
	var key := src.texture.get_instance_id()
	if _atlas_image_cache.has(key) and is_instance_valid(_atlas_image_cache[key]):
		return _atlas_image_cache[key]
	var img := src.texture.get_image()
	_atlas_image_cache[key] = img
	return img

static func sample_tile_modulate(src: TileSetAtlasSource, atlas_coords: Vector2i) -> Color:
	# Average the block's real on-screen color straight from the tileset icon
	# region, so debris matches the actual modulation of the block that was
	# broken instead of the approximation in the palette above.
	if src == null:
		return Color.WHITE
	var basis := Vector2(src.texture_region_size)
	if basis.x <= 0.0 or basis.y <= 0.0:
		return Color.WHITE
	var img := _atlas_image(src)
	if img == null:
		return Color.WHITE
	var origin := Vector2i(atlas_coords) * Vector2i(int(basis.x), int(basis.y))
	const GRID := 8
	var total := Color(0, 0, 0, 0)
	var count := 0
	for gy in range(GRID):
		for gx in range(GRID):
			var px := origin + Vector2i(
				int(basis.x * (float(gx) + 0.5) / float(GRID)),
				int(basis.y * (float(gy) + 0.5) / float(GRID)))
			total += img.get_pixel(px.x, px.y)
			count += 1
	return total / float(count)

const STALACTITE_ROWS := [2, 3, 4]
const CORRUPTED_STALACTITE_COLS := {9: true, 10: true, 11: true, 12: true, 13: true}

static func is_stalactite(atlas_coords: Vector2i) -> bool:
	if atlas_coords.y in STALACTITE_ROWS and atlas_coords.x >= 3 and atlas_coords.x <= 8:
		return true
	if CORRUPTED_STALACTITE_COLS.has(atlas_coords.x):
		if atlas_coords.y >= 7 and atlas_coords.y <= 15:
			return true
	return false

static func break_tile(tilemap: TileMap, tile_pos: Vector2i, parent: Node, force: bool = false) -> void:
	var world_pos := tilemap.to_global(tilemap.map_to_local(tile_pos))
	var source_id := tilemap.get_cell_source_id(0, tile_pos)
	if source_id == -1:
		_break_opened_chests_near(parent, world_pos)
		return
	var atlas_coords := tilemap.get_cell_atlas_coords(0, tile_pos)

	_break_single_tile(tilemap, tile_pos, atlas_coords, parent, force)
	_collapse_unsupported_sides(tilemap, tile_pos, parent)
	_break_opened_chests_near(parent, world_pos)

	var tree := parent.get_tree()
	if tree:
		var mole := tree.get_first_node_in_group("mole")
		if mole and mole.has_method("screen_shake"):
			mole.screen_shake(4.0, 0.1)

	_break_decoration_tile(tilemap, tile_pos, parent)

	if is_stalactite(atlas_coords):
		var below_tiles: Array[Vector2i] = []
		for dy in range(1, 20):
			var below := Vector2i(tile_pos.x, tile_pos.y + dy)
			var s := tilemap.get_cell_source_id(0, below)
			if s == -1:
				break
			var a := tilemap.get_cell_atlas_coords(0, below)
			if not is_stalactite(a):
				break
			below_tiles.append(below)
		if below_tiles.size() > 0:
			_cascade_break(tilemap, below_tiles, parent, 0)

	_break_stuff_above(tilemap, tile_pos, parent)

static func break_decoration_tile(tilemap: TileMap, tile_pos: Vector2i, parent: Node) -> void:
	_break_decoration_tile(tilemap, tile_pos, parent)
	var world_pos := tilemap.to_global(tilemap.map_to_local(tile_pos))
	_break_opened_chests_near(parent, world_pos)

static func break_opened_chest_at_point(parent: Node, world_pos: Vector2) -> bool:
	if not is_instance_valid(parent):
		return false
	var tree := parent.get_tree()
	if tree == null:
		return false
	for chest in tree.get_nodes_in_group("opened_chest"):
		if not is_instance_valid(chest) or not (chest is Area2D):
			continue
		if _opened_chest_contains_point(chest as Area2D, world_pos):
			if chest.has_method("break_as_block"):
				chest.call("break_as_block")
				return true
	return false

static func break_opened_chest_from_node(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	var chest := node
	if not chest.is_in_group("opened_chest") and chest.has_node("Interaction"):
		chest = chest.get_node("Interaction")
	if chest.is_in_group("opened_chest") and chest.has_method("break_as_block"):
		chest.call("break_as_block")
		return true
	return false

static func break_opened_chests_near(parent: Node, world_pos: Vector2, radius: float = 120.0) -> void:
	_break_opened_chests_near(parent, world_pos, radius)

static func _break_decoration_tile(tilemap: TileMap, tile_pos: Vector2i, parent: Node) -> void:
	if tilemap.get_layers_count() < 2:
		return
	var source_id := tilemap.get_cell_source_id(1, tile_pos)
	if source_id == -1:
		return
	var atlas_coords := tilemap.get_cell_atlas_coords(1, tile_pos)
	_break_single_decoration_tile(tilemap, tile_pos, atlas_coords, parent)

static func _break_single_decoration_tile(tilemap: TileMap, tile_pos: Vector2i, atlas_coords: Vector2i, parent: Node) -> void:
	var source_id := tilemap.get_cell_source_id(1, tile_pos)
	if source_id == -1:
		return

	var tile_type := get_tile_type(atlas_coords)
	var variants: Array = SOUNDS[tile_type]
	var sound: AudioStream = variants[randi() % variants.size()]

	var world_pos := tilemap.to_global(tilemap.map_to_local(tile_pos))

	var player := _acquire_player(parent)
	player.stream = sound
	player.pitch_scale = randf_range(0.9, 1.1)
	player.volume_db = -8.0
	player.global_position = world_pos
	player.play()

	spawn_break_particles(tilemap, tile_pos, atlas_coords, parent)
	tilemap.erase_cell(1, tile_pos)

static func _cascade_break(tilemap: TileMap, tiles: Array[Vector2i], parent: Node, index: int) -> void:
	if index >= tiles.size():
		return
	if not is_instance_valid(parent) or parent.get_tree() == null:
		return
	var pos := tiles[index]
	_break_cascade_cell(tilemap, pos, parent)
	parent.get_tree().create_timer(0.06).timeout.connect(_cascade_break.bind(tilemap, tiles, parent, index + 1))

static func _break_cascade_cell(tilemap: TileMap, pos: Vector2i, parent: Node) -> void:
	var s := tilemap.get_cell_source_id(0, pos)
	if s != -1:
		var a := tilemap.get_cell_atlas_coords(0, pos)
		_break_single_tile(tilemap, pos, a, parent)
	_break_decoration_tile(tilemap, pos, parent)

static func _collapse_unsupported_sides(tilemap: TileMap, origin: Vector2i, parent: Node) -> void:
	var pending: Array[Vector2i] = [origin]
	while not pending.is_empty():
		var pos: Vector2i = pending.pop_back()
		for offset in [Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = pos + offset
			if tilemap.get_cell_source_id(0, neighbor) == -1:
				continue
			var data := tilemap.get_cell_tile_data(0, neighbor)
			if data == null or not (data.get_custom_data("sides") as bool):
				continue
			if tilemap.get_cell_source_id(0, neighbor + Vector2i.LEFT) != -1 or tilemap.get_cell_source_id(0, neighbor + Vector2i.RIGHT) != -1:
				continue
			var atlas := tilemap.get_cell_atlas_coords(0, neighbor)
			_break_single_tile(tilemap, neighbor, atlas, parent)
			pending.append(neighbor)

static func _break_stuff_above(tilemap: TileMap, tile_pos: Vector2i, parent: Node) -> void:
	var stuff_tiles: Array[Vector2i] = []
	for dy in range(1, 20):
		var above := Vector2i(tile_pos.x, tile_pos.y - dy)
		if not _cell_has_stuff(tilemap, above):
			break
		stuff_tiles.append(above)
	if stuff_tiles.size() > 0:
		_cascade_break(tilemap, stuff_tiles, parent, 0)

static func _cell_has_stuff(tilemap: TileMap, cell: Vector2i) -> bool:
	var td := tilemap.get_cell_tile_data(0, cell)
	if td != null:
		return (td.get_custom_data("stuff") as bool)
	for layer in range(1, tilemap.get_layers_count()):
		var d := tilemap.get_cell_tile_data(layer, cell)
		if d != null and (d.get_custom_data("stuff") as bool):
			return true
	return false

static func _break_single_tile(tilemap: TileMap, tile_pos: Vector2i, atlas_coords: Vector2i, parent: Node, force: bool = false) -> void:
	var source_id := tilemap.get_cell_source_id(0, tile_pos)
	if source_id == -1:
		return
	var tile_data := tilemap.get_cell_tile_data(0, tile_pos)
	if not force and tile_data and tile_data.get_custom_data("bedrock"):
		return

	var tile_type := get_tile_type(atlas_coords)
	var variants: Array = SOUNDS[tile_type]
	var sound: AudioStream = variants[randi() % variants.size()]

	var world_pos := tilemap.to_global(tilemap.map_to_local(tile_pos))

	# Pooled player: tunneling breaks many tiles per second, so a fresh
	# AudioStreamPlayer2D allocation per tile causes noticeable alloc churn.
	var player := _acquire_player(parent)
	player.stream = sound
	player.pitch_scale = randf_range(0.9, 1.1)
	player.volume_db = -6.0
	player.global_position = world_pos
	player.play()

	spawn_break_particles(tilemap, tile_pos, atlas_coords, parent)
	tilemap.erase_cell(0, tile_pos)

const MAX_POOLED := 12
const DEBRIS_COUNT := 4
static var _pool: Array[AudioStreamPlayer2D] = []

static func _acquire_player(parent: Node) -> AudioStreamPlayer2D:
	var p: AudioStreamPlayer2D
	if _pool.is_empty():
		p = AudioStreamPlayer2D.new()
		p.finished.connect(_release_player.bind(p))
	else:
		p = _pool.pop_back()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(p)
	return p

static func _release_player(p: AudioStreamPlayer2D) -> void:
	if not is_instance_valid(p):
		return
	p.stop()
	p.stream = null
	var tree := p.get_tree()
	if tree != null and tree.current_scene != null and _pool.size() < MAX_POOLED:
		if p.get_parent():
			p.get_parent().remove_child(p)
		_pool.append(p)
	else:
		p.queue_free()

static func spawn_break_particles(tilemap: TileMap, tile_pos: Vector2i, atlas_coords: Vector2i, parent: Node) -> void:
	var world_pos := tilemap.to_global(tilemap.map_to_local(tile_pos))

	var piece_tex: Texture2D = null
	var basis := Vector2.ZERO
	var src := tilemap.tile_set.get_source(0) as TileSetAtlasSource
	if src != null and src.texture != null:
		piece_tex = src.texture
		basis = Vector2(src.texture_region_size)

	if piece_tex != null and basis.x > 0.0 and basis.y > 0.0:
		var origin := Vector2(atlas_coords) * basis
		spawn_texture_break_particles(piece_tex, Rect2(origin, basis), world_pos, parent, DEBRIS_COUNT)
	else:
		spawn_texture_break_particles(null, Rect2(), world_pos, parent, DEBRIS_COUNT)

static func spawn_texture_break_particles(texture: Texture2D, region: Rect2, world_pos: Vector2, parent: Node, count: int = 4, min_size: float = 18.0, max_size: float = 34.0) -> void:
	if not is_instance_valid(parent):
		return
	for i in range(count):
		var chunk := RigidBody2D.new()
		chunk.collision_layer = 2
		chunk.gravity_scale = 3.2
		chunk.linear_damp = 3.5
		chunk.angular_damp = 2.0
		chunk.z_index = 3
		parent.call_deferred("add_child", chunk)
		chunk.global_position = world_pos
		chunk.rotation = randf_range(0.0, TAU)

		var piece_size := Vector2(randf_range(min_size, max_size), randf_range(min_size, max_size))
		if texture != null and region.size.x > 0.0 and region.size.y > 0.0:
			var piece := AtlasTexture.new()
			piece.atlas = texture
			var piece_offset := Vector2(
				randf_range(0.0, maxf(region.size.x - piece_size.x, 0.0)),
				randf_range(0.0, maxf(region.size.y - piece_size.y, 0.0)))
			piece.region = Rect2(region.position + piece_offset, piece_size)
			var sprite := Sprite2D.new()
			sprite.texture = piece
			chunk.add_child(sprite)
		else:
			var dust := Polygon2D.new()
			dust.polygon = PackedVector2Array([
				Vector2(-piece_size.x / 2.0, -piece_size.y / 2.0),
				Vector2(piece_size.x / 2.0, -piece_size.y / 2.0),
				Vector2(piece_size.x / 2.0, piece_size.y / 2.0),
				Vector2(-piece_size.x / 2.0, piece_size.y / 2.0),
			])
			dust.color = Color(0.72, 0.58, 0.38, 1.0)
			chunk.add_child(dust)

		var shape := RectangleShape2D.new()
		shape.size = piece_size * 0.75
		var collision := CollisionShape2D.new()
		collision.shape = shape
		chunk.add_child(collision)

		var angle := -PI / 2.0 + randf_range(-PI / 2.0, PI / 2.0)
		var speed := randf_range(150.0, 350.0)
		chunk.linear_velocity = Vector2.from_angle(angle) * speed
		chunk.angular_velocity = randf_range(-8.0, 8.0)

		var tween := chunk.create_tween()
		tween.tween_interval(1.0)
		tween.tween_property(chunk, "modulate:a", 0.0, 0.5)
		tween.tween_callback(chunk.queue_free)

static func _break_opened_chests_near(parent: Node, world_pos: Vector2, radius: float = 120.0) -> void:
	if not is_instance_valid(parent):
		return
	var tree := parent.get_tree()
	if tree == null:
		return
	for chest in tree.get_nodes_in_group("opened_chest"):
		if not is_instance_valid(chest):
			continue
		if chest is Node2D and chest.global_position.distance_to(world_pos) <= radius:
			if chest.has_method("break_as_block"):
				chest.call("break_as_block")

static func _opened_chest_contains_point(chest: Area2D, world_pos: Vector2) -> bool:
	var shape_node := chest.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect_shape := shape_node.shape as RectangleShape2D
		var local_pos := shape_node.global_transform.affine_inverse() * world_pos
		var rect := Rect2(-rect_shape.size * 0.5, rect_shape.size)
		return rect.has_point(local_pos)
	return chest.global_position.distance_to(world_pos) <= 100.0
