extends Sprite2D
class_name IceOverlay

## A single patch of ice-bomb frost sitting on top of one tilemap cell. It keeps
## an eye on that cell and melts away as soon as the block underneath it is
## broken, so the ice never stays behind floating over a hole the player dug.
##
## Removal always fades first rather than popping, so the frost reads as melting
## whether it is the blast wearing off or the floor being dug out from under it.

## Short fade for a block being dug away. The ice is only leaving because the
## ground is, so this is quicker than the end-of-blast melt.
const MELT_ON_BREAK_TIME := 0.35

var tilemap: TileMap = null
var cell := Vector2i.ZERO
var _melted := false

func _process(_delta: float) -> void:
	if _melted:
		return
	# Cell lookups are cheap and a patch only lives a few seconds, so checking
	# every frame keeps the ice glued to the block it is sitting on.
	if not is_instance_valid(tilemap) or tilemap.get_cell_source_id(0, cell) == -1:
		fade_out(MELT_ON_BREAK_TIME)

## Melts the patch away over `duration` seconds. Ignores repeat calls, so a
## block dug out partway through the end-of-blast melt does not restart it.
func fade_out(duration: float) -> void:
	if _melted:
		return
	_melted = true
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, maxf(duration, 0.01)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(queue_free)
