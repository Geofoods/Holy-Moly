extends Node

signal acorn_changed
## Emitted once the saved audio levels are read, so the settings screen (an
## autoload that comes before this one) can pick them up after the fact.
signal audio_settings_loaded

const SAVE_PATH := "user://holy_moley_progress.cfg"

const ACORN_LEVELS: Array[String] = [
	"res://scenes/level1.tscn",
	"res://scenes/level_02.tscn",
	"res://scenes/level_03.tscn",
	"res://scenes/level_04.tscn",
	"res://scenes/level_05.tscn",
	"res://scenes/level_06.tscn",
	"res://scenes/level_07.tscn",
	"res://scenes/level_08.tscn",
	"res://scenes/level_hive.tscn",
	"res://scenes/level_09.tscn",
	"res://scenes/level_10.tscn",
]

## Scenes the title screen must never offer as "Play Last Level".
const _NON_LEVEL_SCENES: Array[String] = [
	"res://scenes/intro.tscn",
	"res://scenes/game_over.tscn",
	"res://scenes/win_screen.tscn",
	"res://scenes/credits.tscn",
]

var acorns := {}
var completed := {}
## Scenes the mole has actually stood in at least once. Gates the map's travel
## list, so a destination cannot be teleported to until it has been walked to.
## Kept apart from `completed`, which means a level was finished - the hub
## scenes have no results screen and so would never appear in it, which would
## leave both travel destinations locked forever.
var visited := {}
var queen_defeated := false
var corrupted_defeated := false
var boss_rush_cleared := false
var arena_completed := false
## Set the first time the mole buys anything from a shop stall, which is the piece
## of progress the shopping quest is keyed to.
var shop_purchased := false
## Set the first time the mole sells something back to a merchant, which is the
## piece of progress the buy-back quest is keyed to.
var item_sold := false
## Set when the final boss's death hands off to the credits, which is the one
## moment that unambiguously means the campaign was finished. The title screen
## gates Boss Rush on this, so it has to survive a quit between beating the boss
## and rolling the credits.
var game_completed := false
var best_combo := 0
## Quest ids whose reward the player has already collected. Kept here rather than
## in the quests manager so reward claiming travels in the same save file as the
## completion flags it is keyed off - a quest cannot be marked done in one file
## and claimed in another.
var claimed_quests := {}

## Quest ids the player has discovered. A quest stays hidden until its area is
## reached, at which point it is written here so the log and the unlock banner
## never replay for a quest already known. Persisted alongside the completion
## flags the quest is keyed off, for the same reason claimed_quests is.
var unlocked_quests := {}

## Quest completions whose "quest completed" banner has already been shown.
## Persisted so the banner does not replay on a later session after reloading
## in the same state.
var completed_banner_shown := {}

## Persisted audio levels (0..1 linear gain) for the SFX and Music buses, so the
## mix the player dials into the settings screen survives a restart. Kept here
## because Progress owns the game's one save file; the screen itself is what
## reads and writes them and pushes them onto the buses.
var sfx_volume := 1.0
var music_volume := 1.0

## Banked respawn station. `respawn_scene` is the scene the mole is set to
## arrive in, and the station in that scene works out the arrival spot from its
## own pad. `respawn_position` is where the mole stood when it banked the pad,
## kept as a record of the banking rather than used to place the arrival.
var respawn_scene := ""
var respawn_position := Vector2.ZERO

## Which station the mole has actually banked, if any. Deliberately separate from
## `respawn_scene`: travel and a death both set that record so the mole has
## somewhere to come back to, but they are not the player activating a pad. A
## station lights up only once this names its scene, so arriving somewhere does
## not light a checkpoint the player has never used.
var respawn_activated := ""

## Last non-menu scene the mole stood in, updated on every scene change and
## persisted, so the title screen can offer "Play Last Level" after a quit.
## Deliberately separate from `respawn_scene`: the checkpoint is where the game
## wants to return you, this is simply where you were.
var last_level_scene := ""

## Transient, never saved. Set when a death or a map teleport sends the mole back
## to the banked station and consumed once by the mole on arrival, so only the
## station the mole is actually arriving at plays the materialise animation.
var respawn_pending := false

## One-shot tutorial prompt, written the first time the mole village loads so the
## "WASD to move" hint greets a new save exactly once. Saved rather than held in
## memory so quitting before the player moves does not bring it back.
var move_hint_seen := false

## Set once the mole has walked out of the tutorial through its exit, which is the
## one moment that means the training is finished. Its NPC stops replaying the
## step-by-step hints on any later visit to the Surface Caves.
var tutorial_done := false

var acorn_total := ACORN_LEVELS.size()

var _hub_layer: CanvasLayer = null
var _hub_label: Label = null

func _ready() -> void:
	load_progress()
	_build_hub_layer()
	get_tree().scene_changed.connect(_on_scene_changed)

## Records arrivals so the travel list can tell a place the mole has been from one
## it has not. Driven off the tree rather than off individual level scripts, so a
## scene cannot be reached by a route that forgets to announce itself. `current_scene`
## is already the incoming one by the time this fires.
func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := str(scene.scene_file_path)
	mark_visited(path)
	if path in _NON_LEVEL_SCENES:
		return
	if path != last_level_scene:
		last_level_scene = path
		save_progress()

func _process(_delta: float) -> void:
	var cs = get_tree().current_scene
	if cs == null:
		return
	var path := str(cs.scene_file_path)
	if _hub_layer != null:
		_hub_layer.visible = path == "res://scenes/map.tscn"
		if _hub_layer.visible and _hub_label != null:
			_hub_label.text = "ACORNS   %d / %d" % [acorns.size(), acorn_total]

func _build_hub_layer() -> void:
	_hub_layer = CanvasLayer.new()
	_hub_layer.name = "AcornHubLayer"
	_hub_layer.layer = 30
	var label := Label.new()
	label.name = "AcornHubLabel"
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.0
	label.offset_left = -250.0
	label.offset_right = 250.0
	label.offset_top = 8.0
	label.offset_bottom = 48.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hub_layer.add_child(label)
	add_child(_hub_layer)
	_hub_layer.visible = false
	_hub_label = label

func has_acorn(path: String) -> bool:
	return acorns.has(path)

func acorn_count() -> int:
	return acorns.size()

func mark_acorn(path: String) -> void:
	if acorns.has(path):
		return
	acorns[path] = true
	save_progress()
	acorn_changed.emit()

func mark_level_complete(path: String) -> void:
	if not path.is_empty():
		completed[path] = true
	save_progress()

func is_level_complete(path: String) -> bool:
	return completed.has(path)

## Notes that the mole has stood in `path`. Idempotent, and only writes to disk
## the first time a scene is seen so arrivals do not rewrite the save each time.
func mark_visited(path: String) -> void:
	if path.is_empty() or visited.has(path):
		return
	visited[path] = true
	save_progress()

## Whether the mole has been to `path` yet, which is what makes it a legal
## teleport destination.
func has_visited(path: String) -> bool:
	return visited.has(path)

## Records that the opening movement hint has been shown. Written on sight
## rather than on dismissal so "never again" holds even if the player quits
## before ever pressing a key.
func mark_move_hint_seen() -> void:
	if not move_hint_seen:
		move_hint_seen = true
		save_progress()

## Records that the tutorial was finished, so its one-shot hints stay quiet if the
## mole ever returns to the Surface Caves.
func mark_tutorial_done() -> void:
	if not tutorial_done:
		tutorial_done = true
		save_progress()

func mark_queen_defeated() -> void:
	if not queen_defeated:
		queen_defeated = true
		save_progress()

func mark_corrupted_defeated() -> void:
	if not corrupted_defeated:
		corrupted_defeated = true
		save_progress()

func mark_boss_rush_cleared() -> void:
	if not boss_rush_cleared:
		boss_rush_cleared = true
		save_progress()

func mark_game_completed() -> void:
	if not game_completed:
		game_completed = true
		save_progress()

## Whether the title screen has a Boss Rush to offer. Kept as a named query so
## the unlock rule lives in one place rather than being re-derived at every call
## site.
func is_game_completed() -> bool:
	return game_completed

func mark_arena_completed() -> void:
	if not arena_completed:
		arena_completed = true
		save_progress()

func is_arena_completed() -> bool:
	return arena_completed

## Records that the mole has bought something from a shop, so the shopping quest
## reads as done. Written the moment the purchase lands, like the other flags.
func mark_shop_purchased() -> void:
	if not shop_purchased:
		shop_purchased = true
		save_progress()

func is_shop_purchased() -> bool:
	return shop_purchased

## Records that the mole has sold something to a merchant, so the buy-back quest
## reads as done. Written the moment the sale lands, like the other flags.
func mark_item_sold() -> void:
	if not item_sold:
		item_sold = true
		save_progress()

func is_item_sold() -> bool:
	return item_sold

## Whether the reward for a quest has already been handed out. Named as a query so
## the claim rule lives with the save that backs it rather than at each call site.
func is_quest_claimed(quest_id: String) -> bool:
	return claimed_quests.has(quest_id)

## Records that a quest's reward has been collected. Written the moment the reward
## lands, so quitting right after claiming does not hand it out twice.
func mark_quest_claimed(quest_id: String) -> void:
	if quest_id.is_empty() or claimed_quests.has(quest_id):
		return
	claimed_quests[quest_id] = true
	save_progress()

## Whether a quest has been discovered yet. The quest log only lists unlocked
## quests, so this is what separates "not found yet" from "found, still to do".
func is_quest_unlocked(quest_id: String) -> bool:
	return unlocked_quests.has(quest_id)

## Records that a quest has been discovered. Written the moment it opens, so the
## unlock banner shows exactly once and the log stays populated on a later launch.
func mark_quest_unlocked(quest_id: String) -> void:
	if quest_id.is_empty() or unlocked_quests.has(quest_id):
		return
	unlocked_quests[quest_id] = true
	save_progress()

func has_completed_banner_shown(quest_id: String) -> bool:
	return completed_banner_shown.has(quest_id)

func mark_completed_banner_shown(quest_id: String) -> void:
	if quest_id.is_empty() or completed_banner_shown.has(quest_id):
		return
	completed_banner_shown[quest_id] = true
	save_progress()

func update_best_combo(value: int) -> void:
	if value > best_combo:
		best_combo = value
		save_progress()

## Stores the sound-effects slider level and writes it to disk, so the mix the
## player set is still there next launch.
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save_progress()

## The music-side twin of set_sfx_volume().
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	save_progress()

func has_respawn() -> bool:
	return not respawn_scene.is_empty() and ResourceLoader.exists(respawn_scene)

## Whether the title screen has a "Play Last Level" to offer: a recorded scene
## that still exists and is not a front-end screen (a stale save may point at a
## deleted or renamed scene).
func has_last_level() -> bool:
	return not last_level_scene.is_empty() \
		and not last_level_scene in _NON_LEVEL_SCENES \
		and ResourceLoader.exists(last_level_scene)

## Banks `scene_path` as the respawn station and remembers the spot the mole
## was standing, then writes both to disk so a checkpoint survives a restart.
func set_respawn(scene_path: String, pos: Vector2) -> void:
	respawn_scene = scene_path
	respawn_position = pos
	save_progress()

## Banks a station for real: the player stood on the pad and activated it. This
## is the only path that lights a checkpoint, so travel's plain set_respawn cannot
## leave a pad glowing that nobody has touched.
func activate_respawn(scene_path: String, pos: Vector2) -> void:
	respawn_activated = scene_path
	set_respawn(scene_path, pos)

func clear_respawn() -> void:
	respawn_scene = ""
	respawn_position = Vector2.ZERO
	respawn_activated = ""
	respawn_pending = false
	save_progress()

## Read-and-clear, so the arrival animation fires exactly once per respawn
## instead of replaying on every scene load afterwards.
func take_respawn_pending() -> bool:
	var pending := respawn_pending
	respawn_pending = false
	return pending

## Restores every persisted progression field to its fresh-save value.
func clear_save_data() -> void:
	acorns.clear()
	completed.clear()
	visited.clear()
	queen_defeated = false
	corrupted_defeated = false
	boss_rush_cleared = false
	arena_completed = false
	game_completed = false
	shop_purchased = false
	item_sold = false
	best_combo = 0
	claimed_quests.clear()
	unlocked_quests.clear()
	completed_banner_shown.clear()
	respawn_scene = ""
	respawn_position = Vector2.ZERO
	respawn_activated = ""
	respawn_pending = false
	move_hint_seen = false
	tutorial_done = false
	last_level_scene = ""
	acorn_changed.emit()
	save_progress()

func save_progress() -> void:
	var cfg := ConfigFile.new()
	for p in acorns:
		cfg.set_value("acorns", p, true)
	for p in completed:
		cfg.set_value("completed", p, true)
	for p in visited:
		cfg.set_value("visited", p, true)
	for p in claimed_quests:
		cfg.set_value("quests", p, true)
	for p in unlocked_quests:
		cfg.set_value("quests_unlocked", p, true)
	for p in completed_banner_shown:
		cfg.set_value("quests_completed_banners", p, true)
	cfg.set_value("bosses", "queen", queen_defeated)
	cfg.set_value("bosses", "corrupted", corrupted_defeated)
	cfg.set_value("bosses", "rush", boss_rush_cleared)
	cfg.set_value("arena", "completed", arena_completed)
	cfg.set_value("meta", "shop_purchased", shop_purchased)
	cfg.set_value("meta", "item_sold", item_sold)
	cfg.set_value("meta", "best_combo", best_combo)
	cfg.set_value("meta", "game_completed", game_completed)
	cfg.set_value("respawn", "scene", respawn_scene)
	cfg.set_value("respawn", "position", respawn_position)
	cfg.set_value("respawn", "activated", respawn_activated)
	cfg.set_value("meta", "last_level_scene", last_level_scene)
	cfg.set_value("meta", "move_hint_seen", move_hint_seen)
	cfg.set_value("meta", "tutorial_done", tutorial_done)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save(SAVE_PATH)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		audio_settings_loaded.emit()
		return
	if cfg.has_section("acorns"):
		for k in cfg.get_section_keys("acorns"):
			acorns[k] = true
	if cfg.has_section("completed"):
		for k in cfg.get_section_keys("completed"):
			completed[k] = true
	if cfg.has_section("visited"):
		for k in cfg.get_section_keys("visited"):
			visited[k] = true
	if cfg.has_section("quests"):
		for k in cfg.get_section_keys("quests"):
			claimed_quests[k] = true
	if cfg.has_section("quests_unlocked"):
		for k in cfg.get_section_keys("quests_unlocked"):
			unlocked_quests[k] = true
	if cfg.has_section("quests_completed_banners"):
		for k in cfg.get_section_keys("quests_completed_banners"):
			completed_banner_shown[k] = true
	queen_defeated = bool(cfg.get_value("bosses", "queen", false))
	corrupted_defeated = bool(cfg.get_value("bosses", "corrupted", false))
	boss_rush_cleared = bool(cfg.get_value("bosses", "rush", false))
	arena_completed = bool(cfg.get_value("arena", "completed", false))
	shop_purchased = bool(cfg.get_value("meta", "shop_purchased", false))
	item_sold = bool(cfg.get_value("meta", "item_sold", false))
	best_combo = int(cfg.get_value("meta", "best_combo", 0))
	game_completed = bool(cfg.get_value("meta", "game_completed", false))
	respawn_scene = str(cfg.get_value("respawn", "scene", ""))
	var pos = cfg.get_value("respawn", "position", Vector2.ZERO)
	if pos is Vector2:
		respawn_position = pos
	respawn_activated = str(cfg.get_value("respawn", "activated", ""))
	last_level_scene = str(cfg.get_value("meta", "last_level_scene", ""))
	move_hint_seen = bool(cfg.get_value("meta", "move_hint_seen", false))
	tutorial_done = bool(cfg.get_value("meta", "tutorial_done", false))
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	audio_settings_loaded.emit()