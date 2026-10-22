extends Node

const AMBIENT := Color(0.42, 0.42, 0.48, 1.0)

var _tracked_scene: Node = null

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene == _tracked_scene:
		return
	_tracked_scene = scene
	var path := str(scene.scene_file_path)
	if path.ends_with("intro.tscn") or path.ends_with("level1.tscn"):
		return
	# The mole village is a surface area like level 1, so it stays lit the
	# same way instead of getting the cave shade campaign levels use.
	if path.ends_with("molevillage.tscn"):
		return
	if path.ends_with("win_screen.tscn") or path.ends_with("game_over.tscn") \
		or path.ends_with("credits.tscn"):
		return
	# The shopkeeper's room is lit by its own candles, so it never gets the
	# cave shade the campaign levels use.
	if path.ends_with("shopkeeper_item.tscn"):
		return
	# The tutorial is an above-ground training area, so it stays fully lit.
	if path.ends_with("tutorial.tscn"):
		return
	# The PvP front end and its arena are bright by design: the lobby is a menu
	# built on a light panel, and the arena has to be read at a glance by everyone
	# in it, so neither takes the cave shade the campaign levels use.
	if path.ends_with("multiplayer_menu.tscn") or path.ends_with("pvp_arena.tscn"):
		return
	# The level editor is a working surface as well as a preview, so it stays
	# fully lit: authoring tiles in cave shade would hide the palette's colours.
	if path.ends_with("level_editor.tscn"):
		return
	# The community level browser is a front end like the title screen it is
	# opened from, so it keeps the same unshaded background.
	if path.ends_with("level_browser.tscn"):
		return
	if scene.get_node_or_null("AmbientModulate") == null:
		var cm := CanvasModulate.new()
		cm.name = "AmbientModulate"
		cm.color = AMBIENT
		scene.add_child(cm)