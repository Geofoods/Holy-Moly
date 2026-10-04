extends "res://scripts/bomb.gd"

func _ready() -> void:
	super()
	add_to_group("bullet")
	body_entered.connect(_on_body_entered)
	var mole := get_tree().get_first_node_in_group("mole")
	if mole:
		add_collision_exception_with(mole)

func _on_body_entered(_body: Node) -> void:
	_explode()

## Goblin-thrown blasts must not damage the Corrupted Snail or disrupt its
## scripted boss fight. Player bombs keep their normal behavior.
func _blast_exclusions() -> Array[Node]:
	var exclusions: Array[Node] = []
	for snail in get_tree().get_nodes_in_group(&"snail_boss"):
		if is_instance_valid(snail):
			exclusions.append(snail)
	return exclusions
