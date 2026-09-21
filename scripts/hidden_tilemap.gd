extends TileMap

func _ready() -> void:
	for layer in range(get_layers_count()):
		set_layer_enabled(layer, false)