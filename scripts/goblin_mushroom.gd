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
