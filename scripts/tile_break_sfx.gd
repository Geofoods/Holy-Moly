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

# Explicit mapping: Vector2i(column, row) in atlas -> TileType
# Visually matched to tileset.png (160x160 grid)
const TILE_MAP := {
	# Row 0: terrain surface tiles
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

	# Row 1: underground terrain
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

	# Row 2: stalactite caps
	Vector2i(0, 2): TileType.DIRT,       # empty/dirt
	Vector2i(1, 2): TileType.DIRT,       # empty/dirt
	Vector2i(3, 2): TileType.WOOD,       # tan stalactite top
	Vector2i(4, 2): TileType.CRYSTAL,    # cyan/ice stalactite top
	Vector2i(5, 2): TileType.WOOD,       # orange stalactite top
	Vector2i(6, 2): TileType.CORRUPTED,  # red/corrupted stalactite top
	Vector2i(7, 2): TileType.WOOD,       # stalactite variant
	Vector2i(8, 2): TileType.WOOD,       # stalactite variant

	# Row 3: stalactite bodies
	Vector2i(3, 3): TileType.WOOD,       # tan stalactite body
	Vector2i(4, 3): TileType.CRYSTAL,    # ice stalactite body
	Vector2i(5, 3): TileType.WOOD,       # orange stalactite body
	Vector2i(6, 3): TileType.CORRUPTED,  # corrupted stalactite body
	Vector2i(7, 3): TileType.WOOD,       # stalactite body
	Vector2i(8, 3): TileType.WOOD,       # stalactite body

	# Row 4: stalactite lower
	Vector2i(3, 4): TileType.WOOD,       # tan stalactite lower
	Vector2i(4, 4): TileType.CRYSTAL,    # ice stalactite lower
	Vector2i(5, 4): TileType.WOOD,       # orange stalactite lower
	Vector2i(6, 4): TileType.CORRUPTED,  # corrupted stalactite lower

	# Row 5: large mushrooms
	Vector2i(3, 5): TileType.MUSHROOM,   # orange mushroom
	Vector2i(4, 5): TileType.MUSHROOM,   # orange mushroom
	Vector2i(5, 5): TileType.MUSHROOM,   # dark mushroom
	Vector2i(6, 5): TileType.MUSHROOM,   # dark mushroom
	Vector2i(7, 5): TileType.MUSHROOM,   # cyan mushroom
	Vector2i(8, 5): TileType.MUSHROOM,   # cyan mushroom
	Vector2i(9, 5): TileType.MUSHROOM,   # blue mushroom
	Vector2i(10, 5): TileType.MUSHROOM,  # blue mushroom

	# Row 6: small mushrooms
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

	# Row 7: props + corrupted stalactite tops
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

	# Row 8: props + corrupted stalactites
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

	# Row 9: mushroom caps + corrupted
	Vector2i(0, 9): TileType.CRYSTAL,    # potion
	Vector2i(4, 9): TileType.MUSHROOM,   # tan mushroom cap
	Vector2i(5, 9): TileType.MUSHROOM,   # tan mushroom cap
	Vector2i(6, 9): TileType.MUSHROOM,   # orange mushroom cap
	Vector2i(11, 9): TileType.CORRUPTED, # corrupted stalactite
	Vector2i(12, 9): TileType.CORRUPTED, # corrupted stalactite
	Vector2i(13, 9): TileType.CORRUPTED, # corrupted stalactite

	# Row 10: mushroom caps + corrupted
	Vector2i(5, 10): TileType.MUSHROOM,  # orange mushroom cap
	Vector2i(6, 10): TileType.MUSHROOM,  # corrupted mushroom cap
	Vector2i(11, 10): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(12, 10): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(13, 10): TileType.CORRUPTED,# corrupted stalactite

	# Row 11: mushroom tops + corrupted stalactites
	Vector2i(7, 11): TileType.MUSHROOM,  # blue mushroom cap
	Vector2i(8, 11): TileType.MUSHROOM,  # cyan mushroom cap
	Vector2i(9, 11): TileType.MUSHROOM,  # orange mushroom cap
	Vector2i(10, 11): TileType.MUSHROOM, # yellow mushroom cap
	Vector2i(11, 11): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(12, 11): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(13, 11): TileType.CORRUPTED,# corrupted stalactite

	# Row 12: corrupted mushrooms + stalactites
	Vector2i(8, 12): TileType.MUSHROOM,  # corrupted mushroom
	Vector2i(9, 12): TileType.MUSHROOM,  # corrupted mushroom
	Vector2i(10, 12): TileType.MUSHROOM, # corrupted mushroom
	Vector2i(11, 12): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(12, 12): TileType.CORRUPTED,# corrupted stalactite
	Vector2i(13, 12): TileType.CORRUPTED,# corrupted stalactite

	# Row 13-15: corrupted stalactites
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
	# Row 0
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
	# Row 1
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
	# Row 2: stalactite caps
	Vector2i(3, 2): [Color(0.75, 0.62, 0.42), Color(0.60, 0.48, 0.30)],       # tan
	Vector2i(4, 2): [Color(0.40, 0.80, 0.88), Color(0.55, 0.88, 0.95)],       # cyan
	Vector2i(5, 2): [Color(0.85, 0.60, 0.20), Color(0.70, 0.45, 0.15)],       # orange
	Vector2i(6, 2): [Color(0.65, 0.25, 0.15), Color(0.50, 0.18, 0.10)],       # red corrupted
	# Row 3-4: stalactite bodies
	Vector2i(3, 3): [Color(0.70, 0.58, 0.38), Color(0.55, 0.42, 0.25)],
	Vector2i(4, 3): [Color(0.35, 0.75, 0.85), Color(0.50, 0.85, 0.92)],
	Vector2i(5, 3): [Color(0.80, 0.55, 0.18), Color(0.65, 0.40, 0.12)],
	Vector2i(6, 3): [Color(0.60, 0.22, 0.12), Color(0.45, 0.15, 0.08)],
	Vector2i(3, 4): [Color(0.65, 0.52, 0.35), Color(0.50, 0.38, 0.22)],
	Vector2i(4, 4): [Color(0.35, 0.72, 0.82), Color(0.48, 0.82, 0.90)],
	Vector2i(5, 4): [Color(0.78, 0.52, 0.15), Color(0.62, 0.38, 0.10)],
	Vector2i(6, 4): [Color(0.55, 0.20, 0.10), Color(0.42, 0.14, 0.07)],
	# Row 5-6: mushrooms
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
	# Row 7: props
	Vector2i(0, 7): [Color(0.85, 0.65, 0.20), Color(0.70, 0.50, 0.15)],       # amber potion
	Vector2i(1, 7): [Color(0.82, 0.62, 0.18), Color(0.68, 0.48, 0.12)],
	Vector2i(5, 7): [Color(0.55, 0.50, 0.45), Color(0.40, 0.38, 0.35)],       # gravestone
	# Row 8: props
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
	var source_id := tilemap.get_cell_source_id(0, tile_pos)
	if source_id == -1:
		return
	var atlas_coords := tilemap.get_cell_atlas_coords(0, tile_pos)

	_break_single_tile(tilemap, tile_pos, atlas_coords, parent, force)

	# Also break decoration layer tile at same position
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

static func break_decoration_tile(tilemap: TileMap, tile_pos: Vector2i, parent: Node) -> void:
	_break_decoration_tile(tilemap, tile_pos, parent)

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

	var player := AudioStreamPlayer2D.new()
	player.stream = sound
	player.pitch_scale = randf_range(0.9, 1.1)
	player.volume_db = -8.0
	parent.add_child(player)
	player.global_position = world_pos
	player.play()
	player.finished.connect(player.queue_free)

	spawn_break_particles(tilemap, tile_pos, atlas_coords, parent)
	tilemap.erase_cell(1, tile_pos)

static func _cascade_break(tilemap: TileMap, tiles: Array[Vector2i], parent: Node, index: int) -> void:
	if index >= tiles.size():
		return
	if not is_instance_valid(parent) or parent.get_tree() == null:
		return
	var pos := tiles[index]
	var s := tilemap.get_cell_source_id(0, pos)
	if s != -1:
		var a := tilemap.get_cell_atlas_coords(0, pos)
		_break_single_tile(tilemap, pos, a, parent)
	parent.get_tree().create_timer(0.06).timeout.connect(_cascade_break.bind(tilemap, tiles, parent, index + 1))

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

	var player := AudioStreamPlayer2D.new()
	player.stream = sound
	player.pitch_scale = randf_range(0.9, 1.1)
	player.volume_db = -6.0
	parent.add_child(player)
	player.global_position = world_pos
	player.play()
	player.finished.connect(player.queue_free)

	spawn_break_particles(tilemap, tile_pos, atlas_coords, parent)
	tilemap.erase_cell(0, tile_pos)

static func spawn_break_particles(tilemap: TileMap, tile_pos: Vector2i, atlas_coords: Vector2i, parent: Node) -> void:
	var colors := get_tile_colors(atlas_coords)
	var world_pos := tilemap.to_global(tilemap.map_to_local(tile_pos))

	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 12
	particles.lifetime = 0.6
	parent.add_child(particles)
	particles.global_position = world_pos

	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 350.0
	particles.gravity = Vector2(0, 800)

	particles.angular_velocity_min = -400.0
	particles.angular_velocity_max = 400.0

	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0

	particles.damping_min = 20.0
	particles.damping_max = 40.0

	var fade_color: Color = colors[1]
	fade_color.a = 0.0

	var gradient := Gradient.new()
	gradient.set_color(0, colors[0])
	gradient.set_color(1, fade_color)
	particles.color_ramp = gradient

	particles.get_tree().create_timer(1.5).timeout.connect(particles.queue_free)
