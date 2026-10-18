extends Node2D

## Thin drawing surface for the level editor.
##
## It exists as its own node so the grid can sit above the TileMap and the
## placed enemies instead of being painted underneath them. The editor keeps
## the state; this node just forwards the draw callback.

var editor: Node = null


func _draw() -> void:
	if editor != null:
		editor.draw_editor_overlay(self)
