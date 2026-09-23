extends Node

## Tracks which tilemap cells are currently frosted by an Ice Bomb so other
## systems (e.g. the mole's movement) can react, such as slipping on ice.

var _frozen: Dictionary = {}

func register(cell: Vector2i, duration: float) -> void:
	var token := (_frozen.get(cell, 0) as int) + 1
	_frozen[cell] = token
	get_tree().create_timer(duration).timeout.connect(func():
		if _frozen.get(cell, 0) == token:
			_frozen.erase(cell)
	)

func is_frozen(cell: Vector2i) -> bool:
	return _frozen.has(cell)
