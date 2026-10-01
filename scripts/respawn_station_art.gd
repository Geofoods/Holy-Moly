extends AnimatedSprite2D

## Artwork for the respawn station, from sprites/checkpoint.png. Plays "default"
## (dark pad, empty lamp) until this station is the banked checkpoint, then
## "lit". The lit state comes from the station node above, so the sprite and the
## world light always agree.

var _station: Node = null

func _ready() -> void:
	light_mask = 2
	_station = get_parent()
	_sync()

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	var lit: bool = _station != null and _station.is_checkpoint_active()
	var anim: StringName = &"lit" if lit else &"default"
	if animation != anim or not is_playing():
		play(anim)
