extends Sprite2D
class_name IceOverlay

## A single patch of ice-bomb frost sitting on top of one tilemap cell. It keeps
## an eye on that cell and removes itself as soon as the block underneath it is
## broken, so the ice never stays behind floating over a hole the player dug.

var tilemap: TileMap = null
var cell := Vector2i.ZERO

func _process(_delta: float) -> void:
	# Cell lookups are cheap and a patch only lives a few seconds, so checking
	# every frame keeps the ice glued to the block it is sitting on.
	if not is_instance_valid(tilemap) or tilemap.get_cell_source_id(0, cell) == -1:
		queue_free()
